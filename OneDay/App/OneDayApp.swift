import Combine
import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // The delegate must be set before launch finishes so taps on notifications reach the app.
    NotificationManager.shared.activate()
    Diagnostics.shared.start()
    _ = AppLock.shared
    return true
  }

  // Home screen quick actions arrive through the scene delegate.
  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    configuration.delegateClass = SceneDelegate.self
    return configuration
  }
}

@MainActor
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    // Launched from a quick action while the app was not running.
    if let item = connectionOptions.shortcutItem { handle(item) }
  }

  func windowScene(
    _ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    completionHandler(handle(shortcutItem))
  }

  @discardableResult
  private func handle(_ item: UIApplicationShortcutItem) -> Bool {
    guard let route = AppRoute(shortcutType: item.type) else { return false }
    Store.shared.open(route)
    return true
  }
}

@main
struct OneDayApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var store = Store.shared
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(store)
        .preferredColorScheme(store.preferredColorScheme)
        .tint(store.accentColor)
        .modifier(UISizeModifier(size: store.settings.uiSize))
    }
    .onChange(of: scenePhase, initial: true) { _, phase in
      switch phase {
      case .active:
        store.sceneDidBecomeActive()
        AppLock.shared.sceneDidBecomeActive()
      case .inactive:
        AppLock.shared.sceneWillResignActive()
      case .background:
        store.flush()
        AppLock.shared.sceneDidEnterBackground()
        AudioPlayback.shared.stop()
        BackgroundRefresh.schedule()
        backupInBackground()
      @unknown default:
        break
      }
    }
    .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
      await BackgroundRefresh.run()
    }
  }

  /// Gives the folder backup a little time to finish after the app leaves the screen.
  private func backupInBackground() {
    let task = UIApplication.shared.beginBackgroundTask(withName: "OneDayBackup")
    Task {
      await BackupManager.shared.backupIfDue(store.state)
      UIApplication.shared.endBackgroundTask(task)
    }
  }
}

struct RootView: View {
  @Environment(Store.self) private var store
  @Environment(\.colorScheme) private var colorScheme
  @State private var showOnboarding = false

  var body: some View {
    @Bindable var store = store
    TabView(selection: $store.selectedTab) {
      TodayView()
        .tabItem { Label("今天", systemImage: "sun.max") }
        .tag(AppTab.today)
      TasksView()
        .tabItem { Label("事项", systemImage: "checklist") }
        .tag(AppTab.tasks)
      PlansView()
        .tabItem { Label("计划", systemImage: "flag") }
        .tag(AppTab.plans)
      ReviewView()
        .tabItem { Label("回顾", systemImage: "book") }
        .tag(AppTab.review)
      MeView()
        .tabItem { Label("我的", systemImage: "person.crop.circle") }
        .tag(AppTab.me)
    }
    .tabBarMinimizesOnScroll()
    // Fonts come from a static switch, so rebuild the screens when it flips.
    .id(store.appliedFontStyle)
    // 圆体 reaches every system text style; text without its own font gets the app font.
    .fontDesign(store.appliedFontStyle == .rounded ? .rounded : nil)
    .font(.app(.body))
    .environment(\.palette, Palette.make(tone: store.settings.bgTone, dark: colorScheme == .dark))
    .environment(\.visualStyle, store.settings.cardStyle)
    .environment(\.accent, store.accentColor)
    .overlay(alignment: .top) { ToastView() }
    .sheet(item: $store.motivation) { MotivationSheet(motivation: $0).oneDaySheet() }
    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
      store.refreshDay()
    }
    .onChange(of: store.selectedTab) { _, _ in Haptics.tap() }
    .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in store.promptUndo() }
    .onOpenURL { url in
      if let route = AppRoute(url: url) { store.open(route) }
    }
    .overlay {
      // Keeps content hidden under the lock window, including during launch.
      if AppLock.shared.isLocked {
        Color(uiColor: .systemBackground).ignoresSafeArea()
      }
    }
    .fullScreenCover(isPresented: $showOnboarding) { OnboardingView().oneDaySheet() }
    .onAppear {
      if store.hasAnyData { Onboarding.finish() }
      showOnboarding = !Onboarding.isDone
      #if DEBUG
      let defaults = UserDefaults.standard
      if defaults.bool(forKey: "OneDayDemo") { showOnboarding = false }
      if defaults.bool(forKey: "OneDayOnboarding") { showOnboarding = true }
      #endif
    }
    .alert(
      "撤销「\(store.undoPrompt?.label ?? "")」？",
      isPresented: Binding(get: { store.undoPrompt != nil }, set: { if !$0 { store.undoPrompt = nil } })
    ) {
      Button("撤销") { store.undo() }
      Button("取消", role: .cancel) {}
    } message: {
      Text("摇一摇可以撤销最近的操作。")
    }
  }
}

struct MotivationSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent
  let motivation: Motivation
  @State private var appeared = false

  var body: some View {
    VStack(spacing: 18) {
      Image(systemName: "sparkles")
        .font(.app(size: 46, weight: .semibold))
        .foregroundStyle(accent)
        .symbolEffect(.bounce, value: appeared)
      Text("今天做得很好。")
        .font(.app(.title2).bold())
      Text("“\(motivation.text)”")
        .font(.app(.title3))
        .multilineTextAlignment(.center)
      Text("—— \(motivation.author)")
        .foregroundStyle(.secondary)
      Button {
        dismiss()
      } label: {
        Text("继续前进").frame(maxWidth: .infinity).padding(.vertical, 4)
      }
      .oneDayButton(prominent: true)
      .controlSize(.large)
      .padding(.top, 6)
    }
    .padding(28)
    .presentationDetents([.medium])
    .onAppear {
      appeared = true
      Haptics.success()
    }
  }
}
