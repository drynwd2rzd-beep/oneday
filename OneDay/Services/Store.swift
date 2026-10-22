import SwiftUI
import Observation

enum AppTab: String, Hashable {
  case today, tasks, plans, review, me
}

enum ReviewTab: String, CaseIterable, Hashable {
  case timeline = "时间线"
  case overview = "完成概览"
}

/// Everything a new note can carry; built by the quick-capture card.
struct NoteDraft: Identifiable {
  let id = UUID()
  var text = ""
  var photos: [String] = []
  var media: [MediaItem] = []
  var place: String?
  var latitude: Double?
  var longitude: Double?
  var weather: String?

  var isEmpty: Bool { text.trimmed.isEmpty && photos.isEmpty && media.isEmpty }
}

/// A state to return to with 撤销 (toast button or shaking the phone).
struct UndoEntry: Identifiable {
  let id = UUID()
  let label: String
  let state: AppState
}

@MainActor
@Observable
final class Store {
  static let shared = Store()

  var state: AppState
  var today = DayKey.today
  var selectedTab: AppTab = .today
  var toastMessage: String?
  /// Label of the action the visible toast can undo.
  var toastUndoLabel: String?
  var motivation: Motivation?
  var reviewDate: String?
  var reviewTab: ReviewTab = .timeline
  var undoPrompt: UndoEntry?

  @ObservationIgnored private var undoStack: [UndoEntry] = []
  @ObservationIgnored private var toastTask: Task<Void, Never>?

  private init() {
    state = Storage.shared.load()
    MediaStore.collectGarbage(keeping: state.referencedPhotos)
    #if DEBUG
    applyLaunchArguments()
    #endif
  }

  // MARK: Derived

  var settings: Settings { state.settings }

  var accentColor: Color { Color(hex: state.settings.accent) }

  var preferredColorScheme: ColorScheme? {
    if state.settings.bgTone == .meteor { return .dark }
    switch state.settings.theme {
    case .light: return .light
    case .dark: return .dark
    case .system: return nil
    }
  }

  var hasAnyData: Bool { !state.tasks.isEmpty || !state.notes.isEmpty || !state.plans.isEmpty }

  // MARK: Persistence

  func save() {
    state.normalize()
    Storage.shared.save(state)
    NotificationManager.shared.scheduleRefresh(for: state)
  }

  func flush() {
    Storage.shared.save(state)
    Storage.shared.flush()
  }

  func sceneDidBecomeActive() {
    refreshDay()
    Task {
      await NotificationManager.shared.refreshStatus()
      NotificationManager.shared.scheduleRefresh(for: state)
    }
  }

  func refreshDay() {
    let now = DayKey.today
    if now != today { today = now }
  }

  // MARK: Feedback

  func toast(_ message: String, undoable: String? = nil) {
    toastTask?.cancel()
    toastMessage = message
    toastUndoLabel = undoable
    let seconds: Double = undoable == nil ? 1.8 : 4
    toastTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(seconds))
      guard !Task.isCancelled else { return }
      self?.toastMessage = nil
      self?.toastUndoLabel = nil
    }
  }

  // MARK: Undo

  var canUndo: Bool { !undoStack.isEmpty }

  /// Remembers the current state before a change the user may want to take back.
  private func checkpoint(_ label: String) {
    undoStack.append(UndoEntry(label: label, state: state))
    if undoStack.count > 20 { undoStack.removeFirst() }
  }

  func undo() {
    guard let entry = undoStack.popLast() else { return }
    state = entry.state
    if let day = reviewDate, !state.hasNotes(on: day), state.tasks(on: day).isEmpty { reviewDate = nil }
    save()
    Haptics.success()
    toast("已撤销「\(entry.label)」")
  }

  /// Shake gesture: ask before undoing, like system apps.
  func promptUndo() {
    guard let last = undoStack.last else { return }
    Haptics.warning()
    undoPrompt = last
  }

  // MARK: Tasks

  func addTask(title: String, repeatMode: RepeatMode, day: String, reminder: Int?, planId: String? = nil) {
    let t = title.trimmed
    guard !t.isEmpty else { return toast("先写下要做什么") }
    checkpoint("添加事项")
    state.tasks.append(TaskItem(title: t, day: day, repeatMode: repeatMode, reminder: reminder, planId: planId))
    save()
    Haptics.tap()
    toast("已添加")
  }

  func setPlan(_ planId: String?, for taskId: String) {
    guard let i = state.tasks.firstIndex(where: { $0.id == taskId }) else { return }
    checkpoint("更改所属计划")
    state.tasks[i].planId = planId
    save()
    toast(planId.flatMap { state.plan($0)?.title }.map { "已归入「\($0)」" } ?? "已移出计划", undoable: "更改所属计划")
  }

  func setReminder(_ minutes: Int?, for id: String) {
    guard let i = state.tasks.firstIndex(where: { $0.id == id }) else { return }
    state.tasks[i].reminder = minutes
    save()
    toast(minutes == nil ? "已关闭提醒" : "将在 \(DayKey.clock(minutes: minutes ?? 0)) 提醒")
  }

  func toggleTask(_ id: String, on day: String) {
    guard let i = state.tasks.firstIndex(where: { $0.id == id }) else { return }
    let wasAllDone = state.allDone(on: day)
    let completed = !state.tasks[i].isDone(on: day)
    checkpoint(completed ? "完成事项" : "取消完成")
    state.tasks[i].done[day] = completed ? true : nil
    save()
    if completed { Haptics.success() } else { Haptics.tap() }
    toast(completed ? "已完成，进度已更新" : "已取消完成", undoable: completed ? "完成事项" : "取消完成")
    if completed && !wasAllDone && state.allDone(on: day) { celebrate(day) }
  }

  func deleteTask(_ id: String) {
    guard let task = state.tasks.first(where: { $0.id == id }) else { return }
    checkpoint("删除事项")
    state.tasks.removeAll { $0.id == id }
    save()
    Haptics.tap()
    toast("已删除「\(task.title)」", undoable: "删除事项")
  }

  /// All of a day's tasks were just completed: show the motivation sheet once per day.
  private func celebrate(_ day: String) {
    guard !state.settings.celebratedDays.contains(day) else { return }
    state.settings.celebratedDays.append(day)
    save()
    motivation = OneDayText.motivation(for: day)
  }

  // MARK: Notes
  // Removed photos and recordings stay on disk until the next launch so undo can bring them back.

  func addNote(_ draft: NoteDraft, tags: [String]) {
    guard !draft.isEmpty else { return toast("写一点内容，或者留下一张照片") }
    var note = NoteEntry(text: draft.text.trimmed, time: DayKey.clock(), photos: Array(draft.photos.prefix(6)), tags: tags)
    note.media = draft.media
    note.place = draft.place
    note.latitude = draft.latitude
    note.longitude = draft.longitude
    note.weather = draft.weather
    checkpoint("留下记录")
    state.notes[today, default: []].append(note)
    save()
    Haptics.success()
    toast("已经留下来了")
  }

  /// Saves an edited note (text, tags, photos, videos, recordings and place).
  @discardableResult
  func updateNote(day: String, note edited: NoteEntry) -> Bool {
    guard let i = state.notes[day]?.firstIndex(where: { $0.id == edited.id }) else { return false }
    var note = edited
    note.text = note.text.trimmed
    note.tags = note.tags.uniqued()
    guard !note.isEmpty else {
      toast("记录不能是空的")
      return false
    }
    checkpoint("编辑记录")
    state.notes[day]?[i] = note
    save()
    toast("记录已更新", undoable: "编辑记录")
    return true
  }

  func deleteNote(day: String, id: String) {
    guard state.notes[day]?.contains(where: { $0.id == id }) == true else { return }
    checkpoint("删除记录")
    state.notes[day]?.removeAll { $0.id == id }
    dropDayIfEmpty(day)
    save()
    Haptics.tap()
    toast("已删除这条记录", undoable: "删除记录")
  }

  func deleteNotes(on day: String) {
    checkpoint("删除当天记录")
    state.notes[day] = nil
    if reviewDate == day { reviewDate = nil }
    save()
    toast("已删除全部记录", undoable: "删除当天记录")
  }

  func deletePhoto(day: String, noteId: String, photo: String) {
    removeAttachment(day: day, noteId: noteId, label: "删除照片") { $0.photos.removeAll { $0 == photo } }
  }

  func deleteMedia(day: String, noteId: String, file: String) {
    removeAttachment(day: day, noteId: noteId, label: "删除附件") { $0.media.removeAll { $0.file == file } }
  }

  private func removeAttachment(day: String, noteId: String, label: String, _ change: (inout NoteEntry) -> Void) {
    guard let i = state.notes[day]?.firstIndex(where: { $0.id == noteId }) else { return }
    checkpoint(label)
    if var note = state.notes[day]?[i] {
      change(&note)
      if note.isEmpty {
        state.notes[day]?.remove(at: i)
      } else {
        state.notes[day]?[i] = note
      }
    }
    dropDayIfEmpty(day)
    save()
    toast("已\(label)", undoable: label)
  }

  private func dropDayIfEmpty(_ day: String) {
    if state.notes[day]?.isEmpty ?? true {
      state.notes[day] = nil
      if reviewDate == day { reviewDate = nil }
    }
  }

  // MARK: Tags

  /// Returns the cleaned tag, registering it as a custom tag when new.
  @discardableResult
  func addCustomTag(_ raw: String) -> String? {
    let tag = String(raw.trimmed.prefix(12))
    guard !tag.isEmpty else { return nil }
    if !state.allTags.contains(tag) { state.settings.customTags.append(tag) }
    save()
    return tag
  }

  func deleteCustomTag(_ tag: String) {
    guard state.isCustomTag(tag) else { return }
    checkpoint("删除标签")
    state.settings.customTags.removeAll { $0 == tag }
    for (day, list) in state.notes {
      state.notes[day] = list.map { entry in
        var n = entry
        n.tags.removeAll { $0 == tag }
        return n
      }
    }
    save()
    toast("标签已删除", undoable: "删除标签")
  }

  // MARK: Plans

  /// Creates or updates a plan and sets which tasks belong to it.
  func savePlan(id: String?, title: String, desc: String, color: String?, icon: String?, linkedTasks: Set<String>) {
    let t = title.trimmed
    guard !t.isEmpty else { return toast("计划需要一个名字") }
    checkpoint(id == nil ? "添加计划" : "编辑计划")
    let planId: String
    if let id, let i = state.plans.firstIndex(where: { $0.id == id }) {
      state.plans[i].title = t
      state.plans[i].desc = desc.trimmed
      state.plans[i].color = color
      state.plans[i].icon = icon
      planId = id
    } else {
      var plan = Plan(title: t, desc: desc.trimmed)
      plan.color = color
      plan.icon = icon
      state.plans.append(plan)
      planId = plan.id
    }
    for i in state.tasks.indices {
      if linkedTasks.contains(state.tasks[i].id) {
        state.tasks[i].planId = planId
      } else if state.tasks[i].planId == planId {
        state.tasks[i].planId = nil
      }
    }
    save()
    toast(id == nil ? "已添加计划" : "计划已更新", undoable: id == nil ? nil : "编辑计划")
  }

  func setPlanStatus(_ id: String, _ status: PlanStatus) {
    guard let i = state.plans.firstIndex(where: { $0.id == id }) else { return }
    checkpoint("更新计划状态")
    state.plans[i].status = status
    state.plans[i].doneAt = status == .done ? today : nil
    if status != .active { state.plans[i].pinned = false }
    save()
    if status == .done { Haptics.success() } else { Haptics.tap() }
    toast("计划已标记为「\(status.label)」", undoable: "更新计划状态")
  }

  func togglePin(_ id: String) {
    guard let i = state.plans.firstIndex(where: { $0.id == id }) else { return }
    state.plans[i].pinned.toggle()
    save()
    Haptics.tap()
    toast(state.plans[i].pinned ? "已置顶" : "已取消置顶")
  }

  /// Reorders active plans to `ids`; other plans keep their positions after them.
  func reorderActivePlans(_ ids: [String]) {
    let byId = Dictionary(uniqueKeysWithValues: state.plans.map { ($0.id, $0) })
    let ordered = ids.compactMap { byId[$0] }
    let rest = state.plans.filter { !ids.contains($0.id) }
    state.plans = ordered + rest
    save()
  }

  func deletePlan(_ id: String) {
    guard let plan = state.plans.first(where: { $0.id == id }) else { return }
    checkpoint("删除计划")
    state.plans.removeAll { $0.id == id }
    save()
    Haptics.tap()
    toast("已删除「\(plan.title)」，相关事项保留", undoable: "删除计划")
  }

  // MARK: Profile & appearance

  func saveProfile(name: String, signature: String, avatar: String?) {
    state.settings.name = name
    state.settings.signature = signature
    if let avatar, avatar != state.settings.avatar {
      let old = state.settings.avatar
      state.settings.avatar = avatar
      MediaStore.delete(old)
    }
    save()
    toast("个人资料已保存")
  }

  func saveTheme(mode: ThemeMode, accent: String, customAccent: String?) {
    state.settings.theme = mode
    state.settings.accent = accent
    state.settings.customAccent = customAccent
    save()
    toast("主题已保存")
  }

  func setUISize(_ size: UISize) {
    state.settings.uiSize = size
    save()
  }

  func setVisualStyle(_ style: VisualStyle) {
    state.settings.cardStyle = style
    save()
  }

  func setBgTone(_ tone: BgTone) {
    state.settings.bgTone = tone
    save()
  }

  // MARK: Home modules

  func setHomeModule(_ module: HomeModule, visible: Bool) {
    var order = state.settings.homeModules
    if visible {
      if !order.contains(module) { order.append(module) }
    } else {
      order.removeAll { $0 == module }
    }
    state.settings.homeModules = order
    save()
  }

  func moveHomeModules(from source: IndexSet, to destination: Int) {
    state.settings.homeModules.move(fromOffsets: source, toOffset: destination)
    save()
  }

  func resetHomeModules() {
    state.settings.homeModules = HomeModule.defaultOrder
    save()
    toast("已恢复首页默认布局")
  }

  // MARK: Notifications

  func updateNotifications(_ change: (inout NotificationPrefs) -> Void) {
    change(&state.settings.notifications)
    save()
  }

  /// Turns notifications on, asking for permission first. Returns whether they are enabled.
  @discardableResult
  func enableNotifications() async -> Bool {
    let granted = await NotificationManager.shared.requestAuthorization()
    updateNotifications { $0.enabled = granted }
    if !granted { toast("请在系统设置中允许「一天」发送通知") }
    return granted
  }

  func handleNotification(action: String, tab: String?, taskId: String?, day: String?) {
    if action == NotificationManager.doneAction, let taskId, let day {
      if let i = state.tasks.firstIndex(where: { $0.id == taskId }), !state.tasks[i].isDone(on: day) {
        state.tasks[i].done[day] = true
        save()
      }
      return
    }
    if action == NotificationManager.snoozeAction { return }
    if let tab, let target = AppTab(rawValue: tab) { selectedTab = target }
  }

  // MARK: Data

  func webBackupDocument() -> BackupDocument {
    BackupDocument(data: Persistence.backupData(for: state))
  }

  func applyImport(_ incoming: AppState) {
    checkpoint("导入数据")
    state = incoming
    resetNavigation()
    save()
    toast("数据已导入", undoable: "导入数据")
  }

  func restoreAll() {
    undoStack.removeAll()
    state = AppState()
    resetNavigation()
    save()
    MediaStore.collectGarbage(keeping: [])
    toast("已恢复初始状态")
  }

  private func resetNavigation() {
    reviewDate = nil
    reviewTab = .timeline
    motivation = nil
  }

  #if DEBUG
  /// Launch arguments used for CI screenshots, e.g. `-OneDayDemo YES -OneDayTab tasks`.
  private func applyLaunchArguments() {
    let defaults = UserDefaults.standard
    if defaults.bool(forKey: "OneDayDemo") {
      state = DemoData.make()
      if let style = defaults.string(forKey: "OneDayStyle"), let v = VisualStyle(rawValue: style) { state.settings.cardStyle = v }
      if let tone = defaults.string(forKey: "OneDayTone"), let v = BgTone(rawValue: tone) { state.settings.bgTone = v }
    }
    if let tab = defaults.string(forKey: "OneDayTab"), let target = AppTab(rawValue: tab) {
      selectedTab = target
    }
    if defaults.string(forKey: "OneDayReview") == "overview" { reviewTab = .overview }
    if defaults.string(forKey: "OneDayReview") == "day" { reviewDate = DayKey.add(days: -1, to: today) }
  }
  #endif
}

#if DEBUG
enum DemoData {
  static func make() -> AppState {
    var s = AppState()
    let t = DayKey.today
    let y = DayKey.add(days: -1, to: t)
    var read = TaskItem(title: "阅读 20 分钟", day: DayKey.add(days: -120, to: t), repeatMode: .daily, reminder: 21 * 60)
    var walk = TaskItem(title: "散步 30 分钟", day: DayKey.add(days: -120, to: t), repeatMode: .daily, reminder: nil)
    var water = TaskItem(title: "喝 8 杯水", day: DayKey.add(days: -60, to: t), repeatMode: .daily, reminder: nil)
    for k in 1...120 {
      let day = DayKey.add(days: -k, to: t)
      if k % 7 != 3 { read.done[day] = true }
      if k % 3 != 0 { walk.done[day] = true }
      if k <= 60 && k % 5 != 0 { water.done[day] = true }
    }
    read.done[t] = true
    s.tasks = [read, walk, water, TaskItem(title: "整理房间", day: t, repeatMode: .once, reminder: nil)]
    var strong = Plan(title: "成为更强大的人", desc: "每周运动三次，持续读书。")
    strong.color = "#287052"
    strong.icon = "figure.run"
    strong.pinned = true
    var swim = Plan(title: "学会游泳", desc: "报班，先学会换气。")
    swim.color = "#386b98"
    swim.icon = "leaf"
    var guitar = Plan(title: "学吉他", desc: "")
    guitar.icon = "music.note"
    guitar.color = "#d77b48"
    guitar.status = .paused
    var marathon = Plan(title: "跑完半程马拉松", desc: "")
    marathon.status = .done
    marathon.doneAt = DayKey.add(days: -30, to: t)
    s.plans = [strong, swim, guitar, marathon]
    s.tasks[0].planId = strong.id
    s.tasks[1].planId = strong.id
    var lake = NoteEntry(text: "傍晚的风很舒服，绕着湖走了**一圈**。", time: "19:20", photos: [], tags: ["日常", "心情"])
    lake.place = "杭州市 · 西湖区"
    lake.weather = "晴 23°"
    lake.media = [MediaItem(kind: .audio, file: "demo.m4a", duration: 42)]
    lake.photos = [demoPhoto()].compactMap { $0 }
    s.notes[y] = [lake]
    s.notes[t] = [NoteEntry(text: "今天把拖了很久的事情做完了。", time: "10:05", photos: [], tags: ["灵感"])]
    let lastYear = DayKey.of(DayKey.calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date())
    s.notes[lastYear] = [NoteEntry(text: "第一次用 OneDay 记录。希望一年后的自己，过得更从容。", time: "22:10", photos: [], tags: ["心情"])]
    for k in stride(from: 3, through: 100, by: 4) {
      s.notes[DayKey.add(days: -k, to: t)] = [NoteEntry(text: "普通但认真的一天。", time: "21:00", photos: [], tags: ["日常"])]
    }
    s.normalize()
    return s
  }

  /// A soft dusk-over-water picture so screenshots show photo-first cards.
  private static func demoPhoto() -> String? {
    let size = CGSize(width: 1200, height: 800)
    let image = UIGraphicsImageRenderer(size: size).image { ctx in
      let colors = [UIColor(red: 0.98, green: 0.80, blue: 0.62, alpha: 1), UIColor(red: 0.62, green: 0.70, blue: 0.86, alpha: 1)]
      let gradient = CGGradient(colorsSpace: nil, colors: colors.map(\.cgColor) as CFArray, locations: [0, 1])!
      ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height * 0.62), options: [])
      UIColor(red: 0.98, green: 0.88, blue: 0.70, alpha: 1).setFill()
      ctx.cgContext.fillEllipse(in: CGRect(x: 760, y: 300, width: 170, height: 170))
      UIColor(red: 0.36, green: 0.47, blue: 0.62, alpha: 1).setFill()
      ctx.fill(CGRect(x: 0, y: size.height * 0.6, width: size.width, height: size.height * 0.4))
      UIColor(white: 1, alpha: 0.35).setFill()
      for i in 0..<6 {
        ctx.fill(CGRect(x: 640 + i * 18, y: 520 + i * 22, width: 240 - i * 30, height: 4))
      }
    }
    return MediaStore.save(image: image)
  }
}
#endif
