import SwiftUI

private enum MeSheet: String, Identifiable {
  case profile, theme, uiSize, appearance, home, notifications, data, about
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
        VStack(alignment: .leading, spacing: 18) {
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

          Text("通用")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
            .padding(.top, 4)

          VStack(spacing: 0) {
            SettingRow(icon: "circle.lefthalf.filled", title: "外观与主题", desc: "模式与强调色", value: themeLabel(s)) { sheet = .theme }
            rowDivider
            SettingRow(icon: "textformat.size", title: "界面大小", desc: "调整文字、卡片和整体布局", value: s.uiSize.label) { sheet = .uiSize }
            rowDivider
            SettingRow(icon: "square.on.square.intersection.dashed", title: "显示偏好", desc: "液态玻璃或经典样式、背景", value: "\(s.cardStyle.label) · \(s.bgTone.label)") { sheet = .appearance }
            rowDivider
            SettingRow(icon: "square.grid.2x2", title: "首页自定义", desc: "调整首页模块与显示顺序") { sheet = .home }
            rowDivider
            SettingRow(
              icon: "bell.badge", title: "通知提醒", desc: "早晨计划、晚间未完成与记录提醒",
              value: s.notifications.enabled && notifications.isAuthorized ? "已开启" : "未开启",
              tint: .red
            ) { sheet = .notifications }
            rowDivider
            SettingRow(icon: "arrow.up.arrow.down", title: "数据管理", desc: "导出、导入与恢复初始设置", tint: .blue) { sheet = .data }
            rowDivider
            SettingRow(icon: "info.circle", title: "关于 OneDay", desc: "版本信息与使用说明", value: "v\(AppInfo.version)", tint: .gray) { sheet = .about }
          }
          .card(padding: 8)

          Text("不是为了记录而记录，\n而是为了更好地生活。\n\nOneDay v\(AppInfo.version)")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
      }
      .background { AppBackground() }
      .navigationTitle("我的")
      .sheet(item: $sheet) { which in
        switch which {
        case .profile: ProfileSheet()
        case .theme: ThemeSheet()
        case .uiSize: UISizeSheet()
        case .appearance: AppearanceSheet()
        case .home: HomeCustomizeSheet()
        case .notifications: NotificationSettingsSheet()
        case .data: DataSheet()
        case .about: AboutSheet()
        }
      }
    }
  }

  private var rowDivider: some View {
    Divider().padding(.leading, 56)
  }

  private func themeLabel(_ s: Settings) -> String {
    s.bgTone == .meteor ? "流星夜" : s.theme.label
  }
}

enum AppInfo {
  static var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
  }
}
