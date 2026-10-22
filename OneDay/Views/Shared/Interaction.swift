import SwiftUI
import UIKit

// MARK: - Shake to undo

extension Notification.Name {
  static let deviceDidShake = Notification.Name("OneDayDeviceDidShake")
}

extension UIWindow {
  open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    if motion == .motionShake && UIApplication.shared.applicationSupportsShakeToEdit {
      NotificationCenter.default.post(name: .deviceDidShake, object: nil)
    }
    super.motionEnded(motion, with: event)
  }
}

// MARK: - Swipe actions

struct SwipeAction {
  let title: String
  let icon: String
  let tint: Color
  let action: () -> Void
}

/// Full-swipe actions like Mail: drag past the threshold and let go to trigger.
/// The drag runs alongside the scroll view and only takes over once the finger clearly
/// moves sideways, so vertical scrolling keeps working.
private struct SwipeActionsModifier: ViewModifier {
  let leading: SwipeAction?
  let trailing: SwipeAction?
  @State private var offset: CGFloat = 0
  @State private var armed = false
  @State private var axis: Axis?

  private let threshold: CGFloat = 88

  func body(content: Content) -> some View {
    content
      .offset(x: offset)
      .background(alignment: .leading) {
        if offset > 0, let leading { actionBackground(leading, width: offset, alignment: .leading) }
      }
      .background(alignment: .trailing) {
        if offset < 0, let trailing { actionBackground(trailing, width: -offset, alignment: .trailing) }
      }
      .simultaneousGesture(
        DragGesture(minimumDistance: 14, coordinateSpace: .local)
          .onChanged { value in
            let dx = value.translation.width, dy = value.translation.height
            if axis == nil { axis = abs(dx) > abs(dy) * 1.3 ? .horizontal : .vertical }
            guard axis == .horizontal else { return }
            update(dx)
          }
          .onEnded { value in
            defer { axis = nil }
            guard axis == .horizontal else { return }
            let dx = value.translation.width
            let speed = value.predictedEndTranslation.width - dx
            let fire = armed || (abs(speed) > 120 && abs(dx) > 40)
            let action = dx > 0 ? leading : trailing
            withAnimation(.snappy) { offset = 0 }
            armed = false
            if fire { action?.action() }
          })
      .accessibilityActions {
        if let leading { Button(leading.title, action: leading.action) }
        if let trailing { Button(trailing.title, action: trailing.action) }
      }
  }

  private func update(_ dx: CGFloat) {
    var x = dx
    if x > 0 && leading == nil { x = 0 }
    if x < 0 && trailing == nil { x = 0 }
    // Rubber band past the threshold.
    if abs(x) > threshold { x = (x > 0 ? 1 : -1) * (threshold + (abs(x) - threshold) * 0.35) }
    offset = x
    let nowArmed = abs(x) >= threshold
    if nowArmed != armed {
      armed = nowArmed
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
  }

  private func actionBackground(_ action: SwipeAction, width: CGFloat, alignment: Alignment) -> some View {
    ZStack(alignment: alignment == .leading ? .leading : .trailing) {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(action.tint.opacity(armed ? 1 : 0.75))
      Image(systemName: action.icon)
        .font(.app(.body).weight(.bold))
        .foregroundStyle(.white)
        .scaleEffect(armed ? 1.15 : 0.9)
        .padding(.horizontal, 18)
        .opacity(width > 34 ? 1 : 0)
    }
    .frame(width: max(width - 4, 0))
    .animation(.snappy(duration: 0.18), value: armed)
  }
}

extension View {
  func swipeActions(leading: SwipeAction? = nil, trailing: SwipeAction? = nil) -> some View {
    modifier(SwipeActionsModifier(leading: leading, trailing: trailing))
  }
}

// MARK: - Toast

struct ToastView: View {
  @Environment(Store.self) private var store

  var body: some View {
    ZStack {
      if let message = store.toastMessage {
        HStack(spacing: 14) {
          Text(message)
            .font(.app(.subheadline).weight(.semibold))
            .lineLimit(2)
          if store.toastUndoLabel != nil {
            Button("撤销") { store.undo() }
              .font(.app(.subheadline).weight(.bold))
              .foregroundStyle(store.accentColor)
              .accessibilityHint("撤销刚才的操作")
          }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .capsuleSurface()
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .transition(.move(edge: .top).combined(with: .opacity))
        .id(message)
      }
    }
    .animation(.spring(duration: 0.35), value: store.toastMessage)
    .padding(.top, 6)
    .accessibilityAddTraits(.updatesFrequently)
  }
}
