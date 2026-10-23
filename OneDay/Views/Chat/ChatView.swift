import SwiftUI

/// Opens the chat, optionally sending a first question right away.
struct ChatRequest: Identifiable, Hashable {
  let id = UUID()
  var prompt: String?
  /// A deeper read of the records (more effort) rather than small talk.
  var deep = false
}

/// The colors of Messages: blue for what you send, gray for what comes back.
private enum Bubble {
  static let blueTop = Color(hex: "#3d9bff")
  static let blue = Color(hex: "#0a7cff")
  static let gray = Color(uiColor: .systemGray5)
}

/// 和小日聊聊, laid out like Messages: 小日 (Claude) can read the recent records.
struct ChatView: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  var request: ChatRequest?
  @State private var session = ChatSession.shared
  @State private var draft = ""
  @State private var hasKey = APIKeyStore.hasKey || ChatSession.isDemo
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
            .background { AppBackground() }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
        ToolbarItem(placement: .principal) { header }
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

  /// 小日's round picture over its name, like a contact at the top of Messages.
  private var header: some View {
    VStack(spacing: 1) {
      Avatar(size: 30)
      HStack(spacing: 2) {
        Text("小日").font(.app(.caption).weight(.semibold))
        Image(systemName: "chevron.right").font(.app(size: 8, weight: .bold)).foregroundStyle(.tertiary)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("小日")
  }

  // MARK: Chat

  private var chat: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 0) {
          if session.lines.isEmpty && !session.isBusy {
            intro
          }
          ForEach(Array(session.lines.enumerated()), id: \.element.id) { index, line in
            let previous = index > 0 ? session.lines[index - 1] : nil
            let next = index + 1 < session.lines.count ? session.lines[index + 1] : nil
            if previous.map({ line.date.timeIntervalSince($0.date) > 15 * 60 }) ?? true {
              timestamp(line.date)
            }
            // A run of messages from one side sits close together; the last one gets the tail.
            let continues = next?.role == line.role || (line.role == .assistant && next == nil && session.isBusy)
            message(line.role, text: line.text, tail: !continues)
              .padding(.top, previous?.role == line.role ? 2 : 10)
              .id(line.id)
            if line.sharedRecords {
              note("附上了最近 14 天的记录", trailing: true)
            }
          }
          if let streaming = session.streaming {
            Group {
              if streaming.isEmpty {
                TypingBubble()
                  .frame(maxWidth: .infinity, alignment: .leading)
              } else {
                message(.assistant, text: streaming, tail: true)
              }
            }
            .padding(.top, session.lines.last?.role == .assistant ? 2 : 10)
            .id("streaming")
          }
          if let error = session.error {
            note(error, trailing: false, icon: "exclamationmark.circle")
              .frame(maxWidth: .infinity)
              .padding(.top, 8)
          }
          Color.clear.frame(height: 8).id("bottom")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
      }
      .scrollDismissesKeyboard(.interactively)
      .background(Color(uiColor: .systemBackground))
      .onChange(of: session.streaming) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
      .onChange(of: session.lines.count) { _, _ in withAnimation(.snappy) { proxy.scrollTo("bottom", anchor: .bottom) } }
      .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
      .safeAreaInset(edge: .bottom) { inputBar }
    }
  }

  private var intro: some View {
    VStack(spacing: 10) {
      Avatar(size: 76)
      Text("小日").font(.app(.title3).weight(.semibold))
      Text(session.shareRecords ? "由 Claude 提供 · 会先看看你最近 14 天的记录" : "由 Claude 提供 · 这次不带上你的记录")
        .font(.app(.caption))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      FlowLayout(spacing: 8) {
        ForEach(Self.starters, id: \.title) { starter in
          Button {
            send(starter.prompt, deep: starter.deep)
          } label: {
            Text(starter.title)
              .font(.app(.subheadline))
              .foregroundStyle(Bubble.blue)
              .padding(.horizontal, 14)
              .padding(.vertical, 8)
              .overlay(Capsule().stroke(Bubble.blue.opacity(0.5), lineWidth: 1))
              .contentShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.top, 10)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 36)
    .padding(.bottom, 20)
    .padding(.horizontal, 12)
  }

  private func timestamp(_ date: Date) -> some View {
    let day = DayKey.of(date)
    let time = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    let label = day == store.today ? "今天 \(time)" : "\(DayKey.shortDate(day)) \(time)"
    return Text(label)
      .font(.app(.caption2).weight(.medium))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity)
      .padding(.top, 14)
      .padding(.bottom, 2)
  }

  private func note(_ text: String, trailing: Bool, icon: String? = nil) -> some View {
    HStack(spacing: 4) {
      if let icon { Image(systemName: icon) }
      Text(text)
    }
    .font(.app(.caption2))
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .center)
    .padding(.top, 3)
    .padding(.trailing, trailing ? 6 : 0)
  }

  @ViewBuilder
  private func message(_ role: ChatLine.Role, text: String, tail: Bool) -> some View {
    let mine = role == .user
    let shape = BubbleShape(mine: mine, tail: tail)
    Group {
      if mine {
        Text(text)
      } else {
        MarkdownText(text: text)
      }
    }
    .font(.app(.body))
    .foregroundStyle(mine ? Color.white : Color.primary)
    .textSelection(.enabled)
    .padding(.horizontal, 13)
    .padding(.vertical, 8)
    .padding(mine ? .trailing : .leading, tail ? 5 : 0)
    .background {
      if mine {
        shape.fill(LinearGradient(colors: [Bubble.blueTop, Bubble.blue], startPoint: .top, endPoint: .bottom))
      } else {
        shape.fill(Bubble.gray)
      }
    }
    .padding(mine ? .trailing : .leading, tail ? 0 : 5)
    .frame(maxWidth: 300, alignment: mine ? .trailing : .leading)
    .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(mine ? "我：\(text)" : "小日：\(text)")
  }

  private var inputBar: some View {
    HStack(alignment: .bottom, spacing: 8) {
      Menu {
        ForEach(Self.starters, id: \.title) { starter in
          Button(starter.title) { send(starter.prompt, deep: starter.deep) }
        }
      } label: {
        Image(systemName: "plus")
          .font(.app(.body).weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(width: 34, height: 34)
          .background(Color(uiColor: .systemGray6), in: Circle())
      }
      .disabled(session.isBusy)
      .accessibilityLabel("常用问题")
      HStack(alignment: .bottom, spacing: 4) {
        TextField("信息", text: $draft, axis: .vertical)
          .font(.app(.body))
          .lineLimit(1...6)
          .focused($typing)
          .padding(.leading, 14)
          .padding(.vertical, 7)
        Group {
          if session.isBusy {
            Button {
              session.stop()
            } label: {
              Image(systemName: "stop.circle.fill").font(.system(size: 28)).foregroundStyle(.secondary)
            }
            .accessibilityLabel("停止")
          } else if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button {
              send(draft, deep: false)
            } label: {
              Image(systemName: "arrow.up.circle.fill").font(.system(size: 28)).foregroundStyle(Bubble.blue)
            }
            .accessibilityLabel("发送")
            .transition(.scale.combined(with: .opacity))
          }
        }
        .padding(.trailing, 3)
        .padding(.bottom, 3)
      }
      .frame(minHeight: 36)
      .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(uiColor: .systemGray4), lineWidth: 0.8))
      .animation(.snappy(duration: 0.2), value: draft.isEmpty)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(.bar)
  }

  private func send(_ text: String, deep: Bool) {
    let context = session.shareRecords ? store.state.aiContext(today: store.today) : nil
    session.send(text, context: context, deep: deep)
    draft = ""
  }
}

/// 小日 in a round frame on a soft sky.
private struct Avatar: View {
  @Environment(Store.self) private var store
  let size: CGFloat

  var body: some View {
    ZStack {
      LinearGradient(colors: [Color(hex: "#ffe7c2"), Color(hex: "#ffd0b5")], startPoint: .top, endPoint: .bottom)
      MascotView(mood: .happy, size: size * 0.74, stage: store.state.growth(today: store.today).stage.rawValue, outfit: store.mascotOutfit, plant: store.mascotPlant)
        .offset(y: size * 0.06)
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .accessibilityHidden(true)
  }
}

/// A Messages bubble: rounded, with a little curled tail at the bottom corner on the
/// last message of a run.
private struct BubbleShape: Shape {
  let mine: Bool
  let tail: Bool

  func path(in rect: CGRect) -> Path {
    let r: CGFloat = min(18, rect.height / 2)
    // The tail takes 5pt beside the body.
    let body = CGRect(
      x: rect.minX + (tail && !mine ? 5 : 0), y: rect.minY,
      width: rect.width - (tail ? 5 : 0), height: rect.height)
    var p = Path(roundedRect: body, cornerRadius: r, style: .continuous)
    guard tail else { return p }
    var t = Path()
    if mine {
      t.move(to: CGPoint(x: body.maxX - r * 0.6, y: body.maxY - r))
      t.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: body.maxX, y: body.maxY - 2))
      t.addQuadCurve(to: CGPoint(x: body.maxX - r * 0.9, y: body.maxY), control: CGPoint(x: body.maxX - 4, y: body.maxY))
    } else {
      t.move(to: CGPoint(x: body.minX + r * 0.6, y: body.maxY - r))
      t.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control: CGPoint(x: body.minX, y: body.maxY - 2))
      t.addQuadCurve(to: CGPoint(x: body.minX + r * 0.9, y: body.maxY), control: CGPoint(x: body.minX + 4, y: body.maxY))
    }
    t.closeSubpath()
    p.addPath(t)
    return p
  }
}

/// Three dots that pulse while 小日 is writing.
private struct TypingBubble: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: 4) {
      ForEach(0..<3, id: \.self) { i in
        Circle()
          .fill(Color.secondary)
          .frame(width: 8, height: 8)
          .phaseAnimator(reduceMotion ? [1.0] : [0.35, 1.0]) { view, alpha in
            view.opacity(alpha)
          } animation: { _ in
            .easeInOut(duration: 0.5).delay(Double(i) * 0.18)
          }
      }
    }
    .padding(.leading, 21)
    .padding(.trailing, 16)
    .padding(.vertical, 13)
    .background(BubbleShape(mine: false, tail: true).fill(Bubble.gray))
    .accessibilityLabel("小日正在输入")
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
