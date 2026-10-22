import UIKit
import XCTest
@testable import OneDay

/// Statistics, reminders and backups.
final class FeatureTests: XCTestCase {
  let today = "2026-10-22"

  func testStreaks() {
    var s = AppState()
    var t = TaskItem(title: "阅读", day: "2026-10-10", repeatMode: .daily, reminder: nil)
    for k in 0...4 { t.done[DayKey.add(days: k, to: "2026-10-10")] = true }
    for k in 6...11 { t.done[DayKey.add(days: k, to: "2026-10-10")] = true }
    s.tasks = [t]
    var r = s.streak(for: t, today: today)
    XCTAssertEqual(r.current, 6, "an open today does not break the streak")
    XCTAssertEqual(r.best, 6)
    t.done["2026-10-21"] = nil
    r = s.streak(for: t, today: today)
    XCTAssertEqual(r.current, 0)
    XCTAssertEqual(r.best, 5)
  }

  func testHeatmapAndWeeks() {
    var s = AppState()
    s.tasks = [TaskItem(title: "a", day: "2026-01-01", repeatMode: .daily, reminder: nil),
               TaskItem(title: "b", day: "2026-01-01", repeatMode: .daily, reminder: nil)]
    s.tasks[0].done["2026-10-20"] = true
    s.tasks[0].done["2026-10-21"] = true
    s.tasks[1].done["2026-10-21"] = true
    let grid = s.heatmap(today: today, weeks: 53)
    XCTAssertEqual(grid.count, 53)
    XCTAssertEqual(grid.last?.first?.day, "2026-10-19")
    XCTAssertEqual(grid.last?[1].level, 2)
    XCTAssertEqual(grid.last?[2].level, 4)
    XCTAssertTrue(grid.last?[4].isFuture ?? false)
    let weeks = s.weeklyStats(today: today, weeks: 8)
    XCTAssertEqual(weeks.last?.completions, 3)
    // Thursday: compare Mon–Thu with last Mon–Thu, not with all of last week.
    s.tasks[0].done["2026-10-14"] = true  // last Wednesday, counts
    s.tasks[0].done["2026-10-17"] = true  // last Saturday, does not
    let wtd = s.weekToDate(today: today)
    XCTAssertEqual(wtd.thisWeek, 3)
    XCTAssertEqual(wtd.lastWeek, 1)
  }

  func testPlanProgressAndLinks() {
    var s = AppState()
    var plan = Plan(title: "身体", desc: "")
    plan.pinned = true
    let other = Plan(title: "读书", desc: "")
    s.plans = [other, plan]
    var walk = TaskItem(title: "散步", day: "2026-10-01", repeatMode: .daily, reminder: nil, planId: plan.id)
    for k in 0...6 { walk.done[DayKey.add(days: -k, to: "2026-10-21")] = true }
    s.tasks = [walk, TaskItem(title: "孤儿", day: today, repeatMode: .once, reminder: nil, planId: "missing")]
    s.normalize()
    XCTAssertNil(s.tasks[1].planId, "links to deleted plans are cleared")
    XCTAssertEqual(s.activePlans.first?.title, "身体", "pinned first")
    let progress = s.progress(of: plan, today: today)
    XCTAssertEqual(progress.total, 7)
    XCTAssertEqual(progress.lastWeek, 6)
    XCTAssertEqual(progress.streak, 7)
  }

  func testPausedPlanDecodesAndDoneDate() throws {
    let json = #"{"plans":[{"id":"x","title":"吉他","status":"paused","doneAt":"2026-01-01"},{"id":"y","title":"马拉松","status":"done","doneAt":"2026-09-22"}]}"#
    var s = try JSONDecoder().decode(AppState.self, from: Data(json.utf8))
    s.normalize()
    XCTAssertEqual(s.plans[0].status, .paused)
    XCTAssertNil(s.plans[0].doneAt, "only done plans keep a completion date")
    XCTAssertEqual(s.plans[1].doneAt, "2026-09-22")
  }

  func testJournalFontIsBundled() {
    XCTAssertNotNil(UIFont(name: "OneDayJournal-Regular", size: 17), "journal font registered via UIAppFonts")
    XCTAssertNotNil(UIFont(name: "OneDayJournal-Medium", size: 17))
    XCTAssertNotNil(Bundle.main.url(forResource: "LXGWWenKai-OFL", withExtension: "txt"), "font license ships with the app")
  }

  func testOnThisDay() {
    var s = AppState()
    s.notes["2025-10-22"] = [NoteEntry(text: "去年", time: "", photos: [], tags: [])]
    s.notes["2026-10-22"] = [NoteEntry(text: "今天", time: "", photos: [], tags: [])]
    XCTAssertEqual(s.onThisDay(today: today).map(\.yearsAgo), [1])
  }

  func testNotificationPlan() {
    var s = AppState()
    s.settings.notifications.enabled = true
    var task = TaskItem(title: "阅读", day: DayKey.today, repeatMode: .daily, reminder: 23 * 60 + 59)
    task.done = [:]
    s.tasks = [task]
    let now = DayKey.fireDate(DayKey.today, minutes: 0)!
    let requests = NotificationPlanner.requests(for: s, now: now)
    XCTAssertLessThanOrEqual(requests.count, NotificationPlanner.limit)
    XCTAssertTrue(requests.allSatisfy { $0.identifier.hasPrefix(NotificationPlanner.idPrefix) })
    XCTAssertTrue(requests.contains { $0.identifier.contains("task.\(task.id).\(DayKey.today)") })
    XCTAssertTrue(requests.contains { $0.identifier.contains("evening.\(DayKey.today)") })
    // Finishing the task removes its reminder and the evening nudge for today.
    s.tasks[0].done[DayKey.today] = true
    let after = NotificationPlanner.requests(for: s, now: now)
    XCTAssertFalse(after.contains { $0.identifier.contains("task.\(task.id).\(DayKey.today)") })
    XCTAssertFalse(after.contains { $0.identifier.contains("evening.\(DayKey.today)") })
  }

  func testBackupPackageRoundTrip() throws {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { ctx in
      UIColor.orange.setFill()
      ctx.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
    }
    let photo = try XCTUnwrap(MediaStore.save(image: image))
    var s = AppState()
    s.notes[today] = [NoteEntry(text: "带照片", time: "", photos: [photo], tags: [])]
    let package = try BackupManager.makeExportPackage(s)
    XCTAssertTrue(FileManager.default.fileExists(atPath: package.appendingPathComponent("media/\(photo)").path))
    // Simulate a new device: the photo is gone locally and must come from the package.
    MediaStore.delete(photo)
    let restored = try BackupManager.readBackup(at: package)
    XCTAssertEqual(restored.notes[today]?.first?.photos, [photo])
    XCTAssertTrue(MediaStore.exists(photo))
  }

  func testWebBackupEmbedsPhotos() throws {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in }
    let photo = try XCTUnwrap(MediaStore.save(image: image))
    var s = AppState()
    s.notes[today] = [NoteEntry(text: "x", time: "", photos: [photo], tags: [])]
    let json = String(decoding: Persistence.backupData(for: s), as: UTF8.self)
    XCTAssertTrue(json.contains("data:image/jpeg;base64,"))
    let parsed = try Persistence.parseBackup(Data(json.utf8))
    XCTAssertEqual(parsed.notes[today]?.first?.photos.count, 1)
  }

  func testMoodAndRecap() throws {
    var s = AppState()
    var a = NoteEntry(text: "湖边散步", time: "19:00", photos: ["p1.jpg"], tags: ["日常"])
    a.mood = 5
    a.place = "西湖"
    var b = NoteEntry(text: "加班", time: "22:00", photos: [], tags: ["日常", "工作"])
    b.mood = 2
    b.place = "西湖"
    var c = NoteEntry(text: "这一天写得最长的一段话。", time: "21:00", photos: ["p2.jpg"], tags: [])
    c.mood = 9  // out of range, clamped by normalize
    s.notes = ["2026-10-20": [a, b], "2026-10-21": [c], "2026-09-30": [NoteEntry(text: "上个月", time: "", photos: [], tags: [])]]
    var read = TaskItem(title: "阅读", day: "2026-09-01", repeatMode: .daily, reminder: nil)
    for k in 1...4 { read.done["2026-10-0\(k)"] = true }
    read.done["2026-10-10"] = true
    s.tasks = [read]
    s.normalize()

    XCTAssertEqual(s.notes["2026-10-21"]?.first?.mood, 5)
    XCTAssertEqual(try XCTUnwrap(s.mood(on: "2026-10-20")), 3.5, accuracy: 0.001)
    XCTAssertNil(s.mood(on: "2026-10-19"))
    XCTAssertEqual(Mood(average: 3.5), .good)
    XCTAssertEqual(s.moodSeries(today: today, days: 30).map(\.day), ["2026-10-20", "2026-10-21"])

    let recap = s.recap(month: DayKey.date("2026-10-15"))
    XCTAssertEqual(recap.recordDays, 2)
    XCTAssertEqual(recap.notes, 3)
    XCTAssertEqual(recap.photos, ["p1.jpg", "p2.jpg"])
    XCTAssertEqual(recap.topPlaces.first?.name, "西湖")
    XCTAssertEqual(recap.topPlaces.first?.count, 2)
    XCTAssertEqual(recap.topTags.first?.name, "日常")
    XCTAssertEqual(recap.completions, 5)
    XCTAssertEqual(recap.bestStreak?.title, "阅读")
    XCTAssertEqual(recap.bestStreak?.days, 4)
    XCTAssertEqual(recap.highlight?.day, "2026-10-21")
    XCTAssertEqual(try XCTUnwrap(recap.moodAverage), 4, accuracy: 0.001)
    XCTAssertTrue(s.recap(month: DayKey.date("2026-08-01")).isEmpty)
    XCTAssertEqual(s.photoTimeline.map(\.photo), ["p2.jpg", "p1.jpg"])
  }

  func testMoodSurvivesBackupRoundTrip() throws {
    var s = AppState()
    var note = NoteEntry(text: "好天气", time: "09:00", photos: [], tags: [])
    note.mood = 4
    s.notes["2026-10-22"] = [note]
    let data = try JSONEncoder().encode(s)
    let back = try JSONDecoder().decode(AppState.self, from: data)
    XCTAssertEqual(back.notes["2026-10-22"]?.first?.mood, 4)
  }

  func testWeekSummaryAndReflections() {
    var s = AppState()
    // 2026-10-19 is a Monday; today (22nd) is Thursday.
    var read = TaskItem(title: "阅读", day: "2026-10-01", repeatMode: .daily, reminder: nil)
    for day in ["2026-10-19", "2026-10-20", "2026-10-22", "2026-10-12", "2026-10-13", "2026-10-14", "2026-10-16"] {
      read.done[day] = true
    }
    var once = TaskItem(title: "体检", day: "2026-10-21", repeatMode: .once, reminder: nil)
    once.done["2026-10-21"] = true
    var plan = Plan(title: "身体", desc: "")
    plan.id = "p1"
    read.planId = "p1"
    s.tasks = [read, once]
    s.plans = [plan]
    s.notes["2026-10-20"] = [NoteEntry(text: "记录", time: "", photos: [], tags: [])]
    s.dayReflections["2026-10-21"] = DayReflection(text: "  还行  ")
    s.dayReflections["2026-10-23"] = DayReflection(text: "   ")
    s.dayReflections["bad-key"] = DayReflection(text: "x")
    s.weekReflections["2026-10-15"] = WeekReflection(gains: "读完一本书", problems: "", next: "")
    s.normalize()

    // 1.2's separate daily reflections become the day's 复盘 note.
    XCTAssertTrue(s.dayReflections.isEmpty)
    XCTAssertEqual(s.reflectionNote(on: "2026-10-21")?.text, "还行")
    XCTAssertNil(s.notes["2026-10-23"], "blank reflections are dropped")
    XCTAssertNil(s.notes["bad-key"])
    XCTAssertEqual(s.moments(on: "2026-10-21").count, 0)
    XCTAssertEqual(s.daySummary("2026-10-20").notes, 1)
    XCTAssertNotNil(s.weekReflections["2026-10-12"], "weekly reflections are keyed by Monday")

    let week = s.weekSummary(start: "2026-10-22", today: today)
    XCTAssertEqual(week.start, "2026-10-19")
    XCTAssertEqual(week.end, "2026-10-25")
    XCTAssertTrue(week.isCurrent)
    XCTAssertEqual(week.completions, 4)
    XCTAssertEqual(week.lastWeekCompletions, 3, "Mon–Thu of last week only")
    XCTAssertEqual(week.dayDone, [1, 1, 1, 1, 0, 0, 0])
    XCTAssertEqual(week.noteDays, 2, "a 复盘 counts as a record")
    XCTAssertEqual(week.reflectionDays, ["2026-10-21"])
    XCTAssertEqual(week.tasks.first { $0.title == "阅读" }?.marks, [true, true, false, true, nil, nil, nil])
    XCTAssertEqual(week.tasks.first { $0.title == "体检" }?.marks, [nil, nil, true, nil, nil, nil, nil])
    XCTAssertEqual(try XCTUnwrap(week.rate), 4.0 / 5.0, accuracy: 0.001)
    XCTAssertEqual(week.plans.first?.completions, 3)

    let last = s.weekSummary(start: "2026-10-12", today: today)
    XCTAssertFalse(last.isCurrent)
    XCTAssertEqual(last.completions, 4)
    XCTAssertEqual(s.pastReflectionWeeks(today: today), ["2026-10-12"])
    XCTAssertEqual(DayKey.weekRange("2026-10-19"), "10月19日 – 25日")
    XCTAssertEqual(DayKey.weekRange("2026-09-28"), "9月28日 – 10月4日")
  }

  func testNextWeekFocusItems() {
    let r = WeekReflection(gains: "", problems: "", next: "1. 11 点前睡觉\n- 周末去游泳\n\n• 读完《置身事内》\n周末去游泳\n2026 计划")
    XCTAssertEqual(r.nextItems, ["11 点前睡觉", "周末去游泳", "读完《置身事内》", "2026 计划"])
  }

  @MainActor
  func testReflectionsPersistInDatabase() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("reflect-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: url) }
    let db = try Database(url: url)
    // A 1.2 database: the daily reflection lives in its own row.
    var old = AppState()
    old.dayReflections["2026-10-22"] = DayReflection(text: "今天不错")
    old.weekReflections["2026-10-19"] = WeekReflection(gains: "收获", problems: "", next: "早睡")
    try db.apply(Database.diff(from: nil, to: old))

    // Loading migrates it into a 复盘 note and writes that back, as Storage does.
    let raw = try XCTUnwrap(try db.load())
    var migrated = raw
    migrated.normalize()
    try db.apply(Database.diff(from: raw, to: migrated))
    var loaded = try XCTUnwrap(try db.load())
    XCTAssertTrue(loaded.dayReflections.isEmpty, "the old row is gone")
    XCTAssertEqual(loaded.reflectionNote(on: "2026-10-22")?.text, "今天不错")
    XCTAssertEqual(loaded.weekReflections["2026-10-19"]?.next, "早睡")

    var edited = loaded
    edited.notes["2026-10-22"] = nil
    edited.weekReflections["2026-10-19"]?.gains = "新的收获"
    let changes = Database.diff(from: loaded, to: edited)
    XCTAssertEqual(changes.rowCount, 2, "one note deleted and one week updated")
    try db.apply(changes)
    loaded = try XCTUnwrap(try db.load())
    XCTAssertNil(loaded.reflectionNote(on: "2026-10-22"))
    XCTAssertEqual(loaded.weekReflections["2026-10-19"]?.gains, "新的收获")
  }

  func testOneReflectionNotePerDay() throws {
    var s = AppState()
    var a = NoteEntry(text: "复盘一", time: "21:00", photos: [], tags: [])
    a.isReflection = true
    var b = NoteEntry(text: "复盘二", time: "22:00", photos: [], tags: [])
    b.isReflection = true
    s.notes[today] = [a, b]
    s.normalize()
    XCTAssertEqual(s.notes[today]?.filter(\.isReflection).map(\.text), ["复盘一"])
    XCTAssertEqual(s.moments(on: today).map(\.text), ["复盘二"])
    let data = try JSONEncoder().encode(s)
    let back = try JSONDecoder().decode(AppState.self, from: data)
    XCTAssertEqual(back.reflectionNote(on: today)?.text, "复盘一", "the flag survives backups")
  }

  func testWidgetSnapshotRollsOverAtMidnight() {
    var snap = WidgetSnapshot.sample
    snap.day = "2026-10-22"
    snap.tomorrow = [
      WidgetTask(id: "r", title: "阅读", done: false, daily: true, color: nil),
      WidgetTask(id: "x", title: "体检", done: false, daily: false, color: nil),
    ]
    snap.week = [1, 2, 3, 4, 5, 6, 7]
    XCTAssertEqual(snap.resolved(for: "2026-10-22").today, snap.today, "same day is unchanged")
    let next = snap.resolved(for: "2026-10-23")
    XCTAssertEqual(next.day, "2026-10-23")
    XCTAssertEqual(next.today.map(\.title), ["阅读", "体检"])
    XCTAssertFalse(next.wroteToday)
    XCTAssertEqual(next.week, [2, 3, 4, 5, 6, 7, 0])
    let later = snap.resolved(for: "2026-10-25")
    XCTAssertEqual(later.today.map(\.title), ["阅读"], "only daily tasks carry over further")
    XCTAssertEqual(later.week, [4, 5, 6, 7, 0, 0, 0])
  }

  @MainActor
  func testWidgetSnapshotFromState() {
    var s = AppState()
    var read = TaskItem(title: "阅读", day: "2026-10-01", repeatMode: .daily, reminder: nil)
    for k in 0..<5 { read.done[DayKey.add(days: -k, to: today)] = true }
    let once = TaskItem(title: "体检", day: today, repeatMode: .once, reminder: nil)
    s.tasks = [read, once]
    s.notes[today] = [NoteEntry(text: "好", time: "", photos: [], tags: [])]
    let snap = WidgetSync.snapshot(of: s, today: today)
    XCTAssertEqual(snap.today.map(\.title), ["体检", "阅读"], "open tasks first")
    XCTAssertEqual(snap.doneCount, 1)
    XCTAssertEqual(snap.tomorrow.map(\.title), ["阅读"])
    XCTAssertEqual(snap.streakTitle, "阅读")
    XCTAssertEqual(snap.streakDays, 5)
    XCTAssertTrue(snap.wroteToday)
    XCTAssertEqual(snap.week, [0, 0, 1, 1, 1, 1, 1])
    XCTAssertEqual(MascotMood.of(snap, at: DayKey.date(today).addingTimeInterval(10 * 3600)), .happy)
  }

  func testRoutes() {
    XCTAssertEqual(AppRoute(url: URL(string: "oneday://capture")!), .capture)
    XCTAssertEqual(AppRoute(url: URL(string: "oneday://addtask")!), .addTask)
    XCTAssertNil(AppRoute(url: URL(string: "https://capture")!))
    XCTAssertEqual(AppRoute(shortcutType: "com.oneday.app.reflect"), .reflect)
    XCTAssertNil(AppRoute(shortcutType: "com.oneday.app.unknown"))
  }

  func testAppGroupFromProvisioningProfile() {
    let xml = "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>Entitlements</key><dict>"
      + "<key>com.apple.security.application-groups</key><array><string>group.com.oneday.app.ABC123</string>"
      + "<string>group.*</string></array></dict></dict></plist>"
    var data = Data([0x30, 0x82, 0x00])  // stands in for the CMS envelope
    data.append(Data(xml.utf8))
    data.append(Data([0x00, 0xA0]))
    XCTAssertEqual(SharedData.provisionedGroups(fromProfile: data), ["group.com.oneday.app.ABC123"])
    XCTAssertEqual(SharedData.provisionedGroups(fromProfile: Data("no plist".utf8)), [])
  }
}
