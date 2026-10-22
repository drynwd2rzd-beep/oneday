import Foundation
import Observation

/// Backups that survive losing the phone or a mistake:
/// - daily snapshots in the app's Documents folder (visible in the Files app);
/// - an optional backup folder the user picks (iCloud Drive or any Files location),
///   updated automatically with the data and all photos, videos and recordings.
@MainActor
@Observable
final class BackupManager {
  static let shared = BackupManager()

  nonisolated static let dataFile = "oneday.json"
  nonisolated static let mediaFolder = "media"
  nonisolated static let folderName = "OneDay 备份"

  private(set) var folderName: String?
  private(set) var lastBackup: Date?
  private(set) var isWorking = false
  private(set) var lastError: String?

  private let defaults = UserDefaults.standard

  private init() {
    lastBackup = defaults.object(forKey: "backup.last") as? Date
    folderName = defaults.string(forKey: "backup.folderName")
  }

  var hasFolder: Bool { defaults.data(forKey: "backup.bookmark") != nil }

  var snapshotsDirectory: URL { AppFiles.documents.appendingPathComponent("自动备份", isDirectory: true) }

  // MARK: Folder choice

  func setFolder(_ url: URL) {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    do {
      let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
      defaults.set(bookmark, forKey: "backup.bookmark")
      defaults.set(url.lastPathComponent, forKey: "backup.folderName")
      folderName = url.lastPathComponent
      lastError = nil
    } catch {
      lastError = "无法使用这个文件夹：\(error.localizedDescription)"
    }
  }

  func clearFolder() {
    defaults.removeObject(forKey: "backup.bookmark")
    defaults.removeObject(forKey: "backup.folderName")
    folderName = nil
  }

  private func resolveFolder() -> URL? {
    guard let data = defaults.data(forKey: "backup.bookmark") else { return nil }
    var stale = false
    guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
    if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
      defaults.set(fresh, forKey: "backup.bookmark")
    }
    return url
  }

  // MARK: Running backups

  /// Called when the app goes to the background and from background refresh.
  func backupIfDue(_ state: AppState) async {
    writeDailySnapshot(state)
    guard hasFolder else { return }
    if let last = lastBackup, Date().timeIntervalSince(last) < 6 * 3600 { return }
    await backupNow(state)
  }

  @discardableResult
  func backupNow(_ state: AppState) async -> Bool {
    writeDailySnapshot(state)
    guard let folder = resolveFolder() else {
      lastError = "还没有选择备份文件夹"
      return false
    }
    isWorking = true
    defer { isWorking = false }
    let result = await Task.detached(priority: .utility) {
      Result { try Self.writeBackup(state, into: folder) }
    }.value
    switch result {
    case .success:
      lastBackup = Date()
      defaults.set(lastBackup, forKey: "backup.last")
      lastError = nil
      return true
    case .failure(let error):
      lastError = "备份失败：\(error.localizedDescription)"
      return false
    }
  }

  /// Writes `<folder>/OneDay 备份/` with the data file, media files and dated history.
  nonisolated static func writeBackup(_ state: AppState, into folder: URL) throws {
    let access = folder.startAccessingSecurityScopedResource()
    defer { if access { folder.stopAccessingSecurityScopedResource() } }
    let root = folder.appendingPathComponent(folderName, isDirectory: true)
    var coordinationError: NSError?
    var thrown: Error?
    NSFileCoordinator().coordinate(writingItemAt: root, options: [], error: &coordinationError) { url in
      do { try writePackage(state, to: url, keepHistory: true) } catch { thrown = error }
    }
    if let error = coordinationError ?? thrown { throw error }
  }

  /// A self-contained backup package: `oneday.json` plus `media/`. Also used for exports.
  nonisolated static func writePackage(_ state: AppState, to root: URL, keepHistory: Bool) throws {
    let fm = FileManager.default
    let media = root.appendingPathComponent(mediaFolder, isDirectory: true)
    try fm.createDirectory(at: media, withIntermediateDirectories: true)
    let existing = Set((try? fm.contentsOfDirectory(atPath: media.path)) ?? [])
    for name in state.referencedPhotos where !existing.contains(name) && MediaStore.exists(name) {
      try fm.copyItem(at: MediaStore.url(name), to: media.appendingPathComponent(name))
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(state)
    try data.write(to: root.appendingPathComponent(dataFile), options: .atomic)
    if keepHistory {
      let history = root.appendingPathComponent("history", isDirectory: true)
      try fm.createDirectory(at: history, withIntermediateDirectories: true)
      try data.write(to: history.appendingPathComponent("oneday-\(DayKey.today).json"), options: .atomic)
      prune(history, keep: 14)
    }
  }

  /// One JSON snapshot per day in Documents/自动备份, keeping the last seven.
  func writeDailySnapshot(_ state: AppState) {
    let fm = FileManager.default
    try? fm.createDirectory(at: snapshotsDirectory, withIntermediateDirectories: true)
    let url = snapshotsDirectory.appendingPathComponent("oneday-\(DayKey.today).json")
    if let data = try? JSONEncoder().encode(state) {
      try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    Self.prune(snapshotsDirectory, keep: 7)
  }

  var snapshots: [URL] {
    let files = (try? FileManager.default.contentsOfDirectory(at: snapshotsDirectory, includingPropertiesForKeys: nil)) ?? []
    return files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
  }

  nonisolated private static func prune(_ dir: URL, keep: Int) {
    let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
      .filter { $0.pathExtension == "json" }
      .sorted { $0.lastPathComponent > $1.lastPathComponent }
    for old in files.dropFirst(keep) { try? FileManager.default.removeItem(at: old) }
  }

  // MARK: Export / restore

  /// Builds a full backup folder in a temporary location for the user to save anywhere.
  nonisolated static func makeExportPackage(_ state: AppState) throws -> URL {
    let stamp = DayKey.today
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
      .appendingPathComponent("OneDay 备份 \(stamp)", isDirectory: true)
    try writePackage(state, to: dir, keepHistory: false)
    return dir
  }

  /// Reads a backup folder (from this app), the backup folder's root, or a single JSON file
  /// (this app's or the web version's).
  nonisolated static func readBackup(at url: URL) throws -> AppState {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    var isDir: ObjCBool = false
    FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
    var jsonURL = url
    var mediaDir: URL?
    if isDir.boolValue {
      let nested = url.appendingPathComponent(folderName, isDirectory: true)
      let base = FileManager.default.fileExists(atPath: nested.appendingPathComponent(dataFile).path) ? nested : url
      jsonURL = base.appendingPathComponent(dataFile)
      mediaDir = base.appendingPathComponent(mediaFolder, isDirectory: true)
    }
    let data = try Data(contentsOf: jsonURL)
    return try Persistence.parseBackup(data, mediaDirectory: mediaDir)
  }
}
