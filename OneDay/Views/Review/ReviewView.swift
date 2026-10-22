import Charts
import SwiftUI

struct ReviewView: View {
  @Environment(Store.self) private var store
  @State private var showCalendar = false
  @State private var showSearch = false
  @State private var overviewMonth = DayKey.monthStart(Date())

  var body: some View {
    NavigationStack(path: dayPath) {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.stack) {
          Picker("回顾", selection: tabBinding) {
            ForEach(ReviewTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
          }
          .pickerStyle(.segmented)
          .padding(.bottom, 4)

          switch store.reviewTab {
          case .timeline:
            TimelineList()
          case .overview:
            OverviewPanel(month: $overviewMonth)
          }
        }
        .padding(.horizontal, Spacing.page)
        .padding(.bottom, Spacing.section)
        .animation(.snappy, value: store.reviewTab)
      }
      .background { AppBackground() }
      .navigationTitle("回顾")
      .navigationDestination(for: String.self) { day in
        ReviewDayDetail(day: day)
      }
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button {
            showSearch = true
          } label: {
            Image(systemName: "magnifyingglass")
          }
          .accessibilityLabel("搜索记录")
          Button {
            showCalendar = true
          } label: {
            Image(systemName: "calendar")
          }
          .accessibilityLabel("选择回顾日期")
        }
      }
      .sheet(isPresented: $showSearch) { ReviewSearchSheet().oneDaySheet() }
      .sheet(isPresented: $showCalendar) { ReviewCalendarSheet().oneDaySheet() }
    }
  }

  /// The pushed day page mirrors `store.reviewDate`, so search, the calendar and "那年今日"
  /// can open a day from anywhere.
  private var dayPath: Binding<[String]> {
    Binding(
      get: { store.reviewDate.map { [$0] } ?? [] },
      set: { store.reviewDate = $0.last })
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

  var body: some View {
    let dates = store.state.recordDates
    if dates.isEmpty {
      EmptyState(title: "时间线还是空的", icon: "book", message: "留下第一条记录后，这里会慢慢长出属于你的时间线。")
        .card()
    } else {
      LazyVStack(alignment: .leading, spacing: Spacing.stack) {
        ForEach(Array(dates.enumerated()), id: \.element) { index, day in
          if index == 0 || DayKey.monthLabel(ofKey: dates[index - 1]) != DayKey.monthLabel(ofKey: day) {
            Text(DayKey.monthLabel(ofKey: day))
              .font(.journal(.title3, size: 20, bold: true))
              .padding(.top, index == 0 ? 0 : Spacing.section - Spacing.stack)
              .accessibilityAddTraits(.isHeader)
          }
          NavigationLink(value: day) {
            MemoryCard(
              caption: "\(DayKey.shortDate(day)) \(DayKey.weekday(day))",
              notes: store.state.notes[day] ?? [])
          }
          .buttonStyle(.plain)
        }
      }
    }
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

  var body: some View {
    let notes = store.state.notes[day] ?? []
    let tasks = store.state.tasks(on: day)
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.stack) {
        VStack(alignment: .leading, spacing: 4) {
          Text(DayKey.weekday(day))
            .font(.footnote.weight(.medium))
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
            Text("那一天的事项").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
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
    .alert("删除 \(DayKey.fullDate(day)) 的全部记录？", isPresented: $confirmDeleteAll) {
      Button("删除", role: .destructive) { store.deleteNotes(on: day) }
      Button("取消", role: .cancel) {}
    } message: {
      Text("只删除当天留下的文字、照片和语音，不影响事项完成状态。删除后可以撤销。")
    }
  }

  private func entryView(_ note: NoteEntry, index: Int) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(note.time.isEmpty ? "记录 \(index + 1)" : note.time)
        .font(.footnote.weight(.medium).monospacedDigit())
        .foregroundStyle(.secondary)
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
        editing = NoteEditTarget(entry: note)
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
      leading: SwipeAction(title: "编辑", icon: "pencil", tint: .blue) { editing = NoteEditTarget(entry: note) },
      trailing: SwipeAction(title: "删除", icon: "trash", tint: .red) {
        withAnimation(.snappy) { store.deleteNote(day: day, id: note.id) }
      })
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

private struct OverviewPanel: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  @Binding var month: Date

  var body: some View {
    let o = store.state.overview(month: month)
    let maxCount = max(1, o.items.map(\.count).max() ?? 1)
    VStack(spacing: Spacing.stack) {
      WeeklyReportCard()
      HeatmapCard()
      StreaksCard()

      GlassGroup {
        HStack {
          shiftButton("chevron.left", label: "上个月", by: -1)
          Spacer()
          Text(DayKey.monthLabel(month)).font(.headline).contentTransition(.numericText())
          Spacer()
          shiftButton("chevron.right", label: "下个月", by: 1)
        }
        .padding(6)
        .capsuleSurface()
      }
      .padding(.top, 8)

      HStack(spacing: 10) {
        StatTile(title: "本月完成", value: "\(o.total) 次")
        StatTile(title: "连续完成", value: "\(o.streak) 天")
        StatTile(title: "有记录", value: "\(o.noteDays) 天")
      }

      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Text("各事项完成次数").font(.headline)
          Spacer()
          Text(o.items.isEmpty ? "暂无数据" : "\(o.items.count) 个事项")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        if o.items.isEmpty {
          EmptyState(title: "这个月还没有完成记录", icon: "chart.bar", message: "完成一次事项后，这里会自动出现。")
        } else {
          ForEach(o.items) { item in
            VStack(alignment: .leading, spacing: 6) {
              HStack {
                Text(item.title).lineLimit(1)
                Spacer()
                Text("\(item.count) 次").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
              }
              ProgressView(value: Double(item.count), total: Double(maxCount))
                .tint(accent)
            }
            .accessibilityElement(children: .combine)
          }
        }
      }
      .card()
    }
  }

  private func shiftButton(_ icon: String, label: String, by value: Int) -> some View {
    Button {
      withAnimation(.snappy) { month = DayKey.shiftMonth(month, by: value) }
    } label: {
      Image(systemName: icon).font(.body.weight(.semibold)).frame(width: 22, height: 22)
    }
    .oneDayButton()
    .buttonBorderShape(.circle)
    .accessibilityLabel(label)
  }
}

/// This week vs last week, with an eight-week chart.
private struct WeeklyReportCard: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent

  var body: some View {
    let weeks = store.state.weeklyStats(today: store.today, weeks: 8)
    let (this, last) = store.state.weekToDate(today: store.today)
    let diff = this - last
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        Text("本周").font(.headline)
        Spacer()
        Text("近 8 周").font(.caption).foregroundStyle(.secondary)
      }
      HStack(alignment: .lastTextBaseline, spacing: 6) {
        Text("\(this)")
          .font(.system(size: 44, weight: .bold, design: .rounded))
          .contentTransition(.numericText())
        Text("次完成").foregroundStyle(.secondary)
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text(diff == 0 ? "和上周同期持平" : diff > 0 ? "比上周同期多 \(diff) 次" : "比上周同期少 \(-diff) 次")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(diff >= 0 ? accent : .secondary)
          Text("留下记录 \(weeks.last?.noteDays ?? 0) 天")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Chart(weeks) { week in
        BarMark(x: .value("周", week.label), y: .value("完成次数", week.completions))
          .foregroundStyle(week.id == weeks.last?.id ? accent : accent.opacity(0.35))
          .cornerRadius(5)
      }
      .chartYAxis {
        AxisMarks(position: .trailing) { _ in
          AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
          AxisValueLabel()
        }
      }
      .chartXAxis {
        AxisMarks { _ in AxisValueLabel().font(.caption2) }
      }
      .frame(height: 140)
      .accessibilityLabel("近 8 周完成次数柱状图")
    }
    .card()
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
        Text("这一年").font(.headline)
        Spacer()
        if let selected {
          Text("\(DayKey.shortDate(selected.day)) · \(selected.total == 0 ? "无事项" : "完成 \(selected.done)/\(selected.total)")\(selected.hasNote ? " · 有记录" : "")")
            .font(.caption)
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
        Text("少").font(.caption2).foregroundStyle(.secondary)
        ForEach(0..<5, id: \.self) { level in
          RoundedRectangle(cornerRadius: 2).fill(color(level: level)).frame(width: 10, height: 10)
        }
        Text("多").font(.caption2).foregroundStyle(.secondary)
        Spacer()
        Text("圆点表示当天有记录").font(.caption2).foregroundStyle(.secondary)
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
    VStack(alignment: .leading, spacing: 14) {
      Text("坚持").font(.headline)
      if streaks.isEmpty {
        Text("添加「每天循环」的事项后，这里会显示连续完成的天数。")
          .font(.subheadline)
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
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(s.current)")
              .font(.system(.title3, design: .rounded, weight: .bold))
              .foregroundStyle(s.current > 0 ? accent : .secondary)
            Text("天").font(.caption).foregroundStyle(.secondary)
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
    .card()
  }
}

private struct StatTile: View {
  let title: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(value).font(.title3.bold()).contentTransition(.numericText()).lineLimit(1).minimumScaleFactor(0.7)
    }
    .card()
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Sheets

struct ReviewCalendarSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent
  @State private var month = DayKey.monthStart(Date())

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          Text("有圆点的日期留下过记录。")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          CalendarMonthView(
            month: $month,
            selected: store.reviewDate,
            marker: { store.state.hasNotes(on: $0) ? accent : nil },
            onSelect: { key in
              store.reviewTab = .timeline
              store.reviewDate = key
              dismiss()
            }
          )
          .card()
        }
        .padding(20)
      }
      .navigationTitle("选择回顾日期")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("关闭") { dismiss() } }
      }
      .onAppear {
        if let day = store.reviewDate { month = DayKey.monthStart(DayKey.date(day)) }
      }
    }
    .presentationDetents([.fraction(0.7), .large])
  }
}

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
                    .font(.caption)
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
