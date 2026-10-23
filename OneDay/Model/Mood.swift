import Foundation

/// Five moods, from 很糟 to 很好.
enum Mood: Int, CaseIterable, Identifiable {
  case awful = 1, bad, okay, good, great
  var id: Int { rawValue }

  var emoji: String {
    switch self {
    case .awful: "😞"
    case .bad: "🙁"
    case .okay: "😐"
    case .good: "🙂"
    case .great: "😄"
    }
  }

  var label: String {
    switch self {
    case .awful: "很糟"
    case .bad: "不太好"
    case .okay: "一般"
    case .good: "不错"
    case .great: "很好"
    }
  }

  /// Soft, paper-friendly colors from cool (low) to warm (high).
  var hex: String {
    switch self {
    case .awful: "#7b8aa3"
    case .bad: "#9fb0c8"
    case .okay: "#c8b98f"
    case .good: "#e6a96b"
    case .great: "#e07f52"
    }
  }

  init?(average: Double) {
    self.init(rawValue: Int(average.rounded()))
  }
}

struct MoodPoint: Identifiable {
  var id: String { day }
  let day: String
  let value: Double
}

struct CountedItem: Identifiable {
  var id: String { name }
  let name: String
  let count: Int
}

/// Everything shown on a month's recap card.
struct MonthRecap {
  let month: Date
  let recordDays: Int
  let notes: Int
  let characters: Int
  let photos: [String]
  let videos: Int
  let recordings: Int
  let completions: Int
  let topPlaces: [CountedItem]
  let topTags: [CountedItem]
  let moodAverage: Double?
  let moodCounts: [Int: Int]
  let bestStreak: (title: String, days: Int)?
  let highlight: (day: String, text: String)?

  var isEmpty: Bool { recordDays == 0 && completions == 0 }
}

extension AppState {
  /// Average mood of a day's notes, if any were given one.
  /// The day's overall mood when one was chosen, otherwise the average of its notes' moods.
  func mood(on day: String) -> Double? {
    if let overall = dayMoods[day] { return Double(overall) }
    let values = (notes[day] ?? []).compactMap(\.mood)
    guard !values.isEmpty else { return nil }
    return Double(values.reduce(0, +)) / Double(values.count)
  }

  /// Daily mood for the last `days` days (only days with a mood), oldest first.
  func moodSeries(today: String, days: Int = 30) -> [MoodPoint] {
    (0..<days).reversed().compactMap { back in
      let day = DayKey.add(days: -back, to: today)
      return mood(on: day).map { MoodPoint(day: day, value: $0) }
    }
  }

  func recap(month: Date) -> MonthRecap {
    let (start, end) = DayKey.monthBounds(month)
    let days = notes.keys.filter { $0 >= start && $0 <= end }.sorted()
    let monthNotes = days.flatMap { day in (notes[day] ?? []).map { (day, $0) } }

    var places: [String: Int] = [:]
    var tags: [String: Int] = [:]
    var moods: [Int: Int] = [:]
    var characters = 0, videos = 0, recordings = 0
    var photos: [String] = []
    var highlight: (day: String, text: String)?
    for (day, note) in monthNotes {
      characters += note.text.count
      photos += note.photos
      videos += note.media.filter { $0.kind == .video }.count
      recordings += note.media.filter { $0.kind == .audio }.count
      if let place = note.place { places[place, default: 0] += 1 }
      for tag in note.tags { tags[tag, default: 0] += 1 }
      // The longest note of the month is its highlight.
      if note.text.count > (highlight?.text.count ?? 0) { highlight = (day, note.text) }
    }

    let ranked = { (dict: [String: Int]) in
      dict.map { CountedItem(name: $0.key, count: $0.value) }
        .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }
    // One mood per day, whether chosen for the day or taken from its notes.
    for day in DayKey.days(inMonth: month) {
      if let value = mood(on: day), let face = Mood(average: value) { moods[face.rawValue, default: 0] += 1 }
    }
    let moodTotal = moods.reduce(0) { $0 + $1.key * $1.value }
    let moodCount = moods.values.reduce(0, +)

    var best: (title: String, days: Int)?
    let monthDays = DayKey.days(inMonth: month)
    for task in tasks where task.repeatMode == .daily {
      var run = 0, longest = 0
      for day in monthDays {
        if task.isDone(on: day) {
          run += 1
          longest = max(longest, run)
        } else {
          run = 0
        }
      }
      if longest > (best?.days ?? 0) { best = (task.title, longest) }
    }

    return MonthRecap(
      month: DayKey.monthStart(month),
      recordDays: days.count,
      notes: monthNotes.count,
      characters: characters,
      photos: photos,
      videos: videos,
      recordings: recordings,
      completions: overview(month: month).total,
      topPlaces: Array(ranked(places).prefix(3)),
      topTags: Array(ranked(tags).prefix(3)),
      moodAverage: moodCount == 0 ? nil : Double(moodTotal) / Double(moodCount),
      moodCounts: moods,
      bestStreak: best,
      highlight: highlight)
  }

  /// All photos, newest day first, with the day they belong to.
  var photoTimeline: [(day: String, photo: String)] {
    recordDates.flatMap { day in (notes[day] ?? []).flatMap { note in note.photos.map { (day, $0) } } }
  }
}
