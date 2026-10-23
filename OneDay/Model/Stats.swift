import Foundation

struct TaskStreak: Identifiable {
  let id: String
  let title: String
  /// Consecutive completed days up to today (today may still be open without breaking it).
  let current: Int
  let best: Int
  /// Completion rate over the last 30 days the task existed.
  let rate30: Double
  /// 天 for daily tasks, 次 for chosen weekdays, 周 for so-many-times-a-week.
  var unit = "天"
}

/// How the tasks linked to a plan are going.
struct PlanProgress {
  let tasks: [TaskItem]
  /// All completions of the linked tasks.
  let total: Int
  /// Completions in the last 7 days (including today).
  let lastWeek: Int
  /// Longest current streak among the linked daily tasks.
  let streak: Int
}

struct HeatCell: Identifiable {
  var id: String { day }
  let day: String
  /// 0 = nothing done … 4 = everything done.
  let level: Int
  let done: Int
  let total: Int
  let hasNote: Bool
  let isFuture: Bool
}

struct WeekStat: Identifiable {
  var id: String { start }
  /// Monday of the week.
  let start: String
  let label: String
  let completions: Int
  let noteDays: Int
}

extension DayKey {
  /// Monday of the week containing `key`.
  static func weekStart(_ key: String) -> String {
    let weekday = calendar.component(.weekday, from: date(key)) // 1 = Sunday
    return add(days: -((weekday + 5) % 7), to: key)
  }
}

extension AppState {
  /// Current and best run for a repeating task: days for 每天, scheduled days for 指定星期,
  /// weeks that reached their count for 每周几次. Today (or this week) still open does not
  /// break the run.
  func streak(for task: TaskItem, today: String) -> (current: Int, best: Int) {
    guard task.repeatMode.isRecurring, task.created <= today else {
      let done = task.isDone(on: task.date) ? 1 : 0
      return (done, done)
    }
    var best = 0, run = 0
    if task.repeatMode == .weekly {
      let current = DayKey.weekStart(today)
      var week = DayKey.weekStart(task.created)
      while week <= current {
        if task.doneInWeek(of: week) >= max(task.perWeek, 1) {
          run += 1
          best = max(best, run)
        } else if week != current {
          run = 0
        }
        week = DayKey.add(days: 7, to: week)
      }
      return (run, best)
    }
    var day = task.created
    while day <= today {
      if task.occurs(on: day) {
        if task.isDone(on: day) {
          run += 1
          best = max(best, run)
        } else if day != today {
          run = 0
        }
      }
      day = DayKey.add(days: 1, to: day)
    }
    return (run, best)
  }

  func taskStreaks(today: String) -> [TaskStreak] {
    tasks.filter { $0.repeatMode.isRecurring && $0.created <= today }.map { task in
      let (current, best) = streak(for: task, today: today)
      var considered = 0, done = 0
      for k in 0..<30 {
        let day = DayKey.add(days: -k, to: today)
        guard day >= task.created else { break }
        if day == today && !task.isDone(on: day) { continue }
        guard task.repeatMode == .weekly || task.occurs(on: day) else { continue }
        considered += 1
        if task.isDone(on: day) { done += 1 }
      }
      return TaskStreak(
        id: task.id, title: task.title, current: current, best: best,
        rate30: considered == 0 ? 0 : Double(done) / Double(considered),
        unit: task.repeatMode == .weekly ? "周" : task.repeatMode == .weekdays ? "次" : "天")
    }
    .sorted { $0.current != $1.current ? $0.current > $1.current : $0.best > $1.best }
  }

  /// `weeks` columns of seven days (Monday first), the last column containing `today`.
  func heatmap(today: String, weeks: Int = 53) -> [[HeatCell]] {
    let first = DayKey.add(days: -7 * (weeks - 1), to: DayKey.weekStart(today))
    var columns: [[HeatCell]] = []
    var day = first
    for _ in 0..<weeks {
      var column: [HeatCell] = []
      for _ in 0..<7 {
        let list = tasks(on: day)
        let done = list.filter { $0.isDone(on: day) }.count
        let level: Int
        if list.isEmpty || done == 0 {
          level = 0
        } else {
          let ratio = Double(done) / Double(list.count)
          level = ratio >= 1 ? 4 : ratio >= 0.67 ? 3 : ratio >= 0.34 ? 2 : 1
        }
        column.append(HeatCell(
          day: day, level: day > today ? 0 : level, done: done, total: list.count,
          hasNote: hasNotes(on: day), isFuture: day > today))
        day = DayKey.add(days: 1, to: day)
      }
      columns.append(column)
    }
    return columns
  }

  /// The last `weeks` weeks, oldest first, the last one being the current week.
  func weeklyStats(today: String, weeks: Int = 8) -> [WeekStat] {
    let thisWeek = DayKey.weekStart(today)
    return (0..<weeks).reversed().map { back in
      let start = DayKey.add(days: -7 * back, to: thisWeek)
      var completions = 0, noteDays = 0
      for k in 0..<7 {
        let day = DayKey.add(days: k, to: start)
        guard day <= today else { break }
        completions += tasks.filter { $0.isDone(on: day) }.count
        if hasNotes(on: day) { noteDays += 1 }
      }
      let c = DayKey.calendar.dateComponents([.month, .day], from: DayKey.date(start))
      return WeekStat(start: start, label: "\(c.month ?? 0)/\(c.day ?? 0)", completions: completions, noteDays: noteDays)
    }
  }

  func progress(of plan: Plan, today: String) -> PlanProgress {
    let linked = tasks.filter { $0.planId == plan.id }
    let since = DayKey.add(days: -6, to: today)
    var total = 0, lastWeek = 0, streak = 0
    for task in linked {
      for (day, done) in task.done where done {
        total += 1
        if day >= since && day <= today { lastWeek += 1 }
      }
      if task.repeatMode == .daily { streak = max(streak, self.streak(for: task, today: today).current) }
    }
    return PlanProgress(tasks: linked, total: total, lastWeek: lastWeek, streak: streak)
  }

  /// Completions this week so far vs the same weekdays of last week (a fair comparison mid-week).
  func weekToDate(today: String) -> (thisWeek: Int, lastWeek: Int) {
    let start = DayKey.weekStart(today)
    let lastStart = DayKey.add(days: -7, to: start)
    var this = 0, last = 0
    var offset = 0
    while DayKey.add(days: offset, to: start) <= today && offset < 7 {
      let day = DayKey.add(days: offset, to: start)
      let prev = DayKey.add(days: offset, to: lastStart)
      for task in tasks {
        if task.isDone(on: day) { this += 1 }
        if task.isDone(on: prev) { last += 1 }
      }
      offset += 1
    }
    return (this, last)
  }

  /// Notes written on this month/day in earlier years, newest first.
  func onThisDay(today: String) -> [Memory] {
    let suffix = String(today.dropFirst(4)) // "-MM-dd"
    let year = Int(today.prefix(4)) ?? 0
    return notes
      .filter { $0.key.hasSuffix(suffix) && $0.key < today && !$0.value.isEmpty }
      .map { Memory(day: $0.key, yearsAgo: year - (Int($0.key.prefix(4)) ?? year), notes: $0.value) }
      .sorted { $0.day > $1.day }
  }
}

struct Memory: Identifiable {
  var id: String { day }
  let day: String
  let yearsAgo: Int
  let notes: [NoteEntry]
}
