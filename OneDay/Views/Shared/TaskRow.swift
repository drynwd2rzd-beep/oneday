import SwiftUI

/// A task in the style of Reminders: a circle and a title. A second line appears only when
/// there is something worth knowing (repeats daily, has a reminder, belongs to a plan).
/// Actions live in the long-press menu and swipes instead of a visible "⋯" button.
struct TaskRow: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  let task: TaskItem
  let day: String
  @State private var editingReminder = false

  var body: some View {
    let done = task.isDone(on: day)
    let plan = store.state.plan(task.planId)
    HStack(alignment: .center, spacing: 12) {
      Button {
        withAnimation(.snappy) { store.toggleTask(task.id, on: day) }
      } label: {
        Image(systemName: done ? "checkmark.circle.fill" : "circle")
          .font(.app(.title3))
          .foregroundStyle(done ? accent : Color(uiColor: .tertiaryLabel))
          .contentTransition(.symbolEffect(.replace))
          .symbolEffect(.bounce, value: done)
          .frame(width: 28, height: 28)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(done ? "取消完成：\(task.title)" : "完成事项：\(task.title)")

      VStack(alignment: .leading, spacing: 3) {
        Text(task.title)
          .font(.app(.body))
          .strikethrough(done, color: .secondary)
          .foregroundStyle(done ? .secondary : .primary)
        if task.reminder != nil || plan != nil {
          HStack(spacing: 10) {
            if let reminder = task.reminder {
              Label(DayKey.clock(minutes: reminder), systemImage: "bell")
                .labelStyle(CompactLabelStyle())
            }
            if let plan {
              Label(plan.title, systemImage: plan.symbol)
                .labelStyle(CompactLabelStyle())
                .foregroundStyle(plan.color.map { Color(hex: $0) } ?? accent)
                .lineLimit(1)
            }
          }
          .font(.app(.footnote))
          .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 10)
    .contentShape(Rectangle())
    .contextMenu { menu }
    .swipeActions(
      leading: SwipeAction(
        title: done ? "取消完成" : "完成", icon: done ? "arrow.uturn.backward" : "checkmark",
        tint: done ? .gray : accent
      ) { withAnimation(.snappy) { store.toggleTask(task.id, on: day) } },
      trailing: SwipeAction(title: "删除", icon: "trash", tint: .red) {
        withAnimation(.snappy) { store.deleteTask(task.id) }
      })
    .sheet(isPresented: $editingReminder) {
      ReminderSheet(task: task).oneDaySheet()
    }
  }

  @ViewBuilder
  private var menu: some View {
    Button {
      editingReminder = true
    } label: {
      Label(task.reminder == nil ? "设置提醒" : "修改提醒", systemImage: "bell")
    }
    if task.reminder != nil {
      Button {
        store.setReminder(nil, for: task.id)
      } label: {
        Label("关闭提醒", systemImage: "bell.slash")
      }
    }
    if !store.state.activePlans.isEmpty || task.planId != nil {
      Picker(selection: Binding(get: { task.planId }, set: { store.setPlan($0, for: task.id) })) {
        Text("不属于计划").tag(String?.none)
        ForEach(store.state.activePlans) { plan in
          Label(plan.title, systemImage: plan.symbol).tag(Optional(plan.id))
        }
      } label: {
        Label("归入计划", systemImage: "flag")
      }
      .pickerStyle(.menu)
    }
    Divider()
    Button(role: .destructive) {
      store.deleteTask(task.id)
    } label: {
      Label("删除", systemImage: "trash")
    }
  }
}
