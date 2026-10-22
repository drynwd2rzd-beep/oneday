import XCTest

/// End-to-end checks of the main interactions on a seeded demo state.
final class OneDayUITests: XCTestCase {
  private func launch(_ args: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-OneDayDemo", "YES"] + args
    app.launch()
    return app
  }

  func testSwipeDeleteAndUndo() {
    let app = launch(["-OneDayTab", "tasks"])
    let row = app.staticTexts["整理房间"]
    XCTAssertTrue(row.waitForExistence(timeout: 8))
    row.swipeLeft(velocity: .fast)
    XCTAssertTrue(row.waitForNonExistence(timeout: 3), "swipe left deletes the task")
    let undo = app.buttons["撤销"]
    XCTAssertTrue(undo.waitForExistence(timeout: 3), "toast offers undo")
    undo.tap()
    XCTAssertTrue(app.staticTexts["整理房间"].waitForExistence(timeout: 3), "undo brings it back")
  }

  func testScrollingStillWorksOverSwipeRows() {
    let app = launch(["-OneDayTab", "today"])
    XCTAssertTrue(app.staticTexts["散步 30 分钟"].waitForExistence(timeout: 8))
    let memory = app.staticTexts["那年今日"]
    // Start the drag on a task row: it must scroll the page, not trigger the row's swipe.
    let rowStart = app.staticTexts["散步 30 分钟"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    rowStart.press(forDuration: 0.05, thenDragTo: rowStart.withOffset(CGVector(dx: 0, dy: -420)))
    XCTAssertTrue(memory.waitForExistence(timeout: 3))
    XCTAssertTrue(memory.isHittable, "page scrolled to the on-this-day module")
    XCTAssertTrue(app.staticTexts["散步 30 分钟"].exists, "vertical drag did not delete the row")
  }

  func testOnboardingShowsAndFinishes() {
    let app = launch(["-OneDayOnboarding", "YES"])
    XCTAssertTrue(app.staticTexts["每一天，都值得留下。"].waitForExistence(timeout: 8), "first page renders")
    app.buttons["继续"].tap()
    XCTAssertTrue(app.staticTexts["怎么称呼你？"].waitForExistence(timeout: 3))
    app.buttons["继续"].tap()
    XCTAssertTrue(app.staticTexts["提醒与隐私"].waitForExistence(timeout: 3))
    app.buttons["开始使用"].tap()
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5), "onboarding dismissed")
  }

  func testEditRecordShowsMediaAndPlace() {
    let app = launch(["-OneDayTab", "review", "-OneDayReview", "day"])
    let note = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "傍晚的风")).firstMatch
    XCTAssertTrue(note.waitForExistence(timeout: 8), "day page pushed with the note")
    note.press(forDuration: 1.0)
    XCTAssertTrue(app.buttons["编辑"].waitForExistence(timeout: 3), "long press shows the menu")
    app.buttons["编辑"].tap()
    XCTAssertTrue(app.staticTexts["照片和视频"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["添加照片或视频"].exists)
    XCTAssertTrue(app.staticTexts["杭州市 · 西湖区"].exists, "existing place is editable")
    XCTAssertTrue(app.buttons["移除位置"].exists)
    app.buttons["取消"].tap()
  }

  func testPlansShowProgressAndPause() {
    let app = launch(["-OneDayTab", "plans"])
    XCTAssertTrue(app.staticTexts["成为更强大的人"].waitForExistence(timeout: 8))
    let contains = { (text: String) in NSPredicate(format: "label CONTAINS %@", text) }
    XCTAssertTrue(app.descendants(matching: .any).matching(contains("近 7 天")).firstMatch.exists, "linked tasks give the plan progress")
    XCTAssertTrue(app.buttons.matching(contains("已暂停")).firstMatch.exists, "paused group is shown")
    let swim = app.descendants(matching: .any).matching(contains("学会游泳")).firstMatch
    swim.press(forDuration: 1.0)
    XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 3), "long press shows plan actions")
    app.buttons["暂停"].tap()
    XCTAssertTrue(app.buttons["撤销"].waitForExistence(timeout: 3))
  }

  /// Regression: checking a task off used to make the filter highlight jump to another segment.
  func testFilterSelectionSurvivesToggling() {
    let app = launch(["-OneDayTab", "tasks"])
    let all = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "全部")).firstMatch
    XCTAssertTrue(all.waitForExistence(timeout: 8))
    XCTAssertTrue(all.isSelected)
    let check = app.buttons["完成事项：整理房间"]
    for _ in 0..<3 {
      check.firstMatch.tap()
      XCTAssertTrue(all.isSelected, "「全部」 stays selected after completing")
      app.buttons["取消完成：整理房间"].firstMatch.tap()
      XCTAssertTrue(all.isSelected, "「全部」 stays selected after un-completing")
    }
  }

  func testHomeCaptureExpandsFromOneLine() {
    let app = launch(["-OneDayTab", "today"])
    let entry = app.buttons["写一条记录"]
    XCTAssertTrue(entry.waitForExistence(timeout: 8), "capture starts as one line")
    entry.tap()
    XCTAssertTrue(app.staticTexts["值得留下"].waitForExistence(timeout: 3), "tapping opens the editor")
    app.typeText("今天的风很舒服")
    XCTAssertTrue(app.buttons["留下"].isEnabled)
  }

  func testAddTask() {
    let app = launch(["-OneDayTab", "tasks"])
    app.buttons["添加事项"].tap()
    let field = app.textFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.typeText("写周报")
    app.buttons["添加"].tap()
    XCTAssertTrue(app.staticTexts["写周报"].waitForExistence(timeout: 5))
  }

  func testTabsAndOverview() {
    let app = launch(["-OneDayTab", "review"])
    XCTAssertTrue(app.buttons["统计"].waitForExistence(timeout: 8))
    app.buttons["统计"].tap()
    XCTAssertTrue(app.staticTexts["坚持"].waitForExistence(timeout: 5))
    app.tabBars.buttons["我的"].tap()
    let backupRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "备份与恢复")).firstMatch
    XCTAssertTrue(backupRow.waitForExistence(timeout: 5))
  }

  func testReviewCalendarAndPhotoWall() {
    let app = launch(["-OneDayTab", "review"])
    XCTAssertTrue(app.buttons["日历"].waitForExistence(timeout: 8))
    app.buttons["日历"].tap()
    let recapEntry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "月回顾")).firstMatch
    XCTAssertTrue(recapEntry.waitForExistence(timeout: 5), "calendar shows the month recap entry")
    recapEntry.tap()
    XCTAssertTrue(app.buttons["关闭"].waitForExistence(timeout: 5), "recap card opens")
    app.buttons["关闭"].tap()

    app.buttons["照片"].tap()
    let photo = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "的照片")).firstMatch
    XCTAssertTrue(photo.waitForExistence(timeout: 5), "photo wall lists photos")
    photo.tap()
    XCTAssertTrue(app.buttons["更多"].waitForExistence(timeout: 5), "tapping a photo opens its day")
  }
}
