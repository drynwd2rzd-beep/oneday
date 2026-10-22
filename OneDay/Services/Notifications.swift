import Foundation
import Observation
import UIKit
import UserNotifications

/// Schedules OneDay's local notifications and tracks permission state.
///
/// Notifications are rebuilt from the current data on every save, so their text always
/// matches the day (for example the evening reminder only exists while tasks are open).
@MainActor
@Observable
final class NotificationManager {
  static let shared = NotificationManager()

  static let taskCategory = "ONEDAY_TASK"
  static let doneAction = "ONEDAY_DONE"
  static let snoozeAction = "ONEDAY_SNOOZE"

  var status: UNAuthorizationStatus = .notDetermined

  @ObservationIgnored private let center = UNUserNotificationCenter.current()
  @ObservationIgnored private var pending: Task<Void, Never>?

  var isAuthorized: Bool {
    status == .authorized || status == .provisional || status == .ephemeral
  }

  func activate() {
    center.delegate = NotificationDelegate.shared
    let done = UNNotificationAction(
      identifier: Self.doneAction, title: "完成", options: [],
      icon: UNNotificationActionIcon(systemImageName: "checkmark.circle"))
    let snooze = UNNotificationAction(
      identifier: Self.snoozeAction, title: "10 分钟后提醒", options: [],
      icon: UNNotificationActionIcon(systemImageName: "clock.arrow.circlepath"))
    center.setNotificationCategories([
      UNNotificationCategory(identifier: Self.taskCategory, actions: [done, snooze], intentIdentifiers: [], options: [])
    ])
    Task { await refreshStatus() }
  }

  func refreshStatus() async {
    status = await center.notificationSettings().authorizationStatus
  }

  func requestAuthorization() async -> Bool {
    let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    await refreshStatus()
    return granted
  }

  /// Debounced so a burst of edits only reschedules once.
  func scheduleRefresh(for state: AppState) {
    pending?.cancel()
    pending = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(400))
      guard !Task.isCancelled, let self else { return }
      await self.reschedule(state)
    }
  }

  func reschedule(_ state: AppState) async {
    let prefs = state.settings.notifications
    // Replace only the planned reminders; snoozed and test notifications stay.
    let planned = await center.pendingNotificationRequests()
      .map(\.identifier)
      .filter { $0.hasPrefix(NotificationPlanner.idPrefix) }
    center.removePendingNotificationRequests(withIdentifiers: planned)
    await refreshStatus()
    guard prefs.enabled, isAuthorized else {
      try? await center.setBadgeCount(0)
      return
    }
    for request in NotificationPlanner.requests(for: state, now: Date()) {
      try? await center.add(request)
    }
    let today = DayKey.today
    try? await center.setBadgeCount(prefs.badge ? state.openTasks(on: today).count : 0)
  }

  func snooze(_ content: UNNotificationContent) {
    guard let copy = content.mutableCopy() as? UNMutableNotificationContent else { return }
    let request = UNNotificationRequest(
      identifier: "oneday.snooze.\(UUID().uuidString)",
      content: copy,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false))
    center.add(request) { _ in }
  }

  func sendTest() {
    let content = UNMutableNotificationContent()
    content.title = "一天"
    content.body = "通知已经开启。每一天，都值得留下。"
    content.sound = .default
    content.userInfo = ["tab": AppTab.me.rawValue]
    let request = UNNotificationRequest(
      identifier: "oneday.test",
      content: content,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false))
    center.add(request) { _ in }
  }
}

/// Builds the concrete notification requests for the coming days.
enum NotificationPlanner {
  static let horizonDays = 10
  /// iOS keeps at most 64 pending local notifications per app.
  static let limit = 60
  static let idPrefix = "oneday.plan."

  static func requests(for state: AppState, now: Date) -> [UNNotificationRequest] {
    let prefs = state.settings.notifications
    let today = DayKey.of(now)
    var items: [(Date, UNNotificationRequest)] = []

    func add(_ id: String, day: String, minutes: Int, configure: (UNMutableNotificationContent) -> Void) {
      guard let fire = DayKey.fireDate(day, minutes: minutes), fire > now else { return }
      let content = UNMutableNotificationContent()
      content.sound = .default
      content.threadIdentifier = "oneday"
      configure(content)
      let comps = DayKey.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
      let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
      items.append((fire, UNNotificationRequest(identifier: idPrefix + id, content: content, trigger: trigger)))
    }

    for offset in 0..<horizonDays {
      let day = DayKey.add(days: offset, to: today)
      let tasks = state.tasks(on: day)
      let open = tasks.filter { !$0.isDone(on: day) }

      if prefs.morning {
        add("morning.\(day)", day: day, minutes: prefs.morningTime) { c in
          c.title = "早上好，新的一天"
          c.body = tasks.isEmpty
            ? "今天还没有安排事项，从一件小事开始吧。"
            : "今天有 \(tasks.count) 件事项：\(names(tasks))"
          c.userInfo = ["tab": AppTab.today.rawValue]
          if prefs.badge { c.badge = NSNumber(value: open.count) }
        }
      }
      if prefs.evening && !open.isEmpty {
        add("evening.\(day)", day: day, minutes: prefs.eveningTime) { c in
          c.title = "还有 \(open.count) 件事项没完成"
          c.body = "\(names(open))。慢一点没关系，方向没有丢就好。"
          c.userInfo = ["tab": AppTab.tasks.rawValue]
          if prefs.badge { c.badge = NSNumber(value: open.count) }
        }
      }
      if prefs.note && !state.hasNotes(on: day) {
        add("note.\(day)", day: day, minutes: prefs.noteTime) { c in
          c.title = "今天有什么值得留下的吗？"
          c.body = "不需要写得很好，只留下真实的你。"
          c.userInfo = ["tab": AppTab.today.rawValue]
        }
      }
      if prefs.taskReminders {
        for task in open {
          guard let minutes = task.reminder else { continue }
          add("task.\(task.id).\(day)", day: day, minutes: minutes) { c in
            c.title = task.title
            c.body = task.repeatMode == .daily ? "每日事项 · 现在是做这件事的好时候。" : "现在是做这件事的好时候。"
            c.categoryIdentifier = NotificationManager.taskCategory
            c.userInfo = ["tab": AppTab.tasks.rawValue, "taskId": task.id, "day": day]
          }
        }
      }
    }
    return items.sorted { $0.0 < $1.0 }.prefix(limit).map { $0.1 }
  }

  private static func names(_ tasks: [TaskItem]) -> String {
    let head = tasks.prefix(3).map(\.title).joined(separator: "、")
    return tasks.count > 3 ? head + " 等" : head
  }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  static let shared = NotificationDelegate()

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let content = response.notification.request.content
    let info = content.userInfo
    let action = response.actionIdentifier
    let tab = info["tab"] as? String
    let taskId = info["taskId"] as? String
    let day = info["day"] as? String
    Task { @MainActor in
      Store.shared.handleNotification(action: action, tab: tab, taskId: taskId, day: day)
      if action == NotificationManager.snoozeAction {
        NotificationManager.shared.snooze(content)
      }
      completionHandler()
    }
  }
}

enum Haptics {
  @MainActor static func tap() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }

  @MainActor static func success() {
    UINotificationFeedbackGenerator().notificationOccurred(.success)
  }

  @MainActor static func warning() {
    UINotificationFeedbackGenerator().notificationOccurred(.warning)
  }
}
