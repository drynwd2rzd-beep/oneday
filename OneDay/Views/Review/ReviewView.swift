import Charts
import SwiftUI

struct ReviewView: View {
  @Environment(Store.self) private var store
  @State private var showSearch = false
  @State private var overviewMonth = DayKey.monthStart(Date())
  @State private var calendarMonth = DayKey.monthStart(Date())

  var body: some View {
    NavigationStack(path: dayPath) {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.stack) {
          Picker("回顾", selection: tabBinding) {
            ForEach(ReviewTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
          }
          .pickerStyle(.segmented)

          switch store.reviewTab {
          case .timeline:
            switch store.recordsMode {
            case .list: TimelineList()
            case .calendar: JournalCalendar(month: $calendarMonth) { store.recap = MonthRef(month: $0) }
            case .photos: PhotoWall()
            }
          case .overview:
            OverviewPanel(month: $overviewMonth) { store.recap = MonthRef(month: $0) }
          }
        }
        .padding(.horizontal, Spacing.page)
        .padding(.bottom, Spacing.section)
        .animation(.snappy, value: store.reviewTab)
        .animation(.snappy, value: store.recordsMode)
      }
      .background { AppBackground() }
      .navigationTitle("回顾")
      .navigationDestination(for: String.self) { day in
        ReviewDayDetail(day: day)
      }
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          if store.reviewTab == .timeline {
            Menu {
              Picker("显示方式", selection: recordsModeBinding) {
                ForEach(RecordsMode.allCases, id: \.self) { mode in
                  Label(mode.label, systemImage: mode.icon).tag(mode)
                }
              }
            } label: {
              Image(systemName: store.recordsMode.icon)
            }
            .accessibilityLabel("显示方式")
            .accessibilityValue(store.recordsMode.label)
          }
          Button {
            showSearch = true
          } label: {
            Image(systemName: "magnifyingglass")
          }
          .accessibilityLabel("搜索记录")
        }
      }
      .sheet(isPresented: $showSearch) { ReviewSearchSheet().oneDaySheet() }
    }
  }

  /// The pushed day page mirrors `store.reviewDate`, so search, the calendar and "那年今日"
  /// can open a day from anywhere.
  private var dayPath: Binding<[String]> {
    Binding(
      get: { store.reviewDate.map { [$0] } ?? [] },
      set: { store.reviewDate = $0.last })
  }

  private var recordsModeBinding: Binding<RecordsMode> {
    Binding(get: { store.recordsMode }, set: { store.recordsMode = $0 })
  }

  private var tabBinding: Binding<ReviewTab> {
    Binding(
      get: { store.reviewTab },
      set: { tab in
        store.reviewTab = tab
        store.reviewDate = nil
      })
  }
}

// MARK: - Timeline

private struct TimelineList: View {
  @Environment(Store.self) private var store

  private struct MonthGroup: Identifiable {
    let key: String  // "2026-10"
    var days: [String]
    var id: String { key }
  }

  var body: some View {
    let groups = Self.group(store.state.recordDates)
    if groups.isEmpty {
      EmptyState(title: "时间线还是空的", icon: "book", message: "留下第一条记录后，这里会慢慢长出属于你的时间线。")
        .card()
    } else {
      let weeks = Self.weekPlacement(groups, written: store.state.weekReflections)
      VStack(alignment: .leading, spacing: Spacing.stack) {
        if store.state.weekReflections[DayKey.weekStart(store.today)] == nil {
          ThisWeekEntry()
        }
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
          ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
            Section {
              ForEach(Array(group.days.enumerated()), id: \.element) { position, day in
                if let week = weeks[day] {
                  WeekTimelineRow(start: week)
                }
                NavigationLink(value: day) {
                  TimelineRow(day: day, isLast: position == group.days.count - 1)
                }
                .buttonStyle(.plain)
              }
            } header: {
              MonthHeader(
                key: group.key, count: group.days.count,
                showsYear: index == 0 || groups[index - 1].key.prefix(4) != group.key.prefix(4))
            }
          }
        }
      }
    }
  }

  /// Each written weekly review goes just above the newest recorded day of its week.
  private static func weekPlacement(_ groups: [MonthGroup], written: [String: WeekReflection]) -> [String: String] {
    var placed = Set<String>()
    var out: [String: String] = [:]
    for day in groups.flatMap(\.days) {
      let week = DayKey.weekStart(day)
      if written[week] != nil, placed.insert(week).inserted { out[day] = week }
    }
    return out
  }

  private static func group(_ dates: [String]) -> [MonthGroup] {
    var groups: [MonthGroup] = []
    for day in dates {
      let key = String(day.prefix(7))
      if groups.last?.key == key {
        groups[groups.count - 1].days.append(day)
      } else {
        groups.append(MonthGroup(key: key, days: [day]))
      }
    }
    return groups
  }
}

/// A weekly review in the timeline: the card sits in the card column, the axis runs past it.
private struct WeekTimelineRow: View {
  @Environment(\.palette) private var palette
  let start: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Rectangle()
        .fill(palette.line)
        .frame(width: 1)
        .frame(width: 44)
        .frame(maxHeight: .infinity)
      WeekNoteCard(start: start)
        .padding(.bottom, Spacing.stack)
    }
  }
}

/// Stays pinned while scrolling so you always know which month you are in.
private struct MonthHeader: View {
  @Environment(\.palette) private var palette
  let key: String
  let count: Int
  let showsYear: Bool

  var body: some View {
    let year = Int(key.prefix(4)) ?? 0
    let month = Int(key.suffix(2)) ?? 0
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text("\(month)月")
        .font(.journal(.title2, size: 24, bold: true))
      Text(subtitle(year: year))
        .font(.app(.footnote))
        .foregroundStyle(.secondary)
      Spacer()
    }
    .padding(.vertical, 10)
    .background(palette.bg.opacity(0.96))
    .accessibilityAddTraits(.isHeader)
  }

  private func subtitle(year: Int) -> String {
    let thisYear = Int(DayKey.today.prefix(4)) ?? year
    if showsYear || year != thisYear { return "\(String(year)) · \(count) 天有记录" }
    return "\(count) 天有记录"
  }
}

/// Date block on the left joined by a thin line; a fixed-shape card on the right.
private struct TimelineRow: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  @Environment(\.palette) private var palette
  let day: String
  let isLast: Bool

  var body: some View {
    let notes = store.state.notes[day] ?? []
    HStack(alignment: .top, spacing: 12) {
      VStack(spacing: 6) {
        VStack(spacing: 0) {
          Text("\(DayKey.calendar.component(.day, from: DayKey.date(day)))")
            .font(.journal(.title, size: 26, bold: true))
            .foregroundStyle(day == store.today ? accent : .primary)
          Text(relativeLabel)
            .font(.app(.caption2).weight(.medium))
            .foregroundStyle(day == store.today ? accent : .secondary)
        }
        .frame(width: 44)
        Rectangle()
          .fill(isLast ? Color.clear : palette.line)
          .frame(width: 1)
          .frame(maxHeight: .infinity)
      }
      card(notes)
        .padding(.bottom, Spacing.stack)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(DayKey.fullDate(day)) \(DayKey.weekday(day))，\(excerpt(notes))")
    .accessibilityHint("打开这一天")
  }

  private var relativeLabel: String {
    if day == store.today { return "今天" }
    if day == DayKey.add(days: -1, to: store.today) { return "昨天" }
    return DayKey.weekday(day).replacingOccurrences(of: "星期", with: "周")
  }

  private func card(_ notes: [NoteEntry]) -> some View {
    let cover = notes.lazy.compactMap(\.photos.first).first
    let first = notes.first
    return HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 8) {
        Text(excerpt(notes))
          .font(.journal(.body, size: 17))
          .foregroundStyle(.primary)
          .lineSpacing(3)
          .lineLimit(3)
          .multilineTextAlignment(.leading)
        HStack(spacing: 10) {
          MoodBadge(value: store.state.mood(on: day), font: .caption)
          if let place = first?.place {
            Label(place, systemImage: "location.fill").labelStyle(CompactLabelStyle()).lineLimit(1)
          }
          if notes.count > 1 { Text("\(notes.count) 条") }
        }
        .font(.app(.caption))
        .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if let cover {
        PhotoThumb(name: cover)
          .frame(width: 64, height: 64)
          .accessibilityHidden(true)
      }
    }
    .card()
  }

  private func excerpt(_ notes: [NoteEntry]) -> String {
    guard let first = notes.first else { return "" }
    if !first.text.isEmpty { return MarkdownText.plain(first.text).replacingOccurrences(of: "\n", with: " ") }
    if !first.photos.isEmpty { return "留下了照片" }
    if first.media.contains(where: { $0.kind == .video }) { return "留下了视频" }
    return "留下了一段语音"
  }
}

// MARK: - Single day

private struct NoteEditTarget: Identifiable {
  let entry: NoteEntry
  var id: String { entry.id }
}

/// One day, pushed from the timeline: every note as a journal page, then that day's tasks.
private struct ReviewDayDetail: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  let day: String
  @State private var editing: NoteEditTarget?
  @State private var confirmDeleteAll = false
  @State private var preview: PhotoRef?
  @State private var sharing = false

  var body: some View {
    let notes = store.state.notes[day] ?? []
    let tasks = store.state.tasks(on: day)
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.stack) {
        VStack(alignment: .leading, spacing: 4) {
          Text(DayKey.weekday(day))
            .font(.app(.footnote).weight(.medium))
            .foregroundStyle(.secondary)
          Text(DayKey.fullDate(day))
            .font(.journal(.title, size: 28, bold: true))
        }
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)

        if notes.isEmpty {
          EmptyState(title: "这一天没有记录", icon: "text.page.slash").card()
        } else {
          ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
            entryView(note, index: index)
          }
        }

        if !tasks.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            Text("那一天的事项").font(.app(.footnote).weight(.semibold)).foregroundStyle(.secondary)
            ForEach(tasks) { task in
              let done = task.isDone(on: day)
              HStack(spacing: 10) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                  .foregroundStyle(done ? accent : Color(uiColor: .tertiaryLabel))
                Text(task.title).foregroundStyle(done ? .primary : .secondary)
              }
              .accessibilityElement(children: .combine)
              .accessibilityValue(done ? "已完成" : "未完成")
            }
          }
          .card()
          .padding(.top, Spacing.section - Spacing.stack)
        }
      }
      .padding(.horizontal, Spacing.page)
      .padding(.bottom, Spacing.section)
    }
    .background { AppBackground() }
    .navigationTitle(DayKey.shortDate(day))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if !notes.isEmpty {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button {
              sharing = true
            } label: {
              Label("分享这一天", systemImage: "square.and.arrow.up")
            }
            Button {
              store.reflection = .day(day)
            } label: {
              Label(store.state.reflectionNote(on: day) == nil ? "写这天的复盘" : "修改这天的复盘", systemImage: "moon.stars")
            }
            Divider()
            Button(role: .destructive) {
              confirmDeleteAll = true
            } label: {
              Label("删除这一天的全部记录", systemImage: "trash")
            }
          } label: {
            Image(systemName: "ellipsis")
          }
          .accessibilityLabel("更多")
        }
      }
    }
    .sheet(item: $editing) { NoteEditorSheet(day: day, entry: $0.entry).oneDaySheet() }
    .fullScreenCover(item: $preview) { PhotoLightbox(name: $0.name).oneDaySheet() }
    .sheet(isPresented: $sharing) {
      ShareCardSheet(title: DayKey.shortDate(day)) {
        DayShareCard(day: day, notes: notes, accent: accent)
      }
      .oneDaySheet()
    }
    .alert("删除 \(DayKey.fullDate(day)) 的全部记录？", isPresented: $confirmDeleteAll) {
      Button("删除", role: .destructive) { store.deleteNotes(on: day) }
      Button("取消", role: .cancel) {}
    } message: {
      Text("只删除当天留下的文字、照片和语音，不影响事项完成状态。删除后可以撤销。")
    }
  }

  private func entryView(_ note: NoteEntry, index: Int) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 6) {
        if note.isReflection {
          Label("复盘", systemImage: "moon.stars")
            .font(.app(.footnote).weight(.semibold))
            .foregroundStyle(accent)
        }
        Text(note.time.isEmpty ? (note.isReflection ? "" : "记录 \(index + 1)") : note.time)
          .font(.app(.footnote).weight(.medium).monospacedDigit())
          .foregroundStyle(.secondary)
        if let mood = note.mood.flatMap(Mood.init(rawValue:)) {
          Text("\(mood.emoji) \(mood.label)")
            .font(.app(.footnote))
            .foregroundStyle(Color(hex: mood.hex))
        }
      }
      if !note.text.isEmpty {
        MarkdownText(text: note.text)
          .font(.journal(.body, size: 18))
          .lineSpacing(6)
          .textSelection(.enabled)
      }
      if !note.photos.isEmpty {
        photoGrid(note)
      }
      if !note.media.isEmpty {
        MediaAttachments(media: note.media) { item in
          store.deleteMedia(day: day, noteId: note.id, file: item.file)
        }
      }
      if note.place != nil || note.weather != nil || !note.tags.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          NoteMetaLine(note: note)
          if !note.tags.isEmpty {
            FlowLayout(spacing: 6) {
              ForEach(note.tags, id: \.self) { TagLabel(tag: $0) }
            }
          }
        }
      }
    }
    .card()
    .contentShape(Rectangle())
    .contextMenu {
      Button {
        edit(note)
      } label: {
        Label("编辑", systemImage: "pencil")
      }
      Button(role: .destructive) {
        withAnimation(.snappy) { store.deleteNote(day: day, id: note.id) }
      } label: {
        Label("删除这条记录", systemImage: "trash")
      }
    }
    .swipeActions(
      leading: SwipeAction(title: "编辑", icon: "pencil", tint: accent) { edit(note) },
      trailing: SwipeAction(title: "删除", icon: "trash", tint: .red) {
        withAnimation(.snappy) { store.deleteNote(day: day, id: note.id) }
      })
  }

  /// The 复盘 is edited on its own page, next to the day's tasks and notes.
  private func edit(_ note: NoteEntry) {
    if note.isReflection {
      store.reflection = .day(day)
    } else {
      editing = NoteEditTarget(entry: note)
    }
  }

  /// One photo fills the width; several share a grid.
  @ViewBuilder
  private func photoGrid(_ note: NoteEntry) -> some View {
    if note.photos.count == 1, let photo = note.photos.first, let image = MediaStore.image(photo) {
      Image(uiImage: image)
        .resizable()
        .scaledToFill()
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { preview = PhotoRef(name: photo) }
        .contextMenu { photoMenu(note, photo) }
        .accessibilityLabel("照片，双击查看")
        .accessibilityAddTraits(.isButton)
    } else {
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: note.photos.count == 2 ? 2 : 3), spacing: 6) {
        ForEach(note.photos, id: \.self) { photo in
          PhotoThumb(name: photo)
            .onTapGesture { preview = PhotoRef(name: photo) }
            .contextMenu { photoMenu(note, photo) }
            .accessibilityLabel("照片，双击查看")
            .accessibilityAddTraits(.isButton)
        }
      }
    }
  }

  @ViewBuilder
  private func photoMenu(_ note: NoteEntry, _ photo: String) -> some View {
    Button(role: .destructive) {
      store.deletePhoto(day: day, noteId: note.id, photo: photo)
    } label: {
      Label("删除这张照片", systemImage: "trash")
    }
  }
}

// MARK: - Overview

/// Long-term numbers only; this week lives in 复盘.
private struct OverviewPanel: View {
  @Environment(Store.self) private var store
  @Binding var month: Date
  var onRecap: (Date) -> Void

  var body: some View {
    VStack(spacing: Spacing.stack) {
      TotalsCard()
      HeatmapCard()
      StreaksCard()
      if store.state.moodSeries(today: store.today, days: 30).count >= 2 {
        MoodCard()
      }
      MonthCard(month: $month, onRecap: onRecap)
    }
  }
}

/// 累计完成 · 有记录 · 最长连续.
private struct TotalsCard: View {
  @Environment(Store.self) private var store

  var body: some View {
    let state = store.state
    let completions = state.tasks.reduce(0) { $0 + $1.completionCount }
    let best = state.taskStreaks(today: store.today).map(\.best).max() ?? 0
    HStack(alignment: .top, spacing: 0) {
      number("\(completions)", "累计完成", unit: "次")
      number("\(state.recordDates.count)", "有记录", unit: "天")
      number("\(best)", "最长连续", unit: "天")
    }
    .card()
  }

  private func number(_ value: String, _ label: String, unit: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(.app(size: 28, weight: .bold))
          .contentTransition(.numericText())
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text(unit).font(.app(.caption)).foregroundStyle(.secondary)
      }
      Text(label).font(.app(.caption)).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// One month: completions per task, and its recap card.
private struct MonthCard: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  @Binding var month: Date
  var onRecap: (Date) -> Void

  var body: some View {
    let o = store.state.overview(month: month)
    let recap = store.state.recap(month: month)
    let maxCount = max(1, o.items.map(\.count).max() ?? 1)
    let isCurrent = DayKey.monthStart(month) >= DayKey.monthStart(Date())
    VStack(alignment: .leading, spacing: Spacing.inner) {
      HStack {
        shiftButton("chevron.left", label: "上个月", by: -1)
        Spacer()
        Text(DayKey.monthLabel(month)).font(.app(.headline)).contentTransition(.numericText())
        Spacer()
        shiftButton("chevron.right", label: "下个月", by: 1)
          .disabled(isCurrent)
          .opacity(isCurrent ? 0.3 : 1)
      }

      if o.items.isEmpty {
        Text("这个月还没有完成记录。")
          .font(.app(.subheadline))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 8)
      } else {
        ForEach(o.items) { item in
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(item.title).font(.app(.subheadline)).lineLimit(1)
              Spacer()
              Text("\(item.count) 次").font(.app(.subheadline).weight(.semibold)).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(item.count), total: Double(maxCount))
              .tint(accent)
          }
          .accessibilityElement(children: .combine)
        }
      }

      Divider()
      Button {
        onRecap(month)
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "sparkles").foregroundStyle(accent)
          Text("\(DayKey.calendar.component(.month, from: month))月回顾").font(.app(.subheadline).weight(.semibold))
          Spacer()
          Text(recap.isEmpty ? "暂无内容" : "可以分享成图片").font(.app(.caption)).foregroundStyle(.secondary)
          Image(systemName: "chevron.right").font(.app(.caption).weight(.semibold)).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(recap.isEmpty)
      .accessibilityLabel("\(DayKey.calendar.component(.month, from: month))月回顾")
    }
    .card()
  }

  private func shiftButton(_ icon: String, label: String, by value: Int) -> some View {
    Button {
      withAnimation(.snappy) { month = DayKey.shiftMonth(month, by: value) }
    } label: {
      Image(systemName: icon)
        .font(.app(.body).weight(.semibold))
        .foregroundStyle(accent)
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}

/// A year of days, GitHub style. Darker means more of that day's tasks were done.
private struct HeatmapCard: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  @State private var selected: HeatCell?

  private let cell: CGFloat = 12
  private let gap: CGFloat = 3

  var body: some View {
    let columns = store.state.heatmap(today: store.today, weeks: 53)
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("这一年").font(.app(.headline))
        Spacer()
        if let selected {
          Text("\(DayKey.shortDate(selected.day)) · \(selected.total == 0 ? "无事项" : "完成 \(selected.done)/\(selected.total)")\(selected.hasNote ? " · 有记录" : "")")
            .font(.app(.caption))
            .foregroundStyle(.secondary)
            .transition(.opacity)
        }
      }
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: gap) {
          ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
            VStack(spacing: gap) {
              ForEach(column) { day in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                  .fill(color(day))
                  .frame(width: cell, height: cell)
                  .overlay {
                    if day.hasNote && !day.isFuture {
                      Circle().fill(Color.primary.opacity(0.35)).frame(width: 3, height: 3)
                    }
                  }
                  .overlay {
                    if selected?.day == day.day {
                      RoundedRectangle(cornerRadius: 3).strokeBorder(Color.primary, lineWidth: 1.2)
                    }
                  }
                  .onTapGesture {
                    guard !day.isFuture else { return }
                    withAnimation(.snappy) { selected = selected?.day == day.day ? nil : day }
                  }
              }
            }
          }
        }
        .padding(.vertical, 2)
      }
      .defaultScrollAnchor(.trailing)
      HStack(spacing: 4) {
        Text("少").font(.app(.caption2)).foregroundStyle(.secondary)
        ForEach(0..<5, id: \.self) { level in
          RoundedRectangle(cornerRadius: 2).fill(color(level: level)).frame(width: 10, height: 10)
        }
        Text("多").font(.app(.caption2)).foregroundStyle(.secondary)
        Spacer()
        Text("圆点表示当天有记录").font(.app(.caption2)).foregroundStyle(.secondary)
      }
    }
    .card()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("这一年的完成热力图")
    .accessibilityValue("最近 7 天完成了 \(recentDone(columns)) 次")
  }

  private func recentDone(_ columns: [[HeatCell]]) -> Int {
    let since = DayKey.add(days: -7, to: store.today)
    var total = 0
    for column in columns.suffix(2) {
      for day in column where !day.isFuture && day.day > since { total += day.done }
    }
    return total
  }

  private func color(_ day: HeatCell) -> Color {
    day.isFuture ? .clear : color(level: day.level)
  }

  private func color(level: Int) -> Color {
    level == 0 ? Color.secondary.opacity(0.13) : accent.opacity([0, 0.3, 0.5, 0.72, 1][level])
  }
}

/// Current and best streak for each daily task.
private struct StreaksCard: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent

  var body: some View {
    let streaks = store.state.taskStreaks(today: store.today)
    VStack(alignment: .leading, spacing: Spacing.inner) {
      VStack(alignment: .leading, spacing: 3) {
        Text("每日打卡").font(.app(.headline))
        Text("设为「每天」重复的事项，连续完成了几天")
          .font(.app(.caption))
          .foregroundStyle(.secondary)
      }
      if streaks.isEmpty {
        Text("添加「每天循环」的事项后，这里会显示连续完成的天数。")
          .font(.app(.subheadline))
          .foregroundStyle(.secondary)
      } else {
        ForEach(streaks) { s in
          HStack(spacing: 12) {
            Image(systemName: s.current >= 7 ? "flame.fill" : "flame")
              .foregroundStyle(s.current > 0 ? accent : Color.secondary)
              .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
              Text(s.title).lineLimit(1)
              Text("最长 \(s.best) 天 · 近 30 天完成率 \(Int((s.rate30 * 100).rounded()))%")
                .font(.app(.caption))
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text("连续").font(.app(.caption)).foregroundStyle(.secondary)
            Text("\(s.current)")
              .font(.app(.title3).weight(.bold))
              .foregroundStyle(s.current > 0 ? accent : .secondary)
            Text("天").font(.app(.caption)).foregroundStyle(.secondary)
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
    .card()
  }
}


// MARK: - Sheets

struct ReviewSearchSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var query = ""

  private struct Result: Identifiable {
    let day: String
    let note: NoteEntry
    var id: String { note.id }
  }

  var body: some View {
    let results = search()
    NavigationStack {
      List {
        Section("标签") {
          FlowLayout(spacing: 8) {
            ForEach(store.state.allTags, id: \.self) { tag in
              TagChip(title: tag, selected: query == tag) { query = query == tag ? "" : tag }
            }
          }
          .padding(.vertical, 4)
        }
        if !query.trimmed.isEmpty {
          Section("找到 \(results.count) 条记录") {
            ForEach(results) { result in
              Button {
                store.reviewTab = .timeline
                store.reviewDate = result.day
                store.selectedTab = .review
                dismiss()
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(result.note.text.isEmpty ? "留下了照片或语音" : MarkdownText.plain(result.note.text))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                  Text(([DayKey.fullDate(result.day)] + [result.note.place].compactMap { $0 } + result.note.tags.map { "#\($0)" }).joined(separator: " · "))
                    .font(.app(.caption))
                    .foregroundStyle(.secondary)
                }
              }
            }
          }
        }
      }
      .overlay {
        if !query.trimmed.isEmpty && results.isEmpty {
          ContentUnavailableView.search(text: query)
        }
      }
      .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索文字、标签或地点")
      .navigationTitle("搜索记录")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("关闭") { dismiss() } }
      }
    }
    .presentationDetents([.large])
  }

  private func search() -> [Result] {
    let q = query.trimmed.lowercased()
    guard !q.isEmpty else { return [] }
    var out: [Result] = []
    for (day, notes) in store.state.notes {
      for note in notes {
        let haystack = ([MarkdownText.plain(note.text), note.place ?? "", note.weather ?? ""] + note.tags).joined(separator: " ").lowercased()
        if haystack.contains(q) { out.append(Result(day: day, note: note)) }
      }
    }
    return out.sorted { $0.day > $1.day }
  }
}
