import SwiftUI

struct TasksView: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent

  private enum Panel: String, CaseIterable { case today = "今日", calendar = "日历" }
  private enum Filter: Hashable { case all, active, done }

  @State private var panel: Panel = .today
  @State private var filter: Filter = .all
  @State private var selected = DayKey.today
  @State private var month = DayKey.monthStart(Date())
  @State private var showAdd = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.stack) {
          Picker("视图", selection: $panel.animation(.snappy)) {
            ForEach(Panel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
          }
          .pickerStyle(.segmented)

          if panel == .today {
            dayPanel
          } else {
            calendarPanel
          }
        }
        .padding(.horizontal, Spacing.page)
        .padding(.bottom, Spacing.section)
      }
      .background { AppBackground() }
      .navigationTitle("事项")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showAdd = true
          } label: {
            Image(systemName: "plus")
          }
          .accessibilityLabel("添加事项")
        }
      }
      .sheet(isPresented: $showAdd) { AddTaskSheet(day: selected).oneDaySheet() }
      .onChange(of: store.today) { old, new in
        if selected == old { selected = new }
      }
    }
  }

  private var dayPanel: some View {
    let all = store.state.tasks(on: selected)
    let done = all.filter { $0.isDone(on: selected) }
    let active = all.filter { !$0.isDone(on: selected) }
    let shown: [TaskItem] = switch filter {
    case .all: all
    case .active: active
    case .done: done
    }
    return VStack(alignment: .leading, spacing: Spacing.inner) {
      HStack(alignment: .firstTextBaseline) {
        Text(selected == store.today ? "今天" : DayKey.fullDate(selected))
          .font(.title3.bold())
        Spacer()
        if selected != store.today {
          Button("回到今天") {
            withAnimation(.snappy) {
              selected = store.today
              month = DayKey.monthStart(Date())
            }
          }
          .font(.subheadline.weight(.medium))
        }
      }
      Picker("筛选", selection: $filter.animation(.snappy)) {
        Text("全部 \(all.count)").tag(Filter.all)
        Text("进行中 \(active.count)").tag(Filter.active)
        Text("已完成 \(done.count)").tag(Filter.done)
      }
      .pickerStyle(.segmented)

      if shown.isEmpty {
        EmptyState(title: "这里还没有事项", icon: "checklist", message: "点右上角的 ＋ 添加一件事。")
      } else {
        TaskList(tasks: shown, day: selected)
      }
    }
    .card()
  }

  private var calendarPanel: some View {
    let list = store.state.tasks(on: selected)
    return VStack(alignment: .leading, spacing: Spacing.stack) {
      CalendarMonthView(
        month: $month,
        selected: selected,
        marker: { key -> Color? in
          switch store.state.dayStatus(key) {
          case .all: return accent
          case .partial: return Color.partialDone
          case .none: return nil
          }
        },
        onSelect: { key in withAnimation(.snappy) { selected = key } }
      )
      .card()

      HStack(spacing: 14) {
        Label("全部完成", systemImage: "circle.fill").foregroundStyle(accent)
        Label("部分完成", systemImage: "circle.fill").foregroundStyle(Color.partialDone)
      }
      .font(.caption)
      .labelStyle(LegendLabelStyle())

      Text("\(DayKey.fullDate(selected)) \(DayKey.weekday(selected))")
        .font(.title3.bold())

      VStack(alignment: .leading, spacing: 0) {
        if list.isEmpty {
          EmptyState(title: "这一天没有事项", icon: "calendar")
        } else {
          TaskList(tasks: list, day: selected)
        }
      }
      .padding(.vertical, list.isEmpty ? Spacing.card - 4 : 0)
      .listCard()
    }
  }
}

private struct LegendLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 5) {
      configuration.icon.font(.system(size: 6))
      configuration.title.foregroundStyle(.secondary)
    }
  }
}

struct AddTaskSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  let day: String
  @State private var title = ""
  @State private var repeatMode: RepeatMode = .once
  @State private var remind = false
  @State private var time = DayKey.dateToday(minutes: 9 * 60)
  @FocusState private var focused: Bool

  var body: some View {
    NavigationStack {
      Form {
        Section("事项") {
          TextField("例如：阅读 20 分钟", text: $title)
            .focused($focused)
            .submitLabel(.done)
            .onSubmit(save)
        }
        Section("类型") {
          Picker("类型", selection: $repeatMode) {
            Text("仅这一天").tag(RepeatMode.once)
            Text("每天循环").tag(RepeatMode.daily)
          }
          .pickerStyle(.segmented)
        }
        Section {
          Toggle(isOn: $remind.animation()) {
            Label("提醒我", systemImage: "bell")
          }
          if remind {
            DatePicker("提醒时间", selection: $time, displayedComponents: .hourAndMinute)
          }
        } footer: {
          Text(day == store.today ? "添加到今天。" : "添加到 \(DayKey.fullDate(day))。")
        }
      }
      .navigationTitle("添加一件事")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("添加", action: save).disabled(title.trimmed.isEmpty)
        }
      }
      .onAppear { focused = true }
    }
    .presentationDetents([.medium, .large])
  }

  private func save() {
    guard !title.trimmed.isEmpty else { return }
    store.addTask(title: title, repeatMode: repeatMode, day: day, reminder: remind ? DayKey.minutes(of: time) : nil)
    if remind { Task { await ensureNotificationsOn(store) } }
    dismiss()
  }
}
