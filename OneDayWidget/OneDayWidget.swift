import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot
  /// Shown instead of 小日's line when there is no data to show.
  var notice: String?
}

struct TodayProvider: TimelineProvider {
  func placeholder(in context: Context) -> TodayEntry {
    TodayEntry(date: Date(), snapshot: .sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
    if context.isPreview, SharedData.loadSnapshot() == nil {
      completion(TodayEntry(date: Date(), snapshot: .sample))
    } else {
      completion(entry(at: Date()))
    }
  }

  /// Now, the evening (小日 gets sleepy at 22:00) and midnight (tomorrow's list takes over).
  func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
    let now = Date()
    let calendar = SharedDay.calendar
    let startOfToday = calendar.startOfDay(for: now)
    var dates = [now]
    if let evening = calendar.date(byAdding: .hour, value: 22, to: startOfToday), evening > now { dates.append(evening) }
    if let midnight = calendar.date(byAdding: .day, value: 1, to: startOfToday) {
      dates.append(midnight)
      if let morning = calendar.date(byAdding: .hour, value: 5, to: midnight) { dates.append(morning) }
    }
    completion(Timeline(entries: dates.map(entry(at:)), policy: .atEnd))
  }

  private func entry(at date: Date) -> TodayEntry {
    guard SharedData.containerURL != nil else {
      // The sideloading tool gave the widget no App Group, so it cannot see the app's data.
      return TodayEntry(date: date, snapshot: .empty, notice: "安装方式不支持共享")
    }
    guard let snapshot = SharedData.loadSnapshot() else {
      return TodayEntry(date: date, snapshot: .empty, notice: "打开 OneDay 一次")
    }
    return TodayEntry(date: date, snapshot: snapshot.resolved(for: SharedDay.key(date)))
  }
}

struct TodayWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "OneDayToday", provider: TodayProvider()) { entry in
      TodayWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("今天")
    .description("小日陪你看今天的事项，可以直接打勾。")
    .supportedFamilies([
      .systemSmall, .systemMedium, .systemLarge,
      .accessoryCircular, .accessoryRectangular, .accessoryInline,
    ])
  }
}

struct TodayWidgetEntryView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme
  let entry: TodayEntry

  var body: some View {
    OneDayWidgetView(family: family, snapshot: entry.snapshot, date: entry.date, notice: entry.notice)
      .containerBackground(for: .widget) {
        if family.isAccessory {
          Color.clear
        } else {
          CuteBackground(theme: CuteTheme.make(scheme, accent: entry.snapshot.accent))
        }
      }
  }
}

private extension WidgetFamily {
  var isAccessory: Bool {
    switch self {
    case .accessoryCircular, .accessoryRectangular, .accessoryInline: true
    default: false
    }
  }
}

@main
struct OneDayWidgetBundle: WidgetBundle {
  var body: some Widget {
    TodayWidget()
  }
}
