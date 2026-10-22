import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct TodayView: View {
  @Environment(Store.self) private var store
  /// Bumped to open (and focus) the capture card from a quick action or widget link.
  @State private var captureSignal = 0
  @State private var captureSheet = false

  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.section) {
          if store.settings.homeModules.isEmpty {
            EmptyState(title: "首页是空的", icon: "square.dashed", message: "在「我的 → 首页自定义」中打开需要的模块。")
              .card()
          }
          ForEach(store.settings.homeModules) { module in
            switch module {
            case .hero:
              HeroModule()
              RecapBanner()
            case .tasks: TodayTasksModule()
            case .note: QuickCaptureModule(openSignal: captureSignal).id("capture")
            case .onThisDay: OnThisDayModule()
            case .progress: EmptyView()
            case .plans: HomePlansModule()
            }
          }
        }
        .padding(.horizontal, Spacing.page)
        .padding(.bottom, Spacing.section)
        .animation(.snappy, value: store.settings.homeModules)
      }
      .scrollDismissesKeyboard(.interactively)
      .background { AppBackground() }
      // Without a navigation bar, content scrolled up would run under the clock.
      .overlay(alignment: .top) { StatusBarScrim() }
      .navigationTitle("一天")
      // The greeting is the page header; a second large title would compete with it.
      .toolbar(.hidden, for: .navigationBar)
      .onChange(of: store.pendingCapture, initial: true) { _, pending in
        guard pending else { return }
        store.pendingCapture = false
        if store.settings.homeModules.contains(.note) {
          captureSignal += 1
          withAnimation(.snappy) { proxy.scrollTo("capture", anchor: .top) }
        } else {
          captureSheet = true
        }
      }
      .sheet(isPresented: $captureSheet) { CaptureSheet().oneDaySheet() }
      }
    }
  }
}

/// The capture card on its own, for when the home page has it turned off.
private struct CaptureSheet: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        QuickCaptureModule(openSignal: 1)
          .padding(.horizontal, Spacing.page)
          .padding(.vertical, Spacing.stack)
      }
      .scrollDismissesKeyboard(.interactively)
      .background { AppBackground() }
      .navigationTitle("写一条记录")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
      }
    }
    .presentationDetents([.medium, .large])
  }
}

/// Fades the page background in behind the status bar.
private struct StatusBarScrim: View {
  @Environment(\.palette) private var palette

  var body: some View {
    GeometryReader { geo in
      let top = geo.safeAreaInsets.top
      LinearGradient(
        stops: [
          .init(color: palette.bg, location: 0),
          .init(color: palette.bg.opacity(0.92), location: top / (top + 18)),
          .init(color: palette.bg.opacity(0), location: 1),
        ],
        startPoint: .top, endPoint: .bottom)
        .frame(height: top + 18)
        .offset(y: -top)
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

/// In the first days of a month, offers last month's recap card.
private struct RecapBanner: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  @AppStorage("recapBannerDismissed") private var dismissed = ""
  @State private var showing = false

  var body: some View {
    let now = DayKey.date(store.today)
    let lastMonth = DayKey.shiftMonth(now, by: -1)
    let key = String(DayKey.of(lastMonth).prefix(7))
    let dayOfMonth = DayKey.calendar.component(.day, from: now)
    if dayOfMonth <= 3, dismissed != key, !store.state.recap(month: lastMonth).isEmpty {
      HStack(spacing: 12) {
        Button {
          showing = true
        } label: {
          HStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
              .font(.title3)
              .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 2) {
              Text("\(DayKey.calendar.component(.month, from: lastMonth))月回顾已经准备好了")
                .font(.subheadline.weight(.semibold))
              Text("看看上个月的自己")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        Button {
          withAnimation(.snappy) { dismissed = key }
        } label: {
          Image(systemName: "xmark")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("不再显示")
      }
      .card(padding: 14)
      .sheet(isPresented: $showing) { RecapSheet(month: lastMonth).oneDaySheet() }
    }
  }
}

private struct HeroModule: View {
  @Environment(Store.self) private var store

  var body: some View {
    let now = Date()
    VStack(alignment: .leading, spacing: 6) {
      Text("\(DayKey.shortDate(store.today)) \(DayKey.weekday(store.today))")
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
      Text(OneDayText.greeting(now))
        .font(.journal(.largeTitle, size: 34, bold: true))
      Text(OneDayText.quote(for: now, mode: store.settings.quoteMode))
        .font(.journal(.subheadline, size: 15))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 20)
    .accessibilityElement(children: .combine)
  }
}

private struct TodayTasksModule: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent

  var body: some View {
    let day = store.today
    let list = store.state.tasks(on: day)
    let open = list.filter { !$0.isDone(on: day) }
    let done = list.count - open.count
    VStack(alignment: .leading, spacing: Spacing.title) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("今天")
          .font(.title3.weight(.semibold))
          .accessibilityAddTraits(.isHeader)
        if !list.isEmpty {
          Text("\(done)/\(list.count)")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .contentTransition(.numericText())
            .accessibilityLabel("已完成 \(done) 件，共 \(list.count) 件")
        }
        Spacer()
        Button {
          store.selectedTab = .tasks
        } label: {
          HStack(spacing: 3) {
            Text("全部事项")
            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
          }
          .font(.subheadline)
          .foregroundStyle(.secondary)
        }
      }
      VStack(alignment: .leading, spacing: 0) {
        if !list.isEmpty {
          ProgressView(value: Double(done), total: Double(list.count))
            .tint(accent)
            .padding(.top, 12)
            .padding(.bottom, open.isEmpty ? 0 : 4)
            .animation(.snappy, value: done)
            .accessibilityHidden(true)
        }
        if open.isEmpty {
          EmptyState(
            title: list.isEmpty ? "今天没有待办" : "今天的事项都完成了",
            icon: list.isEmpty ? "sun.max" : "checkmark.seal",
            message: list.isEmpty ? "在「事项」里添加一件小事。" : nil)
            .padding(.vertical, 12)
        } else {
          TaskList(tasks: open, day: day)
        }
      }
      .listCard()
    }
  }
}

private struct HomePlansModule: View {
  @Environment(Store.self) private var store

  var body: some View {
    let plans = Array(store.state.activePlans.prefix(3))
    VStack(alignment: .leading, spacing: Spacing.title) {
      SectionHeader(title: "我的计划", actionTitle: "全部计划") { store.selectedTab = .plans }
      VStack(alignment: .leading, spacing: 0) {
        if plans.isEmpty {
          EmptyState(title: "还没有进行中的计划", icon: "scope")
        } else {
          ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
            if index > 0 { Divider().padding(.vertical, 10) }
            HomePlanRow(plan: plan)
          }
        }
      }
      .card()
    }
  }
}

/// Notes written on this day in earlier years. Hidden when there are none.
private struct OnThisDayModule: View {
  @Environment(Store.self) private var store

  var body: some View {
    let memories = store.state.onThisDay(today: store.today)
    if !memories.isEmpty {
      VStack(alignment: .leading, spacing: Spacing.title) {
        SectionHeader(title: "那年今日")
        ForEach(memories) { memory in
          Button {
            store.reviewTab = .timeline
            store.reviewDate = memory.day
            store.selectedTab = .review
          } label: {
            MemoryCard(
              caption: "\(memory.yearsAgo) 年前 · \(DayKey.fullDate(memory.day))",
              notes: memory.notes)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

// MARK: - Quick capture

private struct QuickCaptureModule: View {
  @Environment(Store.self) private var store
  var openSignal = 0
  @Environment(\.accent) private var accent
  @State private var draft = NoteDraft()
  @State private var pickerItems: [PhotosPickerItem] = []
  @State private var loading = false
  @State private var locating = false
  @State private var recording = false
  @State private var pending: NoteDraft?
  @State private var expanded = false
  @State private var focusOnOpen = false
  @State private var handledSignal = 0

  var body: some View {
    Group {
      if expanded || !draft.isEmpty {
        editor
      } else {
        collapsed
      }
    }
    .animation(.snappy, value: expanded)
    .onChange(of: openSignal) { _, _ in openIfAsked() }
    .onAppear { openIfAsked() }
    .onChange(of: pickerItems) { _, items in
      guard !items.isEmpty else { return }
      focusOnOpen = false
      expanded = true
      Task { await load(items) }
    }
    .sheet(isPresented: $recording) {
      RecorderSheet { item in
        withAnimation(.snappy) { draft.media.append(item) }
      }
      .oneDaySheet()
    }
    .sheet(item: $pending) { note in
      TagPickerSheet(draft: note).oneDaySheet()
    }
  }

  /// One quiet line until the user wants to write.
  private var collapsed: some View {
    HStack(spacing: 12) {
      Button {
        focusOnOpen = true
        expanded = true
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "square.and.pencil")
            .font(.body.weight(.medium))
            .foregroundStyle(accent)
          Text("今天有什么值得留下的？")
            .foregroundStyle(.secondary)
          Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("写一条记录")
      PhotosPicker(selection: $pickerItems, maxSelectionCount: 6, matching: .any(of: [.images, .videos])) {
        Image(systemName: "photo").font(.body).foregroundStyle(.secondary)
      }
      .accessibilityLabel("添加照片或视频")
      Button {
        focusOnOpen = false
        expanded = true
        recording = true
      } label: {
        Image(systemName: "mic").font(.body).foregroundStyle(.secondary)
      }
      .accessibilityLabel("录制语音")
    }
    .padding(.vertical, 2)
    .card()
  }

  private var editor: some View {
    VStack(alignment: .leading, spacing: Spacing.title) {
      // Stays open until 留下 or 收起: losing focus (scrolling, opening the photo picker)
      // must not close it, or picked photos have nowhere to go.
      HStack(alignment: .firstTextBaseline) {
        Text("值得留下")
          .font(.title3.weight(.semibold))
          .accessibilityAddTraits(.isHeader)
        Spacer()
        if draft.isEmpty && !loading {
          Button("收起") {
            focusOnOpen = false
            expanded = false
          }
          .font(.subheadline)
          .foregroundStyle(.secondary)
        }
      }
      VStack(alignment: .leading, spacing: Spacing.inner) {
        NoteTextEditor(
          placeholder: "不需要写得很好，只留下真实的你。", text: $draft.text, minHeight: 64,
          autoFocus: focusOnOpen && draft.isEmpty)

        if !draft.photos.isEmpty || !draft.media.isEmpty || loading {
          attachmentStrip
        }

        if let place = draft.place {
          HStack(spacing: 8) {
            Label(place, systemImage: "location.fill")
            if let weather = draft.weather {
              Label(weather, systemImage: LocationWeather.symbol(for: weather))
            }
            Spacer()
            Button {
              withAnimation(.snappy) {
                draft.place = nil
                draft.latitude = nil
                draft.longitude = nil
                draft.weather = nil
              }
            } label: {
              Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("移除位置")
          }
          .font(.caption)
          .foregroundStyle(.secondary)
          .labelStyle(CompactLabelStyle())
        }

        MoodPicker(selection: $draft.mood, compact: true)

        Divider()
        HStack(spacing: 8) {
          GlassGroup(spacing: 6) {
            HStack(spacing: 6) {
              PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: 6,
                matching: .any(of: [.images, .videos])
              ) {
                Image(systemName: "photo.on.rectangle.angled")
              }
              .accessibilityLabel("添加照片或视频")
              Button {
                recording = true
              } label: {
                Image(systemName: "mic")
              }
              .accessibilityLabel("录制语音")
              Button {
                Task { await addLocation() }
              } label: {
                if locating { ProgressView() } else { Image(systemName: draft.place == nil ? "location" : "location.fill") }
              }
              .disabled(locating)
              .accessibilityLabel("添加位置和天气")
            }
            .oneDayButton()
            .buttonBorderShape(.circle)
          }
          Spacer()
          Button("留下") { submit() }
            .oneDayButton(prominent: true)
            .disabled(draft.isEmpty || loading)
        }
      }
      .card()
    }
  }

  private var attachmentStrip: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(draft.photos, id: \.self) { name in
          PhotoThumb(name: name)
            .frame(width: 76, height: 76)
            .overlay(alignment: .topTrailing) { removeButton { draft.photos.removeAll { $0 == name } } }
        }
        ForEach(draft.media) { item in
          Group {
            if item.kind == .video {
              VideoThumb(item: item)
            } else {
              VStack(spacing: 4) {
                Image(systemName: "waveform").font(.title3).foregroundStyle(accent)
                Text(item.duration.clockText).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
          }
          .frame(width: 76, height: 76)
          .overlay(alignment: .topTrailing) { removeButton { draft.media.removeAll { $0.file == item.file } } }
        }
        if loading { ProgressView().frame(width: 76, height: 76) }
      }
    }
  }

  private func removeButton(_ action: @escaping () -> Void) -> some View {
    Button {
      withAnimation(.snappy) { action() }
    } label: {
      Image(systemName: "xmark.circle.fill")
        .font(.title3)
        .symbolRenderingMode(.palette)
        .foregroundStyle(.white, .black.opacity(0.55))
    }
    .padding(3)
    .accessibilityLabel("移除")
  }

  private func load(_ items: [PhotosPickerItem]) async {
    loading = true
    defer {
      pickerItems = []
      loading = false
    }
    for item in items {
      if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
        guard draft.media.filter({ $0.kind == .video }).count < 3 else {
          store.toast("每条记录最多 3 个视频")
          continue
        }
        if let video = try? await item.loadTransferable(type: PickedVideo.self) {
          withAnimation(.snappy) { draft.media.append(video.item) }
        }
      } else {
        guard draft.photos.count < 6 else {
          store.toast("每条记录最多 6 张照片")
          continue
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
        let name = await Task.detached(priority: .userInitiated) { MediaStore.save(data: data) }.value
        if let name { withAnimation(.snappy) { draft.photos.append(name) } }
      }
    }
  }

  private func addLocation() async {
    locating = true
    defer { locating = false }
    do {
      let stamp = try await LocationWeather.shared.stamp()
      withAnimation(.snappy) {
        draft.place = stamp.place
        draft.latitude = stamp.latitude
        draft.longitude = stamp.longitude
        draft.weather = stamp.weather
      }
    } catch {
      store.toast(error.localizedDescription)
    }
  }

  /// Opens the editor once per request from a quick action or widget link.
  private func openIfAsked() {
    guard openSignal > handledSignal else { return }
    handledSignal = openSignal
    focusOnOpen = true
    expanded = true
  }

  private func submit() {
    guard !draft.isEmpty else { return store.toast("写一点内容，或者留下一张照片") }
    pending = draft
    draft = NoteDraft()
    expanded = false
  }
}

/// Voice recording sheet with a live level meter.
struct RecorderSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent
  @State private var recorder = AudioRecorder()
  @State private var denied = false
  let onFinish: (MediaItem) -> Void

  var body: some View {
    VStack(spacing: 24) {
      Text(recorder.isRecording ? "正在录音" : denied ? "无法使用麦克风" : "准备录音")
        .font(.headline)
      Text(recorder.elapsed.clockText)
        .font(.system(size: 48, weight: .light, design: .rounded).monospacedDigit())
        .contentTransition(.numericText())
      HStack(spacing: 4) {
        ForEach(0..<24, id: \.self) { i in
          Capsule()
            .fill(accent.opacity(0.85))
            .frame(width: 4, height: 6 + CGFloat(recorder.level) * CGFloat(28 + (i * 7) % 20))
        }
      }
      .frame(height: 56)
      .animation(.linear(duration: 0.1), value: recorder.level)
      if denied {
        Text("请在系统设置中允许「一天」使用麦克风。").font(.subheadline).foregroundStyle(.secondary)
      }
      HStack(spacing: 16) {
        Button("取消") {
          recorder.cancel()
          dismiss()
        }
        .oneDayButton()
        Button {
          if let item = recorder.stop() { onFinish(item) }
          dismiss()
        } label: {
          Label("完成", systemImage: "stop.fill")
        }
        .oneDayButton(prominent: true)
        .disabled(!recorder.isRecording)
      }
      .controlSize(.large)
    }
    .padding(28)
    .presentationDetents([.height(360)])
    .interactiveDismissDisabled(recorder.isRecording)
    .task {
      denied = !(await recorder.start())
      if !denied { Haptics.tap() }
    }
    .onDisappear { if recorder.isRecording { recorder.cancel() } }
  }
}

/// After "留下": choose or create tags. Dismissing the sheet still saves the note.
struct TagPickerSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  let draft: NoteDraft
  @State private var selected: [String] = []
  @State private var newTag = ""
  @State private var saved = false
  @State private var tagToDelete: String?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text("标签可选，也可以自己创建；以后可在回顾中按标签搜索。")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          FlowLayout(spacing: 9) {
            ForEach(store.state.allTags, id: \.self) { tag in
              TagChip(
                title: tag,
                selected: selected.contains(tag),
                onDelete: store.state.isCustomTag(tag) ? { tagToDelete = tag } : nil
              ) {
                toggle(tag)
              }
            }
          }
          HStack(spacing: 10) {
            TextField("新标签，例如：旅行", text: $newTag)
              .submitLabel(.done)
              .onSubmit(addTag)
              .fieldBackground()
            Button("添加", action: addTag)
              .oneDayButton()
              .disabled(newTag.trimmed.isEmpty)
          }
        }
        .padding(20)
      }
      .navigationTitle("加个标签")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("跳过") { finish(tags: []) }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") { finish(tags: selected) }
        }
      }
      .alert(
        "删除这个标签？",
        isPresented: Binding(get: { tagToDelete != nil }, set: { if !$0 { tagToDelete = nil } }),
        presenting: tagToDelete
      ) { tag in
        Button("删除", role: .destructive) {
          selected.removeAll { $0 == tag }
          store.deleteCustomTag(tag)
        }
        Button("取消", role: .cancel) {}
      } message: { tag in
        Text("「\(tag)」会从所有历史记录中移除。")
      }
    }
    .presentationDetents([.medium, .large])
    .onDisappear {
      if !saved { store.addNote(draft, tags: selected) }
    }
  }

  private func toggle(_ tag: String) {
    Haptics.tap()
    if selected.contains(tag) {
      selected.removeAll { $0 == tag }
    } else {
      selected.append(tag)
    }
  }

  private func addTag() {
    guard let tag = store.addCustomTag(newTag) else { return }
    if !selected.contains(tag) { selected.append(tag) }
    newTag = ""
  }

  private func finish(tags: [String]) {
    saved = true
    store.addNote(draft, tags: tags)
    dismiss()
  }
}


private struct HomePlanRow: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  let plan: Plan

  var body: some View {
    let progress = store.state.progress(of: plan, today: store.today)
    let tint = plan.color.map { Color(hex: $0) } ?? accent
    HStack(spacing: 12) {
      Image(systemName: plan.symbol)
        .font(.body.weight(.medium))
        .foregroundStyle(tint)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 2) {
        Text(plan.title).font(.body)
        Text(subtitle(progress))
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  private func subtitle(_ progress: PlanProgress) -> String {
    if progress.tasks.isEmpty { return plan.desc.isEmpty ? "正在前进。" : plan.desc }
    var text = "近 7 天 \(progress.lastWeek) 次"
    if progress.streak > 0 { text += " · 连续 \(progress.streak) 天" }
    return text
  }
}
