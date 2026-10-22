import SwiftUI

/// A mood (1 很糟 … 5 很好) drawn as a small face in 小日's style, instead of an emoji.
struct MoodFace: View {
  let level: Int
  var size: CGFloat = 20
  /// Greyed out, e.g. unselected choices in a picker.
  var dimmed = false

  static let colors: [Color] = [
    Color(red: 0.48, green: 0.54, blue: 0.64),
    Color(red: 0.62, green: 0.69, blue: 0.78),
    Color(red: 0.84, green: 0.77, blue: 0.58),
    Color(red: 1.0, green: 0.78, blue: 0.40),
    Color(red: 1.0, green: 0.62, blue: 0.38),
  ]

  private let ink = Color(red: 0.30, green: 0.20, blue: 0.14)

  var body: some View {
    let level = min(max(self.level, 1), 5)
    let s = size
    let line = max(1, s * 0.07)
    ZStack {
      Circle().fill(dimmed ? Color.secondary.opacity(0.18) : Self.colors[level - 1])
      Circle().stroke(ink.opacity(dimmed ? 0.25 : 0.85), lineWidth: line * 0.8)
      Group {
        eyes(level, line: line)
        mouth(level, line: line)
      }
      .opacity(dimmed ? 0.35 : 1)
    }
    .frame(width: s, height: s)
    .accessibilityHidden(true)
  }

  @ViewBuilder
  private func eyes(_ level: Int, line: CGFloat) -> some View {
    let s = size
    if level == 5 {
      HStack(spacing: s * 0.2) {
        ForEach(0..<2, id: \.self) { _ in
          Path { p in
            p.move(to: CGPoint(x: 0, y: s * 0.07))
            p.addLine(to: CGPoint(x: s * 0.07, y: 0))
            p.addLine(to: CGPoint(x: s * 0.14, y: s * 0.07))
          }
          .stroke(ink, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
          .frame(width: s * 0.14, height: s * 0.07)
        }
      }
      .offset(y: -s * 0.1)
    } else {
      HStack(spacing: s * 0.24) {
        ForEach(0..<2, id: \.self) { _ in
          Capsule().fill(ink).frame(width: s * 0.09, height: level == 1 ? s * 0.08 : s * 0.13)
        }
      }
      .offset(y: -s * 0.08)
    }
  }

  private func mouth(_ level: Int, line: CGFloat) -> some View {
    let s = size
    let w = s * (level == 5 ? 0.36 : 0.3)
    // Curve depth: negative frowns, positive smiles.
    let bend: CGFloat = [-0.18, -0.08, 0, 0.12, 0.22][level - 1] * s
    return Path { p in
      p.move(to: CGPoint(x: 0, y: 0))
      p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w / 2, y: bend))
      if level == 5 { p.closeSubpath() }
    }
    .stroke(ink, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
    .background {
      if level == 5 {
        Path { p in
          p.move(to: .zero)
          p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w / 2, y: bend))
          p.closeSubpath()
        }
        .fill(Color(red: 0.91, green: 0.36, blue: 0.38))
      }
    }
    .frame(width: w, height: abs(bend) / 2 + line)
    .offset(y: s * 0.17 - (bend < 0 ? bend / 2 : 0))
  }
}
