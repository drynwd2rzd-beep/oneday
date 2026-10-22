import XCTest
@testable import OneDay

/// SQLite storage: round trips, incremental writes and migration from 1.0's state.json.
final class StorageTests: XCTestCase {
  private func tempDir() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("oneday-tests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: url) }
    return url
  }

  private func sample() -> AppState {
    var s = AppState()
    s.tasks = [
      TaskItem(title: "阅读", day: "2026-10-22", repeatMode: .daily, reminder: 600),
      TaskItem(title: "散步", day: "2026-10-22", repeatMode: .once, reminder: nil),
    ]
    s.notes["2026-10-22"] = [
      NoteEntry(text: "一", time: "09:00", photos: [], tags: ["日常"]),
      NoteEntry(text: "二", time: "10:00", photos: [], tags: []),
    ]
    s.plans = [Plan(title: "学游泳", desc: "")]
    s.normalize()
    return s
  }

  func testRoundTrip() {
    let dir = tempDir()
    let storage = Storage(directory: dir)
    XCTAssertTrue(storage.load().tasks.isEmpty)
    let s = sample()
    storage.save(s)
    storage.flush()
    let loaded = Storage(directory: dir).load()
    XCTAssertEqual(loaded.tasks, s.tasks)
    XCTAssertEqual(loaded.notes, s.notes)
    XCTAssertEqual(loaded.plans, s.plans)
  }

  func testIncrementalDiff() {
    let s = sample()
    var next = s
    next.tasks[0].done["2026-10-22"] = true
    XCTAssertEqual(Database.diff(from: s, to: next).rowCount, 1)
    next.notes["2026-10-22"]?.remove(at: 1)
    next.plans.removeAll()
    let d = Database.diff(from: s, to: next)
    XCTAssertEqual(d.deletedNotes.count, 1)
    XCTAssertEqual(d.deletedPlans.count, 1)
    XCTAssertTrue(Database.diff(from: next, to: next).isEmpty)
  }

  func testDeletesPersist() {
    let dir = tempDir()
    let storage = Storage(directory: dir)
    _ = storage.load()
    var s = sample()
    storage.save(s)
    s.notes["2026-10-22"]?.remove(at: 0)
    s.tasks.removeLast()
    storage.save(s)
    storage.flush()
    let loaded = Storage(directory: dir).load()
    XCTAssertEqual(loaded.notes["2026-10-22"]?.map(\.text), ["二"])
    XCTAssertEqual(loaded.tasks.count, 1)
  }

  func testMigratesLegacyJSON() throws {
    let dir = tempDir()
    let legacy = #"{"tasks":[{"id":"t1","title":"旧事项","date":"2026-10-01","repeat":"daily"}],"notes":{"2026-10-01":[{"text":"旧记录"}]},"settings":{"name":"旧名字"}}"#
    try legacy.write(to: dir.appendingPathComponent("state.json"), atomically: true, encoding: .utf8)
    let migrated = Storage(directory: dir).load()
    XCTAssertEqual(migrated.tasks.first?.title, "旧事项")
    XCTAssertEqual(migrated.settings.name, "旧名字")
    XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("state.migrated.json").path))
    XCTAssertEqual(Storage(directory: dir).load().notes.count, 1)
  }

  func testLargeDataToggleWritesOneRow() {
    var big = AppState()
    for t in 0..<30 { big.tasks.append(TaskItem(title: "事项\(t)", day: "2024-01-01", repeatMode: .daily, reminder: nil)) }
    for k in 0..<800 { big.notes[DayKey.add(days: k, to: "2024-01-01")] = [NoteEntry(text: "记录\(k)", time: "", photos: [], tags: [])] }
    var next = big
    next.tasks[3].done["2026-10-22"] = true
    measure { _ = Database.diff(from: big, to: next) }
    XCTAssertEqual(Database.diff(from: big, to: next).rowCount, 1)
  }
}
