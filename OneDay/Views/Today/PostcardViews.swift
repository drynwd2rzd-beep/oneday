import SwiftUI

private enum CardPaper {
  static let bg = Color(hex: "#fbf7ef")
  static let ink = Color(hex: "#2b2722")
  static let soft = Color(hex: "#8a8175")
  static let stamp = Color(hex: "#d9534f")
}

/// The picture side of a postcard: the place, its landmark, and 小日 standing in front.
struct PostcardPicture: View {
  let destination: Destination
  let look: MascotLook

  private static let stars: [(x: CGFloat, y: CGFloat)] = [(0.1, 0.12), (0.26, 0.3), (0.44, 0.1), (0.62, 0.24), (0.9, 0.14), (0.78, 0.36)]
  private static let extras: [(x: CGFloat, y: CGFloat)] = [(0.14, 0.24), (0.58, 0.14), (0.28, 0.5)]

  private static func hill(_ x: CGFloat) -> CGFloat {
    HillShape.y(at: x, left: 0.8, top: 0.68, right: 0.76)
  }

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width, h = geo.size.height
      let ink = Color(hex: destination.ink)
      ZStack {
        LinearGradient(
          colors: [Color(hex: destination.sky.0), Color(hex: destination.sky.1)],
          startPoint: .top, endPoint: .bottom)
        if destination.night {
          ForEach(Array(Self.stars.enumerated()), id: \.offset) { _, spot in
            Sparkle().fill(Color.white.opacity(0.9)).frame(width: h * 0.045, height: h * 0.045)
              .position(x: w * spot.x, y: h * spot.y)
          }
        } else {
          Circle()
            .fill(Color(hex: "#ffd76a"))
            .frame(width: h * 0.18, height: h * 0.18)
            .shadow(color: Color(hex: "#ffd76a").opacity(0.8), radius: h * 0.08)
            .position(x: w * 0.86, y: h * 0.2)
        }
        ForEach(Array(Self.extras.enumerated()), id: \.offset) { index, spot in
          Image(systemName: destination.extra)
            .font(.system(size: h * (index == 1 ? 0.07 : 0.09)))
            .foregroundStyle(destination.night ? Color.white.opacity(0.8) : ink.opacity(0.45))
            .position(x: w * spot.x, y: h * spot.y)
        }
        HillShape(left: 0.8, top: 0.68, right: 0.76).fill(Color(hex: destination.ground))
        Image(systemName: destination.symbol)
          .font(.system(size: h * 0.36, weight: .regular))
          .foregroundStyle(ink)
          .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
          .position(x: w * 0.36, y: Self.hill(0.36) * h - h * 0.16)
        MascotView(mood: .happy, size: h * 0.34, stage: look.stage, outfit: look.outfit, plant: look.plant)
          .position(x: w * 0.76, y: Self.hill(0.76) * h - h * 0.1)
      }
      .frame(width: w, height: h)
    }
    .accessibilityHidden(true)
  }
}

/// A whole postcard: the picture on top, 小日's note, a stamp and a postmark below.
struct PostcardCard: View {
  let card: Postcard
  let look: MascotLook
  let name: String

  var body: some View {
    let d = card.destination
    VStack(alignment: .leading, spacing: 16) {
      PostcardPicture(destination: d, look: look)
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .bottomLeading) {
          Text(d.name)
            .font(.journal(.title2, size: 24, bold: true))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
            .padding(14)
        }
      HStack(alignment: .top, spacing: 14) {
        VStack(alignment: .leading, spacing: 10) {
          Text("来自\(d.region)的明信片")
            .font(.app(.footnote).weight(.semibold))
            .foregroundStyle(CardPaper.soft)
          Text(d.message)
            .font(.journal(.body, size: 19))
            .foregroundStyle(CardPaper.ink)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
          Text("—— 小日")
            .font(.journal(.subheadline, size: 15))
            .foregroundStyle(CardPaper.soft)
        }
        Spacer(minLength: 0)
        stamp(d)
      }
      Rectangle()
        .fill(CardPaper.soft.opacity(0.35))
        .frame(height: 1)
      HStack {
        Text("寄给 \(name.isEmpty ? "你" : name)")
        Spacer()
        Text("No.\(card.number) · \(DayKey.fullDate(card.day))")
          .monospacedDigit()
      }
      .font(.app(.caption))
      .foregroundStyle(CardPaper.soft)
    }
    .padding(18)
    .frame(width: 340)
    .background(CardPaper.bg)
    .environment(\.colorScheme, .light)
  }

  /// A small stamp of the place with a round postmark over its corner.
  private func stamp(_ d: Destination) -> some View {
    VStack(spacing: 3) {
      ZStack {
        LinearGradient(colors: [Color(hex: d.sky.0), Color(hex: d.sky.1)], startPoint: .top, endPoint: .bottom)
        Image(systemName: d.symbol)
          .font(.system(size: 24))
          .foregroundStyle(Color(hex: d.ink))
      }
      .frame(width: 52, height: 52)
      Text("小日邮政").font(.app(size: 8, weight: .bold)).foregroundStyle(CardPaper.stamp)
    }
    .padding(5)
    .background(Color.white)
    .overlay(Rectangle().strokeBorder(CardPaper.stamp.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])))
    .overlay(alignment: .bottomLeading) {
      Text("\(DayKey.calendar.component(.month, from: DayKey.date(card.day))).\(DayKey.calendar.component(.day, from: DayKey.date(card.day)))\n\(d.region)")
        .font(.app(size: 9, weight: .bold))
        .multilineTextAlignment(.center)
        .foregroundStyle(CardPaper.stamp.opacity(0.7))
        .frame(width: 46, height: 46)
        .overlay(Circle().stroke(CardPaper.stamp.opacity(0.6), lineWidth: 1.5))
        .rotationEffect(.degrees(-14))
        .offset(x: -24, y: 18)
    }
    .accessibilityHidden(true)
  }
}

/// One postcard, ready to share.
struct PostcardSheet: View {
  @Environment(Store.self) private var store
  let card: Postcard

  var body: some View {
    ShareCardSheet(title: "来自\(card.destination.region)") {
      PostcardCard(card: card, look: store.postcardLook, name: store.settings.name == Settings.defaultName ? "" : store.settings.name)
    }
  }
}

/// Every postcard so far, newest first, and how far the next trip is.
struct PostcardsSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent
  @State private var open: Postcard?

  var body: some View {
    let cards = store.state.postcards(today: store.today)
    let left = store.state.daysToNextPostcard(today: store.today)
    let look = store.postcardLook
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.stack) {
          HStack(spacing: 12) {
            Image(systemName: "airplane")
              .font(.app(.title3))
              .foregroundStyle(accent)
              .frame(width: 40, height: 40)
              .background(accent.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
              Text(cards.isEmpty ? "小日在准备第一次旅行" : "小日正在路上")
                .font(.app(.headline))
              Text("再来 \(left) 天，就会寄来下一张明信片")
                .font(.app(.subheadline))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
          }
          .card()

          if cards.isEmpty {
            Text("每来 \(Travel.daysPerTrip) 天（不用连续），小日就会出门旅行一次。")
              .font(.app(.footnote))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 4)
          } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
              ForEach(cards.reversed()) { card in
                Button {
                  open = card
                } label: {
                  VStack(alignment: .leading, spacing: 6) {
                    PostcardPicture(destination: card.destination, look: look)
                      .aspectRatio(1.4, contentMode: .fit)
                      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text(card.destination.name).font(.app(.subheadline).weight(.semibold))
                    Text("\(card.destination.region) · \(DayKey.shortDate(card.day))")
                      .font(.app(.caption))
                      .foregroundStyle(.secondary)
                  }
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(card.destination.region)\(card.destination.name)的明信片，\(DayKey.fullDate(card.day))")
              }
            }
            Text("一共 \(cards.count) 张 · 每来 \(Travel.daysPerTrip) 天寄来一张")
              .font(.app(.footnote))
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal, Spacing.page)
        .padding(.bottom, Spacing.section)
      }
      .background { AppBackground() }
      .navigationTitle("小日的明信片")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
      }
      .sheet(item: $open) { PostcardSheet(card: $0).oneDaySheet() }
      .onAppear { MascotSpeech.markPostcardsSeen(cards.count) }
    }
  }
}

extension Store {
  /// 小日 as it appears on postcards: happy, in today's outfit and plant.
  var postcardLook: MascotLook {
    MascotLook(
      mood: .happy, stage: state.growth(today: today).stage.rawValue,
      outfit: mascotOutfit, droopy: false, plant: mascotPlant)
  }
}
