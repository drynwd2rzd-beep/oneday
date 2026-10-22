import Charts
import SwiftUI

// MARK: - Calendar

/// A month as a page of a diary: days with a photo show it, other recorded days show their mood.
struct JournalCalendar: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  @Binding var month: Date
  var onRecap: (Date) -> Void

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
  private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

  var body: some View {
    let recap = store.state.recap(month: month)
    VStack(spacing: Spacing.stack) {
      VStack(spacing: 12) {
        HStack {
          shiftButton("chevron.left", label: "上个月", by: -1)
          Spacer()
          Text(DayKey.monthLabel(month))
            .font(.journal(.title3, size: 20, bold: true))
            .contentTransition(.numericText())
          Spacer()
          shiftButton("chevron.right", label: "下个月", by: 1)
            .disabled(DayKey.monthStart(month) >= DayKey.monthStart(Date()))
        }
        LazyVGrid(columns: columns, spacing: 4) {
          ForEach(weekdays, id: \.self) { name in
            Text(name).font(.app(.caption).weight(.medium)).foregroundStyle(.secondary)
          }
          ForEach(0..<DayKey.leadingBlanks(month), id: \.self) { _ in
            Color.clear.aspectRatio(0.8, contentMode: .fit)
          }
          ForEach(DayKey.days(inMonth: month), id: \.self) { day in
            cell(day)
          }
        }
      }
      .card()
      .simultaneousGesture(
        DragGesture(minimumDistance: 30).onEnded { value in
          guard abs(value.translation.width) > abs(value.translation.height) else { return }
          let step = value.translation.width < 0 ? 1 : -1
          let target = DayKey.shiftMonth(month, by: step)
          guard target <= DayKey.monthStart(Date()) else { return }
          withAnimation(.snappy) { month = target }
        })

      RecapEntryCard(recap: recap) { onRecap(month) }
    }
  }

  @ViewBuilder
  private func cell(_ day: String) -> some View {
    let notes = store.state.notes[day] ?? []
    let photo = notes.lazy.compactMap(\.photos.first).first
    let number = DayKey.calendar.component(.day, from: DayKey.date(day))
    let isToday = day == store.today
    let isFuture = day > store.today
    let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
    let content = Color.clear
      .aspectRatio(0.8, contentMode: .fit)
      .overlay {
        if let photo, let image = MediaStore.image(photo) {
          Image(uiImage: image).resizable().scaledToFill()
            .overlay(Color.black.opacity(0.18))
        } else if !notes.isEmpty {
          accent.opacity(0.08)
        }
      }
      .clipShape(shape)
      .overlay(alignment: .topLeading) {
        Text("\(number)")
          .font(.app(.caption).weight(isToday ? .bold : .medium).monospacedDigit())
          .foregroundStyle(numberColor(hasPhoto: photo != nil, isToday: isToday, isFuture: isFuture))
          .padding(.leading, 5)
          .padding(.top, 3)
      }
      .overlay(alignment: .bottom) {
        if photo == nil {
          if let mood = store.state.mood(on: day), let face = Mood(average: mood) {
            Text(face.emoji).font(.app(.callout)).padding(.bottom, 4)
          } else if !notes.isEmpty {
            Circle().fill(accent).frame(width: 5, height: 5).padding(.bottom, 8)
          }
        }
      }
      .overlay {
        if isToday { shape.strokeBorder(accent, lineWidth: 1.5) }
      }
    if notes.isEmpty {
      content
        .accessibilityElement()
        .accessibilityLabel("\(DayKey.fullDate(day))，没有记录")
    } else {
      NavigationLink(value: day) { content }
        .buttonStyle(.plain)
        .accessibilityLabel("\(DayKey.fullDate(day))，\(notes.count) 条记录")
    }
  }

  private func numberColor(hasPhoto: Bool, isToday: Bool, isFuture: Bool) -> Color {
    if hasPhoto { return .white }
    if isToday { return accent }
    if isFuture { return Color.secondary.opacity(0.5) }
    return .primary
  }

  private func shiftButton(_ icon: String, label: String, by value: Int) -> some View {
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

/// "10月回顾": a teaser that opens the shareable recap card.
struct RecapEntryCard: View {
  @Environment(\.accent) private var accent
  let recap: MonthRecap
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: "sparkles.rectangle.stack")
          .font(.app(.title3))
          .foregroundStyle(accent)
          .frame(width: 32)
        VStack(alignment: .leading, spacing: 3) {
          Text("\(DayKey.calendar.component(.month, from: recap.month))月回顾")
            .font(.app(.headline))
          Text(summary)
            .font(.app(.subheadline))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer(minLength: 8)
        Image(systemName: "chevron.right")
          .font(.app(.footnote).weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .card()
    .disabled(recap.isEmpty)
    .opacity(recap.isEmpty ? 0.6 : 1)
  }

  private var summary: String {
    if recap.isEmpty { return "这个月还没有内容" }
    var parts = ["记录 \(recap.recordDays) 天", "完成 \(recap.completions) 次"]
    if let avg = recap.moodAverage, let mood = Mood(average: avg) { parts.append("心情\(mood.label)") }
    return parts.joined(separator: " · ")
  }
}

// MARK: - Photo wall

/// Every photo, newest first, in month sections. Tapping one opens its day.
struct PhotoWall: View {
  @Environment(Store.self) private var store
  @Environment(\.palette) private var palette

  private struct PhotoMonth: Identifiable {
    let key: String
    var items: [(day: String, photo: String)]
    var id: String { key }
  }

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)

  var body: some View {
    let sections = Self.sections(store.state.photoTimeline)
    if sections.isEmpty {
      EmptyState(title: "还没有照片", icon: "photo.on.rectangle", message: "在记录里留下照片后，它们会按月份排在这里。")
        .card()
    } else {
      LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
        ForEach(sections) { section in
          Section {
            LazyVGrid(columns: columns, spacing: 3) {
              ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                NavigationLink(value: item.day) {
                  Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                      if let image = MediaStore.image(item.photo) {
                        Image(uiImage: image).resizable().scaledToFill()
                      }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(DayKey.fullDate(item.day)) 的照片")
                .accessibilityHint("打开这一天")
              }
            }
            .padding(.bottom, Spacing.stack)
          } header: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Text(DayKey.monthLabel(ofKey: section.key + "-01"))
                .font(.journal(.headline, size: 18, bold: true))
              Text("\(section.items.count) 张")
                .font(.app(.footnote))
                .foregroundStyle(.secondary)
              Spacer()
            }
            .padding(.vertical, 8)
            .background(palette.bg.opacity(0.96))
            .accessibilityAddTraits(.isHeader)
          }
        }
      }
    }
  }

  private static func sections(_ items: [(day: String, photo: String)]) -> [PhotoMonth] {
    var out: [PhotoMonth] = []
    for item in items {
      let key = String(item.day.prefix(7))
      if out.last?.key == key {
        out[out.count - 1].items.append(item)
      } else {
        out.append(PhotoMonth(key: key, items: [item]))
      }
    }
    return out
  }
}

// MARK: - Mood chart

/// The last 30 days of mood as a soft line, and how often each mood came up.
struct MoodCard: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent

  var body: some View {
    let series = store.state.moodSeries(today: store.today, days: 30)
    let counts = Dictionary(grouping: series, by: { Mood(average: $0.value) ?? .okay }).mapValues(\.count)
    VStack(alignment: .leading, spacing: Spacing.inner) {
      HStack(alignment: .firstTextBaseline) {
        Text("心情").font(.app(.headline))
        Spacer()
        Text("近 30 天").font(.app(.caption)).foregroundStyle(.secondary)
      }
      if series.count < 2 {
        Text("写记录时选一个心情，这里会画出你最近的情绪曲线。")
          .font(.app(.subheadline))
          .foregroundStyle(.secondary)
      } else {
        Chart(series) { point in
          LineMark(x: .value("日期", DayKey.date(point.day), unit: .day), y: .value("心情", point.value))
            .interpolationMethod(.catmullRom)
            .foregroundStyle(accent.opacity(0.5))
          PointMark(x: .value("日期", DayKey.date(point.day), unit: .day), y: .value("心情", point.value))
            .foregroundStyle(Color(hex: (Mood(average: point.value) ?? .okay).hex))
            .symbolSize(40)
        }
        .chartYScale(domain: 0.5...5.5)
        .chartYAxis {
          AxisMarks(position: .leading, values: [1.0, 3.0, 5.0]) { value in
            AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
            AxisValueLabel {
              Text(value.as(Double.self).flatMap(Mood.init(average:))?.emoji ?? "")
            }
          }
        }
        .chartXAxis {
          AxisMarks(values: .stride(by: .day, count: 7)) { _ in
            AxisValueLabel(format: .dateTime.month(.defaultDigits).day()).font(.app(.caption2))
          }
        }
        .frame(height: 140)
        .accessibilityLabel("近 30 天心情曲线")

        HStack(spacing: 0) {
          ForEach(Mood.allCases) { mood in
            VStack(spacing: 4) {
              Text(mood.emoji).font(.app(.title3))
              Text("\(counts[mood] ?? 0) 天")
                .font(.app(.caption2).monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(mood.label) \(counts[mood] ?? 0) 天")
          }
        }
      }
    }
    .card()
  }
}
