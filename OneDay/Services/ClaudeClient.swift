import Foundation
import Security

/// The Anthropic API key, kept in this device's keychain only.
enum APIKeyStore {
  private static let service = "com.oneday.app.anthropic"
  private static let account = "api-key"

  static var key: String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static var hasKey: Bool { key?.isEmpty == false }

  static func save(_ key: String) {
    delete()
    let item: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecValueData as String: Data(key.utf8),
    ]
    SecItemAdd(item as CFDictionary, nil)
  }

  static func delete() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
  }
}

/// A raw Messages API content block or message, kept exactly as sent or received so that
/// earlier turns (thinking blocks included) go back to the API unchanged.
typealias JSONObject = [String: Any]

/// What arrives while 小日 is answering.
enum ClaudeEvent {
  /// More of the visible answer.
  case text(String)
  /// The finished assistant message (every content block, as received) and why it stopped.
  case done(content: [JSONObject], stopReason: String?)
}

enum ClaudeError: LocalizedError {
  case noKey
  case http(status: Int, type: String?, message: String?)
  case stream(type: String?, message: String?)
  case refused

  var errorDescription: String? {
    switch self {
    case .noKey:
      return "还没有设置 API Key。"
    case .http(let status, let type, let message):
      switch status {
      case 401: return "API Key 不对，请检查一下。"
      case 403: return "这个 API Key 没有权限。"
      case 429: return "请求太频繁，或者额度用完了，稍后再试。"
      case 500...599: return "Claude 那边有点忙（\(type ?? "\(status)")），稍后再试。"
      default: return message ?? "请求失败（\(status)）。"
      }
    case .stream(let type, let message):
      if type == "overloaded_error" { return "Claude 那边有点忙，稍后再试。" }
      return message ?? "回答中断了，再试一次吧。"
    case .refused:
      return "这个问题小日没法回答，换个说法试试。"
    }
  }
}

/// Calls the Claude Messages API directly (there is no Swift SDK) and streams the answer.
enum ClaudeClient {
  static let model = "claude-opus-5-5"
  private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

  /// Streams one assistant turn for `messages` (raw API messages, oldest first).
  /// `effort` is "low" for chatting and "medium" for a deeper read of the records.
  static func stream(system: String, messages: [JSONObject], effort: String) -> AsyncThrowingStream<ClaudeEvent, Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        do {
          guard let key = APIKeyStore.key, !key.isEmpty else { throw ClaudeError.noKey }
          var request = URLRequest(url: endpoint)
          request.httpMethod = "POST"
          request.timeoutInterval = 600
          request.setValue("application/json", forHTTPHeaderField: "content-type")
          request.setValue(key, forHTTPHeaderField: "x-api-key")
          request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
          // If a safety classifier declines, the API retries on its recommended model.
          request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
          let body: JSONObject = [
            "model": model,
            "max_tokens": 64000,
            "stream": true,
            "system": system,
            "messages": messages,
            "output_config": ["effort": effort],
            "fallbacks": "default",
          ]
          request.httpBody = try JSONSerialization.data(withJSONObject: body)

          let (bytes, response) = try await URLSession.shared.bytes(for: request)
          let status = (response as? HTTPURLResponse)?.statusCode ?? 0
          guard status == 200 else {
            var data = Data()
            for try await byte in bytes { data.append(byte) }
            let error = (try? JSONSerialization.jsonObject(with: data) as? JSONObject)?["error"] as? JSONObject
            throw ClaudeError.http(status: status, type: error?["type"] as? String, message: error?["message"] as? String)
          }

          var blocks: [Int: JSONObject] = [:]
          var stopReason: String?
          for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let data = payload.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? JSONObject,
              let type = event["type"] as? String
            else { continue }
            switch type {
            case "content_block_start":
              if let index = event["index"] as? Int, let block = event["content_block"] as? JSONObject {
                blocks[index] = block
              }
            case "content_block_delta":
              guard let index = event["index"] as? Int, let delta = event["delta"] as? JSONObject else { break }
              var block = blocks[index] ?? [:]
              switch delta["type"] as? String {
              case "text_delta":
                let text = delta["text"] as? String ?? ""
                block["text"] = (block["text"] as? String ?? "") + text
                continuation.yield(.text(text))
              case "thinking_delta":
                block["thinking"] = (block["thinking"] as? String ?? "") + (delta["thinking"] as? String ?? "")
              case "signature_delta":
                block["signature"] = delta["signature"] as? String ?? ""
              default:
                break
              }
              blocks[index] = block
            case "message_delta":
              if let delta = event["delta"] as? JSONObject, let reason = delta["stop_reason"] as? String {
                stopReason = reason
              }
            case "error":
              let error = event["error"] as? JSONObject
              throw ClaudeError.stream(type: error?["type"] as? String, message: error?["message"] as? String)
            default:
              break
            }
          }
          if stopReason == "refusal" { throw ClaudeError.refused }
          let content = blocks.keys.sorted().compactMap { blocks[$0] }
          continuation.yield(.done(content: content, stopReason: stopReason))
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }
}
