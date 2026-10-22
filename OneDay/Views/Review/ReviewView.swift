import Charts
import SwiftUI

struct ReviewView: View {
  @Environment(Store.self) private var store
  @State private var showCalendar = false
  @State private var showSearch = false
  @State private var overviewMonth = DayKey.monthStart(Date())

  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            Color.clear.frame(height: 0).id("top")
            PageIntro(title: "回到走过的日子。", subtitle: "看看发生过什么，也看看坚持了什么。")
            Picker("回顾", selection: tabBinding) {
              ForEach(ReviewTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            switch store.reviewTab {
            case .timeline:
              if let day = store.reviewDate {
                ReviewDayDetail(day: day)
                  .transition(.move(edge: .trailing).combined(with: .opacity))
              } else {
                TimelineList()
                  .transition(.opacity)
              }
            case .overview:
              OverviewPanel(month: $overviewMonth)
            }
          }
          .padding(.horizontal, Spacing.page)
          .padding(.bottom, Spacing.section)
          .animation(.snappy, value: store.reviewDate)
          .animation(.snappy, value: store.reviewTab)
        }
        .onChange(of: store.reviewDate) { _, _ in
          withAnimation(.snappy) { proxy.scrollTo("top", anchor: .top) }
        }
      }
      .background { AppBackground() }
      .navigationTitle("回顾")
      .toolbar {
        if store.reviewDate != nil && store.reviewTab == .timeline {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              store.reviewDate = nil
            } label: {
              Label("时间线", systemImage: "chevron.left")
            }
          }
        }
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
      .sheet(isPresented: $showSearch) { ReviewSearchSheet() }
      .sheet(isPresented: $showCalendar) { ReviewCalendarSheet() }
    }
  }

  /// Switching tabs from the picker also leaves the single-day view, like the web version.
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
      EmptyState(title: "时间线还是空的", icon: "clock.arrow.circlepath", message: "开始留下记录后，这里会慢慢长出属于你的时间线。")
        .card()
    } else {
      LazyVStack(alignment: .leading, spacing: 12) {
        ForEach(Array(dates.enumerated()), id: \.element) { index, day in
          if index == 0 || DayKey.monthLabel(ofKey: dates[index - 1]) != DayKey.monthLabel(ofKey: day) {
            Text(DayKey.monthLabel(ofKey: day))
              .font(.footnote.weight(.semibold))
              .foregroundStyle(.secondary)
              .padding(.top, index == 0 ? 0 : 10)
              .padding(.leading, 4)
              .accessibilityAddTraits(.isHeader)
          }
          TimelineCard(day: day)
        }
      }
    }
  }
}

private struct TimelineCard: View {
  @Environment(Store.self) private var store
  let day: String

  var body: some View {
    let notes = store.state.notes[day] ?? []
    let doneCount = store.state.tasks(on: day).filter { $0.isDone(on: day) }.count
    let tags = notes.flatMap(\.tags).uniqued()
    let hasPhotos = notes.contains { !$0.photos.isEmpty }
    let hasVideo = notes.contains { $0.media.contains { $0.kind == .video } }
    let hasAudio = notes.contains { $0.media.contains { $0.kind == .audio } }
    Button {
      store.reviewDate = day
    } label: {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(DayKey.shortDate(day)).font(.headline)
            Text(DayKey.weekday(day)).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
              if hasPhotos { Image(systemName: "photo") }
              if hasVideo { Image(systemName: "video") }
              if hasAudio { Image(systemName: "waveform") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
          }
          Text(excerpt(notes))
            .font(.subheadline)
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
          if let first = notes.first(where: { $0.place != nil || $0.weather != nil }) {
            NoteMetaLine(note: first)
          }
          if !tags.isEmpty {
            FlowLayout(spacing: 6) {
              ForEach(tags, id: \.self) { TagLabel(tag: $0) }
            }
          }
          HStack(spacing: 8) {
            MetaPill(text: notes.count > 1 ? "\(notes.count) 条记录" : "有记录")
            if doneCount > 0 { MetaPill(text: "完成了 \(doneCount) 件事项") }
          }
        }
        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .card(padding: 16)
  }

  private func excerpt(_ notes: [NoteEntry]) -> String {
    guard let first = notes.first else { return "" }
    if !first.text.isEmpty { return MarkdownText.plain(first.text).replacingOccurrences(of: "\n", with: " ") }
    if !first.photos.isEmpty { return "留下了照片" }
    if first.media.contains(where: { $0.kind == .video }) { return "留下了视频" }
    return "留下了一段语音"
  }
}

private struct MetaPill: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(Color.secondary.opacity(0.12), in: Capsule())
  }
}

// MARK: - Single day

private struct NoteEditTarget: Identifiable {
  let entry: NoteEntry
  var id: String { entry.id }
}

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
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 6) {
        Text("\(DayKey.fullDate(day)) · \(DayKey.weekday(day))")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
        Text("那一天").font(.system(.largeTitle, design: .serif, weight: .semibold))
        Text("回到这一天，看看留下了什么。").font(.callout).foregroundStyle(.secondary)
      }
      .accessibilityElement(children: .combine)
      .padding(.vertical, 4)

      if notes.isEmpty {
        EmptyState(title: "这一天没有记录", icon: "text.page.slash").card()
      } else {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
            if index > 0 { Divider().padding(.vertical, 14) }
            entryView(note, index: index)
          }
        }
        .card()
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("那一天的事项").font(.headline)
        if tasks.isEmpty {
          Text("这一天没有安排事项。").font(.subheadline).foregroundStyle(.secondary)
        } else {
          ForEach(tasks) { task in
            let done = task.isDone(on: day)
            HStack(spacing: 10) {
              Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? accent : Color.secondary)
              Text(task.title).foregroundStyle(done ? .primary : .secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(done ? "已完成" : "未完成")
          }
        }
      }
      .card()

      GlassGroup {
        HStack {
          if !notes.isEmpty {
            Button("删除全部记录", role: .destructive) { confirmDeleteAll = true }
              .oneDayButton()
              .tint(.red)
          }
          Spacer()
          Button {
            store.reviewDate = nil
          } label: {
            HStack(spacing: 6) {
              Text("查看时间线")
              Image(systemName: "arrow.right")
            }
          }
          .oneDayButton(prominent: true)
        }
      }
    }
    .sheet(item: $editing) { NoteEditorSheet(day: day, entry: $0.entry) }
    .fullScreenCover(item: $preview) { PhotoLightbox(name: $0.name) }
    .alert("删除 \(DayKey.fullDate(day)) 的全部记录？", isPresented: $confirmDeleteAll) {
      Button("删除", role: .destructive) { store.deleteNotes(on: day) }
      Button("取消", role: .cancel) {}
    } message: {
      Text("只删除当天留下的文字、照片和语音，不影响事项完成状态。删除后可以撤销。")
    }
  }

  @ViewBuilder
  private func entryView(_ note: NoteEntry, index: Int) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(note.time.isEmpty ? "记录 \(index + 1)" : note.time)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        Menu {
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
        } label: {
          Image(systemName: "ellipsis")
            .font(.body.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 28)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("记录操作")
      }
      if !note.text.isEmpty {
        MarkdownText(text: note.text)
          .font(.body)
          .textSelection(.enabled)
      }
      NoteMetaLine(note: note)
      if !note.tags.isEmpty {
        FlowLayout(spacing: 6) {
          ForEach(note.tags, id: \.self) { TagLabel(tag: $0) }
        }
      }
      if !note.photos.isEmpty {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
          ForEach(note.photos, id: \.self) { photo in
            PhotoThumb(name: photo)
              .onTapGesture { preview = PhotoRef(name: photo) }
              .contextMenu {
                Button(role: .destructive) {
                  store.deletePhoto(day: day, noteId: note.id, photo: photo)
                } label: {
                  Label("删除这张照片", systemImage: "trash")
                }
              }
              .accessibilityLabel("照片，双击查看")
              .accessibilityAddTraits(.isButton)
          }
        }
      }
      if !note.media.isEmpty {
        MediaAttachments(media: note.media) { item in
          store.deleteMedia(day: day, noteId: note.id, file: item.file)
        }
      }
    }
    .contentShape(Rectangle())
    .swipeActions(
      leading: SwipeAction(title: "编辑", icon: "pencil", tint: .blue) { editing = NoteEditTarget(entry: note) },
      trailing: SwipeAction(title: "删除", icon: "trash", tint: .red) {
        withAnimation(.snappy) { store.deleteNote(day: day, id: note.id) }
      })
  }
}

// MARK: - Record editor

struct NoteEditorSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  let day: String
  let entry: NoteEntry
  @State private var text = ""
  @State private var tags: [String] = []
  @State private var newTag = ""

  var body: some View {
    NavigationStack {
      Form {
        Section {
          NoteTextEditor(placeholder: "不需要写得很好，只留下真实的你。", text: $text)
        } header: {
          Text("内容")
        } footer: {
          Text("支持 **粗体**、*斜体*、~~删除线~~。选中文字后点上方按钮即可。")
        }
        Section("当前标签") {
          if tags.isEmpty {
            Text("暂未添加标签").foregroundStyle(.secondary)
          } else {
            FlowLayout(spacing: 8) {
              ForEach(tags, id: \.self) { tag in
                TagChip(title: tag, selected: true, onDelete: { remove(tag) }) { remove(tag) }
              }
            }
            .padding(.vertical, 4)
          }
        }
        Section("添加标签") {
          let available = store.state.allTags.filter { !tags.contains($0) }
          if !available.isEmpty {
            FlowLayout(spacing: 8) {
              ForEach(available, id: \.self) { tag in
                TagChip(title: "＋ \(tag)") { add(tag) }
              }
            }
            .padding(.vertical, 4)
          }
          HStack {
            TextField("输入新标签", text: $newTag)
              .submitLabel(.done)
              .onSubmit(addNew)
            Button("添加", action: addNew)
              .buttonStyle(.borderless)
              .disabled(newTag.trimmed.isEmpty)
          }
        }
      }
      .navigationTitle("编辑这条记录")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") {
            if store.updateNote(day: day, id: entry.id, text: text, tags: tags) { dismiss() }
          }
        }
      }
      .onAppear {
        text = entry.text
        tags = entry.tags
      }
    }
    .presentationDetents([.large])
  }

  private func add(_ tag: String) {
    Haptics.tap()
    if !tags.contains(tag) { tags.append(tag) }
  }

  private func remove(_ tag: String) {
    Haptics.tap()
    tags.removeAll { $0 == tag }
  }

  private func addNew() {
    guard let tag = store.addCustomTag(newTag) else { return }
    add(tag)
    newTag = ""
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
    VStack(spacing: 14) {
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
              .foregroundStyle(s.current > 0 ? Color.orange : Color.secondary)
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
    .card(padding: 14)
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
          .card(padding: 14)
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
