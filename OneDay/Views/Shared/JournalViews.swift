import AVKit
import SwiftUI

// MARK: - Empty states

/// System empty-state layout, sized for use inside cards.
struct EmptyState: View {
  let title: String
  let icon: String
  var message: String?

  var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: icon)
    } description: {
      if let message { Text(message) }
    }
    .font(.app(.subheadline))
    .padding(.vertical, -12)
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Markdown

/// Renders the inline Markdown a note may contain (**粗体**、*斜体*、~~删除线~~、`代码`、链接).
struct MarkdownText: View {
  let text: String

  var body: some View {
    Text(Self.attributed(text))
      .fixedSize(horizontal: false, vertical: true)
  }

  static func attributed(_ text: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
  }

  /// Plain text for excerpts and search.
  static func plain(_ text: String) -> String {
    String(attributed(text).characters)
  }
}

/// Multi-line note editor. Plain text in, so what you type is what you see; Markdown already
/// in older notes still renders when viewing.
struct NoteTextEditor: View {
  let placeholder: String
  @Binding var text: String
  var minHeight: CGFloat = 96
  var autoFocus = false
  var onFocusChange: (Bool) -> Void = { _ in }
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      TextField(placeholder, text: $text, axis: .vertical)
        .lineLimit(4...14)
        .focused($focused)
        .frame(minHeight: minHeight, alignment: .topLeading)
      if focused {
        HStack {
          Spacer()
          Button("完成") { focused = false }
            .font(.app(.subheadline).weight(.semibold))
            .buttonStyle(.borderless)
        }
        .transition(.opacity)
      }
    }
    .animation(.snappy, value: focused)
    .task {
      // Let the card finish expanding before the keyboard scrolls the page.
      guard autoFocus else { return }
      try? await Task.sleep(for: .milliseconds(280))
      focused = true
    }
    .onChange(of: focused) { _, value in onFocusChange(value) }
  }
}

// MARK: - Note pieces

/// "杭州市 · 西湖区 · 晴 23°"
struct NoteMetaLine: View {
  let note: NoteEntry

  var body: some View {
    if note.place != nil || note.weather != nil {
      HStack(spacing: 10) {
        if let place = note.place {
          Label(place, systemImage: "location.fill")
        }
        if let weather = note.weather {
          Label(weather, systemImage: LocationWeather.symbol(for: weather))
        }
      }
      .font(.app(.caption))
      .foregroundStyle(.secondary)
      .labelStyle(CompactLabelStyle())
      .lineLimit(1)
    }
  }
}

struct CompactLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 4) {
      configuration.icon.imageScale(.small)
      configuration.title
    }
  }
}

/// Video thumbnails and voice recordings attached to a note.
struct MediaAttachments: View {
  let media: [MediaItem]
  var onDelete: ((MediaItem) -> Void)?
  @State private var playing: MediaItem?

  var body: some View {
    let videos = media.filter { $0.kind == .video }
    let audios = media.filter { $0.kind == .audio }
    VStack(alignment: .leading, spacing: 8) {
      if !videos.isEmpty {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
          ForEach(videos) { item in
            VideoThumb(item: item)
              .onTapGesture { playing = item }
              .contextMenu { deleteButton(item) }
              .accessibilityLabel("视频，\(item.duration.clockText)")
              .accessibilityAddTraits(.isButton)
          }
        }
      }
      ForEach(audios) { item in
        AudioRow(item: item)
          .contextMenu { deleteButton(item) }
      }
    }
    .fullScreenCover(item: $playing) { item in
      VideoPlayerScreen(file: item.file).oneDaySheet()
    }
  }

  @ViewBuilder
  private func deleteButton(_ item: MediaItem) -> some View {
    if let onDelete {
      Button(role: .destructive) {
        onDelete(item)
      } label: {
        Label(item.kind == .video ? "删除视频" : "删除录音", systemImage: "trash")
      }
    }
  }
}

struct VideoThumb: View {
  let item: MediaItem
  @State private var image: UIImage?

  var body: some View {
    Color.secondary.opacity(0.12)
      .aspectRatio(1, contentMode: .fit)
      .overlay {
        if let image {
          Image(uiImage: image).resizable().scaledToFill()
        }
      }
      .overlay {
        Image(systemName: "play.fill")
          .font(.app(.title3))
          .foregroundStyle(.white)
          .shadow(radius: 4)
      }
      .overlay(alignment: .bottomTrailing) {
        Text(item.duration.clockText)
          .font(.app(.caption2).weight(.semibold).monospacedDigit())
          .foregroundStyle(.white)
          .padding(.horizontal, 5)
          .padding(.vertical, 2)
          .background(.black.opacity(0.45), in: Capsule())
          .padding(5)
      }
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .task(id: item.file) { image = await VideoThumbnails.image(for: item.file) }
  }
}

struct AudioRow: View {
  @Environment(\.accent) private var accent
  let item: MediaItem
  private var playback: AudioPlayback { AudioPlayback.shared }

  var body: some View {
    let isPlaying = playback.current == item.file
    Button {
      playback.toggle(item.file)
    } label: {
      HStack(spacing: 12) {
        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
          .font(.app(.footnote).weight(.bold))
          .foregroundStyle(.white)
          .frame(width: 32, height: 32)
          .background(accent, in: Circle())
          .contentTransition(.symbolEffect(.replace))
        VStack(alignment: .leading, spacing: 5) {
          Text("语音记录").font(.app(.subheadline).weight(.medium))
          ProgressView(value: isPlaying ? playback.progress : 0)
            .tint(accent)
        }
        Text(item.duration.clockText)
          .font(.app(.caption).monospacedDigit())
          .foregroundStyle(.secondary)
      }
      .padding(10)
      .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(isPlaying ? "停止播放语音" : "播放语音，\(item.duration.clockText)")
  }
}

struct VideoPlayerScreen: View {
  @Environment(\.dismiss) private var dismiss
  let file: String
  @State private var player: AVPlayer?

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Color.black.ignoresSafeArea()
      if let player {
        VideoPlayer(player: player).ignoresSafeArea()
      }
      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark").font(.app(.body).weight(.semibold)).frame(width: 24, height: 24)
      }
      .oneDayButton()
      .buttonBorderShape(.circle)
      .environment(\.colorScheme, .dark)
      .padding(20)
      .accessibilityLabel("关闭视频")
    }
    .onAppear {
      AudioPlayback.shared.stop()
      let p = AVPlayer(url: MediaStore.url(file))
      player = p
      p.play()
    }
    .onDisappear { player?.pause() }
  }
}

// MARK: - Photo-first journal card

/// A journal card: the first photo large on top (when there is one), then the date and text in
/// the journal typeface. Used by the timeline and "那年今日".
struct MemoryCard: View {
  @Environment(\.palette) private var palette
  @Environment(\.visualStyle) private var style
  let caption: String
  let notes: [NoteEntry]
  var showsChevron = false

  private var cover: String? { notes.lazy.compactMap(\.photos.first).first }

  var body: some View {
    let first = notes.first
    VStack(alignment: .leading, spacing: 0) {
      if let cover, let image = MediaStore.image(cover) {
        Color.clear
          .frame(height: 180)
          .overlay {
            Image(uiImage: image).resizable().scaledToFill()
          }
          .clipped()
          .accessibilityHidden(true)
      }
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline) {
          Text(caption)
            .font(.app(.footnote).weight(.medium))
            .foregroundStyle(.secondary)
          Spacer(minLength: 8)
          HStack(spacing: 6) {
            if notes.contains(where: { $0.media.contains { $0.kind == .video } }) { Image(systemName: "video") }
            if notes.contains(where: { $0.media.contains { $0.kind == .audio } }) { Image(systemName: "waveform") }
            if notes.count > 1 { Text("\(notes.count) 条") }
            if showsChevron { Image(systemName: "chevron.right").fontWeight(.semibold) }
          }
          .font(.app(.caption))
          .foregroundStyle(.tertiary)
        }
        if let first {
          Text(excerpt(first))
            .font(.journal(.body, size: 17))
            .foregroundStyle(.primary)
            .lineSpacing(4)
            .lineLimit(4)
            .multilineTextAlignment(.leading)
          NoteMetaLine(note: first)
        }
      }
      .padding(Spacing.card)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .surface(cornerRadius: style == .flat ? Radius.flatCard : Radius.card)
    .clipShape(RoundedRectangle(cornerRadius: style == .flat ? Radius.flatCard : Radius.card, style: .continuous))
    .contentShape(Rectangle())
  }

  private func excerpt(_ note: NoteEntry) -> String {
    if !note.text.isEmpty { return MarkdownText.plain(note.text) }
    if !note.photos.isEmpty { return "留下了照片" }
    if note.media.contains(where: { $0.kind == .video }) { return "留下了视频" }
    return "留下了一段语音"
  }
}
