import SwiftUI

enum Onboarding {
  static let key = "onboarding.done"

  static var isDone: Bool { UserDefaults.standard.bool(forKey: key) }

  static func finish() { UserDefaults.standard.set(true, forKey: key) }
}

/// Three short pages on first launch: what the app is, a name and look, reminders and privacy.
struct OnboardingView: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  @Environment(\.dismiss) private var dismiss
  @State private var page = 0
  @State private var name = ""
  @State private var settingPasscode = false

  var body: some View {
    ZStack {
      AppBackground()
      VStack(spacing: 0) {
        // A plain pager: renders reliably inside a full-screen cover, unlike a paged TabView.
        ZStack {
          switch page {
          case 0: welcome.transition(pageTransition)
          case 1: personalize.transition(pageTransition)
          default: remindersAndPrivacy.transition(pageTransition)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 30).onEnded { value in
            let dx = value.translation.width
            withAnimation(.snappy) {
              if dx < -60 && page < 2 { page += 1 }
              if dx > 60 && page > 0 { page -= 1 }
            }
          })

        HStack(spacing: 8) {
          ForEach(0..<3, id: \.self) { i in
            Capsule()
              .fill(i == page ? accent : Color.secondary.opacity(0.3))
              .frame(width: i == page ? 20 : 7, height: 7)
          }
        }
        .animation(.snappy, value: page)
        .padding(.bottom, 18)
        .accessibilityElement()
        .accessibilityLabel("第 \(page + 1) 页，共 3 页")

        Button {
          if page < 2 {
            withAnimation(.snappy) { page += 1 }
          } else {
            finish()
          }
        } label: {
          Text(page < 2 ? "继续" : "开始使用")
            .font(.app(.headline))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .oneDayButton(prominent: true)
        .controlSize(.large)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)

        Button("跳过") { finish() }
          .font(.app(.subheadline))
          .foregroundStyle(.secondary)
          .opacity(page < 2 ? 1 : 0)
          .padding(.bottom, 8)
      }
    }
    .interactiveDismissDisabled()
    .sheet(isPresented: $settingPasscode) { PasscodeSetupSheet().oneDaySheet() }
    .onAppear { name = store.settings.name == Settings.defaultName ? "" : store.settings.name }
  }

  private var pageTransition: AnyTransition {
    .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))
  }

  private var welcome: some View {
    VStack(spacing: 28) {
      Spacer()
      Image("Logo")
        .resizable()
        .frame(width: 104, height: 104)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        .accessibilityHidden(true)
      VStack(spacing: 8) {
        Text("一天").font(.app(.largeTitle).weight(.semibold))
        Text("每一天，都值得留下。").font(.app(.title3)).foregroundStyle(.secondary)
      }
      VStack(alignment: .leading, spacing: 18) {
        feature("checklist", "事项", "每天要做的小事，完成一件勾一件。")
        feature("square.and.pencil", "记录", "文字、照片、视频和语音，带上地点与天气。")
        feature("clock.arrow.circlepath", "回顾", "时间线、那年今日和这一年的坚持。")
      }
      .padding(.horizontal, 8)
      Spacer()
    }
    .padding(.horizontal, 28)
  }

  private var personalize: some View {
    VStack(alignment: .leading, spacing: 24) {
      Spacer()
      Text("怎么称呼你？").font(.app(.title2).weight(.semibold))
      TextField("你的名字", text: $name)
        .font(.app(.title3))
        .submitLabel(.done)
        .fieldBackground()
      Text("界面风格").font(.app(.title2).weight(.semibold)).padding(.top, 8)
      VStack(spacing: 10) {
        ForEach(VisualStyle.allCases) { style in
          Button {
            withAnimation(.smooth) { store.setVisualStyle(style) }
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(style.label).font(.app(.headline))
                Text(style.hint).font(.app(.caption)).foregroundStyle(.secondary)
              }
              Spacer()
              Image(systemName: store.settings.cardStyle == style ? "checkmark.circle.fill" : "circle")
                .font(.app(.title3))
                .foregroundStyle(store.settings.cardStyle == style ? accent : Color.secondary)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .card()
          .accessibilityAddTraits(store.settings.cardStyle == style ? .isSelected : [])
        }
      }
      Text("之后可以在「我的 → 显示偏好」中随时更改。").font(.app(.caption)).foregroundStyle(.secondary)
      Spacer()
    }
    .padding(.horizontal, 24)
  }

  private var remindersAndPrivacy: some View {
    VStack(alignment: .leading, spacing: 20) {
      Spacer()
      Text("提醒与隐私").font(.app(.title2).weight(.semibold))
      choice(
        icon: "bell.badge", title: "开启提醒",
        detail: "早上看今天的事项，晚上提醒留下记录。",
        done: store.settings.notifications.enabled
      ) {
        Task { await store.enableNotifications() }
      }
      choice(
        icon: "lock.shield", title: "设置密码锁",
        detail: AppLock.shared.canUseBiometrics ? "日记只属于你，可用\(AppLock.shared.biometryName)解锁。" : "日记只属于你。",
        done: AppLock.shared.isEnabled
      ) {
        settingPasscode = true
      }
      Label("所有内容都保存在这台 iPhone 上。可以在「备份与恢复」中设置自动备份到 iCloud 云盘。", systemImage: "internaldrive")
        .font(.app(.footnote))
        .foregroundStyle(.secondary)
        .padding(.top, 6)
      Spacer()
    }
    .padding(.horizontal, 24)
  }

  private func feature(_ icon: String, _ title: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: icon)
        .font(.app(.title3))
        .foregroundStyle(accent)
        .frame(width: 30)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.app(.headline))
        Text(text).font(.app(.subheadline)).foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private func choice(icon: String, title: String, detail: String, done: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Image(systemName: icon).font(.app(.title3)).foregroundStyle(accent).frame(width: 30)
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.app(.headline))
          Text(detail).font(.app(.caption)).foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: done ? "checkmark.circle.fill" : "chevron.right")
          .foregroundStyle(done ? accent : Color.secondary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(done)
    .card()
  }

  private func finish() {
    let trimmed = name.trimmed
    if !trimmed.isEmpty {
      store.state.settings.name = String(trimmed.prefix(20))
      store.save()
    }
    Onboarding.finish()
    dismiss()
  }
}
