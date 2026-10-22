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
    .font(.subheadline)
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

/// Multi-line editor with a small formatting bar that wraps the selection in Markdown.
struct NoteTextEditor: View {
  let placeholder: String
  @Binding var text: String
  var minHeight: CGFloat = 96
  @State private var selection: TextSelection?
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      TextField(placeholder, text: $text, selection: $selection, axis: .vertical)
        .lineLimit(4...14)
        .focused($focused)
        .frame(minHeight: minHeight, alignment: .topLeading)
      if focused {
        HStack(spacing: 4) {
          formatButton("bold", label: "粗体", marker: "**")
          formatButton("italic", label: "斜体", marker: "*")
          formatButton("strikethrough", label: "删除线", marker: "~~")
          formatButton("chevron.left.forwardslash.chevron.right", label: "代码", marker: "`")
          Spacer()
          Button("完成") { focused = false }
            .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderless)
        .transition(.opacity)
      }
    }
    .animation(.snappy, value: focused)
  }

  private func formatButton(_ icon: String, label: String, marker: String) -> some View {
    Button {
      wrap(marker)
    } label: {
      Image(systemName: icon)
        .font(.subheadline.weight(.semibold))
        .frame(width: 34, height: 30)
    }
    .foregroundStyle(.secondary)
    .accessibilityLabel(label)
  }

  private func wrap(_ marker: String) {
    if case .selection(let range) = selection?.indices, !range.isEmpty,
       range.lowerBound >= text.startIndex, range.upperBound <= text.endIndex {
      let inner = String(text[range])
      text.replaceSubrange(range, with: marker + inner + marker)
    } else {
      text += marker + marker
    }
    Haptics.tap()
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
      .font(.caption)
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
          .font(.title3)
          .foregroundStyle(.white)
          .shadow(radius: 4)
      }
      .overlay(alignment: .bottomTrailing) {
        Text(item.duration.clockText)
          .font(.caption2.weight(.semibold).monospacedDigit())
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
          .font(.footnote.weight(.bold))
          .foregroundStyle(.white)
          .frame(width: 32, height: 32)
          .background(accent, in: Circle())
          .contentTransition(.symbolEffect(.replace))
        VStack(alignment: .leading, spacing: 5) {
          Text("语音记录").font(.subheadline.weight(.medium))
          ProgressView(value: isPlaying ? playback.progress : 0)
            .tint(accent)
        }
        Text(item.duration.clockText)
          .font(.caption.monospacedDigit())
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
        Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 24, height: 24)
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
