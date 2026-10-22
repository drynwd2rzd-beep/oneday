import Foundation

enum AppFiles {
  static let root: URL = {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("OneDay", isDirectory: true)
    try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    return base
  }()

  /// Visible in the Files app under "我的 iPhone › 一天".
  static let documents: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
}

/// Owns the database: loads it at launch, migrates the 1.0 `state.json` once,
/// and writes only changed rows on a background queue.
final class Storage: @unchecked Sendable {
  static let shared = Storage(directory: AppFiles.root)

  let directory: URL
  private let queue = DispatchQueue(label: "oneday.storage", qos: .utility)
  private var database: Database?
  /// Last state handed to the database; only touched from the caller's (main) thread.
  private var lastSaved: AppState?
  private(set) var lastError: String?

  var databaseURL: URL { directory.appendingPathComponent("oneday.sqlite") }
  var legacyURL: URL { directory.appendingPathComponent("state.json") }

  init(directory: URL) {
    self.directory = directory
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  func load() -> AppState {
    do {
      let db = try Database(url: databaseURL)
      database = db
      protectFiles()
      if let loaded = try db.load() {
        var state = loaded
        state.normalize()
        // Write back what normalizing migrated (e.g. 1.2's daily reflections becoming notes),
        // so the database never resurrects the old rows.
        if !loaded.dayReflections.isEmpty {
          try? db.apply(Database.diff(from: loaded, to: state))
        }
        lastSaved = state
        return state
      }
    } catch {
      lastError = "\(error)"
    }
    return migrateLegacy()
  }

  /// Persists the difference from the last save. Cheap when little changed.
  func save(_ state: AppState) {
    guard let database else {
      writeLegacy(state)
      return
    }
    let changes = Database.diff(from: lastSaved, to: state)
    guard !changes.isEmpty else { return }
    lastSaved = state
    queue.async {
      do {
        try database.apply(changes)
      } catch {
        let message = "\(error)"
        // Force a full rewrite on the next save.
        DispatchQueue.main.async {
          self.lastError = message
          self.lastSaved = nil
        }
      }
    }
  }

  /// Blocks until pending writes finish (used when the app goes to the background).
  func flush() {
    queue.sync { database?.checkpoint() }
  }

  /// Copies the database to `url` as a consistent snapshot.
  func snapshot(to url: URL) throws {
    try queue.sync {
      database?.checkpoint()
      try? FileManager.default.removeItem(at: url)
      try FileManager.default.copyItem(at: databaseURL, to: url)
    }
  }

  private func migrateLegacy() -> AppState {
    guard let data = try? Data(contentsOf: legacyURL) else { return AppState() }
    guard var state = try? JSONDecoder().decode(AppState.self, from: data) else {
      let stamp = Int(Date().timeIntervalSince1970)
      try? FileManager.default.moveItem(at: legacyURL, to: directory.appendingPathComponent("state-unreadable-\(stamp).json"))
      return AppState()
    }
    state.normalize()
    if let database {
      do {
        try database.apply(Database.diff(from: nil, to: state))
        lastSaved = state
        try? FileManager.default.moveItem(at: legacyURL, to: directory.appendingPathComponent("state.migrated.json"))
      } catch {
        lastError = "\(error)"
      }
    }
    return state
  }

  /// Fallback when SQLite cannot be opened, so data is never silently dropped.
  private func writeLegacy(_ state: AppState) {
    guard let data = try? JSONEncoder().encode(state) else { return }
    try? data.write(to: legacyURL, options: .atomic)
  }

  private func protectFiles() {
    #if os(iOS)
    for suffix in ["", "-wal", "-shm"] {
      let path = databaseURL.path + suffix
      try? FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: path)
    }
    #endif
  }
}
