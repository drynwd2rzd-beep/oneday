import XCTest
@testable import OneDay

/// Data model and web-backup compatibility.
final class ModelTests: XCTestCase {
  private let webBackup = """
  {
    "tasks": [
      {"id":"a1","title":"阅读 20 分钟","date":"2026-10-01","created":"2026-10-01","repeat":"daily","done":{"2026-10-01":true,"2026-10-02":true,"2026-10-03":false,"2026-10-05":true}},
      {"id":1700000000.5,"name":"旧格式事项","date":"2026-10-02","repeat":"once","done":{}},
      {"title":"   ","date":"2026-10-02"},
      null,
      {"id":"bad id!!","title":"带非法字符 ID","date":"2026-10-04","repeat":"weird"}
    ],
    "notes": {
      "2026-10-01": [{"text":"第一条","time":"09:00","photos":[],"tags":["日常","  心情  ","一个超级超级超级长的标签名字"]}],
      "2026-10-02": "纯字符串记录",
      "2026-10-03": {"content":"单个对象记录"},
      "2026-10-04": [{"text":"","photos":[]}]
    },
    "plans": [{"id":"p1","title":"成为更强大的人","description":"坚持","status":"bogus"}],
    "settings": {"theme":"dark","accent":"#386b98","name":"  一个名字非常非常非常非常非常长的用户名字超出二十  ","signature":"","homeModules":["note","hero","nope","hero"],"uiSize":"large","cardStyle":"flat","bgTone":"meteor","customTags":["旅行"]}
  }
  """

  private func decode() throws -> AppState {
    var s = try JSONDecoder().decode(AppState.self, from: Data(webBackup.utf8))
    s.normalize()
    return s
  }

  func testWebBackupIsNormalized() throws {
    let s = try decode()
    XCTAssertEqual(s.tasks.count, 3)
    XCTAssertEqual(s.tasks[1].title, "旧格式事项")
    XCTAssertEqual(s.tasks[2].id, "badid")
    XCTAssertEqual(s.tasks[2].repeatMode, .once)
    XCTAssertNil(s.tasks[0].done["2026-10-03"])
    XCTAssertEqual(s.tasks[0].completionCount, 3)
    XCTAssertEqual(s.notes["2026-10-02"]?.first?.text, "纯字符串记录")
    XCTAssertEqual(s.notes["2026-10-03"]?.first?.text, "单个对象记录")
    XCTAssertNil(s.notes["2026-10-04"])
    XCTAssertEqual(s.notes["2026-10-01"]?.first?.tags, ["日常", "心情", "一个超级超级超级长的标签"])
    XCTAssertEqual(s.plans.first?.desc, "坚持")
    XCTAssertEqual(s.plans.first?.status, .active)
    XCTAssertEqual(s.settings.name.count, 20)
    XCTAssertEqual(s.settings.signature, Settings.defaultSignature)
    XCTAssertEqual(s.settings.homeModules, [.note, .hero])
    XCTAssertEqual(s.settings.cardStyle, .flat)
    XCTAssertEqual(s.settings.bgTone, .meteor)
  }

  func testTaskOccurrenceAndDayStatus() throws {
    let s = try decode()
    XCTAssertFalse(s.tasks[0].occurs(on: "2026-09-30"))
    XCTAssertTrue(s.tasks[0].occurs(on: "2027-01-01"))
    XCTAssertEqual(s.dayStatus("2026-10-02"), .partial)
    XCTAssertEqual(s.dayStatus("2026-10-01"), .all)
  }

  func testRoundTripKeepsWebKeys() throws {
    var s = try decode()
    var note = NoteEntry(text: "**粗体**", time: "10:00", photos: [], tags: [])
    note.media = [MediaItem(kind: .audio, file: "a.m4a", duration: 3)]
    note.place = "杭州"
    note.weather = "晴 20°"
    s.notes["2026-10-05"] = [note]
    let data = try JSONEncoder().encode(s)
    XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"repeat\":\"daily\""))
    var again = try JSONDecoder().decode(AppState.self, from: data)
    again.normalize()
    XCTAssertEqual(again.tasks, s.tasks)
    XCTAssertEqual(again.notes, s.notes)
    XCTAssertEqual(again.settings, s.settings)
  }

  func testDayKeyHelpers() {
    XCTAssertEqual(DayKey.add(days: 1, to: "2026-12-31"), "2027-01-01")
    XCTAssertEqual(DayKey.daysInMonth(DayKey.date("2028-02-10")), 29)
    XCTAssertEqual(DayKey.leadingBlanks(DayKey.date("2026-10-01")), 4)
    XCTAssertEqual(DayKey.weekday("2026-10-22"), "星期四")
    XCTAssertEqual(DayKey.weekStart("2026-10-25"), "2026-10-19")
  }

  func testMarkdownPlainText() {
    XCTAssertEqual(MarkdownText.plain("今天**很开心**，*真的*"), "今天很开心，真的")
  }
}
