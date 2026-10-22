import SwiftUI

/// Colors for cards that leave the app: always warm paper, whatever the app's theme.
private enum Paper {
  static let bg = Color(hex: "#fbf7ef")
  static let ink = Color(hex: "#2b2722")
  static let soft = Color(hex: "#8a8175")
  static let line = Color(hex: "#e7dfd1")
  static let width: CGFloat = 360
}

// MARK: - Month recap

/// A month on one page, rendered to an image for sharing.
struct RecapCard: View {
  let recap: MonthRecap
  let accent: Color
  let name: String

  var body: some View {
    let comps = DayKey.calendar.dateComponents([.year, .month], from: recap.month)
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 4) {
        Text("\(String(comps.year ?? 0)) · \(name.isEmpty ? "我" : name)的")
          .font(.footnote.weight(.medium))
          .foregroundStyle(Paper.soft)
        Text("\(comps.month ?? 0)月回顾")
          .font(.journal(.largeTitle, size: 34, bold: true))
      }

      if !recap.photos.isEmpty { collage }

      HStack(spacing: 0) {
        number("\(recap.recordDays)", "天有记录")
        number("\(recap.completions)", "次完成")
        number(recap.characters >= 10_000 ? String(format: "%.1f万", Double(recap.characters) / 10_000) : "\(recap.characters)", "个字")
      }

      if let avg = recap.moodAverage, let mood = Mood(average: avg) {
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 6) {
            Text(mood.emoji)
            Text("这个月心情大多\(mood.label)")
          }
          .font(.journal(.body, size: 16))
          moodBar
        }
      }

      if !recap.topPlaces.isEmpty || !recap.topTags.isEmpty || recap.bestStreak != nil {
        VStack(alignment: .leading, spacing: 8) {
          if !recap.topPlaces.isEmpty {
            line("location.fill", "常去 " + recap.topPlaces.map(\.name).joined(separator: "、"))
          }
          if !recap.topTags.isEmpty {
            line("number", recap.topTags.map { "#\($0.name)" }.joined(separator: " "))
          }
          if let best = recap.bestStreak, best.days >= 2 {
            line("flame.fill", "「\(best.title)」连续 \(best.days) 天")
          }
          if recap.videos + recap.recordings > 0 {
            line("waveform", mediaLine)
          }
        }
        .font(.subheadline)
      }

      if let highlight = recap.highlight {
        VStack(alignment: .leading, spacing: 6) {
          Text("“" + MarkdownText.plain(highlight.text).replacingOccurrences(of: "\n", with: " ") + "”")
            .font(.journal(.body, size: 17))
            .lineSpacing(5)
            .lineLimit(5)
          Text(DayKey.fullDate(highlight.day))
            .font(.caption)
            .foregroundStyle(Paper.soft)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      }

      footer
    }
    .foregroundStyle(Paper.ink)
    .padding(24)
    .frame(width: Paper.width, alignment: .leading)
    .background(Paper.bg)
  }

  private var mediaLine: String {
    var parts: [String] = []
    if recap.videos > 0 { parts.append("\(recap.videos) 段视频") }
    if recap.recordings > 0 { parts.append("\(recap.recordings) 段语音") }
    return "还留下了 " + parts.joined(separator: "、")
  }

  /// Up to four photos: one large, the rest in a column.
  private var collage: some View {
    let photos = Array(recap.photos.prefix(4))
    return HStack(spacing: 4) {
      photo(photos[0])
      if photos.count > 1 {
        VStack(spacing: 4) {
          ForEach(photos.dropFirst(), id: \.self) { photo($0) }
        }
        .frame(width: 96)
      }
    }
    .frame(height: 200)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func photo(_ name: String) -> some View {
    Color(hex: "#e9e2d4")
      .overlay {
        if let image = MediaStore.image(name) {
          Image(uiImage: image).resizable().scaledToFill()
        }
      }
      .clipped()
  }

  private var moodBar: some View {
    let total = max(1, recap.moodCounts.values.reduce(0, +))
    return GeometryReader { geo in
      HStack(spacing: 2) {
        ForEach(Mood.allCases.reversed()) { mood in
          let count = recap.moodCounts[mood.rawValue] ?? 0
          if count > 0 {
            Color(hex: mood.hex)
              .frame(width: max(4, (geo.size.width - 8) * CGFloat(count) / CGFloat(total)))
          }
        }
      }
    }
    .frame(height: 8)
    .clipShape(Capsule())
  }

  private func number(_ value: String, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value).font(.system(size: 28, weight: .bold, design: .default)).foregroundStyle(accent)
      Text(label).font(.caption).foregroundStyle(Paper.soft)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func line(_ icon: String, _ text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(systemName: icon).foregroundStyle(accent).frame(width: 18)
      Text(text).lineLimit(2)
    }
  }

  private var footer: some View {
    HStack {
      Rectangle().fill(Paper.line).frame(height: 1)
      Text("OneDay · 把每一天留下来")
        .font(.caption2)
        .foregroundStyle(Paper.soft)
        .fixedSize()
    }
  }
}

// MARK: - A single day

/// One day as a journal page, for sharing.
struct DayShareCard: View {
  let day: String
  let notes: [NoteEntry]
  let accent: Color

  var body: some View {
    let cover = notes.lazy.compactMap(\.photos.first).first
    let first = notes.first
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .lastTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text(DayKey.weekday(day))
            .font(.footnote.weight(.medium))
            .foregroundStyle(Paper.soft)
          Text(DayKey.fullDate(day))
            .font(.journal(.title, size: 26, bold: true))
        }
        Spacer()
        if let mood = notes.compactMap(\.mood).first.flatMap(Mood.init(rawValue:)) {
          Text(mood.emoji).font(.system(size: 30))
        }
      }

      if let cover, let image = MediaStore.image(cover) {
        Color.clear
          .frame(height: 220)
          .overlay { Image(uiImage: image).resizable().scaledToFill() }
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }

      VStack(alignment: .leading, spacing: 14) {
        ForEach(notes.filter { !$0.text.isEmpty }.prefix(3)) { note in
          VStack(alignment: .leading, spacing: 4) {
            if notes.count > 1 && !note.time.isEmpty {
              Text(note.time).font(.caption.monospacedDigit()).foregroundStyle(Paper.soft)
            }
            Text(MarkdownText.plain(note.text))
              .font(.journal(.body, size: 18))
              .lineSpacing(6)
              .lineLimit(8)
          }
        }
      }

      if let first, first.place != nil || first.weather != nil {
        HStack(spacing: 12) {
          if let place = first.place { Label(place, systemImage: "location.fill") }
          if let weather = first.weather { Label(weather, systemImage: LocationWeather.symbol(for: weather)) }
        }
        .labelStyle(CompactLabelStyle())
        .font(.caption)
        .foregroundStyle(Paper.soft)
      }

      HStack {
        Rectangle().fill(Paper.line).frame(height: 1)
        Text("OneDay").font(.caption2.weight(.semibold)).foregroundStyle(accent).fixedSize()
      }
    }
    .foregroundStyle(Paper.ink)
    .padding(24)
    .frame(width: Paper.width, alignment: .leading)
    .background(Paper.bg)
  }
}

// MARK: - Preview and share

/// Shows a card as it will be shared, renders it to an image, and offers the share sheet.
struct ShareCardSheet<Card: View>: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.displayScale) private var displayScale
  let title: String
  let card: Card
  @State private var rendered: UIImage?

  init(title: String, @ViewBuilder card: () -> Card) {
    self.title = title
    self.card = card()
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        styledCard
          .shadow(color: .black.opacity(0.12), radius: 18, y: 6)
          .padding(.vertical, 20)
          .frame(maxWidth: .infinity)
      }
      .background(Color(uiColor: .systemGroupedBackground))
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          if let rendered {
            ShareLink(item: Image(uiImage: rendered), preview: SharePreview(title, image: Image(uiImage: rendered))) {
              Label("分享", systemImage: "square.and.arrow.up")
            }
          } else {
            ProgressView()
          }
        }
      }
      .task { render() }
    }
  }

  private var styledCard: some View {
    card
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
      .environment(\.colorScheme, .light)
  }

  private func render() {
    let renderer = ImageRenderer(content: card.environment(\.colorScheme, .light))
    renderer.scale = max(displayScale, 3)
    renderer.isOpaque = true
    rendered = renderer.uiImage
  }
}

/// The recap for a month, ready to share.
struct RecapSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  let month: Date

  var body: some View {
    let recap = store.state.recap(month: month)
    ShareCardSheet(title: "\(DayKey.calendar.component(.month, from: month))月回顾") {
      RecapCard(recap: recap, accent: accent, name: store.settings.name == Settings.defaultName ? "" : store.settings.name)
    }
  }
}
