import SwiftUI

/// Opens the chat, optionally sending a first question right away.
struct ChatRequest: Identifiable, Hashable {
  let id = UUID()
  var prompt: String?
  /// A deeper read of the records (more effort) rather than small talk.
  var deep = false
}

/// 和小日聊聊: a chat with Claude as 小日, who can read the recent records.
struct ChatView: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent
  var request: ChatRequest?
  @State private var session = ChatSession.shared
  @State private var draft = ""
  @State private var hasKey = APIKeyStore.hasKey
  @State private var showKey = false
  @State private var confirmClear = false
  @FocusState private var typing: Bool

  private static let starters: [(title: String, prompt: String, deep: Bool)] = [
    ("解读我最近的状态", "帮我解读一下我最近的状态：做得好的地方、可能的问题，还有一个小建议。", true),
    ("我最近心情怎么样？", "看看我最近的心情，有什么变化或者规律吗？", true),
    ("帮我想想下周重点", "根据我最近的记录，帮我想 2 到 3 个下周的重点，要具体、小一点。", true),
    ("陪我聊聊天", "今天想和你随便聊聊。", false),
  ]

  var body: some View {
    NavigationStack {
      Group {
        if hasKey {
          chat
        } else {
          APIKeySetup { hasKey = true }
        }
      }
      .background { AppBackground() }
      .navigationTitle("和小日聊聊")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
        if hasKey {
          ToolbarItem(placement: .primaryAction) {
            Menu {
              Button("新的对话", systemImage: "square.and.pencil") { confirmClear = true }
                .disabled(session.lines.isEmpty)
              Toggle("带上我最近 14 天的记录", isOn: Binding(get: { session.shareRecords }, set: { session.shareRecords = $0 }))
              Button("API Key", systemImage: "key") { showKey = true }
            } label: {
              Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("聊天设置")
          }
        }
      }
      .confirmationDialog("开始新的对话？", isPresented: $confirmClear, titleVisibility: .visible) {
        Button("清空并重新开始", role: .destructive) { session.clear() }
      } message: {
        Text("现在的聊天记录会被清空。")
      }
      .sheet(isPresented: $showKey) {
        NavigationStack {
          APIKeySetup(editing: true) {
            hasKey = APIKeyStore.hasKey
            showKey = false
          }
          .background { AppBackground() }
          .navigationTitle("API Key")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { showKey = false } } }
        }
        .presentationDetents([.medium, .large])
      }
    }
    .onAppear {
      if let prompt = request?.prompt, hasKey, !session.isBusy {
        send(prompt, deep: request?.deep ?? false)
      }
    }
    .onChange(of: session.pendingRetry) { _, text in
      if let text, draft.isEmpty { draft = text }
      session.pendingRetry = nil
    }
  }

  // MARK: Chat

  private var chat: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 14) {
          if session.lines.isEmpty && !session.isBusy {
            intro
          }
          ForEach(session.lines) { line in
            bubble(line.role, text: line.text, shared: line.sharedRecords).id(line.id)
          }
          if let streaming = session.streaming {
            bubble(.assistant, text: streaming.isEmpty ? "小日在想…" : streaming, thinking: streaming.isEmpty)
              .id("streaming")
          }
          if let error = session.error {
            Label(error, systemImage: "exclamationmark.triangle")
              .font(.app(.footnote))
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity)
              .padding(.top, 4)
          }
          Color.clear.frame(height: 1).id("bottom")
        }
        .padding(.horizontal, Spacing.page)
        .padding(.vertical, Spacing.stack)
      }
      .scrollDismissesKeyboard(.interactively)
      .onChange(of: session.streaming) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
      .onChange(of: session.lines.count) { _, _ in withAnimation(.snappy) { proxy.scrollTo("bottom", anchor: .bottom) } }
      .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
      .safeAreaInset(edge: .bottom) { inputBar }
    }
  }

  private var intro: some View {
    VStack(spacing: Spacing.stack) {
      MascotView(mood: .happy, size: 84, stage: store.state.growth(today: store.today).stage.rawValue, outfit: store.mascotOutfit, plant: store.mascotPlant)
      Text("想聊点什么？").font(.app(.title3).weight(.bold))
      Text(session.shareRecords ? "我会看看你最近 14 天的记录再回答。" : "这次不带上你的记录。")
        .font(.app(.subheadline))
        .foregroundStyle(.secondary)
      VStack(spacing: 8) {
        ForEach(Self.starters, id: \.title) { starter in
          Button {
            send(starter.prompt, deep: starter.deep)
          } label: {
            HStack {
              Text(starter.title).font(.app(.subheadline).weight(.medium))
              Spacer()
              Image(systemName: "arrow.up.circle.fill").foregroundStyle(accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.top, 6)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 20)
  }

  @ViewBuilder
  private func bubble(_ role: ChatLine.Role, text: String, shared: Bool = false, thinking: Bool = false) -> some View {
    if role == .user {
      VStack(alignment: .trailing, spacing: 4) {
        Text(text)
          .font(.app(.body))
          .foregroundStyle(.white)
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .background(accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        if shared {
          Label("带上了最近 14 天的记录", systemImage: "paperclip")
            .font(.app(.caption2))
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .trailing)
      .padding(.leading, 48)
    } else {
      HStack(alignment: .top, spacing: 8) {
        MascotView(mood: thinking ? .calm : .happy, size: 30, stage: 1, plant: store.mascotPlant)
          .frame(width: 32, height: 32)
          .accessibilityHidden(true)
        Group {
          if thinking {
            Text(text).foregroundStyle(.secondary)
              .phaseAnimator([0.4, 1]) { view, alpha in view.opacity(alpha) } animation: { _ in .easeInOut(duration: 0.8) }
          } else {
            MarkdownText(text: text)
              .textSelection(.enabled)
          }
        }
        .font(.journal(.body, size: 17))
        .lineSpacing(4)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.background.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.sun.opacity(0.35), lineWidth: 1))
      }
      .padding(.trailing, 32)
      .accessibilityElement(children: .combine)
      .accessibilityLabel("小日说：\(text)")
    }
  }

  private var inputBar: some View {
    HStack(alignment: .bottom, spacing: 8) {
      TextField("和小日说点什么", text: $draft, axis: .vertical)
        .font(.app(.body))
        .lineLimit(1...5)
        .focused($typing)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
      if session.isBusy {
        Button {
          session.stop()
        } label: {
          Image(systemName: "stop.circle.fill").font(.system(size: 32)).foregroundStyle(.secondary)
        }
        .accessibilityLabel("停止")
      } else {
        Button {
          send(draft, deep: false)
        } label: {
          Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)).foregroundStyle(accent)
        }
        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityLabel("发送")
      }
    }
    .padding(.horizontal, Spacing.page)
    .padding(.vertical, 8)
    .background(.bar)
  }

  private func send(_ text: String, deep: Bool) {
    let context = session.shareRecords ? store.state.aiContext(today: store.today) : nil
    session.send(text, context: context, deep: deep)
    draft = ""
  }
}

/// Explains what the chat needs and keeps the API key in the keychain.
struct APIKeySetup: View {
  @Environment(\.accent) private var accent
  var editing = false
  let onSaved: () -> Void
  @State private var key = ""

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.stack) {
        if !editing {
          HStack {
            Spacer()
            MascotView(mood: .happy, size: 80)
            Spacer()
          }
          .padding(.top, 8)
        }
        VStack(alignment: .leading, spacing: 10) {
          Text("小日的聊天由 Claude 提供").font(.app(.headline))
          Text("需要一个你自己的 Anthropic API Key。在 console.anthropic.com 创建，用多少付多少。")
            .font(.app(.subheadline))
            .foregroundStyle(.secondary)
          Link(destination: URL(string: "https://console.anthropic.com/settings/keys")!) {
            Label("去创建 API Key", systemImage: "arrow.up.right.square")
              .font(.app(.subheadline).weight(.medium))
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()

        VStack(alignment: .leading, spacing: 10) {
          SecureField("sk-ant-…", text: $key)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.app(.body).monospaced())
            .padding(12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          Button {
            APIKeyStore.save(key.trimmingCharacters(in: .whitespacesAndNewlines))
            Haptics.success()
            onSaved()
          } label: {
            Text("保存").frame(maxWidth: .infinity)
          }
          .oneDayButton(prominent: true)
          .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).count < 20)
          if editing && APIKeyStore.hasKey {
            Button("删除已保存的 Key", role: .destructive) {
              APIKeyStore.delete()
              onSaved()
            }
            .font(.app(.subheadline))
            .frame(maxWidth: .infinity)
          }
        }
        .card()

        VStack(alignment: .leading, spacing: 6) {
          Label("Key 只保存在这台手机的钥匙串里。", systemImage: "lock")
          Label("聊天时，你的消息（如果你选择，还有最近 14 天的记录）会发给 Anthropic 来生成回答。", systemImage: "paperplane")
          Label("可以在聊天右上角关掉「带上记录」。", systemImage: "switch.2")
        }
        .font(.app(.footnote))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
      }
      .padding(.horizontal, Spacing.page)
      .padding(.vertical, Spacing.stack)
    }
  }
}
