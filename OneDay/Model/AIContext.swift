import Foundation

extension AppState {
  /// The last `days` days in plain text for 小日 to read: tasks, mood, notes and reviews.
  func aiContext(today: String, days: Int = 14) -> String {
    var out: [String] = []
    out.append("今天是 \(DayKey.fullDate(today)) \(DayKey.weekday(today))。")
    let growth = growth(today: today)
    out.append("小日现在是「\(growth.stage.name)」，连续活跃 \(growth.streak) 天，最长 \(growth.bestStreak) 天。")
    let plans = activePlans.map(\.title)
    if !plans.isEmpty { out.append("进行中的计划：" + plans.joined(separator: "、")) }
    out.append("")
    out.append("最近 \(days) 天（从近到远）：")
    for offset in 0..<days {
      let day = DayKey.add(days: -offset, to: today)
      let list = tasks(on: day)
      let notes = moments(on: day)
      let reflection = reflectionNote(on: day)
      let mood = mood(on: day).flatMap(Mood.init(average:))
      guard !list.isEmpty || !notes.isEmpty || reflection != nil || mood != nil else { continue }
      var head = "\(DayKey.shortDate(day)) \(DayKey.weekday(day))"
      if let mood { head += "｜心情：\(mood.label)" }
      if !list.isEmpty {
        let done = list.filter { $0.isDone(on: day) }
        head += "｜事项 \(done.count)/\(list.count)："
        head += list.map { "\($0.title)\($0.isDone(on: day) ? "✓" : "✗")" }.joined(separator: "，")
      }
      out.append(head)
      for note in notes where !note.text.isEmpty {
        out.append("  记录：「\(Self.clip(note.text, 300))」")
      }
      if let reflection, !reflection.text.isEmpty {
        out.append("  复盘：「\(Self.clip(reflection.text, 300))」")
      }
    }
    let thisWeek = DayKey.weekStart(today)
    for week in [thisWeek, DayKey.add(days: -7, to: thisWeek)] {
      guard let r = weekReflections[week] else { continue }
      out.append("")
      out.append("一周复盘（\(DayKey.weekRange(week))）：")
      if !r.gains.isEmpty { out.append("  收获：\(Self.clip(r.gains, 300))") }
      if !r.problems.isEmpty { out.append("  问题：\(Self.clip(r.problems, 300))") }
      if !r.next.isEmpty { out.append("  下周重点：\(Self.clip(r.next, 200))") }
    }
    return out.joined(separator: "\n")
  }

  private static func clip(_ text: String, _ limit: Int) -> String {
    let flat = text.replacingOccurrences(of: "\n", with: " ")
    return flat.count > limit ? String(flat.prefix(limit)) + "…" : flat
  }
}
