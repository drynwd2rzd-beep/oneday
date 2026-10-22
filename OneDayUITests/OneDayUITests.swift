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
