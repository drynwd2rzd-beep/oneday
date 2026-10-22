import SwiftUI

private enum MeSheet: String, Identifiable {
  case profile, theme, uiSize, appearance, home, notifications, security, backup, diagnostics, about
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
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.stack) {
          Button {
            sheet = .profile
          } label: {
            HStack(spacing: 16) {
              AvatarView(name: s.avatar, size: 66)
              VStack(alignment: .leading, spacing: 4) {
                Text(s.name).font(.title3.bold()).foregroundStyle(.primary)
                Text(s.signature).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
              }
              Spacer(minLength: 8)
              Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .card()

          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("“").font(.system(.title, design: .serif)).foregroundStyle(accent)
            Text("每一天，都是向理想生活靠近的一步。")
              .font(.system(.title3, design: .serif, weight: .medium))
            Text("”").font(.system(.title, design: .serif)).foregroundStyle(accent)
          }
          .card(tint: accent.opacity(0.12))

          groupTitle("个性化")
          VStack(spacing: 0) {
            SettingRow(icon: "circle.lefthalf.filled", title: "外观与主题", desc: "模式与强调色", value: themeLabel(s)) { sheet = .theme }
            rowDivider
            SettingRow(icon: "square.on.square.intersection.dashed", title: "显示偏好", desc: "液态玻璃或经典样式、背景", value: s.cardStyle.label) { sheet = .appearance }
            rowDivider
            SettingRow(icon: "textformat.size", title: "界面大小", desc: "文字与整体布局", value: s.uiSize.label) { sheet = .uiSize }
            rowDivider
            SettingRow(icon: "square.grid.2x2", title: "首页自定义", desc: "模块与显示顺序") { sheet = .home }
          }
          .listCard()

          groupTitle("提醒、隐私与数据")
          VStack(spacing: 0) {
            SettingRow(
              icon: "bell.badge", title: "通知提醒", desc: "早晨计划、晚间未完成与记录提醒",
              value: s.notifications.enabled && notifications.isAuthorized ? "已开启" : "未开启", tint: .red
            ) { sheet = .notifications }
            rowDivider
            SettingRow(
              icon: "lock.shield", title: "隐私与安全", desc: "密码锁与\(AppLock.shared.biometryName)",
              value: AppLock.shared.isEnabled ? "已开启" : "未开启", tint: .indigo
            ) { sheet = .security }
            rowDivider
            SettingRow(
              icon: "externaldrive.badge.icloud", title: "备份与恢复", desc: "自动备份、导出与导入",
              value: BackupManager.shared.hasFolder ? "自动" : "未设置", tint: .blue
            ) { sheet = .backup }
          }
          .listCard()

          groupTitle("其他")
          VStack(spacing: 0) {
            SettingRow(icon: "stethoscope", title: "诊断信息", desc: "数据统计与崩溃报告", tint: .teal) { sheet = .diagnostics }
            rowDivider
            SettingRow(icon: "info.circle", title: "关于 OneDay", desc: "版本信息与使用说明", value: "v\(AppInfo.version)", tint: .gray) { sheet = .about }
          }
          .listCard()

          Text("不是为了记录而记录，\n而是为了更好地生活。\n\nOneDay v\(AppInfo.version)")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
        }
        .padding(.horizontal, Spacing.page)
        .padding(.bottom, Spacing.section)
      }
      .background { AppBackground() }
      .navigationTitle("我的")
      .sheet(item: $sheet) { which in
        Group {
          switch which {
          case .profile: ProfileSheet()
          case .theme: ThemeSheet()
          case .uiSize: UISizeSheet()
          case .appearance: AppearanceSheet()
          case .home: HomeCustomizeSheet()
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

  private func groupTitle(_ text: String) -> some View {
    Text(text)
      .font(.footnote.weight(.semibold))
      .foregroundStyle(.secondary)
      .padding(.top, Spacing.section - Spacing.stack)
      .accessibilityAddTraits(.isHeader)
  }

  private var rowDivider: some View {
    Divider().padding(.leading, 46)
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
