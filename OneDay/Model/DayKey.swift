import Foundation

/// Day keys use the web version's `yyyy-MM-dd` format so string comparison equals date order.
enum DayKey {
  static let calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.locale = Locale(identifier: "zh_CN")
    c.timeZone = .autoupdatingCurrent
    return c
  }()

  static var today: String { of(Date()) }

  static func of(_ date: Date) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
  }

  /// A well-formed `yyyy-MM-dd` key for a real date.
  static func isValid(_ key: String) -> Bool {
    guard key.count == 10 else { return false }
    let parts = key.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3, parts.allSatisfy({ $0.allSatisfy(\.isNumber) }) else { return false }
    return of(date(key)) == key
  }

  /// 1 = Monday … 7 = Sunday.
  static func weekdayIndex(_ key: String) -> Int {
    let weekday = calendar.component(.weekday, from: date(key))  // 1 = Sunday
    return (weekday + 5) % 7 + 1
  }

  /// "周一、三、五", "工作日", "周末", "每天".
  static func weekdaysLabel(_ days: [Int]) -> String {
    let set = Set(days)
    if set == Set(1...7) { return "每天" }
    if set == Set(1...5) { return "工作日" }
    if set == [6, 7] { return "周末" }
    let names = ["一", "二", "三", "四", "五", "六", "日"]
    let parts = set.sorted().map { names[$0 - 1] }
    return parts.isEmpty ? "" : "周" + parts.joined(separator: "、")
  }

  static func date(_ key: String) -> Date {
    let parts = key.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return Date() }
    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? Date()
  }

  static func add(days: Int, to key: String) -> String {
    of(calendar.date(byAdding: .day, value: days, to: date(key)) ?? date(key))
  }

  static func fullDate(_ key: String) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date(key))
    return "\(c.year ?? 0)年\(c.month ?? 0)月\(c.day ?? 0)日"
  }

  static func shortDate(_ key: String) -> String {
    let c = calendar.dateComponents([.month, .day], from: date(key))
    return "\(c.month ?? 0)月\(c.day ?? 0)日"
  }

  static func weekday(_ key: String) -> String {
    let names = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
    return names[(calendar.component(.weekday, from: date(key)) - 1 + 7) % 7]
  }

  static func monthLabel(_ month: Date) -> String {
    let c = calendar.dateComponents([.year, .month], from: month)
    return "\(c.year ?? 0)年\(c.month ?? 0)月"
  }

  static func monthLabel(ofKey key: String) -> String { monthLabel(date(key)) }

  static func monthStart(_ date: Date) -> Date {
    calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
  }

  static func shiftMonth(_ month: Date, by value: Int) -> Date {
    calendar.date(byAdding: .month, value: value, to: monthStart(month)) ?? month
  }

  static func daysInMonth(_ month: Date) -> Int {
    calendar.range(of: .day, in: .month, for: monthStart(month))?.count ?? 30
  }

  /// Leading blank cells for a Sunday-first calendar grid.
  static func leadingBlanks(_ month: Date) -> Int {
    calendar.component(.weekday, from: monthStart(month)) - 1
  }

  static func key(_ month: Date, day: Int) -> String {
    let start = monthStart(month)
    return of(calendar.date(byAdding: .day, value: day - 1, to: start) ?? start)
  }

  static func days(inMonth month: Date) -> [String] {
    (1...daysInMonth(month)).map { key(month, day: $0) }
  }

  static func monthBounds(_ month: Date) -> (String, String) {
    (key(month, day: 1), key(month, day: daysInMonth(month)))
  }

  static func clock(_ date: Date = Date()) -> String {
    let c = calendar.dateComponents([.hour, .minute], from: date)
    return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
  }

  static func clock(minutes: Int) -> String {
    String(format: "%02d:%02d", minutes / 60, minutes % 60)
  }

  static func minutes(of date: Date) -> Int {
    let c = calendar.dateComponents([.hour, .minute], from: date)
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
  }

  static func dateToday(minutes: Int) -> Date {
    calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
  }

  static func fireDate(_ key: String, minutes: Int) -> Date? {
    calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: date(key))
  }
}
