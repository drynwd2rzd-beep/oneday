import Foundation
import UIKit

enum AppFiles {
  static let root: URL = {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("OneDay", isDirectory: true)
    try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    return base
  }()
}

enum Persistence {
  static let url = AppFiles.root.appendingPathComponent("state.json")

  static func load() -> AppState {
    guard let data = try? Data(contentsOf: url) else { return AppState() }
    do {
      var state = try JSONDecoder().decode(AppState.self, from: data)
      state.normalize()
      return state
    } catch {
      // Keep the unreadable file instead of overwriting it on the next save.
      let stamp = Int(Date().timeIntervalSince1970)
      let backup = AppFiles.root.appendingPathComponent("state-unreadable-\(stamp).json")
      try? FileManager.default.moveItem(at: url, to: backup)
      return AppState()
    }
  }

  static func save(_ state: AppState) {
    do {
      let data = try JSONEncoder().encode(state)
      try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    } catch {
      print("OneDay save failed: \(error)")
    }
  }

  /// Encodes a backup in the web version's format: photos and avatar become `data:` URLs.
  static func backupData(for state: AppState) -> Data {
    var copy = state
    copy.settings.avatar = copy.settings.avatar.isEmpty ? "" : (PhotoStore.dataURL(copy.settings.avatar) ?? "")
    for (day, list) in copy.notes {
      copy.notes[day] = list.map { entry in
        var n = entry
        n.photos = n.photos.compactMap(PhotoStore.dataURL)
        return n
      }
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return (try? encoder.encode(copy)) ?? Data()
  }

  enum ImportError: Error { case unreadable }

  /// Decodes a backup and moves embedded photos into `PhotoStore`. Safe to run off the main thread.
  static func parseBackup(_ data: Data) throws -> AppState {
    guard
      let object = try? JSONSerialization.jsonObject(with: data),
      object is [String: Any],
      var state = try? JSONDecoder().decode(AppState.self, from: data)
    else { throw ImportError.unreadable }
    state.settings.avatar = PhotoStore.ingest(state.settings.avatar) ?? ""
    for (day, list) in state.notes {
      state.notes[day] = list.map { entry in
        var n = entry
        n.photos = n.photos.compactMap(PhotoStore.ingest)
        return n
      }
    }
    state.normalize()
    return state
  }
}

enum PhotoStore {
  static let directory: URL = {
    let dir = AppFiles.root.appendingPathComponent("Photos", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }()

  private static let cache: NSCache<NSString, UIImage> = {
    let c = NSCache<NSString, UIImage>()
    c.countLimit = 80
    return c
  }()

  static func url(_ name: String) -> URL { directory.appendingPathComponent(name) }

  static func exists(_ name: String) -> Bool {
    !name.isEmpty && !name.contains("/") && FileManager.default.fileExists(atPath: url(name).path)
  }

  /// Resizes to at most `maxDimension` (1280 like the web version) and stores a JPEG.
  static func save(data: Data, maxDimension: CGFloat = 1280) -> String? {
    guard let image = UIImage(data: data) else { return nil }
    return save(image: image, maxDimension: maxDimension)
  }

  static func save(image: UIImage, maxDimension: CGFloat = 1280) -> String? {
    let resized = resize(image, maxDimension: maxDimension)
    guard let jpeg = resized.jpegData(compressionQuality: 0.82) else { return nil }
    let name = UUID().uuidString + ".jpg"
    do {
      try jpeg.write(to: url(name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    } catch {
      return nil
    }
    cache.setObject(resized, forKey: name as NSString)
    return name
  }

  static func image(_ name: String) -> UIImage? {
    guard !name.isEmpty else { return nil }
    if let cached = cache.object(forKey: name as NSString) { return cached }
    let image: UIImage?
    if name.hasPrefix("data:") {
      image = decodeDataURL(name).flatMap(UIImage.init(data:))
    } else if exists(name) {
      image = UIImage(contentsOfFile: url(name).path)
    } else {
      image = nil
    }
    if let image { cache.setObject(image, forKey: name as NSString) }
    return image
  }

  static func dataURL(_ name: String) -> String? {
    if name.hasPrefix("data:image/") { return name }
    guard exists(name), let data = try? Data(contentsOf: url(name)) else { return nil }
    return "data:image/jpeg;base64," + data.base64EncodedString()
  }

  /// Accepts a `data:image/...` URL or an existing file name and returns a stored file name.
  static func ingest(_ value: String) -> String? {
    if value.hasPrefix("data:image/") {
      guard let data = decodeDataURL(value) else { return nil }
      return save(data: data)
    }
    return exists(value) ? value : nil
  }

  static func delete(_ name: String) {
    guard exists(name) else { return }
    cache.removeObject(forKey: name as NSString)
    try? FileManager.default.removeItem(at: url(name))
  }

  static func collectGarbage(keeping names: Set<String>) {
    let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    for file in files where !names.contains(file) {
      try? FileManager.default.removeItem(at: url(file))
    }
  }

  private static func decodeDataURL(_ value: String) -> Data? {
    guard let comma = value.firstIndex(of: ",") else { return nil }
    return Data(base64Encoded: String(value[value.index(after: comma)...]), options: .ignoreUnknownCharacters)
  }

  private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
    let size = image.size
    let longest = max(size.width, size.height)
    guard longest > 0 else { return image }
    let scale = longest > maxDimension ? maxDimension / longest : 1
    let target = CGSize(width: max(1, (size.width * scale).rounded()), height: max(1, (size.height * scale).rounded()))
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: target, format: format).image { ctx in
      UIColor.white.setFill()
      ctx.fill(CGRect(origin: .zero, size: target))
      image.draw(in: CGRect(origin: .zero, size: target))
    }
  }
}
