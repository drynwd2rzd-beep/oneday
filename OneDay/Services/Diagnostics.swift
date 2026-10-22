import BackgroundTasks
import Foundation
import MetricKit

/// Crash and hang reports from MetricKit, kept on device in Documents/诊断 so the user can
/// share them; nothing is uploaded.
final class Diagnostics: NSObject, MXMetricManagerSubscriber {
  static let shared = Diagnostics()

  var directory: URL { AppFiles.documents.appendingPathComponent("诊断", isDirectory: true) }

  func start() {
    MXMetricManager.shared.add(self)
  }

  func didReceive(_ payloads: [MXDiagnosticPayload]) {
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for payload in payloads {
      let crashes = payload.crashDiagnostics?.count ?? 0
      let hangs = payload.hangDiagnostics?.count ?? 0
      let stamp = ISO8601DateFormatter().string(from: payload.timeStampEnd).replacingOccurrences(of: ":", with: "-")
      let name = "diagnostic-\(stamp)-c\(crashes)-h\(hangs).json"
      try? payload.jsonRepresentation().write(to: directory.appendingPathComponent(name), options: .atomic)
    }
  }

  var reports: [URL] {
    ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
      .filter { $0.pathExtension == "json" }
      .sorted { $0.lastPathComponent > $1.lastPathComponent }
  }

  var crashCount: Int {
    reports.reduce(0) { total, url in
      let part = url.deletingPathExtension().lastPathComponent.split(separator: "-").first { $0.hasPrefix("c") }
      return total + (part.flatMap { Int($0.dropFirst()) } ?? 0)
    }
  }

  func clear() {
    reports.forEach { try? FileManager.default.removeItem(at: $0) }
  }
}

/// Background refresh keeps reminders scheduled and backups current even if the app is not opened.
enum BackgroundRefresh {
  static let identifier = "com.oneday.app.refresh"

  static func schedule() {
    let request = BGAppRefreshTaskRequest(identifier: identifier)
    request.earliestBeginDate = Date().addingTimeInterval(6 * 3600)
    try? BGTaskScheduler.shared.submit(request)
  }

  @MainActor
  static func run() async {
    schedule()
    let store = Store.shared
    store.refreshDay()
    await NotificationManager.shared.reschedule(store.state)
    await BackupManager.shared.backupIfDue(store.state)
  }
}
