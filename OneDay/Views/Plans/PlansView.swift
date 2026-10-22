import SwiftUI

enum PlanEditTarget: Identifiable {
  case new
  case edit(Plan)

  var id: String {
    switch self {
    case .new: "new"
    case .edit(let plan): plan.id
    }
  }
}

struct PlansView: View {
  @Environment(Store.self) private var store
  @State private var editing: PlanEditTarget?
  @State private var reordering = false
  @State private var showPaused = true
  @State private var showDone = false
  @State private var showArchived = false

  var body: some View {
    let active = store.state.activePlans
    let paused = store.state.plans.filter { $0.status == .paused }
    let done = store.state.plans.filter { $0.status == .done }
    let archived = store.state.plans.filter { $0.status == .archived }
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.stack) {
          if active.isEmpty {
            EmptyState(title: "还没有进行中的计划", icon: "scope", message: "先写下真正重要的方向。").card()
          } else {
            ForEach(active) { plan in
              PlanCard(plan: plan) { editing = .edit(plan) }
            }
          }

          if !paused.isEmpty {
            CollapsibleSection(title: "已暂停", count: paused.count, isOpen: $showPaused) {
              ForEach(paused) { plan in PlanCard(plan: plan) { editing = .edit(plan) } }
            }
          }
          if !done.isEmpty {
            CollapsibleSection(title: "已完成", count: done.count, isOpen: $showDone) {
              ForEach(done) { plan in PlanCard(plan: plan) { editing = .edit(plan) } }
            }
          }
          if !archived.isEmpty {
            CollapsibleSection(title: "已归档", count: archived.count, isOpen: $showArchived) {
              ForEach(archived) { plan in PlanCard(plan: plan) { editing = .edit(plan) } }
            }
          }
        }
        .padding(.horizontal, Spacing.page)
        .padding(.bottom, Spacing.section)
        .animation(.snappy, value: store.state.plans)
      }
      .background { AppBackground() }
      .navigationTitle("计划")
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          if active.count > 1 {
            Button {
              reordering = true
            } label: {
              Image(systemName: "arrow.up.arrow.down")
            }
            .accessibilityLabel("调整顺序")
          }
          Button {
            editing = .new
          } label: {
            Image(systemName: "plus")
          }
          .accessibilityLabel("新的计划")
        }
      }
      .sheet(item: $editing) { PlanEditorSheet(target: $0).oneDaySheet() }
      .sheet(isPresented: $reordering) { PlanReorderSheet().oneDaySheet() }
    }
  }
}

private struct CollapsibleSection<Inner: View>: View {
  let title: String
  let count: Int
  @Binding var isOpen: Bool
  @ViewBuilder var content: () -> Inner

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.stack) {
      Button {
        withAnimation(.snappy) { isOpen.toggle() }
      } label: {
        HStack(spacing: 6) {
          Text(title).font(.app(.subheadline).weight(.semibold))
          Text("\(count)").font(.app(.subheadline)).foregroundStyle(.secondary)
          Image(systemName: "chevron.right")
            .font(.app(.caption).weight(.semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isOpen ? 90 : 0))
          Spacer()
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .padding(.top, Spacing.section - Spacing.stack)
      .accessibilityAddTraits(.isHeader)
      .accessibilityValue(isOpen ? "已展开" : "已收起")

      if isOpen { content() }
    }
  }
}

private struct PlanCard: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  let plan: Plan
  let onEdit: () -> Void

  private var tint: Color { plan.color.map { Color(hex: $0) } ?? accent }

  var body: some View {
    let progress = store.state.progress(of: plan, today: store.today)
    let muted = plan.status != .active
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: plan.symbol)
        .font(.app(.title3).weight(.medium))
        .foregroundStyle(muted ? Color.secondary : tint)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(plan.title)
            .font(.app(.headline))
            .foregroundStyle(muted ? .secondary : .primary)
          if plan.pinned {
            Image(systemName: "pin.fill").font(.app(.caption2)).foregroundStyle(.tertiary)
              .accessibilityLabel("已置顶")
          }
        }
        Text(summary(progress))
          .font(.app(.footnote))
          .foregroundStyle(.secondary)
          .lineLimit(2)
        if !progress.tasks.isEmpty && plan.status == .active {
          WeekDots(plan: plan, tint: tint)
            .padding(.top, 4)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .card()
    .contentShape(Rectangle())
    .onTapGesture(perform: onEdit)
    .contextMenu { menu }
    .swipeActions(
      leading: leadingSwipe,
      trailing: SwipeAction(title: "删除", icon: "trash", tint: .red) {
        withAnimation(.snappy) { store.deletePlan(plan.id) }
      })
    .accessibilityElement(children: .combine)
    .accessibilityHint("轻点编辑，长按查看更多操作")
  }

  /// One quiet line: progress when tasks are linked, otherwise the description or status.
  private func summary(_ progress: PlanProgress) -> String {
    switch plan.status {
    case .done: return plan.doneAt.map { "完成于 \(DayKey.fullDate($0))" } ?? "已经完成"
    case .paused: return "已暂停"
    case .archived: return "已归档"
    case .active:
      if !progress.tasks.isEmpty {
        var text = "近 7 天 \(progress.lastWeek) 次 · 累计 \(progress.total) 次"
        if progress.streak > 0 { text += " · 连续 \(progress.streak) 天" }
        return text
      }
      return plan.desc.isEmpty ? "长按可以关联每天的事项" : plan.desc
    }
  }

  private var leadingSwipe: SwipeAction {
    switch plan.status {
    case .active:
      SwipeAction(title: "完成", icon: "checkmark", tint: tint) { store.setPlanStatus(plan.id, .done) }
    case .paused:
      SwipeAction(title: "继续", icon: "play.fill", tint: tint) { store.setPlanStatus(plan.id, .active) }
    default:
      SwipeAction(title: "重新进行", icon: "arrow.uturn.backward", tint: tint) { store.setPlanStatus(plan.id, .active) }
    }
  }

  @ViewBuilder
  private var menu: some View {
    Button {
      onEdit()
    } label: {
      Label("编辑与关联事项", systemImage: "pencil")
    }
    if plan.status == .active {
      Button {
        store.togglePin(plan.id)
      } label: {
        Label(plan.pinned ? "取消置顶" : "置顶", systemImage: plan.pinned ? "pin.slash" : "pin")
      }
    }
    Divider()
    switch plan.status {
    case .active:
      Button { store.setPlanStatus(plan.id, .done) } label: { Label("标记完成", systemImage: "checkmark.circle") }
      Button { store.setPlanStatus(plan.id, .paused) } label: { Label("暂停", systemImage: "pause.circle") }
    case .paused:
      Button { store.setPlanStatus(plan.id, .active) } label: { Label("继续进行", systemImage: "play.circle") }
      Button { store.setPlanStatus(plan.id, .done) } label: { Label("标记完成", systemImage: "checkmark.circle") }
    case .done, .archived:
      Button { store.setPlanStatus(plan.id, .active) } label: { Label("重新进行", systemImage: "arrow.uturn.backward.circle") }
    }
    if plan.status != .archived {
      Button { store.setPlanStatus(plan.id, .archived) } label: { Label("归档", systemImage: "archivebox") }
    }
    Divider()
    Button(role: .destructive) {
      withAnimation(.snappy) { store.deletePlan(plan.id) }
    } label: {
      Label("删除", systemImage: "trash")
    }
  }
}

/// Seven dots for the last seven days: filled when any linked task was done that day.
private struct WeekDots: View {
  @Environment(Store.self) private var store
  let plan: Plan
  let tint: Color

  var body: some View {
    let linked = store.state.tasks.filter { $0.planId == plan.id }
    HStack(spacing: 6) {
      ForEach((0..<7).reversed(), id: \.self) { back in
        let day = DayKey.add(days: -back, to: store.today)
        let done = linked.contains { $0.isDone(on: day) }
        Circle()
          .fill(done ? tint : Color.secondary.opacity(0.18))
          .frame(width: 8, height: 8)
      }
    }
    .accessibilityHidden(true)
  }
}

// MARK: - Editor

struct PlanEditorSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent
  let target: PlanEditTarget
  @State private var title = ""
  @State private var desc = ""
  @State private var color: String?
  @State private var icon: String?
  @State private var linked: Set<String> = []
  @FocusState private var focused: Bool

  private var editingPlan: Plan? {
    if case .edit(let plan) = target { return plan }
    return nil
  }

  /// Daily tasks first, then one-off tasks from today on (plus any already linked).
  private var candidateTasks: [TaskItem] {
    let daily = store.state.tasks.filter { $0.repeatMode == .daily }
    let once = store.state.tasks.filter { $0.repeatMode == .once && ($0.date >= store.today || linked.contains($0.id)) }
    return daily + once.sorted { $0.date < $1.date }
  }

  var body: some View {
    let tint = color.map { Color(hex: $0) } ?? accent
    NavigationStack {
      Form {
        Section {
          HStack(spacing: 12) {
            Image(systemName: icon ?? "scope")
              .font(.app(.title3).weight(.semibold))
              .foregroundStyle(.white)
              .frame(width: 44, height: 44)
              .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            TextField("计划名称，例如：成为更强大的人", text: $title)
              .font(.app(.headline))
              .focused($focused)
          }
          TextField("为什么要做？下一步是什么？", text: $desc, axis: .vertical)
            .lineLimit(2...8)
        }

        Section("图标") {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 10)], spacing: 10) {
            ForEach(Plan.icons, id: \.self) { symbol in
              iconCell(symbol, tint: tint)
            }
          }
          .padding(.vertical, 4)
        }

        Section("颜色") {
          HStack(spacing: 10) {
            ForEach(Plan.colors, id: \.self) { hex in
              colorCell(hex)
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 4)
        }

        Section {
          if candidateTasks.isEmpty {
            Text("还没有事项。在「事项」页添加时也可以选择所属计划。")
              .foregroundStyle(.secondary)
          } else {
            ForEach(candidateTasks) { task in
              taskRow(task, tint: tint)
            }
          }
        } header: {
          Text("关联的事项")
        } footer: {
          Text("完成这些事项会计入这个计划的进度。一个事项只属于一个计划。")
        }
      }
      .navigationTitle(editingPlan == nil ? "新的计划" : "编辑计划")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") {
            store.savePlan(id: editingPlan?.id, title: title, desc: desc, color: color, icon: icon, linkedTasks: linked)
            dismiss()
          }
          .disabled(title.trimmed.isEmpty)
        }
      }
      .onAppear {
        if let plan = editingPlan {
          title = plan.title
          desc = plan.desc
          color = plan.color
          icon = plan.icon
          linked = Set(store.state.tasks.filter { $0.planId == plan.id }.map(\.id))
        } else {
          focused = true
        }
      }
    }
    .presentationDetents([.large])
  }

  private func iconCell(_ symbol: String, tint: Color) -> some View {
    let selected = (icon ?? "scope") == symbol
    return Image(systemName: symbol)
      .font(.app(.body))
      .frame(width: 40, height: 40)
      .foregroundStyle(selected ? Color.white : Color.primary)
      .background(selected ? tint : Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      .contentShape(Rectangle())
      .onTapGesture {
        Haptics.tap()
        icon = symbol
      }
      .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
  }

  private func colorCell(_ hex: String) -> some View {
    let selected = (color ?? accent.hexString).lowercased() == hex.lowercased()
    return Circle()
      .fill(Color(hex: hex))
      .frame(width: 30, height: 30)
      .overlay {
        if selected {
          Image(systemName: "checkmark").font(.app(.caption).bold()).foregroundStyle(.white)
        }
      }
      .contentShape(Circle())
      .onTapGesture {
        Haptics.tap()
        color = hex
      }
      .accessibilityLabel("颜色")
      .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
  }

  private func taskRow(_ task: TaskItem, tint: Color) -> some View {
    let isLinked = linked.contains(task.id)
    return Button {
      Haptics.tap()
      if isLinked { linked.remove(task.id) } else { linked.insert(task.id) }
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(task.title).foregroundStyle(.primary)
          Text(taskCaption(task)).font(.app(.caption)).foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: isLinked ? "checkmark.circle.fill" : "circle")
          .font(.app(.title3))
          .foregroundStyle(isLinked ? tint : Color.secondary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isLinked ? .isSelected : [])
  }

  private func taskCaption(_ task: TaskItem) -> String {
    var parts = [task.repeatMode == .daily ? "每天" : DayKey.shortDate(task.date)]
    if let other = store.state.plan(task.planId), other.id != editingPlan?.id {
      parts.append("当前属于「\(other.title)」")
    }
    return parts.joined(separator: " · ")
  }
}

// MARK: - Reorder

struct PlanReorderSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var ids: [String] = []

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(ids, id: \.self) { id in
            row(id)
          }
          .onMove { from, to in
            ids.move(fromOffsets: from, toOffset: to)
            store.reorderActivePlans(ids)
          }
        } footer: {
          Text("拖动右侧把手调整顺序。置顶的计划总是显示在最前面。")
        }
      }
      .environment(\.editMode, .constant(.active))
      .navigationTitle("调整顺序")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
      }
      .onAppear {
        ids = store.state.plans.filter { $0.status == .active }.map(\.id)
      }
    }
    .presentationDetents([.medium, .large])
  }

  @ViewBuilder
  private func row(_ id: String) -> some View {
    if let plan = store.state.plan(id) {
      HStack(spacing: 12) {
        Image(systemName: plan.symbol)
          .foregroundStyle(plan.color.map { Color(hex: $0) } ?? store.accentColor)
          .frame(width: 24)
        Text(plan.title)
        Spacer()
        if plan.pinned {
          Image(systemName: "pin.fill").font(.app(.caption)).foregroundStyle(.secondary)
        }
      }
    }
  }
}
