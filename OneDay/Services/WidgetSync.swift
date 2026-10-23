import Foundation
import WidgetKit

/// Keeps the widgets in step with the app: publishes a snapshot after each change and applies
/// tasks ticked on the widget.
@MainActor
enum WidgetSync {
  static func snapshot(of state: AppState, today: String) -> WidgetSnapshot {
    func items(_ day: String) -> [WidgetTask] {
      let list = state.tasks(on: day).map { task in
        WidgetTask(
          id: task.id, title: task.title, done: task.isDone(on: day), daily: task.repeatMode.isRecurring,
          color: state.plan(task.planId)?.color)
      }
      // Open tasks first, like a to-do list; order is otherwise kept.
      return list.filter { !$0.done } + list.filter(\.done)
    }
    let best = state.taskStreaks(today: today).first { $0.current > 0 }
    let growth = state.growth(today: today)
    let mood = state.mood(on: today).map { Int($0.rounded()) }
    let week = (0..<7).reversed().map { back in
      let day = DayKey.add(days: -back, to: today)
      return state.tasks.filter { $0.isDone(on: day) }.count
    }
    return WidgetSnapshot(
      day: today,
      today: items(today),
      tomorrow: items(DayKey.add(days: 1, to: today)),
      accent: state.settings.accent,
      streakTitle: best?.title,
      streakDays: best?.current ?? 0,
      mood: mood,
      wroteToday: state.hasNotes(on: today),
      week: week,
      stage: growth.stage.rawValue,
      outfit: state.settings.mascotOutfit,
      droopy: growth.droopy)
  }

  /// Writes the snapshot and reloads widgets only when something they show has changed.
  static func publish(_ state: AppState, today: String) {
    // Ticks made on the widget are applied when the app becomes active; until then the
    // widget's own snapshot is newer than ours.
    guard SharedData.pendingToggles().isEmpty else { return }
    if SharedData.save(snapshot(of: state, today: today)) {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
}

extension Store {
  /// Applies checkboxes ticked on the widget while the app was closed.
  func applyWidgetToggles() {
    let toggles = SharedData.pendingToggles()
    guard !toggles.isEmpty else { return }
    SharedData.clearToggles()
    var changed = false
    for toggle in toggles {
      guard let i = state.tasks.firstIndex(where: { $0.id == toggle.taskId }) else { continue }
      if state.tasks[i].isDone(on: toggle.day) != toggle.done {
        state.tasks[i].done[toggle.day] = toggle.done ? true : nil
        changed = true
      }
    }
    if changed { save() }
  }
}
