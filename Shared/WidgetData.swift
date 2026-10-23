import Foundation

/// One task as the widget shows it.
struct WidgetTask: Codable, Hashable, Identifiable {
  var id: String
  var title: String
  var done: Bool
  var daily: Bool
  /// Plan color (hex), if the task belongs to a plan.
  var color: String?
}

/// What the app hands to the widget: a small, self-contained picture of today (and tomorrow,
/// so the widget is right after midnight even before the app runs again).
struct WidgetSnapshot: Codable, Hashable {
  var day: String
  var today: [WidgetTask]
  var tomorrow: [WidgetTask]
  var accent: String
  var streakTitle: String?
  var streakDays: Int
  var mood: Int?
  var wroteToday: Bool
  /// Completions for the last seven days, oldest first, ending with `day`.
  var week: [Int]
  /// 小日 as in the app (growth stage, outfit, droopy); nil in snapshots from before 1.6.
  var stage: Int?
  var outfit: String?
  var droopy: Bool?
  var plant: String?

  var doneCount: Int { today.filter(\.done).count }
  var total: Int { today.count }
  var progress: Double { total == 0 ? 0 : Double(doneCount) / Double(total) }
  var allDone: Bool { total > 0 && doneCount == total }
  var next: WidgetTask? { today.first { !$0.done } }

  /// The snapshot as it should look on `day`: after midnight tomorrow's list becomes today's.
  func resolved(for day: String) -> WidgetSnapshot {
    guard day > self.day else { return self }
    var s = self
    s.day = day
    s.today = (day == SharedDay.add(1, to: self.day) ? tomorrow : tomorrow.filter(\.daily))
      .map { var t = $0; t.done = false; return t }
    s.tomorrow = s.today.filter(\.daily)
    s.mood = nil
    s.wroteToday = false
    let gap = min(7, SharedDay.distance(from: self.day, to: day))
    s.week = Array((week + Array(repeating: 0, count: gap)).suffix(7))
    return s
  }

  static let sample = WidgetSnapshot(
    day: SharedDay.key(Date()),
    today: [
      WidgetTask(id: "1", title: "阅读 20 分钟", done: true, daily: true, color: "#287052"),
      WidgetTask(id: "2", title: "散步 30 分钟", done: true, daily: true, color: nil),
      WidgetTask(id: "3", title: "喝 8 杯水", done: false, daily: true, color: nil),
      WidgetTask(id: "4", title: "整理房间", done: false, daily: false, color: nil),
    ],
    tomorrow: [],
    accent: "#287052",
    streakTitle: "阅读 20 分钟",
    streakDays: 12,
    mood: 4,
    wroteToday: false,
    week: [3, 2, 4, 3, 1, 3, 2])

  static let empty = WidgetSnapshot(
    day: SharedDay.key(Date()), today: [], tomorrow: [], accent: "#287052",
    streakTitle: nil, streakDays: 0, mood: nil, wroteToday: false, week: Array(repeating: 0, count: 7))
}

/// `yyyy-MM-dd` keys, matching the app's DayKey, for code shared with the widget.
enum SharedDay {
  static let calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.locale = Locale(identifier: "zh_CN")
    c.timeZone = .autoupdatingCurrent
    return c
  }()

  static func key(_ date: Date) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
  }

  static func date(_ key: String) -> Date {
    let parts = key.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return Date() }
    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? Date()
  }

  static func add(_ days: Int, to key: String) -> String {
    Self.key(calendar.date(byAdding: .day, value: days, to: date(key)) ?? date(key))
  }

  static func distance(from a: String, to b: String) -> Int {
    calendar.dateComponents([.day], from: date(a), to: date(b)).day ?? 0
  }
}

/// A task ticked off on the widget, waiting for the app to apply it.
struct WidgetToggle: Codable, Hashable {
  var taskId: String
  var day: String
  var done: Bool
}

/// The App Group container shared by the app and the widget.
///
/// Sideloading tools re-sign with their own App Group ids (AltStore and SideStore list them
/// under `ALTAppGroups` in the app's Info.plist), so every candidate is tried.
enum SharedData {
  static let defaultGroup = "group.com.oneday.app"

  /// App Group ids to try, most trustworthy first. Sideloading tools re-sign with their own
  /// ids: the provisioning profile inside the bundle says which ones were really granted, and
  /// AltStore/SideStore also list theirs under `ALTAppGroups`. The app's bundle is read first
  /// in both processes so the app and the widget settle on the same group.
  static let candidateGroups: [String] = {
    var ids: [String] = []
    let bundles = [hostAppBundle, Bundle.main].compactMap { $0 }
    for bundle in bundles { ids += provisionedGroups(in: bundle) }
    for bundle in bundles {
      if let alt = bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] { ids += alt }
    }
    if let id = (hostAppBundle ?? Bundle.main).bundleIdentifier { ids.append("group." + id) }
    ids.append(defaultGroup)
    var seen = Set<String>()
    return ids.filter { seen.insert($0).inserted }
  }()

  /// The group in use and its folder, or nil when this build has no App Group at all.
  static let group: (id: String, url: URL)? = {
    for id in candidateGroups {
      if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) { return (id, url) }
    }
    return nil
  }()

  static var containerURL: URL? { group?.url }

  /// App Groups granted by `embedded.mobileprovision` (a signed envelope around a plist).
  static func provisionedGroups(in bundle: Bundle) -> [String] {
    guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
      let data = try? Data(contentsOf: url)
    else { return [] }
    return provisionedGroups(fromProfile: data)
  }

  static func provisionedGroups(fromProfile data: Data) -> [String] {
    guard let start = data.range(of: Data("<?xml".utf8)),
      let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
      let plist = try? PropertyListSerialization.propertyList(
        from: data.subdata(in: start.lowerBound..<end.upperBound), format: nil) as? [String: Any],
      let entitlements = plist["Entitlements"] as? [String: Any],
      let groups = entitlements["com.apple.security.application-groups"] as? [String]
    else { return [] }
    return groups.filter { !$0.contains("*") }
  }

  /// The app bundle when running inside the widget extension (`OneDay.app/PlugIns/X.appex`).
  private static var hostAppBundle: Bundle? {
    let url = Bundle.main.bundleURL
    guard url.pathExtension == "appex" else { return nil }
    return Bundle(url: url.deletingLastPathComponent().deletingLastPathComponent())
  }

  private static var snapshotURL: URL? { containerURL?.appendingPathComponent("widget-snapshot.json") }
  private static var togglesURL: URL? { containerURL?.appendingPathComponent("widget-toggles.json") }

  static func loadSnapshot() -> WidgetSnapshot? {
    guard let url = snapshotURL, let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
  }

  /// Writes the snapshot; returns false when nothing changed (so widgets need no reload).
  @discardableResult
  static func save(_ snapshot: WidgetSnapshot) -> Bool {
    guard let url = snapshotURL, let data = try? JSONEncoder().encode(snapshot) else { return false }
    if let old = try? Data(contentsOf: url), old == data { return false }
    try? data.write(to: url, options: .atomic)
    return true
  }

  static func pendingToggles() -> [WidgetToggle] {
    guard let url = togglesURL, let data = try? Data(contentsOf: url) else { return [] }
    return (try? JSONDecoder().decode([WidgetToggle].self, from: data)) ?? []
  }

  static func clearToggles() {
    guard let url = togglesURL else { return }
    try? FileManager.default.removeItem(at: url)
  }

  /// Ticks a task on the widget: updates the snapshot right away and queues it for the app.
  static func toggle(taskId: String, day: String) {
    guard var snapshot = loadSnapshot()?.resolved(for: SharedDay.key(Date())),
      snapshot.day == day,
      let i = snapshot.today.firstIndex(where: { $0.id == taskId })
    else { return }
    snapshot.today[i].done.toggle()
    let done = snapshot.today[i].done
    if let last = snapshot.week.indices.last { snapshot.week[last] = max(0, snapshot.week[last] + (done ? 1 : -1)) }
    save(snapshot)
    var toggles = pendingToggles().filter { !($0.taskId == taskId && $0.day == day) }
    toggles.append(WidgetToggle(taskId: taskId, day: day, done: done))
    if let url = togglesURL, let data = try? JSONEncoder().encode(toggles) {
      try? data.write(to: url, options: .atomic)
    }
  }
}
