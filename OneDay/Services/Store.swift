import SwiftUI
import Observation

enum AppTab: String, Hashable {
  case today, tasks, plans, review, me
}

enum ReviewTab: String, CaseIterable, Hashable {
  case timeline = "时间线"
  case overview = "完成概览"
}

@MainActor
@Observable
final class Store {
  static let shared = Store()

  var state: AppState
  var today = DayKey.today
  var selectedTab: AppTab = .today
  var toastMessage: String?
  var motivation: Motivation?
  var reviewDate: String?
  var reviewTab: ReviewTab = .timeline

  @ObservationIgnored private var toastTask: Task<Void, Never>?

  private init() {
    state = Persistence.load()
    PhotoStore.collectGarbage(keeping: state.referencedPhotos)
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

  // MARK: Persistence

  func save() {
    state.normalize()
    Persistence.save(state)
    NotificationManager.shared.scheduleRefresh(for: state)
  }

  func flush() { Persistence.save(state) }

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

  func toast(_ message: String) {
    toastTask?.cancel()
    toastMessage = message
    toastTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1.8))
      guard !Task.isCancelled else { return }
      self?.toastMessage = nil
    }
  }

  // MARK: Tasks

  func addTask(title: String, repeatMode: RepeatMode, day: String, reminder: Int?) {
    let t = title.trimmed
    guard !t.isEmpty else { return toast("先写下要做什么") }
    state.tasks.append(TaskItem(title: t, day: day, repeatMode: repeatMode, reminder: reminder))
    save()
    Haptics.tap()
    toast("已添加")
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
    state.tasks[i].done[day] = completed ? true : nil
    save()
    if completed { Haptics.success() } else { Haptics.tap() }
    toast(completed ? "已完成，进度已更新" : "已取消完成")
    if completed && !wasAllDone && state.allDone(on: day) { celebrate(day) }
  }

  func deleteTask(_ id: String) {
    state.tasks.removeAll { $0.id == id }
    save()
    toast("已删除")
  }

  /// All of a day's tasks were just completed: show the motivation sheet once per day.
  private func celebrate(_ day: String) {
    guard !state.settings.celebratedDays.contains(day) else { return }
    state.settings.celebratedDays.append(day)
    save()
    motivation = OneDayText.motivation(for: day)
  }

  // MARK: Notes

  func addNote(text: String, photos: [String], tags: [String]) {
    let body = text.trimmed
    guard !body.isEmpty || !photos.isEmpty else { return toast("写一点内容，或者留下一张照片") }
    state.notes[today, default: []].append(
      NoteEntry(text: body, time: DayKey.clock(), photos: Array(photos.prefix(6)), tags: tags)
    )
    save()
    Haptics.success()
    toast("已经留下来了")
  }

  @discardableResult
  func updateNote(day: String, id: String, text: String, tags: [String]) -> Bool {
    guard let i = state.notes[day]?.firstIndex(where: { $0.id == id }) else { return false }
    let body = text.trimmed
    if body.isEmpty && (state.notes[day]?[i].photos.isEmpty ?? true) {
      toast("记录不能是空的")
      return false
    }
    state.notes[day]?[i].text = body
    state.notes[day]?[i].tags = tags.uniqued()
    save()
    toast("记录和标签已更新")
    return true
  }

  func deleteNote(day: String, id: String) {
    guard let entry = state.notes[day]?.first(where: { $0.id == id }) else { return }
    state.notes[day]?.removeAll { $0.id == id }
    entry.photos.forEach(PhotoStore.delete)
    if state.notes[day]?.isEmpty ?? true {
      state.notes[day] = nil
      if reviewDate == day { reviewDate = nil }
    }
    save()
    toast("已删除这条记录")
  }

  func deleteNotes(on day: String) {
    state.notes[day]?.flatMap(\.photos).forEach(PhotoStore.delete)
    state.notes[day] = nil
    if reviewDate == day { reviewDate = nil }
    save()
    toast("已删除全部记录")
  }

  func deletePhoto(day: String, noteId: String, photo: String) {
    guard let i = state.notes[day]?.firstIndex(where: { $0.id == noteId }) else { return }
    state.notes[day]?[i].photos.removeAll { $0 == photo }
    PhotoStore.delete(photo)
    if let n = state.notes[day]?[i], n.text.isEmpty && n.photos.isEmpty {
      state.notes[day]?.remove(at: i)
      if state.notes[day]?.isEmpty ?? true {
        state.notes[day] = nil
        if reviewDate == day { reviewDate = nil }
      }
    }
    save()
    toast("照片已删除")
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
    state.settings.customTags.removeAll { $0 == tag }
    for (day, list) in state.notes {
      state.notes[day] = list.map { entry in
        var n = entry
        n.tags.removeAll { $0 == tag }
        return n
      }
    }
    save()
    toast("标签已删除")
  }

  // MARK: Plans

  func savePlan(id: String?, title: String, desc: String) {
    let t = title.trimmed
    guard !t.isEmpty else { return toast("计划需要一个名字") }
    if let id, let i = state.plans.firstIndex(where: { $0.id == id }) {
      state.plans[i].title = t
      state.plans[i].desc = desc.trimmed
      save()
      toast("计划已更新")
    } else {
      state.plans.append(Plan(title: t, desc: desc.trimmed))
      save()
      toast("已添加计划")
    }
  }

  func setPlanStatus(_ id: String, _ status: PlanStatus) {
    guard let i = state.plans.firstIndex(where: { $0.id == id }) else { return }
    state.plans[i].status = status
    save()
    Haptics.tap()
    toast("已更新计划状态")
  }

  func deletePlan(_ id: String) {
    state.plans.removeAll { $0.id == id }
    save()
    toast("已删除")
  }

  // MARK: Profile & appearance

  func saveProfile(name: String, signature: String, avatar: String?) {
    state.settings.name = name
    state.settings.signature = signature
    if let avatar, avatar != state.settings.avatar {
      let old = state.settings.avatar
      state.settings.avatar = avatar
      PhotoStore.delete(old)
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

  func backupDocument() -> BackupDocument {
    BackupDocument(data: Persistence.backupData(for: state))
  }

  func applyImport(_ incoming: AppState) {
    state = incoming
    resetNavigation()
    save()
    PhotoStore.collectGarbage(keeping: state.referencedPhotos)
    toast("数据已导入")
  }

  func restoreAll() {
    state = AppState()
    resetNavigation()
    save()
    PhotoStore.collectGarbage(keeping: [])
    toast("已恢复初始状态")
  }

  private func resetNavigation() {
    reviewDate = nil
    reviewTab = .timeline
    motivation = nil
  }

  #if DEBUG
  /// `-OneDayDemo YES` seeds sample data and `-OneDayTab tasks` picks a tab (used for CI screenshots).
  private func applyLaunchArguments() {
    let defaults = UserDefaults.standard
    if defaults.bool(forKey: "OneDayDemo") {
      var s = AppState()
      let t = DayKey.today
      let y = DayKey.add(days: -1, to: t)
      var read = TaskItem(title: "阅读 20 分钟", day: y, repeatMode: .daily, reminder: 21 * 60)
      read.done = [y: true, t: true]
      var walk = TaskItem(title: "散步 30 分钟", day: y, repeatMode: .daily, reminder: nil)
      walk.done = [y: true]
      s.tasks = [read, walk, TaskItem(title: "整理房间", day: t, repeatMode: .once, reminder: nil)]
      s.plans = [Plan(title: "成为更强大的人", desc: "每周运动三次，持续读书。"), Plan(title: "学会游泳", desc: "")]
      s.notes[y] = [NoteEntry(text: "傍晚的风很舒服，绕着湖走了一圈。", time: "19:20", photos: [], tags: ["日常", "心情"])]
      s.notes[t] = [NoteEntry(text: "今天把拖了很久的事情做完了。", time: "10:05", photos: [], tags: ["灵感"])]
      if let style = defaults.string(forKey: "OneDayStyle"), let v = VisualStyle(rawValue: style) { s.settings.cardStyle = v }
      if let tone = defaults.string(forKey: "OneDayTone"), let v = BgTone(rawValue: tone) { s.settings.bgTone = v }
      state = s
    }
    if let tab = defaults.string(forKey: "OneDayTab"), let target = AppTab(rawValue: tab) {
      selectedTab = target
    }
  }
  #endif
}
