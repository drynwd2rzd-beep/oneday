import PhotosUI
import SwiftUI

struct TodayView: View {
  @Environment(Store.self) private var store

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          if store.settings.homeModules.isEmpty {
            EmptyText("首页模块都已隐藏，可以在「我的 → 首页自定义」中重新打开。").card()
          }
          ForEach(store.settings.homeModules) { module in
            switch module {
            case .hero: HeroModule()
            case .tasks: TodayTasksModule()
            case .note: QuickCaptureModule()
            case .progress: ProgressModule()
            case .plans: HomePlansModule()
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
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
    VStack(alignment: .leading, spacing: 10) {
      Text("\(DayKey.shortDate(store.today)) \(DayKey.weekday(store.today))")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(OneDayText.greeting(now))
        .font(.system(.largeTitle, design: .serif, weight: .bold))
      Text(OneDayText.quote(for: now, mode: store.settings.quoteMode))
        .font(.body)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 4)
  }
}

private struct TodayTasksModule: View {
  @Environment(Store.self) private var store

  var body: some View {
    let day = store.today
    let list = store.state.tasks(on: day)
    let open = list.filter { !$0.isDone(on: day) }
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "今天", actionTitle: "查看事项") { store.selectedTab = .tasks }
      VStack(alignment: .leading, spacing: 0) {
        if open.isEmpty {
          EmptyText(list.isEmpty ? "今天没有待办事项。" : "今天的事项已经完成了。")
        } else {
          TaskList(tasks: open, day: day)
        }
      }
      .card(padding: open.isEmpty ? 18 : 12)
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
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .lastTextBaseline) {
        VStack(alignment: .leading, spacing: 4) {
          Text("今天的完成情况").font(.subheadline).foregroundStyle(.secondary)
          Text("\(Int((ratio * 100).rounded()))%")
            .font(.system(size: 40, weight: .bold, design: .rounded))
            .contentTransition(.numericText())
        }
        Spacer()
        Text(list.isEmpty ? "从一件小事开始" : "\(done)/\(list.count) 已完成")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      ProgressView(value: ratio)
        .tint(accent)
        .scaleEffect(x: 1, y: 1.6, anchor: .center)
        .animation(.snappy, value: ratio)
    }
    .card()
  }
}

private struct HomePlansModule: View {
  @Environment(Store.self) private var store

  var body: some View {
    let plans = Array(store.state.activePlans.prefix(3))
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "我的计划", actionTitle: "查看计划") { store.selectedTab = .plans }
      if plans.isEmpty {
        EmptyText("还没有进行中的计划。").card()
      } else {
        ForEach(plans) { plan in
          VStack(alignment: .leading, spacing: 4) {
            Text(plan.title).font(.headline)
            Text(plan.desc.isEmpty ? "正在前进。" : plan.desc)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
          .card(padding: 16)
        }
      }
    }
  }
}

// MARK: - Quick capture

struct PendingNote: Identifiable {
  let id = UUID()
  var text: String
  var photos: [String]
}

private struct QuickCaptureModule: View {
  @Environment(Store.self) private var store
  @State private var text = ""
  @State private var photos: [String] = []
  @State private var pickerItems: [PhotosPickerItem] = []
  @State private var loadingPhotos = false
  @State private var pending: PendingNote?
  @FocusState private var focused: Bool

  private var isEmpty: Bool { text.trimmed.isEmpty && photos.isEmpty }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "值得留下")
      VStack(alignment: .leading, spacing: 14) {
        TextField("今天有什么值得留下的吗？不需要写得很好，只留下真实的你。", text: $text, axis: .vertical)
          .lineLimit(3...8)
          .focused($focused)
          .fieldBackground()

        if !photos.isEmpty || loadingPhotos {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
              ForEach(photos, id: \.self) { name in
                PhotoThumb(name: name)
                  .frame(width: 76, height: 76)
                  .overlay(alignment: .topTrailing) {
                    Button {
                      withAnimation(.snappy) { removePhoto(name) }
                    } label: {
                      Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.55))
                    }
                    .padding(3)
                    .accessibilityLabel("移除这张照片")
                  }
                  .transition(.scale.combined(with: .opacity))
              }
              if loadingPhotos {
                ProgressView().frame(width: 76, height: 76)
              }
            }
          }
        }

        HStack(spacing: 10) {
          PhotosPicker(
            selection: $pickerItems,
            maxSelectionCount: max(1, 6 - photos.count),
            matching: .images
          ) {
            Label("添加照片", systemImage: "photo.on.rectangle.angled")
          }
          .oneDayButton()
          .disabled(photos.count >= 6)

          Spacer()

          Button("留下") { submit() }
            .oneDayButton(prominent: true)
            .disabled(isEmpty)
        }
        .controlSize(.regular)

        Text(photos.count >= 6 ? "最多添加 6 张照片。" : "文字和照片都可以单独留下。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .card()
    }
    .onChange(of: pickerItems) { _, items in
      guard !items.isEmpty else { return }
      Task { await load(items) }
    }
    .sheet(item: $pending) { note in
      TagPickerSheet(note: note)
    }
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("完成") { focused = false }
      }
    }
  }

  private func load(_ items: [PhotosPickerItem]) async {
    loadingPhotos = true
    for item in items where photos.count < 6 {
      guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
      let name = await Task.detached(priority: .userInitiated) { PhotoStore.save(data: data) }.value
      if let name {
        withAnimation(.snappy) { photos.append(name) }
      }
    }
    if items.count > 6 - photos.count && photos.count >= 6 { store.toast("最多添加 6 张照片") }
    pickerItems = []
    loadingPhotos = false
  }

  private func removePhoto(_ name: String) {
    photos.removeAll { $0 == name }
    PhotoStore.delete(name)
  }

  private func submit() {
    guard !isEmpty else { return store.toast("写一点内容，或者留下一张照片") }
    focused = false
    pending = PendingNote(text: text.trimmed, photos: photos)
    text = ""
    photos = []
  }
}

/// After "留下": choose or create tags. Dismissing the sheet still saves the note.
struct TagPickerSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  let note: PendingNote
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
      .navigationTitle("给这条记录加标签")
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
      if !saved { store.addNote(text: note.text, photos: note.photos, tags: selected) }
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
    store.addNote(text: note.text, photos: note.photos, tags: tags)
    dismiss()
  }
}
