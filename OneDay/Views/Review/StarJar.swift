import SwiftUI

extension AppState {
  /// The month's moods as stars, oldest first: one per day that has a mood.
  func moodStars(month: Date, today: String) -> [(day: String, level: Int)] {
    DayKey.days(inMonth: month).filter { $0 <= today }.compactMap { day in
      mood(on: day).flatMap { Mood(average: $0) }.map { (day, $0.rawValue) }
    }
  }
}

/// A five-pointed star.
struct StarShape: Shape {
  func path(in r: CGRect) -> Path {
    var p = Path()
    let c = CGPoint(x: r.midX, y: r.midY)
    let outer = min(r.width, r.height) / 2
    let inner = outer * 0.48
    for i in 0..<10 {
      let radius = i.isMultiple(of: 2) ? outer : inner
      let angle = Double(i) * .pi / 5 - .pi / 2
      let point = CGPoint(x: c.x + radius * cos(angle), y: c.y + radius * sin(angle))
      if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
    }
    p.closeSubpath()
    return p
  }
}

/// A glass jar that each day's mood drops into as a colored star.
struct StarJar: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  /// Mood levels (1…5), oldest first.
  let stars: [Int]
  /// Shown on the paper tag, e.g. "10月".
  let label: String
  var width: CGFloat = 120
  /// Drop the stars in one by one when first shown.
  var animated = true
  @State private var landed: Bool

  private static let columns = 5

  init(stars: [Int], label: String, width: CGFloat = 120, animated: Bool = true) {
    self.stars = stars
    self.label = label
    self.width = width
    self.animated = animated
    // A still jar (e.g. rendered for sharing) starts full; onAppear may never run there.
    _landed = State(initialValue: !animated)
  }

  var body: some View {
    let w = width, h = width * 1.3
    let neckTop = h * 0.1
    let glass = CGRect(x: w * 0.05, y: h * 0.16, width: w * 0.9, height: h * 0.84)
    let starSize = w * 0.17
    ZStack(alignment: .topLeading) {
      // Glass.
      RoundedRectangle(cornerRadius: w * 0.2, style: .continuous)
        .fill(Color.white.opacity(0.28))
        .frame(width: glass.width, height: glass.height)
        .offset(x: glass.minX, y: glass.minY)

      // Stars, packed from the bottom.
      ForEach(Array(stars.enumerated()), id: \.offset) { index, level in
        let spot = position(index, in: glass, star: starSize)
        StarShape()
          .fill(Color(hex: (Mood(rawValue: level) ?? .okay).hex))
          .overlay(StarShape().stroke(Color.white.opacity(0.7), lineWidth: 1))
          .frame(width: starSize, height: starSize)
          .rotationEffect(.degrees(spot.turn))
          .position(x: spot.point.x, y: spot.point.y)
          .offset(y: landed ? 0 : -(spot.point.y + starSize))
          .opacity(landed ? 1 : 0)
          .animation(
            .spring(response: 0.5, dampingFraction: 0.62).delay(Double(index) * 0.04),
            value: landed)
      }

      // Glass outline and a highlight on top of the stars.
      RoundedRectangle(cornerRadius: w * 0.2, style: .continuous)
        .stroke(Color.white.opacity(0.9), lineWidth: 2)
        .overlay(RoundedRectangle(cornerRadius: w * 0.2, style: .continuous).stroke(Color.black.opacity(0.12), lineWidth: 1))
        .frame(width: glass.width, height: glass.height)
        .offset(x: glass.minX, y: glass.minY)
      Capsule()
        .fill(Color.white.opacity(0.55))
        .frame(width: w * 0.05, height: glass.height * 0.5)
        .offset(x: glass.minX + w * 0.08, y: glass.minY + glass.height * 0.14)

      // Cork lid and ribbon.
      RoundedRectangle(cornerRadius: w * 0.04, style: .continuous)
        .fill(Color(hex: "#cfa57a"))
        .overlay(RoundedRectangle(cornerRadius: w * 0.04, style: .continuous).stroke(Color(hex: "#8a5a3b").opacity(0.5), lineWidth: 1))
        .frame(width: w * 0.62, height: h * 0.1)
        .offset(x: w * 0.19, y: neckTop - h * 0.06)
      Capsule()
        .fill(Color(hex: "#e0645a"))
        .frame(width: w * 0.68, height: h * 0.035)
        .offset(x: w * 0.16, y: neckTop + h * 0.04)

      // Paper tag.
      Text(label)
        .font(.app(size: max(9, w * 0.09), weight: .bold))
        .foregroundStyle(Color(hex: "#5c3b2e"))
        .padding(.horizontal, w * 0.05)
        .padding(.vertical, w * 0.02)
        .background(Color(hex: "#fbf3df"), in: RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(hex: "#8a5a3b").opacity(0.4), lineWidth: 0.8))
        .rotationEffect(.degrees(8))
        .offset(x: w * 0.66, y: neckTop + h * 0.06)
    }
    .frame(width: w, height: h, alignment: .topLeading)
    .onAppear {
      if !landed {
        if reduceMotion {
          landed = true
        } else {
          DispatchQueue.main.async { landed = true }
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(label)的星星罐，\(stars.count) 颗星星")
  }

  /// Rows of five from the bottom, odd rows shifted half a step, each star nudged and turned a
  /// little (the same way every time) so the jar looks filled by hand.
  private func position(_ index: Int, in glass: CGRect, star: CGFloat) -> (point: CGPoint, turn: Double) {
    let row = index / Self.columns, col = index % Self.columns
    let inner = glass.insetBy(dx: glass.width * 0.07, dy: glass.height * 0.04)
    let step = inner.width / CGFloat(Self.columns)
    let shift = row.isMultiple(of: 2) ? 0 : step * 0.35
    let jitter = { (seed: Int) -> CGFloat in CGFloat((seed * 7919 + 13) % 17) / 17 - 0.5 }
    let x = inner.minX + step * (CGFloat(col) + 0.5) + shift * (col == Self.columns - 1 ? -1 : 1) + jitter(index) * step * 0.3
    let y = inner.maxY - star * 0.5 - CGFloat(row) * star * 0.82 + jitter(index + 5) * star * 0.2
    return (CGPoint(x: x, y: y), Double(jitter(index + 11)) * 60)
  }
}

/// 统计 → this month's jar, with how many of each mood went in.
struct StarJarCard: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  @State private var showing = false

  var body: some View {
    let month = DayKey.monthStart(DayKey.date(store.today))
    let stars = store.state.moodStars(month: month, today: store.today)
    let monthNumber = DayKey.calendar.component(.month, from: month)
    Button {
      showing = true
    } label: {
      HStack(spacing: Spacing.card) {
        StarJar(stars: stars.map(\.level), label: "\(monthNumber)月", width: 96)
        VStack(alignment: .leading, spacing: 8) {
          Text("星星罐").font(.app(.headline))
          Text(stars.isEmpty ? "选一个心情，第一颗星星就会掉进罐子里。" : "\(monthNumber)月攒了 \(stars.count) 颗星星")
            .font(.app(.subheadline))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          MoodTally(levels: stars.map(\.level))
          HStack(spacing: 3) {
            Text("打开罐子")
            Image(systemName: "chevron.right").font(.app(.caption).weight(.semibold))
          }
          .font(.app(.subheadline).weight(.medium))
          .foregroundStyle(accent)
        }
        Spacer(minLength: 0)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .card()
    .sheet(isPresented: $showing) { StarJarSheet().oneDaySheet() }
    #if DEBUG
    .onAppear {
      if UserDefaults.standard.bool(forKey: "OneDayJar") { showing = true }
    }
    #endif
  }
}

/// Small faces with how many stars of each mood.
private struct MoodTally: View {
  let levels: [Int]

  var body: some View {
    HStack(spacing: 8) {
      ForEach(Mood.allCases.reversed()) { mood in
        let count = levels.filter { $0 == mood.rawValue }.count
        if count > 0 {
          HStack(spacing: 2) {
            MoodFace(level: mood.rawValue, size: 16)
            Text("\(count)").font(.app(.caption).monospacedDigit()).foregroundStyle(.secondary)
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("\(mood.label) \(count) 天")
        }
      }
    }
  }
}

/// The jar up close, month by month, and a card to share it.
struct StarJarSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent
  @State private var month = DayKey.monthStart(Date())
  @State private var sharing = false

  var body: some View {
    let stars = store.state.moodStars(month: month, today: store.today)
    let monthNumber = DayKey.calendar.component(.month, from: month)
    NavigationStack {
      ScrollView {
        VStack(spacing: Spacing.section) {
          HStack {
            shift("chevron.left", label: "上个月", by: -1)
            Spacer()
            Text(DayKey.monthLabel(month)).font(.journal(.title3, size: 20, bold: true))
            Spacer()
            shift("chevron.right", label: "下个月", by: 1)
              .disabled(month >= DayKey.monthStart(Date()))
          }
          StarJar(stars: stars.map(\.level), label: "\(monthNumber)月", width: 230)
            .id(month)
          VStack(spacing: 8) {
            Text(stars.isEmpty ? "这个月的罐子还是空的" : "\(stars.count) 颗星星")
              .font(.app(.title3).weight(.bold))
            MoodTally(levels: stars.map(\.level))
            Text("每天的心情都会变成一颗星星，掉进这个月的罐子里。")
              .font(.app(.footnote))
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
        }
        .padding(.horizontal, Spacing.page)
        .padding(.vertical, Spacing.stack)
      }
      .background { AppBackground() }
      .navigationTitle("星星罐")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            sharing = true
          } label: {
            Image(systemName: "square.and.arrow.up")
          }
          .accessibilityLabel("分享")
          .disabled(stars.isEmpty)
        }
        ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
      }
      .sheet(isPresented: $sharing) {
        ShareCardSheet(title: "\(monthNumber)月的星星罐") {
          StarJarShareCard(stars: stars.map(\.level), month: month)
        }
        .oneDaySheet()
      }
    }
  }

  private func shift(_ icon: String, label: String, by value: Int) -> some View {
    Button {
      withAnimation(.snappy) { month = DayKey.shiftMonth(month, by: value) }
    } label: {
      Image(systemName: icon).font(.app(.body).weight(.semibold)).frame(width: 22, height: 22)
    }
    .oneDayButton()
    .buttonBorderShape(.circle)
    .accessibilityLabel(label)
  }
}

/// The jar on paper, for sharing.
private struct StarJarShareCard: View {
  let stars: [Int]
  let month: Date

  var body: some View {
    let comps = DayKey.calendar.dateComponents([.year, .month], from: month)
    VStack(spacing: 18) {
      VStack(spacing: 4) {
        Text("\(String(comps.year ?? 0))").font(.app(.footnote).weight(.medium)).foregroundStyle(Color(hex: "#8a8175"))
        Text("\(comps.month ?? 0)月的星星罐").font(.journal(.title, size: 28, bold: true)).foregroundStyle(Color(hex: "#2b2722"))
      }
      StarJar(stars: stars, label: "\(comps.month ?? 0)月", width: 200, animated: false)
      Text("\(stars.count) 颗星星，\(stars.count) 天的心情")
        .font(.journal(.body, size: 17))
        .foregroundStyle(Color(hex: "#2b2722"))
      Text("OneDay")
        .font(.app(.caption).weight(.semibold))
        .foregroundStyle(Color(hex: "#8a8175"))
    }
    .padding(28)
    .frame(width: 340)
    .background(
      LinearGradient(colors: [Color(hex: "#fbf7ef"), Color(hex: "#f3e6d3")], startPoint: .top, endPoint: .bottom))
  }
}
