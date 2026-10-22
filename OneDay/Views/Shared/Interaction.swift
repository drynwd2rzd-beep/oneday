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
/// Built on a UIKit pan that only starts on horizontal movement, so vertical scrolling is untouched.
private struct SwipeActionsModifier: ViewModifier {
  let leading: SwipeAction?
  let trailing: SwipeAction?
  @State private var offset: CGFloat = 0
  @State private var armed = false

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
      .gesture(
        HorizontalPanGesture(
          onChange: { dx in
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
          },
          onEnd: { dx, velocity in
            let fire = armed || abs(velocity) > 900 && abs(dx) > 40
            let action = dx > 0 ? leading : trailing
            withAnimation(.snappy) { offset = 0 }
            armed = false
            if fire { action?.action() }
          }))
      .accessibilityActions {
        if let leading { Button(leading.title, action: leading.action) }
        if let trailing { Button(trailing.title, action: trailing.action) }
      }
  }

  private func actionBackground(_ action: SwipeAction, width: CGFloat, alignment: Alignment) -> some View {
    ZStack(alignment: alignment == .leading ? .leading : .trailing) {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(action.tint.opacity(armed ? 1 : 0.75))
      Image(systemName: action.icon)
        .font(.body.weight(.bold))
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

private struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
  var onChange: (CGFloat) -> Void
  var onEnd: (CGFloat, CGFloat) -> Void

  func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

  func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
    let pan = UIPanGestureRecognizer()
    pan.delegate = context.coordinator
    return pan
  }

  func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
    let dx = recognizer.translation(in: recognizer.view).x
    switch recognizer.state {
    case .changed:
      onChange(dx)
    case .ended, .cancelled, .failed:
      onEnd(dx, recognizer.velocity(in: recognizer.view).x)
    default:
      break
    }
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
      guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
      let v = pan.velocity(in: pan.view)
      return abs(v.x) > abs(v.y) * 1.4
    }
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
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          if store.toastUndoLabel != nil {
            Button("撤销") { store.undo() }
              .font(.subheadline.weight(.bold))
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
