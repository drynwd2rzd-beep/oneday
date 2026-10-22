import Combine
import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // The delegate must be set before launch finishes so taps on notifications reach the app.
    NotificationManager.shared.activate()
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
    .onChange(of: scenePhase) { _, phase in
      switch phase {
      case .active: store.sceneDidBecomeActive()
      case .background: store.flush()
      default: break
      }
    }
  }
}

struct RootView: View {
  @Environment(Store.self) private var store
  @Environment(\.colorScheme) private var colorScheme

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
        .tabItem { Label("计划", systemImage: "scope") }
        .tag(AppTab.plans)
      ReviewView()
        .tabItem { Label("回顾", systemImage: "clock.arrow.circlepath") }
        .tag(AppTab.review)
      MeView()
        .tabItem { Label("我的", systemImage: "person.crop.circle") }
        .tag(AppTab.me)
    }
    .tabBarMinimizesOnScroll()
    .environment(\.palette, Palette.make(tone: store.settings.bgTone, dark: colorScheme == .dark))
    .environment(\.visualStyle, store.settings.cardStyle)
    .environment(\.accent, store.accentColor)
    .overlay(alignment: .top) { ToastView() }
    .sheet(item: $store.motivation) { MotivationSheet(motivation: $0) }
    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
      store.refreshDay()
    }
    .onChange(of: store.selectedTab) { _, _ in Haptics.tap() }
  }
}

struct ToastView: View {
  @Environment(Store.self) private var store

  var body: some View {
    ZStack {
      if let message = store.toastMessage {
        Text(message)
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, 18)
          .padding(.vertical, 11)
          .capsuleSurface()
          .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
          .transition(.move(edge: .top).combined(with: .opacity))
          .id(message)
      }
    }
    .animation(.spring(duration: 0.35), value: store.toastMessage)
    .padding(.top, 6)
    .allowsHitTesting(false)
    .accessibilityAddTraits(.updatesFrequently)
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
        .font(.system(size: 46, weight: .semibold))
        .foregroundStyle(accent)
        .symbolEffect(.bounce, value: appeared)
      Text("今天做得很好。")
        .font(.title2.bold())
      Text("“\(motivation.text)”")
        .font(.title3)
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
