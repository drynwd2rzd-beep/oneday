import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Edit everything in a record: text, photos, videos, voice recordings, place and tags.
struct NoteEditorSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent
  let day: String
  let entry: NoteEntry

  @State private var note: NoteEntry
  @State private var newTag = ""
  @State private var pickerItems: [PhotosPickerItem] = []
  @State private var loading = false
  @State private var locating = false
  @State private var recording = false

  private static let maxPhotos = 6
  private static let maxVideos = 3

  init(day: String, entry: NoteEntry) {
    self.day = day
    self.entry = entry
    _note = State(initialValue: entry)
  }

  private var videos: [MediaItem] { note.media.filter { $0.kind == .video } }
  private var audios: [MediaItem] { note.media.filter { $0.kind == .audio } }
  private var canAddVisual: Bool { note.photos.count < Self.maxPhotos || videos.count < Self.maxVideos }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          NoteTextEditor(placeholder: "不需要写得很好，只留下真实的你。", text: $note.text)
        } header: {
          Text("内容")
        }

        Section("心情") {
          MoodPicker(selection: $note.mood)
            .padding(.vertical, 2)
        }

        Section {
          LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(note.photos, id: \.self) { photo in
              PhotoThumb(name: photo)
                .overlay(alignment: .topTrailing) {
                  removeButton("移除这张照片") { note.photos.removeAll { $0 == photo } }
                }
            }
            ForEach(videos) { item in
              VideoThumb(item: item)
                .overlay(alignment: .topTrailing) {
                  removeButton("移除这个视频") { note.media.removeAll { $0.file == item.file } }
                }
            }
            if loading {
              ProgressView().frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
            }
            if canAddVisual {
              PhotosPicker(selection: $pickerItems, maxSelectionCount: 6, matching: .any(of: [.images, .videos])) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .fill(Color.secondary.opacity(0.1))
                  .aspectRatio(1, contentMode: .fit)
                  .overlay {
                    Image(systemName: "plus").font(.app(.title3).weight(.medium)).foregroundStyle(accent)
                  }
              }
              .buttonStyle(.plain)
              .accessibilityLabel("添加照片或视频")
            }
          }
          .padding(.vertical, 4)
        } header: {
          Text("照片和视频")
        } footer: {
          Text("最多 \(Self.maxPhotos) 张照片、\(Self.maxVideos) 个视频。")
        }

        Section("语音") {
          ForEach(audios) { item in
            HStack(spacing: 10) {
              AudioRow(item: item)
              removeButton("删除这段语音", inline: true) { note.media.removeAll { $0.file == item.file } }
            }
          }
          Button {
            recording = true
          } label: {
            Label("录一段语音", systemImage: "mic")
          }
        }

        Section("位置与天气") {
          if let place = note.place {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Label(place, systemImage: "location.fill")
                if let weather = note.weather {
                  Label(weather, systemImage: LocationWeather.symbol(for: weather))
                    .foregroundStyle(.secondary)
                }
              }
              .labelStyle(CompactLabelStyle())
              Spacer()
              removeButton("移除位置", inline: true) {
                note.place = nil
                note.latitude = nil
                note.longitude = nil
                note.weather = nil
              }
            }
          } else {
            Button {
              Task { await addLocation() }
            } label: {
              Label {
                Text(locating ? "正在获取位置…" : "添加当前位置和天气")
              } icon: {
                if locating { ProgressView() } else { Image(systemName: "location") }
              }
            }
            .disabled(locating)
          }
        }

        Section("标签") {
          if note.tags.isEmpty {
            Text("暂未添加标签").foregroundStyle(.secondary)
          } else {
            FlowLayout(spacing: 8) {
              ForEach(note.tags, id: \.self) { tag in
                TagChip(title: tag, selected: true, onDelete: { toggle(tag) }) { toggle(tag) }
              }
            }
            .padding(.vertical, 4)
          }
        }

        Section("添加标签") {
          let available = store.state.allTags.filter { !note.tags.contains($0) }
          if !available.isEmpty {
            FlowLayout(spacing: 8) {
              ForEach(available, id: \.self) { tag in
                TagChip(title: "＋ \(tag)") { toggle(tag) }
              }
            }
            .padding(.vertical, 4)
          }
        }

        Section {
          HStack {
            TextField("新建标签", text: $newTag)
              .submitLabel(.done)
              .onSubmit(addNewTag)
            Button("添加", action: addNewTag)
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
            if store.updateNote(day: day, note: note) { dismiss() }
          }
          .disabled(note == entry)
        }
      }
      .onChange(of: pickerItems) { _, items in
        guard !items.isEmpty else { return }
        Task { await load(items) }
      }
      .sheet(isPresented: $recording) {
        RecorderSheet { item in
          withAnimation(.snappy) { note.media.append(item) }
        }
        .oneDaySheet()
      }
      .animation(.snappy, value: note)
    }
    .presentationDetents([.large])
  }

  private func removeButton(_ label: String, inline: Bool = false, action: @escaping () -> Void) -> some View {
    Button {
      Haptics.tap()
      withAnimation(.snappy) { action() }
    } label: {
      Image(systemName: inline ? "minus.circle.fill" : "xmark.circle.fill")
        .font(inline ? .app(.title3) : .app(.body))
        .symbolRenderingMode(inline ? .multicolor : .palette)
        .foregroundStyle(inline ? Color.red : Color.white, Color.black.opacity(0.55))
    }
    .buttonStyle(.borderless)
    .padding(inline ? 0 : 3)
    .accessibilityLabel(label)
  }

  private func toggle(_ tag: String) {
    Haptics.tap()
    if note.tags.contains(tag) {
      note.tags.removeAll { $0 == tag }
    } else {
      note.tags.append(tag)
    }
  }

  private func addNewTag() {
    guard let tag = store.addCustomTag(newTag) else { return }
    if !note.tags.contains(tag) { note.tags.append(tag) }
    newTag = ""
  }

  private func addLocation() async {
    locating = true
    defer { locating = false }
    do {
      let stamp = try await LocationWeather.shared.stamp()
      note.place = stamp.place
      note.latitude = stamp.latitude
      note.longitude = stamp.longitude
      note.weather = stamp.weather
    } catch {
      store.toast(error.localizedDescription)
    }
  }

  private func load(_ items: [PhotosPickerItem]) async {
    loading = true
    defer {
      pickerItems = []
      loading = false
    }
    for item in items {
      if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
        guard videos.count < Self.maxVideos else {
          store.toast("每条记录最多 \(Self.maxVideos) 个视频")
          continue
        }
        if let video = try? await item.loadTransferable(type: PickedVideo.self) {
          note.media.append(video.item)
        }
      } else {
        guard note.photos.count < Self.maxPhotos else {
          store.toast("每条记录最多 \(Self.maxPhotos) 张照片")
          continue
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
        if let name = await Task.detached(priority: .userInitiated, operation: { MediaStore.save(data: data) }).value {
          note.photos.append(name)
        }
      }
    }
  }
}
