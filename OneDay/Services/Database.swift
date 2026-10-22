import Foundation
import SQLite3

/// SQLite storage. Each task, note and plan is one row holding its JSON, so a change
/// writes only the rows that changed instead of rewriting all data.
final class Database {
  enum DBError: Error, CustomStringConvertible {
    case sqlite(String)
    var description: String {
      switch self {
      case .sqlite(let message): "SQLite: \(message)"
      }
    }
  }

  static let schemaVersion = 1
  private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

  private var handle: OpaquePointer?
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(url: URL) throws {
    guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
      let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
      sqlite3_close(handle)
      throw DBError.sqlite(message)
    }
    try exec("PRAGMA journal_mode=WAL")
    try exec("PRAGMA synchronous=NORMAL")
    try exec("""
      CREATE TABLE IF NOT EXISTS tasks (id TEXT PRIMARY KEY, sort INTEGER NOT NULL, json TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS plans (id TEXT PRIMARY KEY, sort INTEGER NOT NULL, json TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS notes (id TEXT PRIMARY KEY, day TEXT NOT NULL, sort INTEGER NOT NULL, json TEXT NOT NULL);
      CREATE INDEX IF NOT EXISTS notes_day ON notes(day);
      CREATE TABLE IF NOT EXISTS reflections (id TEXT PRIMARY KEY, json TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
      """)
    try setMeta("schema", String(Self.schemaVersion))
  }

  deinit { sqlite3_close(handle) }

  // MARK: Reading

  /// The stored state, or nil when the database has never been written.
  func load() throws -> AppState? {
    guard let settingsJSON = try meta("settings") else { return nil }
    var state = AppState()
    state.settings = (try? decoder.decode(Settings.self, from: Data(settingsJSON.utf8))) ?? Settings()
    try query("SELECT json FROM tasks ORDER BY sort") { stmt in
      if let task = try? decoder.decode(TaskItem.self, from: column(stmt, 0)) { state.tasks.append(task) }
    }
    try query("SELECT json FROM plans ORDER BY sort") { stmt in
      if let plan = try? decoder.decode(Plan.self, from: column(stmt, 0)) { state.plans.append(plan) }
    }
    try query("SELECT day, json FROM notes ORDER BY day, sort") { stmt in
      let day = String(cString: sqlite3_column_text(stmt, 0))
      if let note = try? decoder.decode(NoteEntry.self, from: column(stmt, 1)) {
        state.notes[day, default: []].append(note)
      }
    }
    // Ids are "d:<day>" for daily and "w:<monday>" for weekly reflections.
    try query("SELECT id, json FROM reflections") { stmt in
      let id = String(cString: sqlite3_column_text(stmt, 0))
      let key = String(id.dropFirst(2))
      if id.hasPrefix("d:"), let r = try? decoder.decode(DayReflection.self, from: column(stmt, 1)) {
        state.dayReflections[key] = r
      } else if id.hasPrefix("w:"), let r = try? decoder.decode(WeekReflection.self, from: column(stmt, 1)) {
        state.weekReflections[key] = r
      }
    }
    return state
  }

  func count(_ table: String) throws -> Int {
    var n = 0
    try query("SELECT COUNT(*) FROM \(table)") { n = Int(sqlite3_column_int64($0, 0)) }
    return n
  }

  // MARK: Writing

  /// Rows that differ between two states. `old == nil` rewrites everything.
  struct Changes {
    var replaceAll = false
    var tasks: [(sort: Int, item: TaskItem)] = []
    var deletedTasks: [String] = []
    var plans: [(sort: Int, item: Plan)] = []
    var deletedPlans: [String] = []
    var notes: [(day: String, sort: Int, item: NoteEntry)] = []
    var deletedNotes: [String] = []
    var dayReflections: [(day: String, item: DayReflection)] = []
    var weekReflections: [(week: String, item: WeekReflection)] = []
    var deletedReflections: [String] = []
    var settings: Settings?

    var isEmpty: Bool {
      !replaceAll && tasks.isEmpty && deletedTasks.isEmpty && plans.isEmpty && deletedPlans.isEmpty
        && notes.isEmpty && deletedNotes.isEmpty && reflectionCount == 0 && settings == nil
    }

    var rowCount: Int {
      tasks.count + deletedTasks.count + plans.count + deletedPlans.count + notes.count + deletedNotes.count
        + reflectionCount
    }

    private var reflectionCount: Int { dayReflections.count + weekReflections.count + deletedReflections.count }
  }

  static func diff(from old: AppState?, to new: AppState) -> Changes {
    var changes = Changes()
    guard let old else {
      changes.replaceAll = true
      changes.tasks = new.tasks.enumerated().map { ($0.offset, $0.element) }
      changes.plans = new.plans.enumerated().map { ($0.offset, $0.element) }
      for (day, list) in new.notes {
        for (i, note) in list.enumerated() { changes.notes.append((day, i, note)) }
      }
      changes.dayReflections = new.dayReflections.map { ($0.key, $0.value) }
      changes.weekReflections = new.weekReflections.map { ($0.key, $0.value) }
      changes.settings = new.settings
      return changes
    }

    let oldTasks = Dictionary(old.tasks.enumerated().map { ($0.element.id, ($0.offset, $0.element)) }, uniquingKeysWith: { a, _ in a })
    for (i, task) in new.tasks.enumerated() {
      if let prev = oldTasks[task.id], prev.0 == i, prev.1 == task { continue }
      changes.tasks.append((i, task))
    }
    let newTaskIds = Set(new.tasks.map(\.id))
    changes.deletedTasks = old.tasks.map(\.id).filter { !newTaskIds.contains($0) }

    let oldPlans = Dictionary(old.plans.enumerated().map { ($0.element.id, ($0.offset, $0.element)) }, uniquingKeysWith: { a, _ in a })
    for (i, plan) in new.plans.enumerated() {
      if let prev = oldPlans[plan.id], prev.0 == i, prev.1 == plan { continue }
      changes.plans.append((i, plan))
    }
    let newPlanIds = Set(new.plans.map(\.id))
    changes.deletedPlans = old.plans.map(\.id).filter { !newPlanIds.contains($0) }

    var oldNotes: [String: (String, Int, NoteEntry)] = [:]
    for (day, list) in old.notes {
      for (i, note) in list.enumerated() { oldNotes[note.id] = (day, i, note) }
    }
    var newNoteIds = Set<String>()
    for (day, list) in new.notes {
      for (i, note) in list.enumerated() {
        newNoteIds.insert(note.id)
        if let prev = oldNotes[note.id], prev.0 == day, prev.1 == i, prev.2 == note { continue }
        changes.notes.append((day, i, note))
      }
    }
    changes.deletedNotes = oldNotes.keys.filter { !newNoteIds.contains($0) }

    changes.dayReflections = new.dayReflections.filter { old.dayReflections[$0.key] != $0.value }.map { ($0.key, $0.value) }
    changes.weekReflections = new.weekReflections.filter { old.weekReflections[$0.key] != $0.value }.map { ($0.key, $0.value) }
    changes.deletedReflections = old.dayReflections.keys.filter { new.dayReflections[$0] == nil }.map { "d:" + $0 }
      + old.weekReflections.keys.filter { new.weekReflections[$0] == nil }.map { "w:" + $0 }

    if old.settings != new.settings { changes.settings = new.settings }
    return changes
  }

  func apply(_ changes: Changes) throws {
    guard !changes.isEmpty else { return }
    try exec("BEGIN IMMEDIATE")
    do {
      if changes.replaceAll {
        try exec("DELETE FROM tasks; DELETE FROM plans; DELETE FROM notes; DELETE FROM reflections;")
      }
      try withStatement("DELETE FROM tasks WHERE id = ?") { stmt in
        for id in changes.deletedTasks { try run(stmt, [id]) }
      }
      try withStatement("DELETE FROM plans WHERE id = ?") { stmt in
        for id in changes.deletedPlans { try run(stmt, [id]) }
      }
      try withStatement("DELETE FROM notes WHERE id = ?") { stmt in
        for id in changes.deletedNotes { try run(stmt, [id]) }
      }
      try withStatement("INSERT OR REPLACE INTO tasks (id, sort, json) VALUES (?, ?, ?)") { stmt in
        for (sort, task) in changes.tasks { try run(stmt, [task.id, sort, try json(task)]) }
      }
      try withStatement("INSERT OR REPLACE INTO plans (id, sort, json) VALUES (?, ?, ?)") { stmt in
        for (sort, plan) in changes.plans { try run(stmt, [plan.id, sort, try json(plan)]) }
      }
      try withStatement("INSERT OR REPLACE INTO notes (id, day, sort, json) VALUES (?, ?, ?, ?)") { stmt in
        for (day, sort, note) in changes.notes { try run(stmt, [note.id, day, sort, try json(note)]) }
      }
      try withStatement("DELETE FROM reflections WHERE id = ?") { stmt in
        for id in changes.deletedReflections { try run(stmt, [id]) }
      }
      try withStatement("INSERT OR REPLACE INTO reflections (id, json) VALUES (?, ?)") { stmt in
        for (day, item) in changes.dayReflections { try run(stmt, ["d:" + day, try json(item)]) }
        for (week, item) in changes.weekReflections { try run(stmt, ["w:" + week, try json(item)]) }
      }
      if let settings = changes.settings { try setMeta("settings", try json(settings)) }
      try exec("COMMIT")
    } catch {
      try? exec("ROLLBACK")
      throw error
    }
  }

  func checkpoint() {
    sqlite3_wal_checkpoint_v2(handle, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil)
  }

  // MARK: Meta

  func meta(_ key: String) throws -> String? {
    var value: String?
    try withStatement("SELECT value FROM meta WHERE key = ?") { stmt in
      try bind(stmt, [key])
      if sqlite3_step(stmt) == SQLITE_ROW { value = String(cString: sqlite3_column_text(stmt, 0)) }
    }
    return value
  }

  func setMeta(_ key: String, _ value: String) throws {
    try withStatement("INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)") { try run($0, [key, value]) }
  }

  // MARK: SQLite plumbing

  private func json<T: Encodable>(_ value: T) throws -> String {
    String(decoding: try encoder.encode(value), as: UTF8.self)
  }

  private func column(_ stmt: OpaquePointer, _ index: Int32) -> Data {
    guard let text = sqlite3_column_text(stmt, index) else { return Data() }
    return Data(String(cString: text).utf8)
  }

  private func exec(_ sql: String) throws {
    var error: UnsafeMutablePointer<CChar>?
    if sqlite3_exec(handle, sql, nil, nil, &error) != SQLITE_OK {
      let message = error.map { String(cString: $0) } ?? "exec failed"
      sqlite3_free(error)
      throw DBError.sqlite(message)
    }
  }

  private func withStatement(_ sql: String, _ body: (OpaquePointer) throws -> Void) throws {
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
      throw DBError.sqlite(String(cString: sqlite3_errmsg(handle)))
    }
    defer { sqlite3_finalize(stmt) }
    try body(stmt)
  }

  private func query(_ sql: String, row: (OpaquePointer) throws -> Void) throws {
    try withStatement(sql) { stmt in
      while true {
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_ROW { try row(stmt) } else if rc == SQLITE_DONE { break } else {
          throw DBError.sqlite(String(cString: sqlite3_errmsg(handle)))
        }
      }
    }
  }

  private func bind(_ stmt: OpaquePointer, _ values: [Any]) throws {
    sqlite3_reset(stmt)
    sqlite3_clear_bindings(stmt)
    for (i, value) in values.enumerated() {
      let index = Int32(i + 1)
      switch value {
      case let s as String: sqlite3_bind_text(stmt, index, s, -1, Self.transient)
      case let n as Int: sqlite3_bind_int64(stmt, index, Int64(n))
      default: throw DBError.sqlite("unsupported bind type")
      }
    }
  }

  private func run(_ stmt: OpaquePointer, _ values: [Any]) throws {
    try bind(stmt, values)
    guard sqlite3_step(stmt) == SQLITE_DONE else {
      throw DBError.sqlite(String(cString: sqlite3_errmsg(handle)))
    }
  }
}
