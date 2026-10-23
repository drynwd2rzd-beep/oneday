import SwiftUI

/// The time of day the scene is painted for.
enum SkyTime {
  case dawn, morning, day, golden, dusk, night

  static func at(_ date: Date) -> SkyTime {
    switch DayKey.calendar.component(.hour, from: date) {
    case 5..<7: .dawn
    case 7..<11: .morning
    case 11..<16: .day
    case 16..<18: .golden
    case 18..<20: .dusk
    default: .night
    }
  }

  var sky: (top: Color, bottom: Color) {
    switch self {
    case .dawn: (Color(hex: "#f5b8a0"), Color(hex: "#fde6cf"))
    case .morning: (Color(hex: "#9fd3f0"), Color(hex: "#eaf6fb"))
    case .day: (Color(hex: "#7fc3ee"), Color(hex: "#d9effb"))
    case .golden: (Color(hex: "#f4b26f"), Color(hex: "#fbe2bd"))
    case .dusk: (Color(hex: "#5f5b9e"), Color(hex: "#f19b80"))
    case .night: (Color(hex: "#18213f"), Color(hex: "#34406e"))
    }
  }

  var hills: (far: Color, near: Color) {
    switch self {
    case .dawn: (Color(hex: "#c9c99a"), Color(hex: "#9cc77e"))
    case .morning, .day: (Color(hex: "#bfe0a0"), Color(hex: "#8fcb72"))
    case .golden: (Color(hex: "#d6c487"), Color(hex: "#a9c86a"))
    case .dusk: (Color(hex: "#6d6f8e"), Color(hex: "#56766a"))
    case .night: (Color(hex: "#2c3d55"), Color(hex: "#24433f"))
    }
  }

  var isDark: Bool { self == .dusk || self == .night }
  var hasSun: Bool { self != .night }
}

/// What 小日 looks like right now.
struct MascotLook: Equatable {
  var mood: MascotMood
  var stage: Int
  var outfit: MascotOutfit?
  var droopy: Bool
  var plant: MascotPlant
}

/// 小日's little world at the top of 今天. The sky follows the clock, every task of the day
/// is a bud on the hill that blooms when it's done, and the mailbox holds 小日's postcards.
struct WorldScene: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let now: Date
  let done: Int
  let total: Int
  let look: MascotLook
  /// Bumped on each tap of 小日.
  var pokes = 0
  /// A festival outfit that can be worn today decorates the hill.
  var festival: MascotOutfit?
  /// A postcard is waiting: the mailbox flag is up.
  var hasMail = false
  var onMascotTap: () -> Void = {}
  var onMascotHold: () -> Void = {}
  var onMailbox: () -> Void = {}

  @State private var drift = false

  /// Where the flowers stand along the hill (fraction of the width), clear of 小日 and the mailbox.
  private static let flowerSlots: [CGFloat] = [0.27, 0.36, 0.45, 0.9, 0.31, 0.41, 0.95, 0.5]
  private static let mascotX: CGFloat = 0.7
  private static let mailboxX: CGFloat = 0.12

  var body: some View {
    let time = SkyTime.at(now)
    GeometryReader { geo in
      let w = geo.size.width, h = geo.size.height
      ZStack(alignment: .topLeading) {
        LinearGradient(colors: [time.sky.top, time.sky.bottom], startPoint: .top, endPoint: .bottom)
        if time == .night || time == .dusk { stars(w: w, h: h, faint: time == .dusk) }
        sunOrMoon(time, w: w, h: h)
        if !time.isDark { clouds(w: w, h: h) }
        if festival == .lunarHat || festival == .bunnyEars { lanterns(w: w, h: h) }

        HillShape(left: 0.6, top: 0.46, right: 0.58).fill(time.hills.far)
        HillShape(left: 0.8, top: 0.6, right: 0.74).fill(time.hills.near)

        if festival == .santaHat { snow(w: w, h: h) }
        festivalProps(w: w, h: h)
        flowers(w: w, h: h)

        Mailbox(flagUp: hasMail, size: h * 0.3)
          .position(x: w * Self.mailboxX, y: hillY(Self.mailboxX, h: h) - h * 0.13)
          .onTapGesture(perform: onMailbox)
          .accessibilityElement()
          .accessibilityLabel(hasMail ? "邮筒，有新的明信片" : "邮筒，小日的明信片")
          .accessibilityAddTraits(.isButton)
          .accessibilityAction { onMailbox() }

        if look.droopy { rainCloud(w: w, h: h) }
        mascot(w: w, h: h)
      }
      .frame(width: w, height: h)
    }
    .overlay(alignment: .bottomLeading) { progressChip(dark: time.isDark) }
    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 1))
    .onAppear { if !reduceMotion { drift = true } }
  }

  // MARK: Hill geometry

  /// The near hill's top edge at `x` (a fraction of the width), matching `HillShape(0.8, 0.6, 0.74)`.
  private func hillY(_ x: CGFloat, h: CGFloat) -> CGFloat {
    HillShape.y(at: x, left: 0.8, top: 0.6, right: 0.74) * h
  }

  // MARK: Sky

  private func sunOrMoon(_ time: SkyTime, w: CGFloat, h: CGFloat) -> some View {
    let minutes = DayKey.calendar.component(.hour, from: now) * 60 + DayKey.calendar.component(.minute, from: now)
    let hour = Double(minutes) / 60
    // Across the sky from 6:00 to 18:00 (the moon from 18:00 to 6:00), highest at the middle.
    let nightHour: Double = hour < 12 ? hour + 24 : hour
    let t: Double = time.hasSun ? (hour - 6) / 12 : (nightHour - 18) / 12
    let p: Double = min(max(t, 0.05), 0.95)
    let x: CGFloat = w * CGFloat(0.08 + 0.84 * p)
    let y: CGFloat = h * CGFloat(0.42 - 0.3 * sin(Double.pi * p))
    let side: CGFloat = h * 0.17
    return Group {
      if time.hasSun {
        Circle()
          .fill(time == .day || time == .morning ? Color(hex: "#ffd76a") : Color(hex: "#ffb36b"))
          .frame(width: side, height: side)
          .shadow(color: Color(hex: "#ffd76a").opacity(0.8), radius: side * 0.45)
      } else {
        // A full moon at 中秋, a crescent otherwise.
        Circle()
          .fill(Color(hex: "#f7efc9"))
          .frame(width: side, height: side)
          .overlay {
            if festival != .bunnyEars {
              Circle().fill(time.sky.top).frame(width: side, height: side).offset(x: side * 0.32, y: -side * 0.12)
            }
          }
          .shadow(color: Color(hex: "#f7efc9").opacity(0.6), radius: side * 0.35)
      }
    }
    .position(x: x, y: y)
    .accessibilityHidden(true)
  }

  private func stars(w: CGFloat, h: CGFloat, faint: Bool) -> some View {
    let spots: [(CGFloat, CGFloat, CGFloat)] = [
      (0.06, 0.1, 5), (0.18, 0.28, 3), (0.27, 0.08, 4), (0.4, 0.2, 3), (0.52, 0.06, 5), (0.6, 0.3, 3),
      (0.7, 0.12, 4), (0.82, 0.24, 3), (0.92, 0.08, 5), (0.34, 0.36, 2), (0.86, 0.4, 2), (0.12, 0.42, 2),
    ]
    return ForEach(Array(spots.enumerated()), id: \.offset) { index, spot in
      Sparkle()
        .fill(Color.white.opacity(faint ? 0.5 : 0.9))
        .frame(width: spot.2 * 2, height: spot.2 * 2)
        .phaseAnimator(reduceMotion ? [true] : [true, false]) { view, bright in
          view.opacity(bright ? 1 : 0.35)
        } animation: { _ in
          .easeInOut(duration: 1.2 + Double(index % 4) * 0.4)
        }
        .position(x: w * spot.0, y: h * spot.1)
    }
    .accessibilityHidden(true)
  }

  private func clouds(w: CGFloat, h: CGFloat) -> some View {
    Group {
      Cloud().fill(Color.white.opacity(0.9))
        .frame(width: h * 0.42, height: h * 0.16)
        .position(x: w * 0.3, y: h * 0.16)
        .offset(x: drift ? 22 : -22)
      Cloud().fill(Color.white.opacity(0.75))
        .frame(width: h * 0.32, height: h * 0.12)
        .position(x: w * 0.62, y: h * 0.3)
        .offset(x: drift ? -16 : 16)
    }
    .animation(.easeInOut(duration: 14).repeatForever(autoreverses: true), value: drift)
    .accessibilityHidden(true)
  }

  private func rainCloud(w: CGFloat, h: CGFloat) -> some View {
    VStack(spacing: 2) {
      Cloud().fill(Color(hex: "#b9c0cc")).frame(width: h * 0.3, height: h * 0.11)
      HStack(spacing: 7) {
        ForEach(0..<3, id: \.self) { _ in
          Capsule().fill(Color(hex: "#8fb3d9")).frame(width: 2, height: 7)
        }
      }
    }
    .position(x: w * Self.mascotX, y: h * 0.18)
    .accessibilityHidden(true)
  }

  // MARK: Hill

  private func flowers(w: CGFloat, h: CGFloat) -> some View {
    let count = min(total, Self.flowerSlots.count)
    let size = h * 0.11
    return ForEach(0..<count, id: \.self) { index in
      let x: CGFloat = Self.flowerSlots[index]
      // The second row stands a little lower on the hill.
      let lower: CGFloat = index >= 4 ? h * 0.09 : h * 0.02
      let y: CGFloat = hillY(x, h: h) - size * 0.55 + lower
      HillFlower(bloomed: index < done, plant: look.plant, size: size)
        .position(x: w * x, y: y)
    }
    .accessibilityHidden(true)
  }

  @ViewBuilder
  private func festivalProps(w: CGFloat, h: CGFloat) -> some View {
    switch festival {
    case .some(.pumpkin):
      ForEach([CGFloat(0.2), CGFloat(0.86)], id: \.self) { (x: CGFloat) in
        let y: CGFloat = hillY(x, h: h) + h * 0.03
        Pumpkin(size: h * 0.12).position(x: w * x, y: y)
      }
      .accessibilityHidden(true)
    case .some(.santaHat):
      ChristmasTree(size: h * 0.34)
        .position(x: w * 0.92, y: hillY(0.92, h: h) - h * 0.12)
        .accessibilityHidden(true)
    default:
      EmptyView()
    }
  }

  private func lanterns(w: CGFloat, h: CGFloat) -> some View {
    let spots: [(x: CGFloat, y: CGFloat)] = [(0.06, 0.12), (0.94, 0.16)]
    return ForEach(spots, id: \.x) { spot in
      Lantern(size: h * 0.14)
        .position(x: w * spot.x, y: h * spot.y)
    }
    .accessibilityHidden(true)
  }

  private func snow(w: CGFloat, h: CGFloat) -> some View {
    let flakes: [(CGFloat, CGFloat)] = [
      (0.08, 0.2), (0.2, 0.5), (0.32, 0.14), (0.46, 0.42), (0.55, 0.1), (0.64, 0.5), (0.78, 0.3), (0.9, 0.16), (0.96, 0.46),
    ]
    return ForEach(Array(flakes.enumerated()), id: \.offset) { _, f in
      Circle().fill(Color.white.opacity(0.9)).frame(width: 4, height: 4)
        .position(x: w * f.0, y: h * f.1)
        .offset(y: drift ? 6 : -6)
    }
    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: drift)
    .accessibilityHidden(true)
  }

  // MARK: 小日

  private func mascot(w: CGFloat, h: CGFloat) -> some View {
    let size: CGFloat = h * 0.46
    let x: CGFloat = w * Self.mascotX
    let y: CGFloat = hillY(Self.mascotX, h: h) - size * 0.36
    let tap = onMascotTap, hold = onMascotHold
    return LivelyMascot(look: look, size: size, hops: done, pokes: pokes)
      .frame(width: size * 1.2, height: size * 1.2)
      .contentShape(Rectangle())
      .onTapGesture { tap() }
      .onLongPressGesture(minimumDuration: 0.4) { hold() }
      .position(x: x, y: y)
      .accessibilityElement()
      .accessibilityLabel("小日")
      .accessibilityAddTraits(.isButton)
      .accessibilityHint("轻点和小日玩，长按打开小日的成长")
      .accessibilityAction { tap() }
      .accessibilityAction(named: "小日的成长") { hold() }
  }

  private func progressChip(dark: Bool) -> some View {
    HStack(spacing: 5) {
      Image(systemName: "camera.macro")
      Text(total == 0 ? "自由的一天" : "开了 \(done)/\(total) 朵")
        .monospacedDigit()
        .contentTransition(.numericText())
    }
    .font(.app(.footnote).weight(.semibold))
    .foregroundStyle(dark ? Color.white : Color(hex: "#2f4a2a"))
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(dark ? Color.white.opacity(0.16) : Color.white.opacity(0.7), in: Capsule())
    .padding(12)
    .animation(.snappy, value: done)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(total == 0 ? "今天没有事项" : "今天完成 \(done) 件，共 \(total) 件")
  }
}

// MARK: - 小日 with its reactions

/// How 小日 moves when tapped.
private struct PokeMotion {
  var lift: CGFloat = 0
  var turn: Double = 0
  var scale: CGFloat = 1
}

/// 小日 hopping when a task is ticked (`hops` changes), playing when tapped (`pokes`), and
/// breathing gently the rest of the time.
struct LivelyMascot: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let look: MascotLook
  let size: CGFloat
  var hops = 0
  var pokes = 0

  var body: some View {
    let base = MascotView(mood: look.mood, size: size, stage: look.stage, outfit: look.outfit, droopy: look.droopy, plant: look.plant)
    if reduceMotion {
      base
    } else {
      base
        .keyframeAnimator(initialValue: CGFloat(0), trigger: hops) { view, hop in
          view.offset(y: hop)
        } keyframes: { _ in
          KeyframeTrack {
            SpringKeyframe(-size * 0.14, duration: 0.18, spring: .snappy)
            SpringKeyframe(0, duration: 0.35, spring: .bouncy)
          }
        }
        .keyframeAnimator(initialValue: PokeMotion(), trigger: pokes) { view, m in
          view
            .offset(y: m.lift)
            .rotationEffect(.degrees(m.turn))
            .scaleEffect(m.scale)
        } keyframes: { _ in
          let kind = pokes % 3
          let turns: [Double] = kind == 1 ? [120, 240, 360, 360] : kind == 2 ? [14, -14, 8, 0] : [0, 0, 0, 0]
          KeyframeTrack(\.lift) {
            SpringKeyframe(kind == 0 ? -size * 0.2 : -size * 0.05, duration: 0.18, spring: .snappy)
            SpringKeyframe(0, duration: 0.4, spring: .bouncy)
          }
          KeyframeTrack(\.turn) {
            CubicKeyframe(turns[0], duration: 0.12)
            CubicKeyframe(turns[1], duration: 0.12)
            CubicKeyframe(turns[2], duration: 0.12)
            CubicKeyframe(turns[3], duration: 0.14)
          }
          KeyframeTrack(\.scale) {
            SpringKeyframe(1.08, duration: 0.15, spring: .snappy)
            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
          }
        }
        .phaseAnimator([false, true]) { view, breathe in
          view.scaleEffect(breathe ? 1.03 : 1, anchor: .bottom)
        } animation: { _ in
          .easeInOut(duration: 1.8)
        }
    }
  }
}

// MARK: - Pieces of the scene

/// A rolling hill: a quadratic curve from `left` to `right` (fractions of the height) that
/// peaks towards `top` in the middle, filled down to the bottom.
struct HillShape: Shape {
  let left: CGFloat
  let top: CGFloat
  let right: CGFloat

  func path(in r: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: r.minX, y: r.minY + r.height * left))
    p.addQuadCurve(
      to: CGPoint(x: r.maxX, y: r.minY + r.height * right),
      control: CGPoint(x: r.midX, y: r.minY + r.height * top))
    p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
    p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
    p.closeSubpath()
    return p
  }

  /// The curve's height at `x` (0…1); with the control point centred, x runs linearly with t.
  static func y(at x: CGFloat, left: CGFloat, top: CGFloat, right: CGFloat) -> CGFloat {
    let t = min(max(x, 0), 1)
    return (1 - t) * (1 - t) * left + 2 * (1 - t) * t * top + t * t * right
  }
}

/// Three puffs on a flat base.
struct Cloud: Shape {
  func path(in r: CGRect) -> Path {
    var p = Path()
    let h = r.height
    p.addRoundedRect(in: CGRect(x: r.minX, y: r.minY + h * 0.45, width: r.width, height: h * 0.55), cornerSize: CGSize(width: h * 0.27, height: h * 0.27))
    p.addEllipse(in: CGRect(x: r.minX + r.width * 0.14, y: r.minY + h * 0.2, width: h * 0.7, height: h * 0.7))
    p.addEllipse(in: CGRect(x: r.minX + r.width * 0.38, y: r.minY, width: h * 0.95, height: h * 0.95))
    return p
  }
}

/// A task on the hill: a closed bud until it's done, then a flower of 小日's plant.
private struct HillFlower: View {
  let bloomed: Bool
  let plant: MascotPlant
  let size: CGFloat
  private let stem = Color(hex: "#4f8f45")

  var body: some View {
    VStack(spacing: -size * 0.08) {
      ZStack {
        if bloomed {
          ForEach(0..<5, id: \.self) { i in
            Circle()
              .fill(plant.petal)
              .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 0.6))
              .frame(width: size * 0.46, height: size * 0.46)
              .offset(y: -size * 0.25)
              .rotationEffect(.degrees(Double(i) * 72))
          }
          Circle().fill(plant.center).frame(width: size * 0.34, height: size * 0.34)
        } else {
          Ellipse()
            .fill(plant.bud)
            .overlay(Ellipse().stroke(stem.opacity(0.6), lineWidth: 0.8))
            .frame(width: size * 0.32, height: size * 0.44)
            .offset(y: size * 0.12)
        }
      }
      .frame(width: size, height: size)
      .scaleEffect(bloomed ? 1 : 0.85, anchor: .bottom)
      .animation(.spring(response: 0.45, dampingFraction: 0.55), value: bloomed)
      Capsule().fill(stem).frame(width: max(2, size * 0.09), height: size * 0.6)
    }
  }
}

/// A red mailbox on a post; the yellow flag is up when a postcard is waiting.
private struct Mailbox: View {
  let flagUp: Bool
  let size: CGFloat

  var body: some View {
    ZStack {
      Rectangle()
        .fill(Color(hex: "#8a5a3b"))
        .frame(width: size * 0.1, height: size * 0.55)
        .offset(y: size * 0.24)
      UnevenRoundedRectangle(topLeadingRadius: size * 0.2, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: size * 0.2)
        .fill(Color(hex: "#e0645a"))
        .overlay(
          UnevenRoundedRectangle(topLeadingRadius: size * 0.2, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: size * 0.2)
            .stroke(Color(hex: "#5c3b2e"), lineWidth: 1.2))
        .frame(width: size * 0.62, height: size * 0.4)
        .offset(y: -size * 0.1)
      Capsule().fill(Color(hex: "#5c3b2e")).frame(width: size * 0.3, height: size * 0.05).offset(y: -size * 0.12)
      // The flag swings up on the right side.
      Rectangle()
        .fill(Color(hex: "#f2b33d"))
        .frame(width: size * 0.05, height: size * 0.3)
        .overlay(alignment: .top) {
          Rectangle().fill(Color(hex: "#f2b33d")).frame(width: size * 0.16, height: size * 0.1).offset(x: size * 0.06)
        }
        .rotationEffect(.degrees(flagUp ? 0 : 90), anchor: .bottom)
        .offset(x: size * 0.36, y: -size * 0.2)
        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: flagUp)
      if flagUp {
        Image(systemName: "envelope.fill")
          .font(.system(size: size * 0.2))
          .foregroundStyle(.white)
          .offset(y: -size * 0.1)
      }
    }
    .frame(width: size, height: size)
  }
}

/// A red paper lantern on a string, for 春节 and 中秋.
private struct Lantern: View {
  let size: CGFloat

  var body: some View {
    VStack(spacing: 0) {
      Rectangle().fill(Color(hex: "#5c3b2e")).frame(width: 1, height: size * 0.5)
      Capsule().fill(Color(hex: "#f2b33d")).frame(width: size * 0.45, height: size * 0.12)
      Ellipse()
        .fill(Color(hex: "#e04a3a"))
        .overlay {
          HStack(spacing: size * 0.18) {
            ForEach(0..<3, id: \.self) { _ in Capsule().fill(Color(hex: "#b8352a")).frame(width: 1.2) }
          }
          .padding(.vertical, size * 0.06)
        }
        .frame(width: size, height: size * 0.8)
        .shadow(color: Color(hex: "#ff8a5c").opacity(0.7), radius: size * 0.3)
      Capsule().fill(Color(hex: "#f2b33d")).frame(width: size * 0.45, height: size * 0.12)
      Rectangle().fill(Color(hex: "#e04a3a")).frame(width: 2, height: size * 0.3)
    }
  }
}

private struct Pumpkin: View {
  let size: CGFloat

  var body: some View {
    ZStack {
      Ellipse().fill(Color(hex: "#e8782f")).frame(width: size * 0.6, height: size * 0.8).offset(x: -size * 0.22)
      Ellipse().fill(Color(hex: "#e8782f")).frame(width: size * 0.6, height: size * 0.8).offset(x: size * 0.22)
      Ellipse().fill(Color(hex: "#f2913f")).frame(width: size * 0.62, height: size * 0.84)
      Capsule().fill(Color(hex: "#5f7f3a")).frame(width: size * 0.1, height: size * 0.24).offset(y: -size * 0.46)
    }
    .frame(width: size * 1.1, height: size)
  }
}

private struct ChristmasTree: View {
  let size: CGFloat
  private static let baubles: [(x: CGFloat, y: CGFloat)] = [(-0.12, -0.1), (0.1, 0.06), (-0.16, 0.22), (0.18, 0.26)]

  var body: some View {
    ZStack {
      ForEach(0..<3, id: \.self) { i in
        Triangle()
          .fill(Color(hex: "#2f7a4a"))
          .frame(width: size * (0.5 + CGFloat(i) * 0.18), height: size * 0.36)
          .offset(y: -size * 0.24 + CGFloat(i) * size * 0.18)
      }
      Rectangle().fill(Color(hex: "#8a5a3b")).frame(width: size * 0.1, height: size * 0.14).offset(y: size * 0.4)
      Sparkle().fill(Color(hex: "#ffd76a")).frame(width: size * 0.2, height: size * 0.2).offset(y: -size * 0.46)
      ForEach(Self.baubles, id: \.x) { spot in
        Circle().fill(Color(hex: "#e04a3a")).frame(width: size * 0.06, height: size * 0.06)
          .offset(x: size * spot.x, y: size * spot.y)
      }
    }
    .frame(width: size, height: size)
  }
}

private struct Triangle: Shape {
  func path(in r: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: r.midX, y: r.minY))
    p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
    p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
    p.closeSubpath()
    return p
  }
}
