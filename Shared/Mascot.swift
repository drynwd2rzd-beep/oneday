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
    of(done: snapshot.doneCount, total: snapshot.total, at: date)
  }

  static func of(done: Int, total: Int, at date: Date) -> MascotMood {
    if total > 0 && done == total { return .party }
    let hour = SharedDay.calendar.component(.hour, from: date)
    if hour >= 22 || hour < 5 { return .sleepy }
    if total == 0 { return .calm }
    return done == 0 ? .cheer : .happy
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
  /// `GrowthStage` raw value: 0 小芽 … 5 结果.
  var stage = 1
  var outfit: MascotOutfit?
  /// After a few quiet days the leaves hang down.
  var droopy = false

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
      if outfit == .cosmos { cosmos(line: line) }
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

      if outfit == .halo { halo(line: line) }
      // The sprout grows with 小日; under a hat it pokes out of the top instead.
      if outfit != .hat { sprout(line: line, lift: 0) }

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
      outfitLayer(line: line)

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

  // MARK: Growth

  @ViewBuilder
  private func sprout(line: CGFloat, lift: CGFloat) -> some View {
    let s = size
    let stage = min(max(self.stage, 0), 5)
    let stemHeight: CGFloat = stage == 0 ? 0.1 : stage == 1 ? 0.12 : 0.17
    let base: CGFloat = 0.28 - lift
    let top = base - stemHeight
    let sideAngle: Double = droopy ? 70 : 28
    let sideDrop: CGFloat = droopy ? 0.03 : 0
    ZStack(alignment: .topLeading) {
      Capsule()
        .fill(leaf)
        .overlay(Capsule().stroke(ink, lineWidth: line * 0.8))
        .frame(width: s * 0.045, height: s * stemHeight)
        .position(x: s * 0.5, y: s * (base - stemHeight / 2))
      switch stage {
      case 0:
        leafShape(at: CGPoint(x: 0.43, y: top + 0.01 + sideDrop), angle: -sideAngle, line: line, width: 0.14, height: 0.075)
        leafShape(at: CGPoint(x: 0.57, y: top + 0.01 + sideDrop), angle: sideAngle, line: line, width: 0.14, height: 0.075)
      case 1:
        leafShape(at: CGPoint(x: 0.41, y: top - 0.01 + sideDrop), angle: -sideAngle, line: line)
        leafShape(at: CGPoint(x: 0.59, y: top - 0.01 + sideDrop), angle: sideAngle, line: line)
      default:
        leafShape(at: CGPoint(x: 0.41, y: top + 0.07 + sideDrop), angle: -sideAngle, line: line, width: 0.16, height: 0.085)
        leafShape(at: CGPoint(x: 0.59, y: top + 0.07 + sideDrop), angle: sideAngle, line: line, width: 0.16, height: 0.085)
        crown(stage: stage, top: top, line: line)
      }
    }
  }

  /// What grows at the top of the stem from 三片叶 on.
  @ViewBuilder
  private func crown(stage: Int, top: CGFloat, line: CGFloat) -> some View {
    let s = size
    switch stage {
    case 2:
      Ellipse()
        .fill(leaf)
        .overlay(Ellipse().stroke(ink, lineWidth: line * 0.8))
        .frame(width: s * 0.08, height: s * 0.14)
        .rotationEffect(.degrees(droopy ? 30 : 0))
        .position(x: s * 0.5, y: s * (top - 0.02))
    case 3:
      Ellipse()
        .fill(Color(red: 1, green: 0.66, blue: 0.74))
        .overlay(Ellipse().stroke(ink, lineWidth: line * 0.8))
        .frame(width: s * 0.1, height: s * 0.13)
        .position(x: s * 0.5, y: s * (top - 0.03))
    case 4:
      ZStack {
        ForEach(0..<5, id: \.self) { i in
          let angle = Double(i) / 5 * 2 * .pi - .pi / 2
          Circle()
            .fill(Color(red: 1, green: 0.78, blue: 0.84))
            .overlay(Circle().stroke(ink, lineWidth: line * 0.7))
            .frame(width: s * 0.11, height: s * 0.11)
            .offset(x: CGFloat(cos(angle)) * s * 0.06, y: CGFloat(sin(angle)) * s * 0.06)
        }
        Circle()
          .fill(Color(red: 1, green: 0.8, blue: 0.3))
          .overlay(Circle().stroke(ink, lineWidth: line * 0.7))
          .frame(width: s * 0.075, height: s * 0.075)
      }
      .position(x: s * 0.5, y: s * (top - 0.04))
    default:
      ZStack {
        Circle()
          .fill(Color(red: 0.9, green: 0.27, blue: 0.3))
          .overlay(Circle().stroke(ink, lineWidth: line * 0.8))
          .frame(width: s * 0.14, height: s * 0.14)
        Circle()
          .fill(Color.white.opacity(0.7))
          .frame(width: s * 0.035, height: s * 0.035)
          .offset(x: -s * 0.025, y: -s * 0.025)
      }
      .position(x: s * 0.5, y: s * (top - 0.045))
    }
  }

  // MARK: Outfits

  private var scarfRed: Color { Color(red: 0.9, green: 0.33, blue: 0.35) }
  private var straw: Color { Color(red: 0.94, green: 0.79, blue: 0.5) }

  @ViewBuilder
  private func outfitLayer(line: CGFloat) -> some View {
    let s = size
    switch outfit {
    case .some(.scarf):
      RoundedRectangle(cornerRadius: s * 0.03, style: .continuous)
        .fill(scarfRed)
        .overlay(RoundedRectangle(cornerRadius: s * 0.03, style: .continuous).stroke(ink, lineWidth: line * 0.8))
        .frame(width: s * 0.09, height: s * 0.17)
        .rotationEffect(.degrees(12))
        .position(x: s * 0.67, y: s * 0.86)
      Capsule()
        .fill(scarfRed)
        .overlay(Capsule().stroke(ink, lineWidth: line * 0.8))
        .frame(width: s * 0.66, height: s * 0.1)
        .position(x: s * 0.5, y: s * 0.79)
    case .some(.glasses):
      Group {
        Circle().fill(Color.white.opacity(0.25))
          .overlay(Circle().stroke(ink, lineWidth: line * 0.75))
          .frame(width: s * 0.17, height: s * 0.17)
          .position(x: s * 0.37, y: s * 0.56)
        Circle().fill(Color.white.opacity(0.25))
          .overlay(Circle().stroke(ink, lineWidth: line * 0.75))
          .frame(width: s * 0.17, height: s * 0.17)
          .position(x: s * 0.63, y: s * 0.56)
        Path { p in
          p.move(to: CGPoint(x: s * 0.455, y: s * 0.55))
          p.addLine(to: CGPoint(x: s * 0.545, y: s * 0.55))
        }
        .stroke(ink, lineWidth: line * 0.75)
      }
    case .some(.hat):
      Ellipse()
        .fill(straw)
        .overlay(Ellipse().stroke(ink, lineWidth: line * 0.85))
        .frame(width: s * 0.42, height: s * 0.26)
        .position(x: s * 0.5, y: s * 0.21)
      Capsule()
        .fill(scarfRed)
        .frame(width: s * 0.4, height: s * 0.045)
        .position(x: s * 0.5, y: s * 0.255)
      Ellipse()
        .fill(straw)
        .overlay(Ellipse().stroke(ink, lineWidth: line * 0.85))
        .frame(width: s * 0.72, height: s * 0.12)
        .position(x: s * 0.5, y: s * 0.29)
      sprout(line: line, lift: 0.17)
    case .some(.headset):
      // Silver band over the head, glowing violet ear cups.
      Path { p in
        p.move(to: CGPoint(x: s * 0.12, y: s * 0.54))
        p.addQuadCurve(to: CGPoint(x: s * 0.88, y: s * 0.54), control: CGPoint(x: s * 0.5, y: -s * 0.12))
      }
      .stroke(ink, style: StrokeStyle(lineWidth: line * 2.6, lineCap: .round))
      Path { p in
        p.move(to: CGPoint(x: s * 0.12, y: s * 0.54))
        p.addQuadCurve(to: CGPoint(x: s * 0.88, y: s * 0.54), control: CGPoint(x: s * 0.5, y: -s * 0.12))
      }
      .stroke(chrome, style: StrokeStyle(lineWidth: line * 1.5, lineCap: .round))
      earCup(at: 0.1, line: line)
      earCup(at: 0.9, line: line)
    case .some(.visor):
      RoundedRectangle(cornerRadius: s * 0.065, style: .continuous)
        .fill(LinearGradient(colors: [Color(red: 0.93, green: 0.94, blue: 0.98), violet, cyan], startPoint: .leading, endPoint: .trailing))
        .overlay(RoundedRectangle(cornerRadius: s * 0.065, style: .continuous).stroke(ink, lineWidth: line * 0.85))
        .overlay(alignment: .topLeading) {
          Capsule()
            .fill(Color.white.opacity(0.85))
            .frame(width: s * 0.16, height: s * 0.025)
            .rotationEffect(.degrees(-12))
            .offset(x: s * 0.07, y: s * 0.03)
        }
        .frame(width: s * 0.58, height: s * 0.14)
        .position(x: s * 0.5, y: s * 0.56)
    case .some(.stageMic):
      Circle()
        .fill(Color(red: 0.2, green: 0.2, blue: 0.24))
        .overlay(Circle().stroke(ink, lineWidth: line * 0.7))
        .frame(width: s * 0.11, height: s * 0.11)
        .position(x: s * 0.12, y: s * 0.55)
      Path { p in
        p.move(to: CGPoint(x: s * 0.14, y: s * 0.6))
        p.addQuadCurve(to: CGPoint(x: s * 0.35, y: s * 0.72), control: CGPoint(x: s * 0.16, y: s * 0.75))
      }
      .stroke(Color(red: 0.2, green: 0.2, blue: 0.24), style: StrokeStyle(lineWidth: line * 0.9, lineCap: .round))
      Capsule()
        .fill(Color(red: 0.2, green: 0.2, blue: 0.24))
        .frame(width: s * 0.07, height: s * 0.04)
        .position(x: s * 0.37, y: s * 0.715)
    case .some(.halo), .some(.cosmos), .none:
      EmptyView()
    }
  }

  private var chrome: Color { Color(red: 0.84, green: 0.87, blue: 0.93) }
  private var violet: Color { Color(red: 0.72, green: 0.62, blue: 1.0) }
  private var cyan: Color { Color(red: 0.55, green: 0.88, blue: 1.0) }

  private func earCup(at x: CGFloat, line: CGFloat) -> some View {
    let s = size
    return RoundedRectangle(cornerRadius: s * 0.05, style: .continuous)
      .fill(Color(red: 0.24, green: 0.24, blue: 0.3))
      .overlay(RoundedRectangle(cornerRadius: s * 0.05, style: .continuous).stroke(ink, lineWidth: line * 0.8))
      .overlay(
        RoundedRectangle(cornerRadius: s * 0.03, style: .continuous)
          .fill(violet)
          .frame(width: s * 0.04, height: s * 0.11)
          .shadow(color: violet, radius: s * 0.03))
      .frame(width: s * 0.13, height: s * 0.2)
      .position(x: s * x, y: s * 0.55)
  }

  /// A holographic ring and stars behind 小日.
  private func cosmos(line: CGFloat) -> some View {
    let s = size
    let pink = Color(red: 1, green: 0.62, blue: 0.85)
    return ZStack {
      Circle()
        .fill(RadialGradient(colors: [violet.opacity(0.28), .clear], center: .center, startRadius: s * 0.2, endRadius: s * 0.52))
      Circle()
        .stroke(
          AngularGradient(colors: [violet, cyan, pink, violet], center: .center),
          lineWidth: line * 1.6)
        .frame(width: s * 0.98, height: s * 0.98)
      Sparkle().fill(cyan).frame(width: s * 0.12, height: s * 0.12).offset(x: -s * 0.42, y: -s * 0.3)
      Sparkle().fill(pink).frame(width: s * 0.09, height: s * 0.09).offset(x: s * 0.44, y: -s * 0.18)
      Sparkle().fill(violet).frame(width: s * 0.07, height: s * 0.07).offset(x: s * 0.36, y: s * 0.38)
    }
    .frame(width: s, height: s)
    .position(x: s * 0.5, y: s * 0.55)
  }

  private func halo(line: CGFloat) -> some View {
    let s = size
    let gold = Color(red: 0.95, green: 0.7, blue: 0.24)
    return ZStack {
      Ellipse()
        .stroke(gold, lineWidth: line * 1.4)
        .frame(width: s * 0.5, height: s * 0.11)
      Sparkle().fill(gold).frame(width: s * 0.09, height: s * 0.09).offset(x: -s * 0.3, y: -s * 0.02)
      Sparkle().fill(gold).frame(width: s * 0.07, height: s * 0.07).offset(x: s * 0.3, y: s * 0.01)
    }
    .position(x: s * 0.5, y: s * (stage >= 3 ? 0.0 : 0.04))
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

  private func leafShape(
    at point: CGPoint, angle: Double, line: CGFloat, width: CGFloat = 0.17, height: CGFloat = 0.09
  ) -> some View {
    Ellipse()
      .fill(leaf)
      .overlay(Ellipse().stroke(ink, lineWidth: line * 0.8))
      .frame(width: size * width, height: size * height)
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

/// Things 小日 can wear, unlocked in the app by keeping at it.
enum MascotOutfit: String, CaseIterable, Codable, Identifiable {
  case scarf, glasses, hat, halo
  /// The æ series, after aespa's cyber, chrome and cosmic looks (no logos or likenesses).
  case headset, visor, stageMic, cosmos
  var id: String { rawValue }

  var name: String {
    switch self {
    case .scarf: "围巾"
    case .glasses: "眼镜"
    case .hat: "草帽"
    case .halo: "星星光环"
    case .headset: "赛博耳机"
    case .visor: "未来护目镜"
    case .stageMic: "舞台耳麦"
    case .cosmos: "宇宙光芒"
    }
  }

  var isAeSeries: Bool { [.headset, .visor, .stageMic, .cosmos].contains(self) }
}
