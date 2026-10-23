import Foundation
import Observation

/// One line in the chat, as shown on screen.
struct ChatLine: Codable, Identifiable, Hashable {
  enum Role: String, Codable { case user, assistant }
  var id = UUID().uuidString
  var role: Role
  var text: String
  /// The first message of a conversation can carry the recent records along.
  var sharedRecords = false
  var date = Date()
}

/// The conversation with 小日 (Claude). The raw API messages are kept exactly as sent and
/// received, and only ever appended to: earlier turns, thinking blocks included, go back
/// unchanged on every request. The records travel once, in the first message.
@MainActor
@Observable
final class ChatSession {
  static let shared = ChatSession()

  private(set) var lines: [ChatLine] = []
  /// The answer being written right now.
  private(set) var streaming: String?
  private(set) var error: String?
  var isBusy: Bool { streaming != nil }
  /// Send the last 14 days of records with the first message.
  var shareRecords: Bool = UserDefaults.standard.object(forKey: "chatShareRecords") as? Bool ?? true {
    didSet { UserDefaults.standard.set(shareRecords, forKey: "chatShareRecords") }
  }

  private var apiMessages: [JSONObject] = []
  private var task: Task<Void, Never>?

  private static var fileURL: URL {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("chat.json")
  }

  private init() {
    #if DEBUG
    if Self.isDemo {
      let start = Date().addingTimeInterval(-600)
      lines = [
        ChatLine(role: .user, text: "帮我解读一下我最近的状态", sharedRecords: true, date: start),
        ChatLine(role: .assistant, text: "这两周你有 10 天都来了，很稳 🌱\n\n我注意到：「阅读 20 分钟」几乎每天都做到了，可是**周二和周四**的事项常常没完成——那两天有游泳课。", date: start.addingTimeInterval(20)),
        ChatLine(role: .assistant, text: "一个小建议：游泳那天，只留一件最小的事，比如「喝 8 杯水」。做完就算赢。", date: start.addingTimeInterval(22)),
        ChatLine(role: .user, text: "好主意！那周末呢？", date: start.addingTimeInterval(60)),
      ]
      return
    }
    #endif
    load()
  }

  /// Screenshots: a made-up conversation, no API key needed.
  static var isDemo: Bool {
    #if DEBUG
    return UserDefaults.standard.bool(forKey: "OneDayChatDemo")
    #else
    return false
    #endif
  }

  /// Sends `text`; on the first message of a conversation, the records come along when allowed.
  func send(_ text: String, context: String?, deep: Bool = false) {
    let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty, !isBusy else { return }
    error = nil
    var content: [JSONObject] = []
    let attach = apiMessages.isEmpty && shareRecords && context != nil
    if attach, let context {
      content.append(["type": "text", "text": "<my_records>\n\(context)\n</my_records>"])
    }
    content.append(["type": "text", "text": clean])
    let userMessage: JSONObject = ["role": "user", "content": content]
    lines.append(ChatLine(role: .user, text: clean, sharedRecords: attach))
    streaming = ""
    let history = apiMessages + [userMessage]

    task = Task {
      do {
        for try await event in ClaudeClient.stream(system: Self.system, messages: history, effort: deep ? "medium" : "low") {
          switch event {
          case .text(let piece):
            streaming = (streaming ?? "") + piece
          case .done(let blocks, _):
            let answer = blocks.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }.joined()
            apiMessages = history + [["role": "assistant", "content": blocks]]
            lines.append(ChatLine(role: .assistant, text: answer.isEmpty ? "……" : answer))
            streaming = nil
            save()
          }
        }
        // Cancelled before the end: nothing was added.
        if streaming != nil { rollBack(clean) }
      } catch {
        let stopped = error is CancellationError || (error as? URLError)?.code == .cancelled
        if !stopped { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
        rollBack(clean)
      }
    }
  }

  /// A failed turn leaves no trace in the history, so the next request stays well-formed.
  private func rollBack(_ text: String) {
    streaming = nil
    if lines.last?.role == .user, lines.last?.text == text { lines.removeLast() }
    pendingRetry = text
  }

  /// What to put back in the input after a failed send.
  var pendingRetry: String?

  func stop() {
    task?.cancel()
  }

  func clear() {
    task?.cancel()
    lines = []
    apiMessages = []
    streaming = nil
    error = nil
    save()
  }

  // MARK: Saving

  private struct Saved: Codable {
    var lines: [ChatLine]
    var api: Data
  }

  private func save() {
    guard let api = try? JSONSerialization.data(withJSONObject: apiMessages),
      let data = try? JSONEncoder().encode(Saved(lines: lines, api: api))
    else { return }
    try? data.write(to: Self.fileURL, options: [.atomic, .completeFileProtection])
  }

  private func load() {
    guard let data = try? Data(contentsOf: Self.fileURL),
      let saved = try? JSONDecoder().decode(Saved.self, from: data),
      let api = try? JSONSerialization.jsonObject(with: saved.api) as? [JSONObject]
    else { return }
    lines = saved.lines
    apiMessages = api
  }

  // MARK: Prompt

  /// Fixed for every conversation, so earlier turns stay valid and the prompt cache stays warm.
  static let system = """
  你是「小日」，OneDay 这个日记和习惯 App 里的小伙伴：一个圆滚滚的小太阳，头上长着一株植物。你正在和 App 的主人聊天。

  对方正在学习中文。请用简单、自然的中文回答：句子短一点，少用生僻词和成语。

  语气温暖、真诚，像一个了解对方的朋友。不说教，也不夸张地夸奖。

  如果消息里有 <my_records>，那是对方最近在 OneDay 里的记录（事项、心情、日记、复盘）。解读的时候：
  - 先说你注意到的具体事情，可以提到日期或引用原话；
  - 再说你看到的规律或变化；
  - 最后给一两个很小、马上就能做的建议。
  记录里没有的事情不要编。

  你不是医生或心理咨询师，不做诊断。如果对方提到想伤害自己，或者情绪非常糟糕，温柔地建议对方联系信任的人或专业的帮助。

  回答一般在 200 字以内，除非对方想听更详细的。可以用简单的列表，不要用标题。
  """
}
