import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct TodayView: View {
  @Environment(Store.self) private var store

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.section) {
          if store.settings.homeModules.isEmpty {
            EmptyState(title: "首页是空的", icon: "square.dashed", message: "在「我的 → 首页自定义」中打开需要的模块。")
              .card()
          }
          ForEach(store.settings.homeModules) { module in
            switch module {
            case .hero: HeroModule()
            case .tasks: TodayTasksModule()
            case .note: QuickCaptureModule()
            case .onThisDay: OnThisDayModule()
            case .progress: ProgressModule()
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
      .navigationTitle("一天")
    }
  }
}

private struct HeroModule: View {
  @Environment(Store.self) private var store

  var body: some View {
    let now = Date()
    VStack(alignment: .leading, spacing: 8) {
      Text("\(DayKey.shortDate(store.today)) \(DayKey.weekday(store.today))")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
      Text(OneDayText.greeting(now))
        .font(.system(.largeTitle, design: .serif, weight: .semibold))
      Text(OneDayText.quote(for: now, mode: store.settings.quoteMode))
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

private struct TodayTasksModule: View {
  @Environment(Store.self) private var store

  var body: some View {
    let day = store.today
    let list = store.state.tasks(on: day)
    let open = list.filter { !$0.isDone(on: day) }
    VStack(alignment: .leading, spacing: Spacing.title) {
      SectionHeader(title: "今天", actionTitle: "全部事项") { store.selectedTab = .tasks }
      VStack(alignment: .leading, spacing: 0) {
        if open.isEmpty {
          EmptyState(
            title: list.isEmpty ? "今天没有待办" : "今天的事项都完成了",
            icon: list.isEmpty ? "sun.max" : "checkmark.seal",
            message: list.isEmpty ? "在「事项」里添加一件小事。" : nil)
        } else {
          TaskList(tasks: open, day: day)
        }
      }
      .card(padding: open.isEmpty ? Spacing.card : 12)
    }
  }
}

private struct ProgressModule: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent

  var body: some View {
    let day = store.today
    let list = store.state.tasks(on: day)
    let done = list.filter { $0.isDone(on: day) }.count
    let ratio = list.isEmpty ? 0 : Double(done) / Double(list.count)
    HStack(spacing: 16) {
      ZStack {
        Circle().stroke(accent.opacity(0.15), lineWidth: 7)
        Circle()
          .trim(from: 0, to: ratio)
          .stroke(accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
          .rotationEffect(.degrees(-90))
          .animation(.snappy, value: ratio)
        Text("\(Int((ratio * 100).rounded()))%")
          .font(.system(.subheadline, design: .rounded, weight: .bold))
          .contentTransition(.numericText())
      }
      .frame(width: 64, height: 64)
      VStack(alignment: .leading, spacing: 4) {
        Text("今天的完成情况").font(.headline)
        Text(list.isEmpty ? "从一件小事开始" : "\(done)/\(list.count) 已完成")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .card()
    .accessibilityElement(children: .combine)
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
            VStack(alignment: .leading, spacing: 3) {
              Text(plan.title).font(.body.weight(.semibold))
              Text(plan.desc.isEmpty ? "正在前进。" : plan.desc)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            VStack(alignment: .leading, spacing: 8) {
              Text("\(memory.yearsAgo) 年前 · \(DayKey.fullDate(memory.day))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              if let first = memory.notes.first {
                Text(first.text.isEmpty ? "留下了照片或语音" : MarkdownText.plain(first.text))
                  .font(.body)
                  .foregroundStyle(.primary)
                  .lineLimit(3)
                  .multilineTextAlignment(.leading)
                NoteMetaLine(note: first)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .card()
        }
      }
    }
  }
}

// MARK: - Quick capture

private struct QuickCaptureModule: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  @State private var draft = NoteDraft()
  @State private var pickerItems: [PhotosPickerItem] = []
  @State private var loading = false
  @State private var locating = false
  @State private var recording = false
  @State private var pending: NoteDraft?

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.title) {
      SectionHeader(title: "值得留下")
      VStack(alignment: .leading, spacing: 14) {
        NoteTextEditor(placeholder: "今天有什么值得留下的吗？不需要写得很好，只留下真实的你。", text: $draft.text, minHeight: 72)
          .fieldBackground()

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
    .onChange(of: pickerItems) { _, items in
      guard !items.isEmpty else { return }
      Task { await load(items) }
    }
    .sheet(isPresented: $recording) {
      RecorderSheet { item in
        withAnimation(.snappy) { draft.media.append(item) }
      }
    }
    .sheet(item: $pending) { note in
      TagPickerSheet(draft: note)
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

  private func submit() {
    guard !draft.isEmpty else { return store.toast("写一点内容，或者留下一张照片") }
    pending = draft
    draft = NoteDraft()
  }
}

/// Voice recording sheet with a live level meter.
private struct RecorderSheet: View {
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
