import Foundation

/// A free-form look back at one day (每日复盘).
struct DayReflection: Codable, Hashable {
  var text = ""
  /// Seconds since 1970.
  var updatedAt: Double = 0

  init(text: String = "", updatedAt: Double = Date().timeIntervalSince1970) {
    self.text = text
    self.updatedAt = updatedAt
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: AnyKey.self)
    text = c.string("text") ?? ""
    updatedAt = c.get("updatedAt", as: Double.self) ?? 0
  }
}

/// The weekly look back (一周复盘): three questions on top of the week's numbers.
struct WeekReflection: Codable, Hashable {
  var gains = ""
  var problems = ""
  var next = ""
  var updatedAt: Double = 0

  init(gains: String = "", problems: String = "", next: String = "", updatedAt: Double = Date().timeIntervalSince1970) {
    self.gains = gains
    self.problems = problems
    self.next = next
    self.updatedAt = updatedAt
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: AnyKey.self)
    gains = c.string("gains") ?? ""
    problems = c.string("problems") ?? ""
    next = c.string("next") ?? ""
    updatedAt = c.get("updatedAt", as: Double.self) ?? 0
  }

  var isEmpty: Bool { gains.trimmed.isEmpty && problems.trimmed.isEmpty && next.trimmed.isEmpty }

  /// "下周重点" split into items: one per line, list markers removed.
  var nextItems: [String] {
    next.split(whereSeparator: \.isNewline).map { line in
      var s = Substring(line).drop { $0.isWhitespace }
      if let first = s.first, "•·-*、".contains(first) {
        s = s.dropFirst()
      } else if let dot = s.firstIndex(where: { $0 == "." || $0 == "、" || $0 == ")" || $0 == "）" }),
        s.distance(from: s.startIndex, to: dot) <= 2, s[s.startIndex..<dot].allSatisfy(\.isNumber), dot != s.startIndex {
        s = s[s.index(after: dot)...]
      }
      return String(s).trimmed
    }
    .filter { !$0.isEmpty }
    .uniqued()
  }
}

/// The numbers shown next to a day's reflection.
struct DaySummary {
  let day: String
  let done: [TaskItem]
  let open: [TaskItem]
  let notes: Int
  let mood: Double?

  var total: Int { done.count + open.count }
}

/// One task's week: per weekday `true` done, `false` missed, `nil` not scheduled or still ahead.
struct WeekTaskRow: Identifiable {
  let id: String
  let title: String
  let marks: [Bool?]
  var doneCount: Int { marks.filter { $0 == true }.count }
}

struct WeekPlanRow: Identifiable {
  var id: String { plan.id }
  let plan: Plan
  let completions: Int
}

/// Everything the weekly review shows above its questions.
struct WeekSummary {
  /// Monday … Sunday.
  let days: [String]
  let completions: Int
  /// Same span of last week (to today's weekday when the week is still running).
  let lastWeekCompletions: Int
  /// Scheduled task-days that were done, 0…1; nil when nothing was scheduled.
  let rate: Double?
  let tasks: [WeekTaskRow]
  let moods: [Double?]
  let dayDone: [Int]
  let noteDays: Int
  let reflectionDays: [String]
  let plans: [WeekPlanRow]
  let isCurrent: Bool

  var start: String { days[0] }
  var end: String { days[6] }
  var hasActivity: Bool { completions > 0 || noteDays > 0 || !reflectionDays.isEmpty }
}

extension DayKey {
  /// "10月19日 – 25日" or "9月29日 – 10月5日".
  static func weekRange(_ start: String) -> String {
    let end = add(days: 6, to: start)
    let a = calendar.dateComponents([.month, .day], from: date(start))
    let b = calendar.dateComponents([.month, .day], from: date(end))
    let tail = a.month == b.month ? "\(b.day ?? 0)日" : "\(b.month ?? 0)月\(b.day ?? 0)日"
    return "\(a.month ?? 0)月\(a.day ?? 0)日 – \(tail)"
  }

  static let weekdayLetters = ["一", "二", "三", "四", "五", "六", "日"]
}

extension AppState {
  func daySummary(_ day: String) -> DaySummary {
    let list = tasks(on: day)
    return DaySummary(
      day: day,
      done: list.filter { $0.isDone(on: day) },
      open: list.filter { !$0.isDone(on: day) },
      notes: notes[day]?.count ?? 0,
      mood: mood(on: day))
  }

  func weekSummary(start: String, today: String) -> WeekSummary {
    let monday = DayKey.weekStart(start)
    let days = (0..<7).map { DayKey.add(days: $0, to: monday) }
    let isCurrent = DayKey.weekStart(today) == monday
    let elapsed = days.filter { $0 <= today }

    var completions = 0, last = 0, scheduled = 0, noteDays = 0
    var dayDone: [Int] = []
    for (i, day) in days.enumerated() {
      let doneToday = tasks.filter { $0.isDone(on: day) }.count
      dayDone.append(day <= today ? doneToday : 0)
      guard day <= today else { continue }
      completions += doneToday
      scheduled += tasks(on: day).count
      if hasNotes(on: day) { noteDays += 1 }
      let prev = DayKey.add(days: i - 7, to: monday)
      last += tasks.filter { $0.isDone(on: prev) }.count
    }
    // Tasks completed on a day they were not scheduled for still count as done.
    let scheduledDone = elapsed.reduce(0) { sum, day in sum + tasks(on: day).filter { $0.isDone(on: day) }.count }

    let rows: [WeekTaskRow] = tasks.compactMap { task in
      let marks: [Bool?] = days.map { day in
        guard day <= today else { return nil }
        if task.isDone(on: day) { return true }
        return task.occurs(on: day) ? false : nil
      }
      guard marks.contains(where: { $0 != nil }) else { return nil }
      return WeekTaskRow(id: task.id, title: task.title, marks: marks)
    }

    let plans: [WeekPlanRow] = plans.filter { $0.status == .active || $0.status == .paused }.compactMap { plan in
      let linked = tasks.filter { $0.planId == plan.id }
      guard !linked.isEmpty else { return nil }
      let count = linked.reduce(0) { sum, task in sum + elapsed.filter { task.isDone(on: $0) }.count }
      return WeekPlanRow(plan: plan, completions: count)
    }

    return WeekSummary(
      days: days,
      completions: completions,
      lastWeekCompletions: last,
      rate: scheduled == 0 ? nil : min(1, Double(scheduledDone) / Double(scheduled)),
      tasks: rows,
      moods: days.map { mood(on: $0) },
      dayDone: dayDone,
      noteDays: noteDays,
      reflectionDays: days.filter { dayReflections[$0] != nil },
      plans: plans,
      isCurrent: isCurrent)
  }

  /// Mondays of earlier weeks worth looking back on, newest first (the current week excluded).
  func pastReflectionWeeks(today: String, limit: Int = 52) -> [String] {
    let current = DayKey.weekStart(today)
    var active = Set<String>()
    for task in tasks {
      for (day, done) in task.done where done && day < current { active.insert(DayKey.weekStart(day)) }
    }
    for day in notes.keys where day < current { active.insert(DayKey.weekStart(day)) }
    for day in dayReflections.keys where day < current { active.insert(DayKey.weekStart(day)) }
    for key in weekReflections.keys where key < current { active.insert(key) }
    return Array(active.sorted(by: >).prefix(limit))
  }
}
