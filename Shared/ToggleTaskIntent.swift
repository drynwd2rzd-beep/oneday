import AppIntents
import WidgetKit

/// The checkbox on the widget. Runs in the widget process: it updates the widget's snapshot
/// at once and leaves the change for the app to apply the next time it opens.
struct ToggleTaskIntent: AppIntent {
  static var title: LocalizedStringResource = "完成事项"
  static var isDiscoverable = false

  @Parameter(title: "事项")
  var taskId: String

  @Parameter(title: "日期")
  var day: String

  init() {}

  init(taskId: String, day: String) {
    self.taskId = taskId
    self.day = day
  }

  func perform() async throws -> some IntentResult {
    SharedData.toggle(taskId: taskId, day: day)
    return .result()
  }
}
