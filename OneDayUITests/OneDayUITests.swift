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
    let menu = app.buttons["记录操作"].firstMatch
    XCTAssertTrue(menu.waitForExistence(timeout: 8))
    menu.tap()
    app.buttons["编辑"].tap()
    XCTAssertTrue(app.staticTexts["照片和视频"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["添加照片或视频"].exists)
    XCTAssertTrue(app.staticTexts["杭州市 · 西湖区"].exists, "existing place is editable")
    XCTAssertTrue(app.buttons["移除位置"].exists)
    app.buttons["取消"].tap()
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
    XCTAssertTrue(app.buttons["完成概览"].waitForExistence(timeout: 8))
    app.buttons["完成概览"].tap()
    XCTAssertTrue(app.staticTexts["坚持"].waitForExistence(timeout: 5))
    app.tabBars.buttons["我的"].tap()
    let backupRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "备份与恢复")).firstMatch
    XCTAssertTrue(backupRow.waitForExistence(timeout: 5))
  }
}
