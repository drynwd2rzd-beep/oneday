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
    // The page is long; keep scrolling (from the side, away from the rows) until it shows.
    for _ in 0..<3 where !memory.isHittable {
      let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7))
      edge.press(forDuration: 0.05, thenDragTo: edge.withOffset(CGVector(dx: 0, dy: -300)))
    }
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
    XCTAssertTrue(app.buttons["心情：很好"].exists, "mood is editable")
    // Place sits below the fold of the form.
    let removePlace = app.buttons["移除位置"]
    for _ in 0..<3 where !removePlace.exists { app.collectionViews.firstMatch.swipeUp() }
    XCTAssertTrue(removePlace.waitForExistence(timeout: 5), "existing place is editable")
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

  /// Finished tasks fold away under 「已完成」 and come back when unchecked.
  func testDoneTasksFoldAway() {
    let app = launch(["-OneDayTab", "tasks"])
    let check = app.buttons["完成事项：整理房间"]
    XCTAssertTrue(check.waitForExistence(timeout: 8))
    check.tap()
    XCTAssertTrue(check.waitForNonExistence(timeout: 5), "moves out of the open list")
    let folded = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "已完成")).firstMatch
    XCTAssertTrue(folded.waitForExistence(timeout: 5))
    folded.tap()
    let uncheck = app.buttons["取消完成：整理房间"]
    XCTAssertTrue(uncheck.waitForExistence(timeout: 5), "shown when unfolded")
    uncheck.tap()
    XCTAssertTrue(app.buttons["完成事项：整理房间"].waitForExistence(timeout: 5), "back among the open tasks")
  }

  func testHomeCaptureExpandsFromOneLine() {
    let app = launch(["-OneDayTab", "today"])
    let entry = app.buttons["写一条记录"]
    XCTAssertTrue(entry.waitForExistence(timeout: 8), "capture starts as one line")
    entry.tap()
    XCTAssertTrue(app.staticTexts["值得留下"].waitForExistence(timeout: 3), "tapping opens the editor")
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the text field is focused")
    app.typeText("今天的风很舒服")
    XCTAssertTrue(app.buttons["留下"].isEnabled)
  }

  func testHomeCaptureStaysOpenWhenKeyboardCloses() {
    let app = launch(["-OneDayTab", "today"])
    let entry = app.buttons["写一条记录"]
    XCTAssertTrue(entry.waitForExistence(timeout: 8))
    entry.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
    // Closing the keyboard (完成, scrolling, opening the photo picker) must not close the empty
    // editor, or photos picked afterwards have nowhere to go.
    app.buttons["完成"].firstMatch.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["值得留下"].exists, "editor stays open after the keyboard closes")
    XCTAssertTrue(app.buttons["添加照片或视频"].firstMatch.exists)
    app.buttons["收起"].tap()
    XCTAssertTrue(entry.waitForExistence(timeout: 5), "收起 closes it back to one line")
  }

  func testAddTask() {
    let app = launch(["-OneDayTab", "tasks"])
    app.buttons["添加事项"].tap()
    let field = app.textFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 10))
    field.tap()
    field.typeText("写周报")
    XCTAssertEqual(field.value as? String, "写周报", "typed into the field")
    app.buttons["添加"].tap()
    let row = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "写周报")).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 15))
  }

  func testTabsAndOverview() {
    let app = launch(["-OneDayTab", "review"])
    XCTAssertTrue(app.buttons["统计"].waitForExistence(timeout: 8))
    app.buttons["统计"].tap()
    XCTAssertTrue(app.staticTexts["每日打卡"].waitForExistence(timeout: 5))
    app.tabBars.buttons["我的"].tap()
    let backupRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "备份与恢复")).firstMatch
    XCTAssertTrue(backupRow.waitForExistence(timeout: 5))
  }

  func testReviewCalendarAndPhotoWall() {
    let app = launch(["-OneDayTab", "review"])
    XCTAssertTrue(app.buttons["日历"].waitForExistence(timeout: 8), "layouts are plain choices at the top")
    app.buttons["日历"].tap()
    let recapEntry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "月回顾")).firstMatch
    XCTAssertTrue(recapEntry.waitForExistence(timeout: 5), "calendar shows the month recap entry")
    recapEntry.tap()
    XCTAssertTrue(app.buttons["关闭"].waitForExistence(timeout: 5), "recap card opens")
    app.buttons["关闭"].tap()

    XCTAssertTrue(app.buttons["照片"].waitForExistence(timeout: 5))
    app.buttons["照片"].tap()
    let photo = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "的照片")).firstMatch
    XCTAssertTrue(photo.waitForExistence(timeout: 5), "photo wall lists photos")
    photo.tap()
    XCTAssertTrue(app.buttons["更多"].waitForExistence(timeout: 20), "tapping a photo opens its day")
  }

  func testDailyAndWeeklyReflection() {
    // 复盘 lives on 今天 in the evening (forced here), and the weekly review on Sunday/Monday.
    let app = launch(["-OneDayTab", "today", "-OneDayEvening", "YES"])
    let today = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "今日复盘")).firstMatch
    XCTAssertTrue(today.waitForExistence(timeout: 10))
    today.tap()
    let field = app.descendants(matching: .any).matching(identifier: "reflection-text").firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 15))
    field.tap()
    field.typeText("今天很充实")
    app.buttons["保存"].tap()
    let saved = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "今天很充实")).firstMatch
    XCTAssertTrue(saved.waitForExistence(timeout: 15), "the card shows what was written")

    let week = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "本周复盘")).firstMatch
    XCTAssertTrue(week.waitForExistence(timeout: 10))
    week.tap()
    XCTAssertTrue(app.staticTexts["本周收获"].waitForExistence(timeout: 15), "weekly review asks its questions")
    // Earlier weeks are one tap away.
    app.buttons["上一周"].tap()
    let lastWeek = app.descendants(matching: .any).matching(NSPredicate(format: "value CONTAINS %@", "读完了一本书")).firstMatch
    XCTAssertTrue(lastWeek.waitForExistence(timeout: 10), "last week's review shows")
    app.buttons["取消"].tap()
  }

  func testPlansLiveInTasks() {
    let app = launch(["-OneDayTab", "tasks"])
    XCTAssertEqual(app.tabBars.buttons.count, 4, "今天 / 事项 / 回顾 / 我的")
    let plans = app.buttons["计划"]
    XCTAssertTrue(plans.waitForExistence(timeout: 8))
    plans.tap()
    XCTAssertTrue(app.staticTexts["成为更强大的人"].waitForExistence(timeout: 8))
  }

  func testCaptureLinkOpensEditor() {
    let app = launch(["-OneDayTab", "plans"])
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
    app.open(URL(string: "oneday://capture")!)
    XCTAssertTrue(app.staticTexts["值得留下"].waitForExistence(timeout: 10), "the link opens the capture card on 今天")
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "ready to type")
  }

  func testGrowthPageOpensFromRing() {
    let app = launch(["-OneDayTab", "today"])
    let ring = app.buttons["小日"]
    XCTAssertTrue(ring.waitForExistence(timeout: 10))
    ring.tap()
    XCTAssertFalse(app.staticTexts["小日的成长"].waitForExistence(timeout: 2), "a tap only makes 小日 react")
    ring.press(forDuration: 1.0)
    XCTAssertTrue(app.staticTexts["小日的成长"].waitForExistence(timeout: 10), "a long press opens its growth page")
    XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "怎样收集阳光")).firstMatch.exists)
  }

  func testEditTask() {
    let app = launch(["-OneDayTab", "tasks"])
    let row = app.staticTexts["整理房间"]
    XCTAssertTrue(row.waitForExistence(timeout: 8))
    row.press(forDuration: 1.0)
    XCTAssertTrue(app.buttons["编辑"].waitForExistence(timeout: 5))
    app.buttons["编辑"].tap()
    let field = app.textFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 10))
    XCTAssertEqual(field.value as? String, "整理房间", "the editor starts from the task")
    field.tap()
    field.typeText("和书桌")
    app.buttons["保存"].tap()
    let renamed = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "整理房间和书桌")).firstMatch
    XCTAssertTrue(renamed.waitForExistence(timeout: 10))
  }

  /// An earlier day can get a late entry (补记) from its page.
  func testLateEntryOnEarlierDay() {
    let app = launch(["-OneDayTab", "review", "-OneDayReview", "day"])
    let more = app.buttons["更多"]
    XCTAssertTrue(more.waitForExistence(timeout: 8))
    more.tap()
    let add = app.buttons["补一条记录"]
    XCTAssertTrue(add.waitForExistence(timeout: 5))
    add.tap()
    // A vertical text field: it may show up as a text view or a text field.
    let editor = app.descendants(matching: .any)
      .matching(NSPredicate(format: "placeholderValue == %@", "不需要写得很好，只留下真实的你。")).firstMatch
    XCTAssertTrue(editor.waitForExistence(timeout: 8))
    editor.tap()
    editor.typeText("晚上补记一句")
    app.buttons["保存"].tap()
    let added = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "晚上补记一句")).firstMatch
    XCTAssertTrue(added.waitForExistence(timeout: 10), "the late entry shows on that day")
  }

  /// Tasks can be added from the Today page without switching tabs.
  func testAddTaskFromToday() {
    let app = launch(["-OneDayTab", "today"])
    let plus = app.buttons["添加今天的事项"]
    XCTAssertTrue(plus.waitForExistence(timeout: 8))
    plus.tap()
    let field = app.textFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 10), "the add sheet opens")
    app.buttons["取消"].tap()
    XCTAssertTrue(plus.waitForExistence(timeout: 5))
  }
}
