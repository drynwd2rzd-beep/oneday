import SwiftUI

/// 小日's expressions.
enum MascotMood: String, CaseIterable {
  /// Nothing scheduled: content.
  case calm
  /// Tasks waiting, none done yet: cheering you on.
  case cheer
  /// Some done.
  case happy
  /// Everything done: arms up, sparkles.
  case party
  /// Late and not finished: dozing.
  case sleepy

  static func of(_ snapshot: WidgetSnapshot, at date: Date) -> MascotMood {
    if snapshot.allDone { return .party }
    let hour = SharedDay.calendar.component(.hour, from: date)
    if hour >= 22 || hour < 5 { return .sleepy }
    if snapshot.total == 0 { return .calm }
    return snapshot.doneCount == 0 ? .cheer : .happy
  }

  /// What 小日 says.
  func line(for snapshot: WidgetSnapshot) -> String {
    let left = snapshot.total - snapshot.doneCount
    switch self {
    case .party: return "全部完成啦！"
    case .happy: return "还差 \(left) 件，加油"
    case .cheer: return "今天有 \(snapshot.total) 件事"
    case .calm: return "今天很自由～"
    case .sleepy: return snapshot.total == 0 ? "晚安，明天见" : "困了…还差 \(left) 件"
    }
  }
}

/// OneDay's mascot 小日: a round little sun-bun with a sprout, drawn with shapes so it stays
/// crisp at any size and in every widget rendering mode.
struct MascotView: View {
  let mood: MascotMood
  var size: CGFloat = 64

  private let ink = Color(red: 0.36, green: 0.23, blue: 0.16)
  private let bodyTop = Color(red: 1.0, green: 0.89, blue: 0.56)
  private let bodyBottom = Color(red: 1.0, green: 0.78, blue: 0.34)
  private let leaf = Color(red: 0.56, green: 0.82, blue: 0.51)
  private let blush = Color(red: 1.0, green: 0.56, blue: 0.64)
  private let mouthRed = Color(red: 0.91, green: 0.31, blue: 0.36)

  var body: some View {
    let s = size
    let line = max(1.2, s * 0.045)
    ZStack(alignment: .topLeading) {
      if mood == .party {
        sparkle(at: CGPoint(x: 0.1, y: 0.16), size: 0.16, color: Color(red: 1, green: 0.72, blue: 0.1))
        sparkle(at: CGPoint(x: 0.92, y: 0.2), size: 0.13, color: blush)
        sparkle(at: CGPoint(x: 0.94, y: 0.7), size: 0.09, color: Color(red: 0.45, green: 0.75, blue: 0.95))
        // Arms up.
        limb(at: CGPoint(x: 0.12, y: 0.42), angle: -35, line: line)
        limb(at: CGPoint(x: 0.88, y: 0.42), angle: 35, line: line)
      } else {
        limb(at: CGPoint(x: 0.12, y: 0.66), angle: 20, line: line)
        limb(at: CGPoint(x: 0.88, y: 0.66), angle: -20, line: line)
      }
      // Feet.
      foot(at: CGPoint(x: 0.36, y: 0.92), line: line)
      foot(at: CGPoint(x: 0.64, y: 0.92), line: line)

      // Sprout.
      Capsule()
        .fill(leaf)
        .overlay(Capsule().stroke(ink, lineWidth: line * 0.8))
        .frame(width: s * 0.045, height: s * 0.12)
        .position(x: s * 0.5, y: s * 0.22)
      leafShape(at: CGPoint(x: 0.41, y: 0.15), angle: -28, line: line)
      leafShape(at: CGPoint(x: 0.59, y: 0.15), angle: 28, line: line)

      // Body.
      Ellipse()
        .fill(LinearGradient(colors: [bodyTop, bodyBottom], startPoint: .top, endPoint: .bottom))
        .overlay(Ellipse().stroke(ink, lineWidth: line))
        .frame(width: s * 0.84, height: s * 0.7)
        .position(x: s * 0.5, y: s * 0.58)
      Ellipse()
        .fill(Color.white.opacity(0.55))
        .frame(width: s * 0.16, height: s * 0.08)
        .rotationEffect(.degrees(-24))
        .position(x: s * 0.29, y: s * 0.4)

      // Cheeks.
      Ellipse().fill(blush.opacity(0.8))
        .frame(width: s * 0.12, height: s * 0.07)
        .position(x: s * 0.25, y: s * 0.66)
      Ellipse().fill(blush.opacity(0.8))
        .frame(width: s * 0.12, height: s * 0.07)
        .position(x: s * 0.75, y: s * 0.66)

      eye(at: 0.37, line: line)
      eye(at: 0.63, line: line)
      mouth(line: line)

      if mood == .sleepy {
        Text("z")
          .font(.system(size: s * 0.17, weight: .heavy, design: .rounded))
          .foregroundStyle(ink.opacity(0.75))
          .position(x: s * 0.83, y: s * 0.24)
        Text("z")
          .font(.system(size: s * 0.12, weight: .heavy, design: .rounded))
          .foregroundStyle(ink.opacity(0.55))
          .position(x: s * 0.94, y: s * 0.1)
      }
    }
    .frame(width: s, height: s)
    .accessibilityElement()
    .accessibilityLabel("小日")
  }

  // MARK: Parts

  @ViewBuilder
  private func eye(at x: CGFloat, line: CGFloat) -> some View {
    let s = size
    switch mood {
    case .party:
      // ^ ^
      Path { p in
        p.move(to: CGPoint(x: 0, y: s * 0.06))
        p.addLine(to: CGPoint(x: s * 0.05, y: 0))
        p.addLine(to: CGPoint(x: s * 0.1, y: s * 0.06))
      }
      .stroke(ink, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
      .frame(width: s * 0.1, height: s * 0.06)
      .position(x: s * x, y: s * 0.55)
    case .sleepy:
      // Closed, curved down.
      Path { p in
        p.move(to: .zero)
        p.addQuadCurve(to: CGPoint(x: s * 0.1, y: 0), control: CGPoint(x: s * 0.05, y: s * 0.05))
      }
      .stroke(ink, style: StrokeStyle(lineWidth: line, lineCap: .round))
      .frame(width: s * 0.1, height: s * 0.04)
      .position(x: s * x, y: s * 0.57)
    default:
      ZStack {
        Ellipse().fill(ink)
        Circle().fill(Color.white)
          .frame(width: s * 0.03, height: s * 0.03)
          .offset(x: s * 0.012, y: -s * 0.022)
      }
      .frame(width: s * 0.08, height: mood == .cheer ? s * 0.11 : s * 0.1)
      .position(x: s * x, y: s * 0.56)
    }
  }

  @ViewBuilder
  private func mouth(line: CGFloat) -> some View {
    let s = size
    switch mood {
    case .party, .cheer:
      // Open "D" smile.
      let w = mood == .party ? s * 0.16 : s * 0.12
      HalfDisc()
        .fill(mouthRed)
        .overlay(HalfDisc().stroke(ink, style: StrokeStyle(lineWidth: line * 0.85, lineJoin: .round)))
        .frame(width: w, height: w * 0.62)
        .position(x: s * 0.5, y: s * 0.7)
    case .sleepy:
      Ellipse()
        .stroke(ink, lineWidth: line * 0.85)
        .frame(width: s * 0.05, height: s * 0.06)
        .position(x: s * 0.5, y: s * 0.7)
    case .happy, .calm:
      Path { p in
        let w = mood == .happy ? s * 0.12 : s * 0.08
        p.move(to: .zero)
        p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w / 2, y: w * 0.7))
      }
      .stroke(ink, style: StrokeStyle(lineWidth: line * 0.9, lineCap: .round))
      .frame(width: mood == .happy ? s * 0.12 : s * 0.08, height: s * 0.06)
      .position(x: s * 0.5, y: s * 0.69)
    }
  }

  private func limb(at point: CGPoint, angle: Double, line: CGFloat) -> some View {
    Ellipse()
      .fill(bodyBottom)
      .overlay(Ellipse().stroke(ink, lineWidth: line * 0.85))
      .frame(width: size * 0.17, height: size * 0.1)
      .rotationEffect(.degrees(angle))
      .position(x: size * point.x, y: size * point.y)
  }

  private func foot(at point: CGPoint, line: CGFloat) -> some View {
    Ellipse()
      .fill(bodyBottom)
      .overlay(Ellipse().stroke(ink, lineWidth: line * 0.85))
      .frame(width: size * 0.16, height: size * 0.09)
      .position(x: size * point.x, y: size * point.y)
  }

  private func leafShape(at point: CGPoint, angle: Double, line: CGFloat) -> some View {
    Ellipse()
      .fill(leaf)
      .overlay(Ellipse().stroke(ink, lineWidth: line * 0.8))
      .frame(width: size * 0.17, height: size * 0.09)
      .rotationEffect(.degrees(angle))
      .position(x: size * point.x, y: size * point.y)
  }

  private func sparkle(at point: CGPoint, size relative: CGFloat, color: Color) -> some View {
    Sparkle()
      .fill(color)
      .frame(width: size * relative, height: size * relative)
      .position(x: size * point.x, y: size * point.y)
  }
}

/// The lower half of an ellipse, flat side up: an open, laughing mouth.
private struct HalfDisc: Shape {
  func path(in rect: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: rect.minX, y: rect.minY))
    p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 1.6))
    p.closeSubpath()
    return p
  }
}

/// A four-pointed twinkle.
struct Sparkle: Shape {
  func path(in rect: CGRect) -> Path {
    let c = CGPoint(x: rect.midX, y: rect.midY)
    let r = min(rect.width, rect.height) / 2
    let inner = r * 0.28
    var p = Path()
    for i in 0..<8 {
      let angle = Double(i) * .pi / 4 - .pi / 2
      let radius = i.isMultiple(of: 2) ? r : inner
      let point = CGPoint(x: c.x + CGFloat(cos(angle)) * radius, y: c.y + CGFloat(sin(angle)) * radius)
      if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
    }
    p.closeSubpath()
    return p
  }
}
