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
            PageIntro(title: "回到走过的日子。", subtitle: "看看发生过什么，也看看这个月坚持了什么。")
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
          .padding(.horizontal, 16)
          .padding(.bottom, 28)
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
      EmptyText("开始留下文字记录后，这里会慢慢长出属于你的时间线。").card()
    } else {
      LazyVStack(alignment: .leading, spacing: 12) {
        ForEach(Array(dates.enumerated()), id: \.element) { index, day in
          if index == 0 || DayKey.monthLabel(ofKey: dates[index - 1]) != DayKey.monthLabel(ofKey: day) {
            Text(DayKey.monthLabel(ofKey: day))
              .font(.footnote.weight(.semibold))
              .foregroundStyle(.secondary)
              .padding(.top, index == 0 ? 0 : 10)
              .padding(.leading, 4)
          }
          TimelineCard(day: day)
        }
      }
    }
  }
}

private struct TimelineCard: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  let day: String

  var body: some View {
    let notes = store.state.notes[day] ?? []
    let doneCount = store.state.tasks(on: day).filter { $0.isDone(on: day) }.count
    let tags = notes.flatMap(\.tags).uniqued()
    Button {
      store.reviewDate = day
    } label: {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(DayKey.shortDate(day)).font(.headline)
            Text(DayKey.weekday(day)).font(.subheadline).foregroundStyle(.secondary)
          }
          Text(excerpt(notes))
            .font(.subheadline)
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
          if !tags.isEmpty {
            FlowLayout(spacing: 6) {
              ForEach(tags, id: \.self) { TagLabel(tag: $0) }
            }
          }
          HStack(spacing: 8) {
            MetaPill(text: notes.count > 1 ? "\(notes.count) 条记录" : "有记录")
            if doneCount > 0 { MetaPill(text: "完成了 \(doneCount) 件事项") }
            if notes.contains(where: { !$0.photos.isEmpty }) {
              Image(systemName: "photo").font(.caption).foregroundStyle(.secondary)
            }
          }
        }
        Spacer(minLength: 0)
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
    if !first.text.isEmpty { return first.text.replacingOccurrences(of: "\n", with: " ") }
    return first.photos.isEmpty ? "" : "留下了照片"
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

private struct PhotoDeletion: Identifiable {
  let noteId: String
  let photo: String
  var id: String { photo }
}

private struct ReviewDayDetail: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  let day: String
  @State private var editing: NoteEditTarget?
  @State private var deletingNote: NoteEntry?
  @State private var deletingPhoto: PhotoDeletion?
  @State private var confirmDeleteAll = false
  @State private var preview: PhotoRef?

  var body: some View {
    let notes = store.state.notes[day] ?? []
    let tasks = store.state.tasks(on: day)
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 6) {
        Text("\(DayKey.fullDate(day)) · \(DayKey.weekday(day))")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
        Text("那一天").font(.system(.largeTitle, design: .serif, weight: .bold))
        Text("回到这一天，看看留下了什么。").foregroundStyle(.secondary)
      }
      .card(tint: accent.opacity(0.12))

      if notes.isEmpty {
        EmptyText("这一天没有留下文字或照片。").card()
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
          EmptyText("这一天没有安排事项。")
        } else {
          ForEach(tasks) { task in
            let done = task.isDone(on: day)
            HStack(spacing: 10) {
              Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? accent : Color.secondary)
              Text(task.title).foregroundStyle(done ? .primary : .secondary)
            }
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
    .alert("删除这条记录？", isPresented: isPresented($deletingNote), presenting: deletingNote) { note in
      Button("删除", role: .destructive) { store.deleteNote(day: day, id: note.id) }
      Button("取消", role: .cancel) {}
    } message: { _ in
      Text("文字、照片和标签都会被删除。")
    }
    .background {
      Color.clear
        .alert("只删除这张照片？", isPresented: isPresented($deletingPhoto), presenting: deletingPhoto) { item in
          Button("删除", role: .destructive) { store.deletePhoto(day: day, noteId: item.noteId, photo: item.photo) }
          Button("取消", role: .cancel) {}
        } message: { _ in
          Text("文字和其他照片会保留。")
        }
    }
    .overlay {
      Color.clear
        .allowsHitTesting(false)
        .alert("删除 \(DayKey.fullDate(day)) 的全部记录？", isPresented: $confirmDeleteAll) {
          Button("删除", role: .destructive) { store.deleteNotes(on: day) }
          Button("取消", role: .cancel) {}
        } message: {
          Text("这只会删除当天留下的文字和照片，不会影响事项完成状态。")
        }
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
        Button("编辑") { editing = NoteEditTarget(entry: note) }
          .font(.subheadline)
        Button("删除", role: .destructive) { deletingNote = note }
          .font(.subheadline)
          .tint(.red)
      }
      .buttonStyle(.borderless)
      if !note.text.isEmpty {
        Text(note.text)
          .font(.body)
          .fixedSize(horizontal: false, vertical: true)
          .textSelection(.enabled)
      }
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
              .overlay(alignment: .topTrailing) {
                Button {
                  deletingPhoto = PhotoDeletion(noteId: note.id, photo: photo)
                } label: {
                  Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.55))
                }
                .buttonStyle(.plain)
                .padding(4)
                .accessibilityLabel("删除这张照片")
              }
              .contextMenu {
                Button(role: .destructive) {
                  deletingPhoto = PhotoDeletion(noteId: note.id, photo: photo)
                } label: {
                  Label("删除这张照片", systemImage: "trash")
                }
              }
              .accessibilityAddTraits(.isButton)
          }
        }
      }
    }
  }

  private func isPresented<T>(_ binding: Binding<T?>) -> Binding<Bool> {
    Binding(get: { binding.wrappedValue != nil }, set: { if !$0 { binding.wrappedValue = nil } })
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
        Section("内容") {
          TextField("不需要写得很好，只留下真实的你。", text: $text, axis: .vertical)
            .lineLimit(4...12)
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

      VStack(alignment: .leading, spacing: 10) {
        Text("本月完成事项").font(.subheadline).foregroundStyle(.secondary)
        HStack(alignment: .lastTextBaseline) {
          Text("\(o.total)")
            .font(.system(size: 56, weight: .bold, design: .rounded))
            .contentTransition(.numericText())
          Text("次").font(.title3).foregroundStyle(.secondary)
          Spacer()
          Text("每一次完成，都是\n真实发生过的一天。")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
        }
      }
      .card(tint: accent.opacity(0.14))

      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Text("各事项完成次数").font(.headline)
          Spacer()
          Text(o.items.isEmpty ? "暂无数据" : "\(o.items.count) 个事项")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        if o.items.isEmpty {
          Text("这个月还没有完成记录。\n完成一次事项后，这里会自动出现。")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
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
          }
        }
      }
      .card()

      HStack(spacing: 10) {
        StatTile(title: "连续完成", value: "\(o.streak) 天")
        StatTile(title: "留下文字", value: "\(o.textRecords) 条")
        StatTile(title: "有记录", value: "\(o.noteDays) 天")
      }
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

private struct StatTile: View {
  let title: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(value).font(.title3.bold()).contentTransition(.numericText()).lineLimit(1).minimumScaleFactor(0.7)
    }
    .card(padding: 14)
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
          Text("有圆点的日期留下过文字或照片。")
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
        Section(query.isEmpty ? "结果" : "找到 \(results.count) 条记录") {
          if query.trimmed.isEmpty {
            Text("输入文字，或选择一个标签。").foregroundStyle(.secondary)
          } else if results.isEmpty {
            Text("没有找到相关记录。").foregroundStyle(.secondary)
          } else {
            ForEach(results) { result in
              Button {
                store.reviewTab = .timeline
                store.reviewDate = result.day
                store.selectedTab = .review
                dismiss()
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(result.note.text.isEmpty ? "留下了一张照片" : result.note.text)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                  Text(([DayKey.fullDate(result.day)] + result.note.tags.map { "#\($0)" }).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
            }
          }
        }
      }
      .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索标签或文字")
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
      for note in notes where note.tags.contains(where: { $0.lowercased().contains(q) }) || note.text.lowercased().contains(q) {
        out.append(Result(day: day, note: note))
      }
    }
    return out.sorted { $0.day > $1.day }
  }
}
