import Foundation

// MARK: - Enums

enum RepeatMode: String, Codable, CaseIterable, Hashable {
  case once, daily
  /// On chosen weekdays (`TaskItem.weekdays`).
  case weekdays
  /// A number of times per week, any days (`TaskItem.perWeek`).
  case weekly

  var label: String {
    switch self {
    case .once: "一次"
    case .daily: "每天"
    case .weekdays: "指定星期"
    case .weekly: "每周几次"
    }
  }

  var isRecurring: Bool { self != .once }
}

enum PlanStatus: String, Codable, CaseIterable, Hashable {
  case active, paused, done, archived

  var label: String {
    switch self {
    case .active: "进行中"
    case .paused: "已暂停"
    case .done: "已完成"
    case .archived: "已归档"
    }
  }

  var line: String {
    switch self {
    case .active: "正在前进"
    case .paused: "先停一停，随时可以继续"
    case .done: "已经完成"
    case .archived: "暂时归档"
    }
  }
}

enum ThemeMode: String, Codable, CaseIterable, Identifiable, Hashable {
  case light, dark, system
  var id: String { rawValue }

  var label: String {
    switch self {
    case .light: "浅色"
    case .dark: "深色"
    case .system: "跟随系统"
    }
  }

  var icon: String {
    switch self {
    case .light: "sun.max"
    case .dark: "moon"
    case .system: "circle.lefthalf.filled"
    }
  }
}

enum UISize: String, Codable, CaseIterable, Identifiable, Hashable {
  case compact, standard, large
  var id: String { rawValue }

  var label: String {
    switch self {
    case .compact: "紧凑"
    case .standard: "标准"
    case .large: "大"
    }
  }

  var hint: String {
    switch self {
    case .compact: "更省空间"
    case .standard: "推荐，跟随系统字号"
    case .large: "更易阅读"
    }
  }
}

/// Interface style. Stored under the web version's `cardStyle` key so backups stay compatible.
enum VisualStyle: String, Codable, CaseIterable, Identifiable, Hashable {
  case glass, soft, flat
  var id: String { rawValue }

  var label: String {
    switch self {
    case .glass: "液态玻璃"
    case .soft: "经典柔和"
    case .flat: "经典平面"
    }
  }

  var hint: String {
    switch self {
    case .glass: "iOS 26 原生液态玻璃材质"
    case .soft: "原版 OneDay 的柔和卡片"
    case .flat: "原版 OneDay 的纯净平面"
    }
  }

  var usesGlass: Bool { self == .glass }
}

/// The app's typeface, chosen in 我的 → 字体.
enum FontStyle: String, Codable, CaseIterable, Identifiable, Hashable {
  case system, rounded, journal
  var id: String { rawValue }

  var label: String {
    switch self {
    case .system: "系统字体"
    case .rounded: "圆体"
    case .journal: "手帐体"
    }
  }

  var hint: String {
    switch self {
    case .system: "苹方，和系统 App 一致"
    case .rounded: "数字和英文更圆润，中文仍是苹方"
    case .journal: "霞鹜文楷，像在翻自己的手帐"
    }
  }
}

enum BgTone: String, Codable, CaseIterable, Identifiable, Hashable {
  case warm, cool, gray, meteor
  var id: String { rawValue }

  var label: String {
    switch self {
    case .warm: "暖白"
    case .cool: "冷白"
    case .gray: "浅灰"
    case .meteor: "流星夜"
    }
  }
}

enum HomeModule: String, Codable, CaseIterable, Identifiable, Hashable {
  case hero, tasks, note, onThisDay, progress, plans
  var id: String { rawValue }

  static let defaultOrder: [HomeModule] = [.hero, .tasks, .note, .onThisDay, .plans]
  /// Modules the user can show or hide. Progress now lives in the "今天" header.
  static let choosable: [HomeModule] = allCases.filter { $0 != .progress }

  var title: String {
    switch self {
    case .hero: "问候与日期"
    case .tasks: "今日事项"
    case .note: "值得留下"
    case .onThisDay: "那年今日"
    case .progress: "今日完成情况"
    case .plans: "我的计划"
    }
  }

  var desc: String {
    switch self {
    case .hero: "日期、问候和每日一句"
    case .tasks: "查看并完成今天的事项"
    case .note: "快速记录今天真实的想法"
    case .onThisDay: "往年的今天留下了什么"
    case .progress: "查看当天事项完成进度"
    case .plans: "查看正在进行的长期计划"
    }
  }
}

// MARK: - Records

struct TaskItem: Codable, Identifiable, Hashable {
  var id: String
  var title: String
  var date: String
  var created: String
  var repeatMode: RepeatMode
  var done: [String: Bool]
  /// Reminder time in minutes after midnight.
  var reminder: Int?
  /// The plan this task moves forward, if any.
  var planId: String?
  /// `.weekdays`: 1 = Monday … 7 = Sunday.
  var weekdays: [Int] = []
  /// `.weekly`: how many times a week.
  var perWeek = 0

  enum CodingKeys: String, CodingKey {
    case id, title, date, created, done, reminder, planId, weekdays, perWeek
    case repeatMode = "repeat"
  }

  init(title: String, day: String, repeatMode: RepeatMode, reminder: Int?, planId: String? = nil) {
    id = UUID().uuidString
    self.title = title
    date = day
    created = day
    self.repeatMode = repeatMode
    done = [:]
    self.reminder = reminder
    self.planId = planId
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: AnyKey.self)
    let today = DayKey.today
    id = c.string("id") ?? UUID().uuidString
    title = (c.string("title", "name") ?? "").trimmed
    date = c.string("date") ?? today
    created = c.string("created") ?? c.string("date") ?? today
    repeatMode = c.get("repeat", as: RepeatMode.self) ?? .once
    done = c.get("done", as: [String: Bool].self) ?? [:]
    reminder = c.get("reminder", as: Int.self)
    planId = c.string("planId")
    weekdays = c.get("weekdays", as: LenientArray<Int>.self)?.items ?? []
    perWeek = c.get("perWeek", as: Int.self) ?? 0
  }

  func occurs(on day: String) -> Bool {
    switch repeatMode {
    case .once:
      return date == day
    case .daily:
      return day >= created
    case .weekdays:
      return day >= created && weekdays.contains(DayKey.weekdayIndex(day))
    case .weekly:
      // Shown every day until this week's count is reached (and on the days it was done).
      return day >= created && (isDone(on: day) || doneThisWeek(before: day) < max(perWeek, 1))
    }
  }

  /// Completions earlier in the same Monday-first week, not counting `day`.
  func doneThisWeek(before day: String) -> Int {
    let start = DayKey.weekStart(day)
    var count = 0
    var d = start
    while d < day {
      if isDone(on: d) { count += 1 }
      d = DayKey.add(days: 1, to: d)
    }
    return count
  }

  /// Completions in the week of `day`, including it.
  func doneInWeek(of day: String) -> Int {
    let start = DayKey.weekStart(day)
    return (0..<7).filter { isDone(on: DayKey.add(days: $0, to: start)) }.count
  }

  /// "每天", "周一、三、五", "每周 3 次" or the date.
  var frequencyLabel: String {
    switch repeatMode {
    case .once: return DayKey.shortDate(date)
    case .daily: return "每天"
    case .weekdays: return DayKey.weekdaysLabel(weekdays)
    case .weekly: return "每周 \(max(perWeek, 1)) 次"
    }
  }

  func isDone(on day: String) -> Bool { done[day] == true }

  var completionCount: Int { done.values.filter { $0 }.count }
}

/// A video or voice recording attached to a note; `file` lives in `MediaStore`.
struct MediaItem: Codable, Identifiable, Hashable {
  enum Kind: String, Codable { case video, audio }

  var kind: Kind
  var file: String
  var duration: Double

  var id: String { file }
}

struct NoteEntry: Codable, Identifiable, Hashable {
  var id: String
  /// Markdown text (plain text from the web version renders unchanged).
  var text: String
  var time: String
  /// Photo file names inside `MediaStore` (or `data:` URLs while importing).
  var photos: [String]
  var tags: [String]
  var media: [MediaItem] = []
  var place: String?
  var latitude: Double?
  var longitude: Double?
  var weather: String?
  /// 1 (很糟) … 5 (很好).
  var mood: Int?
  /// The day's 复盘: written from 回顾 → 复盘, at most one per day.
  var isReflection = false

  enum CodingKeys: String, CodingKey {
    case id, text, time, photos, tags, media, place, latitude, longitude, weather, mood
    case isReflection = "reflection"
  }

  init(text: String, time: String, photos: [String], tags: [String]) {
    id = UUID().uuidString
    self.text = text
    self.time = time
    self.photos = photos
    self.tags = tags
  }

  var isEmpty: Bool { text.isEmpty && photos.isEmpty && media.isEmpty }

  init(from decoder: Decoder) throws {
    if let single = try? decoder.singleValueContainer(), let text = try? single.decode(String.self) {
      id = UUID().uuidString
      self.text = text.trimmed
      time = ""
      photos = []
      tags = []
      return
    }
    let c = try decoder.container(keyedBy: AnyKey.self)
    id = c.string("id") ?? UUID().uuidString
    text = (c.string("text", "content", "value") ?? "").trimmed
    time = c.string("time") ?? ""
    photos = c.get("photos", as: LenientArray<String>.self)?.items ?? []
    tags = c.get("tags", as: LenientArray<String>.self)?.items ?? []
    media = c.get("media", as: LenientArray<MediaItem>.self)?.items ?? []
    place = c.string("place")
    latitude = c.get("latitude", as: Double.self)
    longitude = c.get("longitude", as: Double.self)
    weather = c.string("weather")
    mood = c.get("mood", as: Int.self)
    isReflection = c.get("reflection", as: Bool.self) ?? false
  }
}

struct Plan: Codable, Identifiable, Hashable {
  static let colors = ["#287052", "#386b98", "#8057b8", "#c75c88", "#d77b48", "#c9a227", "#3a8f8f", "#68717a"]
  static let icons = [
    "scope", "flag", "star", "heart", "leaf", "book", "figure.run", "dumbbell",
    "brain.head.profile", "graduationcap", "briefcase", "house", "airplane", "music.note", "paintbrush", "dollarsign.circle",
  ]

  var id: String
  var title: String
  var desc: String
  var status: PlanStatus
  var created: String
  var color: String?
  var icon: String?
  var pinned = false
  /// Day the plan was marked done.
  var doneAt: String?

  init(title: String, desc: String) {
    id = UUID().uuidString
    self.title = title
    self.desc = desc
    status = .active
    created = DayKey.today
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: AnyKey.self)
    id = c.string("id") ?? UUID().uuidString
    title = (c.string("title", "name") ?? "").trimmed
    desc = c.string("desc", "description") ?? ""
    status = c.get("status", as: PlanStatus.self) ?? .active
    created = c.string("created") ?? DayKey.today
    color = c.string("color")
    icon = c.string("icon")
    pinned = c.get("pinned", as: Bool.self) ?? false
    doneAt = c.string("doneAt")
  }

  var symbol: String { icon.flatMap { Plan.icons.contains($0) ? $0 : nil } ?? "scope" }
}

// MARK: - Settings

struct NotificationPrefs: Codable, Hashable {
  var enabled = false
  var morning = true
  var morningTime = 8 * 60 + 30
  var evening = true
  var eveningTime = 20 * 60 + 30
  var note = true
  var noteTime = 21 * 60 + 30
  var taskReminders = true
  var badge = true

  init() {}

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: AnyKey.self)
    let d = NotificationPrefs()
    enabled = c.get("enabled") ?? d.enabled
    morning = c.get("morning") ?? d.morning
    morningTime = c.get("morningTime") ?? d.morningTime
    evening = c.get("evening") ?? d.evening
    eveningTime = c.get("eveningTime") ?? d.eveningTime
    note = c.get("note") ?? d.note
    noteTime = c.get("noteTime") ?? d.noteTime
    taskReminders = c.get("taskReminders") ?? d.taskReminders
    badge = c.get("badge") ?? d.badge
  }
}

struct Settings: Codable, Hashable {
  static let defaultName = "OneDay"
  static let defaultSignature = "记录生活，成为更好的自己。"
  static let defaultAccent = "#287052"

  var theme: ThemeMode = .system
  var accent = Settings.defaultAccent
  var customAccent: String?
  var avatar = ""
  var name = Settings.defaultName
  var signature = Settings.defaultSignature
  var quoteMode = "daily"
  var homeModules = HomeModule.defaultOrder
  var uiSize: UISize = .standard
  var cardStyle: VisualStyle = .glass
  var bgTone: BgTone = .warm
  var fontStyle: FontStyle = .system
  /// What 小日 wears (a `MascotOutfit` raw value), if anything.
  var mascotOutfit: String?
  var customTags: [String] = []
  var celebratedDays: [String] = []
  var notifications = NotificationPrefs()

  init() {}

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: AnyKey.self)
    let d = Settings()
    theme = c.get("theme", as: ThemeMode.self) ?? d.theme
    accent = c.string("accent") ?? d.accent
    customAccent = c.string("customAccent")
    avatar = c.string("avatar") ?? ""
    name = c.string("name") ?? d.name
    signature = c.string("signature") ?? d.signature
    quoteMode = c.string("quoteMode") ?? d.quoteMode
    if let raw = c.get("homeModules", as: LenientArray<String>.self)?.items {
      homeModules = raw.compactMap(HomeModule.init(rawValue:))
    }
    uiSize = c.get("uiSize", as: UISize.self) ?? d.uiSize
    cardStyle = c.get("cardStyle", as: VisualStyle.self) ?? d.cardStyle
    bgTone = c.get("bgTone", as: BgTone.self) ?? d.bgTone
    fontStyle = c.get("fontStyle", as: FontStyle.self) ?? d.fontStyle
    mascotOutfit = c.string("mascotOutfit").flatMap { MascotOutfit(rawValue: $0)?.rawValue }
    customTags = c.get("customTags", as: LenientArray<String>.self)?.items ?? []
    celebratedDays = c.get("celebratedDays", as: LenientArray<String>.self)?.items ?? []
    notifications = c.get("notifications", as: NotificationPrefs.self) ?? d.notifications
  }
}

// MARK: - App state

struct AppState: Codable {
  static let defaultTags = ["日常", "心情", "灵感"]

  var tasks: [TaskItem] = []
  var notes: [String: [NoteEntry]] = [:]
  var plans: [Plan] = []
  var settings = Settings()
  /// 每日复盘 by day.
  var dayReflections: [String: DayReflection] = [:]
  /// 一周复盘 by the week's Monday.
  var weekReflections: [String: WeekReflection] = [:]

  init() {}

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: AnyKey.self)
    tasks = c.get("tasks", as: LenientArray<TaskItem>.self)?.items ?? []
    notes = (c.get("notes", as: [String: NoteList].self) ?? [:]).mapValues(\.items)
    plans = c.get("plans", as: LenientArray<Plan>.self)?.items ?? []
    settings = c.get("settings", as: Settings.self) ?? Settings()
    dayReflections = c.get("dayReflections", as: [String: DayReflection].self) ?? [:]
    weekReflections = c.get("weekReflections", as: [String: WeekReflection].self) ?? [:]
  }

  /// Mirrors the web version's `normalize()` so imported and edited data stay valid.
  mutating func normalize() {
    var seen = Set<String>()
    tasks = tasks.compactMap { task in
      var t = task
      t.title = t.title.trimmed
      guard !t.title.isEmpty else { return nil }
      t.id = Self.safeId(t.id, seen: &seen)
      t.done = t.done.filter { $0.value }
      if let r = t.reminder, !(0..<1440).contains(r) { t.reminder = nil }
      t.weekdays = Array(Set(t.weekdays.filter { (1...7).contains($0) })).sorted()
      if t.repeatMode == .weekdays && t.weekdays.isEmpty { t.repeatMode = .daily }
      if t.repeatMode == .weekdays && t.weekdays.count == 7 { t.repeatMode = .daily }
      if t.repeatMode == .weekly { t.perWeek = min(max(t.perWeek, 1), 7) }
      return t
    }
    for (day, list) in notes {
      let cleaned: [NoteEntry] = list.compactMap { entry in
        var n = entry
        n.text = n.text.trimmed
        n.photos = Array(n.photos.filter { !$0.isEmpty }.prefix(6))
        n.media = Array(n.media.filter { !$0.file.isEmpty }.prefix(6))
        n.tags = Array(n.tags.map { String($0.trimmed.prefix(12)) }.filter { !$0.isEmpty }.uniqued().prefix(8))
        if let place = n.place?.trimmed, !place.isEmpty { n.place = place } else { n.place = nil }
        if let mood = n.mood { n.mood = min(max(mood, 1), 5) }
        return n.isEmpty ? nil : n
      }
      notes[day] = cleaned.isEmpty ? nil : cleaned
    }
    plans = plans.compactMap { plan in
      var p = plan
      p.title = p.title.trimmed
      guard !p.title.isEmpty else { return nil }
      p.id = Self.safeId(p.id, seen: &seen)
      if let c = p.color, !HexColor.isValid(c) { p.color = nil }
      if p.status != .done { p.doneAt = nil }
      return p
    }
    // 1.2 kept daily reflections apart from notes; they are now the day's 复盘 note.
    for (day, r) in dayReflections where DayKey.isValid(day) && !r.text.trimmed.isEmpty {
      guard !(notes[day] ?? []).contains(where: \.isReflection) else { continue }
      var note = NoteEntry(text: r.text.trimmed, time: r.updatedAt > 0 ? DayKey.clock(Date(timeIntervalSince1970: r.updatedAt)) : "", photos: [], tags: [])
      note.isReflection = true
      notes[day, default: []].append(note)
    }
    dayReflections = [:]
    // At most one 复盘 per day; any extra becomes an ordinary note.
    for (day, list) in notes where list.filter(\.isReflection).count > 1 {
      var seen = false
      notes[day] = list.map { note in
        var n = note
        if n.isReflection {
          if seen { n.isReflection = false }
          seen = true
        }
        return n
      }
    }
    var weeks: [String: WeekReflection] = [:]
    for (key, r) in weekReflections where DayKey.isValid(key) {
      var r = r
      r.gains = r.gains.trimmed
      r.problems = r.problems.trimmed
      r.next = r.next.trimmed
      if !r.isEmpty { weeks[DayKey.weekStart(key)] = r }
    }
    weekReflections = weeks
    // A task can only point at a plan that still exists.
    let planIds = Set(plans.map(\.id))
    for i in tasks.indices {
      if let id = tasks[i].planId, !planIds.contains(id) { tasks[i].planId = nil }
    }
    var s = settings
    s.name = String(s.name.trimmed.prefix(20))
    if s.name.isEmpty { s.name = Settings.defaultName }
    s.signature = String(s.signature.trimmed.prefix(80))
    if s.signature.isEmpty { s.signature = Settings.defaultSignature }
    if !HexColor.isValid(s.accent) { s.accent = Settings.defaultAccent }
    if let custom = s.customAccent, !HexColor.isValid(custom) { s.customAccent = nil }
    s.quoteMode = s.quoteMode == "static" ? "static" : "daily"
    s.homeModules = s.homeModules.uniqued().filter { $0 != .progress }
    s.customTags = Array(s.customTags.map { String($0.trimmed.prefix(12)) }.filter { !$0.isEmpty }.uniqued().prefix(24))
    s.celebratedDays = Array(s.celebratedDays.uniqued().suffix(60))
    settings = s
  }

  private static func safeId(_ id: String, seen: inout Set<String>) -> String {
    var safe = String(id.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }.prefix(80))
    if safe.isEmpty || seen.contains(safe) { safe = UUID().uuidString }
    seen.insert(safe)
    return safe
  }
}

// MARK: - Derived data

enum DayStatus { case none, partial, all }

struct OverviewItem: Identifiable {
  let id: String
  let title: String
  let count: Int
}

struct MonthOverview {
  var items: [OverviewItem]
  var total: Int
  var noteDays: Int
  var textRecords: Int
  var streak: Int
}

extension AppState {
  func tasks(on day: String) -> [TaskItem] { tasks.filter { $0.occurs(on: day) } }

  func openTasks(on day: String) -> [TaskItem] { tasks(on: day).filter { !$0.isDone(on: day) } }

  func allDone(on day: String) -> Bool {
    let list = tasks(on: day)
    return !list.isEmpty && list.allSatisfy { $0.isDone(on: day) }
  }

  func dayStatus(_ day: String) -> DayStatus {
    let list = tasks(on: day)
    let done = list.filter { $0.isDone(on: day) }.count
    if list.isEmpty || done == 0 { return .none }
    return done == list.count ? .all : .partial
  }

  /// Review dates come only from notes, never from task completion.
  var recordDates: [String] {
    notes.filter { !$0.value.isEmpty }.keys.sorted(by: >)
  }

  func hasNotes(on day: String) -> Bool { !(notes[day] ?? []).isEmpty }

  /// The day's 复盘 note, if written.
  func reflectionNote(on day: String) -> NoteEntry? { notes[day]?.first(where: \.isReflection) }

  /// Notes left during the day (everything but the 复盘).
  func moments(on day: String) -> [NoteEntry] { (notes[day] ?? []).filter { !$0.isReflection } }

  var allTags: [String] {
    Array((Self.defaultTags + settings.customTags).uniqued().prefix(24))
  }

  func isCustomTag(_ tag: String) -> Bool {
    settings.customTags.contains(tag) && !Self.defaultTags.contains(tag)
  }

  /// Active plans, pinned first, otherwise in the user's order.
  var activePlans: [Plan] {
    let active = plans.filter { $0.status == .active }
    return active.filter(\.pinned) + active.filter { !$0.pinned }
  }

  func plan(_ id: String?) -> Plan? {
    guard let id else { return nil }
    return plans.first { $0.id == id }
  }

  var referencedPhotos: Set<String> {
    var names = Set<String>()
    for list in notes.values {
      for note in list {
        names.formUnion(note.photos)
        names.formUnion(note.media.map(\.file))
      }
    }
    if !settings.avatar.isEmpty { names.insert(settings.avatar) }
    return names
  }

  func overview(month: Date) -> MonthOverview {
    let (start, end) = DayKey.monthBounds(month)
    let inMonth: (String) -> Bool = { day in day >= start && day <= end }
    var items: [OverviewItem] = []
    for task in tasks {
      var count = 0
      for (day, done) in task.done where done && inMonth(day) { count += 1 }
      if count > 0 { items.append(OverviewItem(id: task.id, title: task.title, count: count)) }
    }
    items.sort { a, b in
      if a.count != b.count { return a.count > b.count }
      return a.title.localizedCompare(b.title) == .orderedAscending
    }
    var monthNotes: [String: [NoteEntry]] = [:]
    var textRecords = 0
    for (day, list) in notes where inMonth(day) && !list.isEmpty {
      monthNotes[day] = list
      textRecords += list.filter { !$0.text.isEmpty }.count
    }

    var doneDays = Set<String>()
    for t in tasks { for (k, v) in t.done where v && inMonth(k) { doneDays.insert(k) } }
    var best = 0, current = 0
    for day in DayKey.days(inMonth: month) {
      if doneDays.contains(day) {
        current += 1
        best = max(best, current)
      } else {
        current = 0
      }
    }
    return MonthOverview(
      items: items,
      total: items.reduce(0) { $0 + $1.count },
      noteDays: monthNotes.count,
      textRecords: textRecords,
      streak: best
    )
  }
}

// MARK: - Lenient decoding helpers

struct AnyKey: CodingKey {
  var stringValue: String
  var intValue: Int?
  init(_ string: String) { stringValue = string }
  init?(stringValue: String) { self.stringValue = stringValue }
  init?(intValue: Int) {
    stringValue = String(intValue)
    self.intValue = intValue
  }
}

extension KeyedDecodingContainer where K == AnyKey {
  func get<T: Decodable>(_ key: String, as type: T.Type = T.self) -> T? {
    let k = AnyKey(key)
    guard contains(k) else { return nil }
    return try? decode(T.self, forKey: k)
  }

  /// First present string among `keys`; numbers are accepted and stringified.
  func string(_ keys: String...) -> String? {
    for key in keys {
      if let s = get(key, as: String.self) { return s }
      if let n = get(key, as: Double.self) {
        return n.rounded() == n ? String(Int64(n)) : String(n)
      }
    }
    return nil
  }
}

/// Decodes an array, silently skipping elements that fail to decode.
struct LenientArray<T: Decodable>: Decodable {
  var items: [T]

  init(from decoder: Decoder) throws {
    var c = try decoder.unkeyedContainer()
    var out: [T] = []
    while !c.isAtEnd {
      if let v = try? c.decode(T.self) {
        out.append(v)
      } else {
        _ = try? c.decode(Skip.self)
      }
    }
    items = out
  }

  private struct Skip: Decodable {
    init(from decoder: Decoder) throws {}
  }
}

/// The web version stored a day's notes as an array, a single object or a bare string.
struct NoteList: Decodable {
  var items: [NoteEntry]

  init(from decoder: Decoder) throws {
    if let list = try? LenientArray<NoteEntry>(from: decoder) {
      items = list.items
    } else if let one = try? NoteEntry(from: decoder) {
      items = [one]
    } else {
      items = []
    }
  }
}

// MARK: - Small utilities

extension String {
  var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Array where Element: Hashable {
  func uniqued() -> [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
}

enum HexColor {
  static func isValid(_ s: String) -> Bool {
    s.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil
  }
}
