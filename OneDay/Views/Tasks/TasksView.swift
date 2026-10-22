import SwiftUI

/// 事项: the tasks of a day (today by default, any day from the calendar) and the plans they
/// belong to.
struct TasksView: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent

  private enum Filter: Hashable { case all, active, done }

  @State private var filter: Filter = .all
  @State private var selected = DayKey.today
  @State private var month = DayKey.monthStart(Date())
  @State private var showCalendar = false
  @State private var showAdd = false

  var body: some View {
    @Bindable var store = store
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.stack) {
          Picker("分类", selection: $store.tasksSection.animation(.snappy)) {
            ForEach(TasksSection.allCases, id: \.self) { Text($0.rawValue).tag($0) }
          }
          .pickerStyle(.segmented)

          switch store.tasksSection {
          case .tasks:
            if showCalendar { calendarCard }
            dayPanel
          case .plans:
            PlansContent()
          }
        }
        .padding(.horizontal, Spacing.page)
        .padding(.bottom, Spacing.section)
      }
      .background { AppBackground() }
      .navigationTitle("事项")
      .toolbar {
        if store.tasksSection == .tasks {
          ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
              withAnimation(.snappy) { showCalendar.toggle() }
            } label: {
              Image(systemName: showCalendar ? "calendar.badge.checkmark" : "calendar")
            }
            .accessibilityLabel(showCalendar ? "收起日历" : "按日期查看")
            Button {
              showAdd = true
            } label: {
              Image(systemName: "plus")
            }
            .accessibilityLabel("添加事项")
          }
        }
      }
      .sheet(isPresented: $showAdd) { AddTaskSheet(day: selected).oneDaySheet() }
      .onChange(of: store.pendingAddTask, initial: true) { _, pending in
        guard pending else { return }
        store.pendingAddTask = false
        store.tasksSection = .tasks
        showAdd = true
      }
      .onChange(of: store.today) { old, new in
        if selected == old { selected = new }
      }
    }
  }

  /// Month grid; a dot shows whether that day's tasks were all or partly done.
  private var calendarCard: some View {
    VStack(alignment: .leading, spacing: Spacing.inner) {
      CalendarMonthView(
        month: $month,
        selected: selected,
        marker: { key -> Color? in
          switch store.state.dayStatus(key) {
          case .all: return accent
          case .partial: return accent.opacity(0.4)
          case .none: return nil
          }
        },
        onSelect: { key in withAnimation(.snappy) { selected = key } }
      )
      HStack(spacing: 14) {
        Label("全部完成", systemImage: "circle.fill").foregroundStyle(accent)
        Label("部分完成", systemImage: "circle.fill").foregroundStyle(accent.opacity(0.4))
      }
      .font(.app(.caption))
      .labelStyle(LegendLabelStyle())
    }
    .card()
    .transition(.opacity.combined(with: .move(edge: .top)))
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
          .font(.app(.title3).bold())
        Spacer()
        if selected != store.today {
          Button("回到今天") {
            withAnimation(.snappy) {
              selected = store.today
              month = DayKey.monthStart(Date())
            }
          }
          .font(.app(.subheadline).weight(.medium))
        }
      }
      SegmentedBar(
        options: [
          .init(value: Filter.all, title: "全部 \(all.count)"),
          .init(value: Filter.active, title: "进行中 \(active.count)"),
          .init(value: Filter.done, title: "已完成 \(done.count)"),
        ],
        selection: $filter)

      if shown.isEmpty {
        EmptyState(title: "这里还没有事项", icon: "checklist", message: "点右上角的 ＋ 添加一件事。")
      } else {
        TaskList(tasks: shown, day: selected)
      }
    }
    .card()
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
  @State private var planId: String?
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
        if !store.state.activePlans.isEmpty {
          Section {
            Picker(selection: $planId) {
              Text("不属于计划").tag(String?.none)
              ForEach(store.state.activePlans) { plan in
                Label(plan.title, systemImage: plan.symbol).tag(Optional(plan.id))
              }
            } label: {
              Label("所属计划", systemImage: "scope")
            }
          } footer: {
            Text("完成这件事会计入计划的进度。")
          }
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
    store.addTask(title: title, repeatMode: repeatMode, day: day, reminder: remind ? DayKey.minutes(of: time) : nil, planId: planId)
    if remind { Task { await ensureNotificationsOn(store) } }
    dismiss()
  }
}
