import SwiftUI

/// Five faces in a row. Tapping the chosen one again clears it.
struct MoodPicker: View {
  @Binding var selection: Int?
  var compact = false

  var body: some View {
    HStack(spacing: compact ? 4 : 8) {
      ForEach(Mood.allCases) { mood in
        let selected = selection == mood.rawValue
        Button {
          Haptics.tap()
          withAnimation(.snappy) { selection = selected ? nil : mood.rawValue }
        } label: {
          VStack(spacing: 2) {
            Text(mood.emoji)
              .font(compact ? .title3 : .title2)
              .grayscale(selection == nil || selected ? 0 : 0.9)
              .opacity(selection == nil || selected ? 1 : 0.45)
              .scaleEffect(selected ? 1.15 : 1)
            if !compact {
              Text(mood.label)
                .font(.app(.caption2))
                .foregroundStyle(selected ? Color(hex: mood.hex) : .secondary)
            }
          }
          .frame(maxWidth: .infinity, minHeight: 36)
          .padding(.vertical, compact ? 2 : 6)
          .background {
            if selected {
              Capsule().fill(Color(hex: mood.hex).opacity(0.16))
            }
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("心情：\(mood.label)")
        .accessibilityAddTraits(selected ? .isSelected : [])
      }
    }
  }
}

/// A small emoji for a note or day; nothing when no mood was given.
struct MoodBadge: View {
  let value: Double?
  var font: Font = .footnote

  var body: some View {
    if let value, let mood = Mood(average: value) {
      Text(mood.emoji)
        .font(font)
        .accessibilityLabel("心情\(mood.label)")
    }
  }
}
