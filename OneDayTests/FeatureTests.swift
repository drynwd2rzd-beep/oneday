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
}
