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
    }
  }

  func isUnlocked(_ outfit: MascotOutfit) -> Bool {
    let r = requirement(outfit)
    return r.current >= r.target
  }

  var unlocked: [MascotOutfit] { MascotOutfit.allCases.filter(isUnlocked) }

  /// "连续 12/30 天", "阳光 80/100" …
  func lockText(_ outfit: MascotOutfit) -> String {
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

    return Growth(
      sunshine: total,
      today: sunshine(on: today),
      stage: .at(total),
      streak: current,
      bestStreak: best,
      records: records,
      weekReviews: weekReflections.count,
      allDoneDays: allDoneDays,
      droopy: droopy)
  }
}
