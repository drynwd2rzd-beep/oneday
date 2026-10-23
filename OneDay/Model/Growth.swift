import Foundation

/// How far 小日 has grown, shown as the sprout on its head.
enum GrowthStage: Int, CaseIterable, Identifiable {
  case sprout, twoLeaves, threeLeaves, bud, bloom, fruit
  var id: Int { rawValue }

  var name: String {
    switch self {
    case .sprout: "小芽"
    case .twoLeaves: "两片叶"
    case .threeLeaves: "三片叶"
    case .bud: "花苞"
    case .bloom: "开花"
    case .fruit: "结果"
    }
  }

  /// Sunshine needed to reach this stage.
  var threshold: Int { [0, 15, 40, 90, 180, 320][rawValue] }

  static func at(_ sunshine: Int) -> GrowthStage {
    allCases.last { sunshine >= $0.threshold } ?? .sprout
  }
}

/// 小日's growth: sunshine only ever adds up, and nothing is lost after a break.
struct Growth {
  /// The day this was worked out for.
  let day: String
  /// All sunshine collected.
  let sunshine: Int
  /// Sunshine collected today.
  let today: Int
  let stage: GrowthStage
  /// Days in a row with something done or written (today may still be open).
  let streak: Int
  let bestStreak: Int
  /// Notes left (not counting 复盘).
  let records: Int
  /// Weekly reviews written.
  let weekReviews: Int
  /// Days when every task of the day was done.
  let allDoneDays: Int
  /// Three or more days without anything done or written.
  let droopy: Bool
  /// This week's challenge.
  let challenge: WeeklyChallenge
  /// Sunshine from finished weekly challenges (included in `sunshine`).
  let challengeBonus: Int

  var next: GrowthStage? { GrowthStage(rawValue: stage.rawValue + 1) }
  var toNext: Int { next.map { $0.threshold - sunshine } ?? 0 }
  var progress: Double {
    guard let next else { return 1 }
    return Double(sunshine - stage.threshold) / Double(next.threshold - stage.threshold)
  }

  /// Progress towards an outfit: (where you are, what it takes).
  func requirement(_ outfit: MascotOutfit) -> (current: Int, target: Int, unit: String) {
    switch outfit {
    case .scarf: (bestStreak, 7, "天")
    case .glasses: (records, 50, "条")
    case .hat: (bestStreak, 30, "天")
    case .halo: (bestStreak, 100, "天")
    case .headset: (sunshine, 100, "阳光")
    case .visor: (weekReviews, 4, "次")
    case .stageMic: (allDoneDays, 20, "天")
    case .cosmos: (sunshine, 500, "阳光")
    case .lunarHat, .bunnyEars, .pumpkin, .santaHat: (Festivals.isWearable(outfit, today: day) ? 1 : 0, 1, "")
    }
  }

  func isUnlocked(_ outfit: MascotOutfit) -> Bool {
    let r = requirement(outfit)
    return r.current >= r.target
  }

  var unlocked: [MascotOutfit] { MascotOutfit.allCases.filter(isUnlocked) }

  /// "连续 12/30 天", "阳光 80/100", "10月28日起" …
  func lockText(_ outfit: MascotOutfit) -> String {
    if outfit.isFestival {
      guard let window = Festivals.window(of: outfit, around: day) else { return "节日限定" }
      return "\(DayKey.shortDate(window.start))起可以戴"
    }
    let r = requirement(outfit)
    let what: String
    switch outfit {
    case .glasses: what = "记录"
    case .headset, .cosmos: what = "阳光"
    case .visor: what = "一周复盘"
    case .stageMic: what = "全部完成"
    default: what = "连续"
    }
    let unit = r.unit == "阳光" ? "" : " " + r.unit
    return "\(what) \(min(r.current, r.target))/\(r.target)\(unit)"
  }

  /// How sunshine is earned, for the growth page.
  static let rules: [(icon: String, title: String, points: String)] = [
    ("checkmark.circle", "完成一件事", "+1，每天最多 5"),
    ("checkmark.seal", "今天的事全部完成", "+2"),
    ("square.and.pencil", "留下一条记录", "+1"),
    ("moon.stars", "写今天的复盘", "+1"),
    ("calendar.badge.clock", "写一周复盘", "+3"),
    ("flag.checkered", "完成每周挑战", "+5"),
  ]
}

extension AppState {
  /// Sunshine earned on one day (weekly reviews are counted separately).
  func sunshine(on day: String) -> Int {
    let done = tasks.filter { $0.isDone(on: day) }.count
    var points = min(done, 5)
    if allDone(on: day) { points += 2 }
    if !moments(on: day).isEmpty { points += 1 }
    if reflectionNote(on: day) != nil { points += 1 }
    return points
  }

  /// Days with something done or written, oldest first.
  var activeDays: [String] {
    var days = Set<String>()
    for task in tasks {
      for (day, done) in task.done where done { days.insert(day) }
    }
    for (day, list) in notes where !list.isEmpty { days.insert(day) }
    return days.sorted()
  }

  func growth(today: String) -> Growth {
    let days = activeDays.filter { $0 <= today }
    let total = days.reduce(0) { $0 + sunshine(on: $1) } + weekReflections.count * 3

    var best = 0, run = 0
    var previous: String?
    for day in days {
      run = previous.map { DayKey.add(days: 1, to: $0) == day } == true ? run + 1 : 1
      best = max(best, run)
      previous = day
    }
    let active = Set(days)
    var current = 0
    var cursor = active.contains(today) ? today : DayKey.add(days: -1, to: today)
    while active.contains(cursor) {
      current += 1
      cursor = DayKey.add(days: -1, to: cursor)
    }
    let droopy = days.last.map { SharedDay.distance(from: $0, to: today) >= 3 } ?? false
    let records = notes.values.reduce(0) { $0 + $1.filter { !$0.isReflection }.count }
    let allDoneDays = days.filter { allDone(on: $0) }.count
    var challengeBonus = 0
    if let first = days.first {
      var week = DayKey.weekStart(first)
      let current = DayKey.weekStart(today)
      while week <= current {
        if challenge(week: week, today: today).done { challengeBonus += WeeklyChallenge.bonus }
        week = DayKey.add(days: 7, to: week)
      }
    }

    return Growth(
      day: today,
      sunshine: total + challengeBonus,
      today: sunshine(on: today),
      stage: .at(total + challengeBonus),
      streak: current,
      bestStreak: best,
      records: records,
      weekReviews: weekReflections.count,
      allDoneDays: allDoneDays,
      droopy: droopy,
      challenge: challenge(week: today, today: today),
      challengeBonus: challengeBonus)
  }
}

// MARK: - Weekly challenge

/// One small goal a week, picked by the week so it is the same all week long.
struct WeeklyChallenge {
  enum Kind: CaseIterable {
    case notes, reflections, moods, activeDays, allDone, completions
  }

  static let bonus = 5

  let week: String
  let kind: Kind
  let target: Int
  let progress: Int

  var done: Bool { progress >= target }

  var title: String {
    switch kind {
    case .notes: "这周写 \(target) 条记录"
    case .reflections: "这周写 \(target) 次每日复盘"
    case .moods: "这周有 \(target) 天记下心情"
    case .activeDays: "这周有 \(target) 天来打卡"
    case .allDone: "这周有 \(target) 天全部完成"
    case .completions: "这周完成 \(target) 次事项"
    }
  }
}

extension AppState {
  func challenge(week day: String, today: String) -> WeeklyChallenge {
    let monday = DayKey.weekStart(day)
    let week = (0..<7).map { DayKey.add(days: $0, to: monday) }
    let elapsed = week.filter { $0 <= today }
    let hasTasks = tasks.contains { task in week.contains { task.occurs(on: $0) } }
    // Task goals only for weeks that have tasks.
    let pool: [WeeklyChallenge.Kind] = hasTasks ? WeeklyChallenge.Kind.allCases : [.notes, .reflections, .moods, .activeDays]
    let seed = Int(monday.filter(\.isNumber)) ?? 0
    let kind = pool[(seed / 7) % pool.count]

    let target: Int
    let progress: Int
    switch kind {
    case .notes:
      target = 3
      progress = elapsed.reduce(0) { $0 + moments(on: $1).count }
    case .reflections:
      target = 2
      progress = elapsed.filter { reflectionNote(on: $0) != nil }.count
    case .moods:
      target = 4
      progress = elapsed.filter { mood(on: $0) != nil }.count
    case .activeDays:
      target = 5
      progress = elapsed.filter { day in hasNotes(on: day) || tasks.contains { $0.isDone(on: day) } }.count
    case .allDone:
      target = 3
      progress = elapsed.filter { allDone(on: $0) }.count
    case .completions:
      target = 10
      progress = elapsed.reduce(0) { sum, day in sum + tasks.filter { $0.isDone(on: day) }.count }
    }
    return WeeklyChallenge(week: monday, kind: kind, target: target, progress: progress)
  }

  /// One-off tasks left undone on an earlier day move to `today`; returns whether any moved.
  mutating func carryOver(to today: String) -> Bool {
    var changed = false
    for i in tasks.indices where tasks[i].repeatMode == .once {
      let task = tasks[i]
      guard task.date < today, !task.done.values.contains(true) else { continue }
      tasks[i].carriedFrom = task.carriedFrom ?? task.date
      tasks[i].date = today
      changed = true
    }
    return changed
  }

  /// What 小日 wears today: a festival outfit only during its week.
  func wornOutfit(today: String) -> MascotOutfit? {
    guard let outfit = settings.mascotOutfit.flatMap(MascotOutfit.init(rawValue:)) else { return nil }
    if outfit.isFestival && !Festivals.isWearable(outfit, today: today) { return nil }
    return outfit
  }

  var plant: MascotPlant { settings.mascotPlant.flatMap(MascotPlant.init(rawValue:)) ?? .cherry }

  /// Last week's 下周重点 that are not already this week's tasks, with that week's Monday.
  func focusThisWeek(today: String) -> (week: String, items: [String])? {
    let lastWeek = DayKey.add(days: -7, to: DayKey.weekStart(today))
    guard let items = weekReflections[lastWeek]?.nextItems, !items.isEmpty else { return nil }
    let monday = DayKey.weekStart(today)
    let taskTitles = Set(tasks.filter { $0.date >= monday || $0.repeatMode.isRecurring }.map(\.title))
    let open = items.filter { !taskTitles.contains($0) }
    return open.isEmpty ? nil : (lastWeek, open)
  }
}

// MARK: - Festivals

/// Festival outfits can be worn from three days before to three days after the day.
/// 春节 and 中秋 follow the Chinese calendar.
enum Festivals {
  private static var cache: [String: String] = [:]

  /// The festival's day in a Gregorian year.
  static func day(of outfit: MascotOutfit, year: Int) -> String? {
    switch outfit {
    case .pumpkin: return String(format: "%04d-10-31", year)
    case .santaHat: return String(format: "%04d-12-25", year)
    case .lunarHat: return lunar(month: 1, day: 1, year: year)
    case .bunnyEars: return lunar(month: 8, day: 15, year: year)
    default: return nil
    }
  }

  /// The current window, or the next one.
  static func window(of outfit: MascotOutfit, around today: String) -> (start: String, end: String)? {
    let year = Int(today.prefix(4)) ?? 2026
    for y in [year - 1, year, year + 1] {
      guard let day = day(of: outfit, year: y) else { continue }
      let end = DayKey.add(days: 3, to: day)
      if end >= today { return (DayKey.add(days: -3, to: day), end) }
    }
    return nil
  }

  static func isWearable(_ outfit: MascotOutfit, today: String) -> Bool {
    guard let w = window(of: outfit, around: today) else { return false }
    return w.start <= today && today <= w.end
  }

  /// Within two weeks of the window, so it is worth showing.
  static func isNear(_ outfit: MascotOutfit, today: String) -> Bool {
    guard let w = window(of: outfit, around: today) else { return false }
    return DayKey.add(days: -14, to: w.start) <= today && today <= w.end
  }

  private static func lunar(month: Int, day: Int, year: Int) -> String? {
    let key = "\(year)-\(month)-\(day)"
    if let cached = cache[key] { return cached }
    var chinese = Calendar(identifier: .chinese)
    chinese.timeZone = DayKey.calendar.timeZone
    var date = DayKey.date(String(format: "%04d-01-01", year))
    for _ in 0..<366 {
      let c = chinese.dateComponents([.month, .day], from: date)
      if c.month == month, c.day == day, c.isLeapMonth != true {
        let found = DayKey.of(date)
        cache[key] = found
        return found
      }
      date = DayKey.calendar.date(byAdding: .day, value: 1, to: date) ?? date
    }
    return nil
  }
}
