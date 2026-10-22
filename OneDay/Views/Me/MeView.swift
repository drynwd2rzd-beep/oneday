import SwiftUI

private enum MeSheet: String, Identifiable {
  case profile, theme, uiSize, appearance, font, home, widgets, notifications, security, backup, diagnostics, about
  var id: String { rawValue }
}

struct MeView: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  @State private var sheet: MeSheet?
  private let notifications = NotificationManager.shared

  var body: some View {
    let s = store.settings
    NavigationStack {
      List {
        Section {
          Button {
            sheet = .profile
          } label: {
            HStack(spacing: 14) {
              AvatarView(name: s.avatar, size: 60)
              VStack(alignment: .leading, spacing: 3) {
                Text(s.name).font(.app(.title3).weight(.semibold)).foregroundStyle(.primary)
                Text(s.signature).font(.app(.subheadline)).foregroundStyle(.secondary).lineLimit(2)
              }
              Spacer(minLength: 8)
              Image(systemName: "chevron.right")
                .font(.app(.footnote).weight(.semibold))
                .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }

        Section {
          SettingRow(icon: "circle.lefthalf.filled", title: "外观与主题", value: themeLabel(s)) { sheet = .theme }
          SettingRow(icon: "square.on.square", title: "显示偏好", value: s.cardStyle.label, tint: .teal) { sheet = .appearance }
          SettingRow(icon: "textformat", title: "字体", value: s.fontStyle.label, tint: .purple) { sheet = .font }
          SettingRow(icon: "textformat.size", title: "界面大小", value: s.uiSize.label, tint: .blue) { sheet = .uiSize }
          SettingRow(icon: "square.grid.2x2", title: "首页自定义", tint: .orange) { sheet = .home }
          SettingRow(icon: "rectangle.3.group", title: "桌面小组件", tint: .yellow) { sheet = .widgets }
        }

        Section {
          SettingRow(
            icon: "bell.badge.fill", title: "通知提醒",
            value: s.notifications.enabled && notifications.isAuthorized ? "已开启" : "未开启", tint: .red
          ) { sheet = .notifications }
          SettingRow(
            icon: "lock.fill", title: "隐私与安全",
            value: AppLock.shared.isEnabled ? "已开启" : "未开启", tint: .indigo
          ) { sheet = .security }
          SettingRow(
            icon: "externaldrive.fill", title: "备份与恢复",
            value: BackupManager.shared.hasFolder ? "自动" : "未设置", tint: .blue
          ) { sheet = .backup }
        }

        Section {
          SettingRow(icon: "stethoscope", title: "诊断信息", tint: .gray) { sheet = .diagnostics }
          SettingRow(icon: "info", title: "关于 OneDay", value: "v\(AppInfo.version)", tint: .gray) { sheet = .about }
        } footer: {
          Text("不是为了记录而记录，而是为了更好地生活。")
            .font(.journal(.footnote, size: 13))
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        }
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background { AppBackground() }
      .navigationTitle("我的")
      #if DEBUG
      .onAppear {
        if UserDefaults.standard.bool(forKey: "OneDayWidgets") { sheet = .widgets }
      }
      #endif
      .sheet(item: $sheet) { which in
        Group {
          switch which {
          case .profile: ProfileSheet()
          case .theme: ThemeSheet()
          case .uiSize: UISizeSheet()
          case .appearance: AppearanceSheet()
          case .font: FontSheet()
          case .home: HomeCustomizeSheet()
          case .widgets: WidgetGallerySheet()
          case .notifications: NotificationSettingsSheet()
          case .security: SecuritySheet()
          case .backup: BackupSheet()
          case .diagnostics: DiagnosticsSheet()
          case .about: AboutSheet()
          }
        }
        .oneDaySheet()
      }
    }
  }

  private func themeLabel(_ s: Settings) -> String {
    s.bgTone == .meteor ? "流星夜" : s.theme.label
  }
}

enum AppInfo {
  static var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
  }

  static var build: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
  }
}
