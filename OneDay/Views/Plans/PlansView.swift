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
  @State private var showDone = false
  @State private var showArchived = false

  var body: some View {
    let active = store.state.plans.filter { $0.status == .active }
    let done = store.state.plans.filter { $0.status == .done }
    let archived = store.state.plans.filter { $0.status == .archived }
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.stack) {
          PageIntro(title: "以后要去哪里。", subtitle: "记录长期方向，真正行动，也允许计划完成、暂停或归档。")
            .padding(.bottom, 4)

          if active.isEmpty {
            EmptyState(title: "还没有进行中的计划", icon: "scope", message: "先写下真正重要的方向。").card()
          } else {
            ForEach(active) { plan in
              PlanCard(plan: plan, onEdit: { editing = .edit(plan) })
            }
          }

          CollapsibleSection(title: "已完成", count: done.count, isOpen: $showDone) {
            ForEach(done) { plan in
              PlanCard(plan: plan, onEdit: { editing = .edit(plan) })
            }
          }
          CollapsibleSection(title: "已归档", count: archived.count, isOpen: $showArchived) {
            ForEach(archived) { plan in
              PlanCard(plan: plan, onEdit: { editing = .edit(plan) })
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
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            editing = .new
          } label: {
            Image(systemName: "plus")
          }
          .accessibilityLabel("新的计划")
        }
      }
      .sheet(item: $editing) { PlanEditorSheet(target: $0).oneDaySheet() }
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
        HStack {
          Text(title).font(.headline)
          Spacer()
          Text("\(count) 个").foregroundStyle(.secondary)
          Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isOpen ? 90 : 0))
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .card()
      .accessibilityAddTraits(.isHeader)

      if isOpen { content() }
    }
  }
}

private struct PlanCard: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  let plan: Plan
  let onEdit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(plan.status.label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(plan.status == .active ? accent : .secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background((plan.status == .active ? accent : Color.secondary).opacity(0.13), in: Capsule())
      Text(plan.title).font(.title3.bold())
      Text(plan.desc.isEmpty ? "没有额外说明。" : plan.desc)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Text(plan.status.line).font(.caption).foregroundStyle(.secondary)

      GlassGroup(spacing: 8) {
        HStack(spacing: 8) {
          Button("编辑", action: onEdit)
          if plan.status == .active {
            Button("完成") { store.setPlanStatus(plan.id, .done) }
            Button("归档") { store.setPlanStatus(plan.id, .archived) }
          } else {
            Button("重新进行") { store.setPlanStatus(plan.id, .active) }
          }
          Button("删除", role: .destructive) { withAnimation(.snappy) { store.deletePlan(plan.id) } }
            .tint(.red)
        }
        .oneDayButton()
        .controlSize(.small)
        .font(.subheadline.weight(.medium))
      }
      .padding(.top, 2)
    }
    .card()
    .swipeActions(
      leading: plan.status == .active
        ? SwipeAction(title: "完成", icon: "checkmark", tint: accent) { store.setPlanStatus(plan.id, .done) }
        : SwipeAction(title: "重新进行", icon: "arrow.uturn.backward", tint: accent) { store.setPlanStatus(plan.id, .active) },
      trailing: SwipeAction(title: "删除", icon: "trash", tint: .red) {
        withAnimation(.snappy) { store.deletePlan(plan.id) }
      })
  }
}

struct PlanEditorSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  let target: PlanEditTarget
  @State private var title = ""
  @State private var desc = ""
  @FocusState private var focused: Bool

  private var editingPlan: Plan? {
    if case .edit(let plan) = target { return plan }
    return nil
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("计划名称") {
          TextField("例如：成为更强大的人", text: $title).focused($focused)
        }
        Section("说明") {
          TextField("为什么要做？下一步是什么？", text: $desc, axis: .vertical)
            .lineLimit(4...10)
        }
      }
      .navigationTitle(editingPlan == nil ? "新的计划" : "编辑计划")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") {
            store.savePlan(id: editingPlan?.id, title: title, desc: desc)
            dismiss()
          }
          .disabled(title.trimmed.isEmpty)
        }
      }
      .onAppear {
        if let plan = editingPlan {
          title = plan.title
          desc = plan.desc
        } else {
          focused = true
        }
      }
    }
    .presentationDetents([.medium, .large])
  }
}
