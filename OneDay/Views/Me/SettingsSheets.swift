import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Profile

struct ProfileSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent
  @State private var name = ""
  @State private var signature = ""
  @State private var avatarItem: PhotosPickerItem?
  @State private var newAvatar: String?
  @State private var saved = false

  var body: some View {
    let currentAvatar = newAvatar ?? store.settings.avatar
    NavigationStack {
      Form {
        Section {
          HStack {
            Spacer()
            PhotosPicker(selection: $avatarItem, matching: .images) {
              AvatarView(name: currentAvatar, size: 100)
                .overlay(alignment: .bottomTrailing) {
                  Image(systemName: "camera.fill")
                    .font(.app(.footnote).weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(accent, in: Circle())
                    .overlay { Circle().strokeBorder(.white, lineWidth: 2) }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("更换头像")
            Spacer()
          }
          .listRowBackground(Color.clear)
        }
        Section("名称") {
          TextField(Settings.defaultName, text: $name)
            .onChange(of: name) { _, v in if v.count > 20 { name = String(v.prefix(20)) } }
        }
        Section {
          TextField(Settings.defaultSignature, text: $signature, axis: .vertical)
            .lineLimit(2...4)
            .onChange(of: signature) { _, v in if v.count > 80 { signature = String(v.prefix(80)) } }
        } header: {
          Text("个人签名")
        } footer: {
          Text("\(signature.count)/80")
        }
      }
      .navigationTitle("个人资料")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") {
            saved = true
            store.saveProfile(name: name, signature: signature, avatar: newAvatar)
            dismiss()
          }
        }
      }
      .onAppear {
        name = store.settings.name
        signature = store.settings.signature
      }
      .onChange(of: avatarItem) { _, item in
        guard let item else { return }
        Task {
          guard let data = try? await item.loadTransferable(type: Data.self) else {
            store.toast("照片读取失败")
            return
          }
          let stored = await Task.detached { MediaStore.save(data: data, maxDimension: 512) }.value
          if let previous = newAvatar { MediaStore.delete(previous) }
          newAvatar = stored
        }
      }
      .onDisappear {
        // A picked avatar that was never saved should not linger on disk.
        if !saved, let unsaved = newAvatar { MediaStore.delete(unsaved) }
      }
    }
  }
}

// MARK: - Theme

struct ThemeSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var mode: ThemeMode = .system
  @State private var accent = Settings.defaultAccent
  @State private var custom: String?

  private var swatches: [String] {
    OneDayText.accentColors + (custom.map { [$0] } ?? [])
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("外观模式") {
          HStack(spacing: 10) {
            ForEach(ThemeMode.allCases) { m in
              Button {
                withAnimation(.snappy) { mode = m }
              } label: {
                VStack(spacing: 8) {
                  Image(systemName: m.icon).font(.app(.title2))
                  Text(m.label).font(.app(.subheadline))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(mode == m ? Color(hex: accent) : Color.primary)
                .background {
                  RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(mode == m ? Color(hex: accent).opacity(0.14) : Color.secondary.opacity(0.08))
                }
                .overlay {
                  RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(mode == m ? Color(hex: accent) : .clear, lineWidth: 1.5)
                }
              }
              .buttonStyle(.plain)
              .accessibilityAddTraits(mode == m ? .isSelected : [])
            }
          }
          .padding(.vertical, 4)
        }

        Section {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 14)], spacing: 14) {
            ForEach(swatches, id: \.self) { hex in
              Circle()
                .fill(Color(hex: hex))
                .frame(width: 44, height: 44)
                .overlay {
                  if hex.lowercased() == accent.lowercased() {
                    Image(systemName: "checkmark").font(.app(.headline).bold()).foregroundStyle(.white)
                  }
                }
                .contentShape(Circle())
                .onTapGesture {
                  Haptics.tap()
                  accent = hex
                  if OneDayText.accentColors.contains(hex) == false { custom = hex }
                }
                .accessibilityLabel(hex == custom ? "自定义颜色" : "主题色")
                .accessibilityAddTraits(.isButton)
            }
          }
          .padding(.vertical, 6)
          ColorPicker("自定义颜色", selection: customColor, supportsOpacity: false)
        } header: {
          Text("主题色")
        } footer: {
          if store.settings.bgTone == .meteor {
            Text("当前背景为流星夜，会始终使用深色外观。")
          }
        }
      }
      .navigationTitle("外观与主题")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") {
            store.saveTheme(mode: mode, accent: accent, customAccent: custom)
            dismiss()
          }
        }
      }
      .onAppear {
        mode = store.settings.theme
        accent = store.settings.accent
        custom = store.settings.customAccent
      }
    }
    .presentationDetents([.medium, .large])
  }

  /// Only one custom color is kept: picking again replaces it.
  private var customColor: Binding<Color> {
    Binding(
      get: { Color(hex: custom ?? accent) },
      set: { color in
        let hex = color.hexString
        custom = hex
        accent = hex
      })
  }
}

// MARK: - Interface size

struct UISizeSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent

  var body: some View {
    NavigationStack {
      Form {
        Section {
          ForEach(UISize.allCases) { size in
            Button {
              withAnimation(.snappy) { store.setUISize(size) }
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 2) {
                  Text(size.label).foregroundStyle(.primary)
                  Text(size.hint).font(.app(.caption)).foregroundStyle(.secondary)
                }
                Spacer()
                if store.settings.uiSize == size {
                  Image(systemName: "checkmark").font(.app(.body).weight(.semibold)).foregroundStyle(accent)
                }
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
        } footer: {
          Text("「标准」跟随 iPhone 的系统字号，「紧凑」和「大」在此基础上调整。")
        }
        Section("预览") {
          VStack(alignment: .leading, spacing: 6) {
            Text("早上好。").font(.app(.title2).bold())
            Text(OneDayText.quotes[0]).foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
        }
      }
      .navigationTitle("界面大小")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
      }
    }
    .presentationDetents([.medium, .large])
  }
}

// MARK: - Appearance (Liquid Glass or classic)

struct AppearanceSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent

  var body: some View {
    NavigationStack {
      Form {
        Section {
          ForEach(VisualStyle.allCases) { style in
            choiceRow(title: style.label, hint: style.hint, selected: store.settings.cardStyle == style) {
              withAnimation(.smooth) { store.setVisualStyle(style) }
            }
          }
        } header: {
          Text("界面风格")
        } footer: {
          Text(glassFooter)
        }

        Section("预览") {
          StylePreview()
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }

        Section("背景色调") {
          ForEach(BgTone.allCases) { tone in
            choiceRow(
              title: tone.label,
              hint: tone == .meteor ? "简洁的夜空与流星，始终使用深色" : nil,
              selected: store.settings.bgTone == tone
            ) {
              withAnimation(.smooth) { store.setBgTone(tone) }
            }
          }
        }
      }
      .navigationTitle("显示偏好")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
      }
    }
    .presentationDetents([.large])
  }

  private var glassFooter: String {
    if systemSupportsGlass {
      return "液态玻璃会让卡片、按钮和标签呈现 iOS 26 的玻璃质感；经典样式保留原版 OneDay 的外观。导航栏和标签栏始终由系统绘制。"
    }
    return "当前系统低于 iOS 26，液态玻璃会以系统磨砂材质呈现。升级到 iOS 26 即可获得完整效果。"
  }

  private func choiceRow(title: String, hint: String?, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(title).foregroundStyle(.primary)
          if let hint { Text(hint).font(.app(.caption)).foregroundStyle(.secondary) }
        }
        Spacer()
        if selected {
          Image(systemName: "checkmark").font(.app(.body).weight(.semibold)).foregroundStyle(accent)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

/// A miniature of the home screen in the selected style.
private struct StylePreview: View {
  @Environment(\.accent) private var accent

  var body: some View {
    ZStack {
      AppBackground()
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 12) {
          Image(systemName: "checkmark.circle.fill").font(.app(.title3)).foregroundStyle(accent)
          VStack(alignment: .leading, spacing: 2) {
            Text("阅读 20 分钟").font(.app(.subheadline).weight(.semibold))
            Text("每天 · 已完成 12 次").font(.app(.caption)).foregroundStyle(.secondary)
          }
          Spacer()
        }
        .card(padding: 14)
        GlassGroup {
          HStack {
            Button("添加照片") {}.oneDayButton()
            Spacer()
            Button("留下") {}.oneDayButton(prominent: true)
          }
        }
        .allowsHitTesting(false)
      }
      .padding(16)
    }
    .frame(height: 170)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

// MARK: - Home modules

struct HomeCustomizeSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    let shown = store.settings.homeModules
    let hidden = HomeModule.choosable.filter { !shown.contains($0) }
    NavigationStack {
      List {
        Section {
          ForEach(shown) { module in
            row(module, visible: true)
          }
          .onMove { store.moveHomeModules(from: $0, to: $1) }
        } header: {
          Text("首页显示")
        } footer: {
          Text("拖动右侧把手调整顺序，设置会自动保存。")
        }
        if !hidden.isEmpty {
          Section("已隐藏") {
            ForEach(hidden) { module in
              row(module, visible: false)
            }
          }
        }
        Section {
          Button("恢复默认") { withAnimation { store.resetHomeModules() } }
        }
      }
      .environment(\.editMode, .constant(.active))
      .navigationTitle("首页自定义")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
      }
      .animation(.snappy, value: shown)
    }
  }

  private func row(_ module: HomeModule, visible: Bool) -> some View {
    Toggle(isOn: Binding(get: { visible }, set: { store.setHomeModule(module, visible: $0) })) {
      VStack(alignment: .leading, spacing: 2) {
        Text(module.title)
        Text(module.desc).font(.app(.caption)).foregroundStyle(.secondary)
      }
    }
  }
}

// MARK: - Notifications

struct NotificationSettingsSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  private let manager = NotificationManager.shared

  var body: some View {
    let prefs = store.settings.notifications
    NavigationStack {
      Form {
        Section {
          Toggle(isOn: enabledBinding) {
            Label("开启通知提醒", systemImage: "bell.badge")
          }
        } footer: {
          Text(statusText(prefs))
        }

        if manager.status == .denied {
          Section {
            Button {
              if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
            } label: {
              Label("前往系统设置允许通知", systemImage: "gear")
            }
          }
        }

        if prefs.enabled {
          Section {
            Toggle("早晨计划", isOn: bool(\.morning))
            if prefs.morning {
              DatePicker("时间", selection: time(\.morningTime), displayedComponents: .hourAndMinute)
            }
          } header: {
            Text("每日提醒")
          } footer: {
            Text("早上告诉你今天有几件事项。")
          }

          Section {
            Toggle("晚间未完成提醒", isOn: bool(\.evening))
            if prefs.evening {
              DatePicker("时间", selection: time(\.eveningTime), displayedComponents: .hourAndMinute)
            }
          } footer: {
            Text("只有当天还有未完成事项时才会提醒，全部完成后自动取消。")
          }

          Section {
            Toggle("记录提醒", isOn: bool(\.note))
            if prefs.note {
              DatePicker("时间", selection: time(\.noteTime), displayedComponents: .hourAndMinute)
            }
          } footer: {
            Text("提醒你留下今天值得记住的事；当天已经留下记录就不会打扰你。")
          }

          Section {
            Toggle("事项定时提醒", isOn: bool(\.taskReminders))
            Toggle("图标角标显示未完成数", isOn: bool(\.badge))
          } footer: {
            Text("在事项的「⋯」菜单或添加事项时设置提醒时间。收到提醒后可以直接点「完成」，或选择 10 分钟后再提醒。")
          }

          Section {
            Button {
              manager.sendTest()
              store.toast("3 秒后会收到一条测试通知")
            } label: {
              Label("发送一条测试通知", systemImage: "paperplane")
            }
            .disabled(!manager.isAuthorized)
          }
        }
      }
      .navigationTitle("通知提醒")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
      }
      .task { await manager.refreshStatus() }
    }
  }

  private func statusText(_ prefs: NotificationPrefs) -> String {
    switch manager.status {
    case .denied: return "通知权限已被关闭，请在系统设置中允许「一天」发送通知。"
    case .notDetermined: return "开启后，系统会询问是否允许发送通知。"
    default: return prefs.enabled ? "提醒会根据你的事项和记录自动更新。" : "所有提醒都在本机生成，不会上传任何数据。"
    }
  }

  private var enabledBinding: Binding<Bool> {
    Binding(
      get: { store.settings.notifications.enabled && manager.status != .denied },
      set: { on in
        if on {
          Task { await store.enableNotifications() }
        } else {
          store.updateNotifications { $0.enabled = false }
        }
      })
  }

  private func bool(_ key: WritableKeyPath<NotificationPrefs, Bool>) -> Binding<Bool> {
    Binding(
      get: { store.settings.notifications[keyPath: key] },
      set: { value in withAnimation { store.updateNotifications { $0[keyPath: key] = value } } })
  }

  private func time(_ key: WritableKeyPath<NotificationPrefs, Int>) -> Binding<Date> {
    Binding(
      get: { DayKey.dateToday(minutes: store.settings.notifications[keyPath: key]) },
      set: { date in store.updateNotifications { $0[keyPath: key] = DayKey.minutes(of: date) } })
  }
}

// MARK: - About

struct AboutSheet: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section {
          VStack(spacing: 10) {
            Image("Logo")
              .resizable()
              .scaledToFit()
              .frame(width: 88, height: 88)
              .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
              .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
            Text("OneDay").font(.app(.title2).bold())
            Text("v\(AppInfo.version)").font(.app(.subheadline)).foregroundStyle(.secondary)
            Text("每一天，都值得留下。").font(.app(.body)).padding(.top, 4)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .listRowBackground(Color.clear)
        }
        Section {
          NavigationLink {
            InfoPage(title: "使用说明", text: OneDayText.help)
          } label: {
            Label("使用说明", systemImage: "book")
          }
          NavigationLink {
            InfoPage(title: "版本信息", text: OneDayText.versionNotes)
          } label: {
            Label("版本信息", systemImage: "clock")
          }
          NavigationLink {
            InfoPage(title: "致谢", text: OneDayText.credits)
          } label: {
            Label("致谢与开源许可", systemImage: "heart")
          }
        }
      }
      .navigationTitle("关于")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
      }
    }
  }
}

private struct InfoPage: View {
  let title: String
  let text: String

  var body: some View {
    ScrollView {
      Text(text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .textSelection(.enabled)
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
  }
}

/// 我的 → 字体: each typeface with a live sample.
struct FontSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent

  var body: some View {
    NavigationStack {
      Form {
        Section {
          ForEach(FontStyle.allCases) { style in
            Button {
              store.setFontStyle(style)
            } label: {
              HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                  HStack(spacing: 6) {
                    Text(style.label).font(.app(.headline))
                    Text(style.hint).font(.app(.caption)).foregroundStyle(.secondary)
                  }
                  Text("下午好。今天也认真生活了。")
                    .font(sample(style, size: 20, bold: true))
                  Text("完成 3/4 · 2026年10月22日 · OneDay")
                    .font(sample(style, size: 15))
                    .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image(systemName: store.settings.fontStyle == style ? "checkmark.circle.fill" : "circle")
                  .font(.app(.title3))
                  .foregroundStyle(store.settings.fontStyle == style ? accent : Color(uiColor: .tertiaryLabel))
              }
              .padding(.vertical, 6)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(store.settings.fontStyle == style ? .isSelected : [])
          }
        } footer: {
          Text("关闭这一页后，全 App 会换成所选字体。系统弹窗和键盘始终使用系统字体。")
        }
      }
      .onDisappear { store.applyFontStyle() }
      .navigationTitle("字体")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
      }
    }
  }

  private func sample(_ style: FontStyle, size: CGFloat, bold: Bool = false) -> Font {
    switch style {
    case .system: .system(size: size, weight: bold ? .semibold : .regular)
    case .rounded: .system(size: size, weight: bold ? .semibold : .regular, design: .rounded)
    case .journal: .custom(bold ? "OneDayJournal-Medium" : "OneDayJournal-Regular", size: size)
    }
  }
}
