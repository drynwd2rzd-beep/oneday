import LocalAuthentication
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Privacy & security

struct SecuritySheet: View {
  @Environment(\.dismiss) private var dismiss
  private var lock: AppLock { AppLock.shared }
  @State private var settingUp = false
  @State private var verifyingToDisable = false
  @State private var verifyingToChange = false
  @State private var changing = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle(isOn: Binding(
            get: { lock.isEnabled },
            set: { on in if on { settingUp = true } else { verifyingToDisable = true } }
          )) {
            Label("密码锁", systemImage: "lock")
          }
          if lock.isEnabled {
            Button {
              verifyingToChange = true
            } label: {
              Label("更改密码", systemImage: "key")
            }
          }
        } footer: {
          Text("打开「一天」时需要输入密码。密码只以加密摘要保存在这台设备的钥匙串里，不会上传。忘记密码只能清除数据后重新开始。")
        }

        if lock.isEnabled {
          if lock.canUseBiometrics {
            Section {
              Toggle(isOn: biometricsBinding) {
                Label("使用\(lock.biometryName)解锁", systemImage: lock.biometryIcon)
              }
            }
          }
          Section {
            Picker(selection: Binding(get: { lock.autoLock }, set: { lock.autoLock = $0 })) {
              ForEach(AutoLock.allCases) { Text($0.label).tag($0) }
            } label: {
              Label("自动锁定", systemImage: "timer")
            }
          } footer: {
            Text("离开「一天」多久后需要重新解锁。切换到其他 App 时，多任务界面中的内容总会被遮住。")
          }
        }

        Section {
          Label("位置只在你点「添加位置」时获取一次；天气通过 Open-Meteo 查询，只发送大致坐标。", systemImage: "location")
          Label("所有记录、照片、视频和录音都保存在本机，备份只写到你选择的文件夹。", systemImage: "internaldrive")
        } header: {
          Text("隐私说明")
        }
        .font(.app(.subheadline))
        .foregroundStyle(.secondary)
      }
      .navigationTitle("隐私与安全")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
      }
      .sheet(isPresented: $settingUp) { PasscodeSetupSheet().oneDaySheet() }
      .sheet(isPresented: $changing) { PasscodeSetupSheet().oneDaySheet() }
      .sheet(isPresented: $verifyingToDisable) {
        PasscodeVerifySheet(title: "关闭密码锁") { lock.removePasscode() }.oneDaySheet()
      }
      .sheet(isPresented: $verifyingToChange) {
        PasscodeVerifySheet(title: "更改密码") {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { changing = true }
        }
        .oneDaySheet()
      }
    }
  }

  private var biometricsBinding: Binding<Bool> {
    Binding(
      get: { lock.biometricsEnabled },
      set: { on in
        guard on else {
          lock.biometricsEnabled = false
          return
        }
        // Confirm the user can actually authenticate before relying on it.
        Task {
          let context = LAContextBox()
          if await context.evaluate() { lock.biometricsEnabled = true }
        }
      })
  }
}

/// Wraps a one-off biometric check used when turning Face ID on.
private struct LAContextBox {
  func evaluate() async -> Bool {
    (try? await LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "确认开启生物识别解锁")) ?? false
  }
}

// MARK: - Backup & restore

struct BackupSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  private var backup: BackupManager { BackupManager.shared }

  private enum ImportMode { case folder, restore }
  @State private var importMode: ImportMode = .folder
  @State private var showImporter = false
  @State private var exportPackage: URL?
  @State private var showMover = false
  @State private var exportingPackage = false
  @State private var webDocument: BackupDocument?
  @State private var showWebExporter = false
  @State private var pendingRestore: PendingRestore?
  @State private var reading = false
  @State private var confirmReset = false
  @State private var confirmResetAgain = false

  private struct PendingRestore: Identifiable {
    let id = UUID()
    let source: String
    let state: AppState
  }

  var body: some View {
    NavigationStack {
      Form {
        folderSection
        snapshotSection
        exportSection
        Section {
          Button {
            importMode = .restore
            showImporter = true
          } label: {
            Label {
              VStack(alignment: .leading, spacing: 2) {
                Text("从备份恢复")
                Text("选择备份文件夹，或网页版导出的 JSON 文件").font(.app(.caption)).foregroundStyle(.secondary)
              }
            } icon: {
              if reading { ProgressView() } else { Image(systemName: "arrow.down.doc") }
            }
          }
          .disabled(reading)
        }
        Section {
          Button(role: .destructive) {
            confirmReset = true
          } label: {
            Label("恢复初始设置", systemImage: "arrow.counterclockwise")
          }
        } footer: {
          Text("清除全部数据，回到第一次打开时的状态。")
        }
      }
      .navigationTitle("备份与恢复")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
      }
      .fileImporter(
        isPresented: $showImporter,
        allowedContentTypes: importMode == .folder ? [.folder] : [.folder, .json]
      ) { result in
        guard case .success(let url) = result else { return }
        if importMode == .folder {
          backup.setFolder(url)
          Task { await backup.backupNow(store.state) }
        } else {
          Task { await read(url, source: url.lastPathComponent) }
        }
      }
      .fileMover(isPresented: $showMover, file: exportPackage) { result in
        if case .success = result { store.toast("完整备份已导出") }
      }
      .fileExporter(
        isPresented: $showWebExporter, document: webDocument, contentType: .json,
        defaultFilename: "oneday-backup-\(store.today)"
      ) { result in
        if case .success = result { store.toast("已导出网页版备份") }
      }
      .alert("用这份备份替换当前数据？", isPresented: isPresented($pendingRestore), presenting: pendingRestore) { item in
        Button("恢复", role: .destructive) {
          store.applyImport(item.state)
          dismiss()
        }
        Button("取消", role: .cancel) {}
      } message: { item in
        Text("来自「\(item.source)」。恢复后如果不满意，可以摇一摇撤销。")
      }
      .background {
        Color.clear
          .alert("确定恢复初始设置吗？", isPresented: $confirmReset) {
            Button("继续", role: .destructive) {
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { confirmResetAgain = true }
            }
            Button("取消", role: .cancel) {}
          } message: {
            Text("这会清除头像、主题、事项、计划、记录、照片、视频和录音。")
          }
      }
      .overlay {
        Color.clear
          .allowsHitTesting(false)
          .alert("请再次确认", isPresented: $confirmResetAgain) {
            Button("全部清空", role: .destructive) {
              store.restoreAll()
              dismiss()
            }
            Button("取消", role: .cancel) {}
          } message: {
            Text("此操作无法撤销。建议先导出一份完整备份。")
          }
      }
    }
  }

  // MARK: Sections

  private var folderSection: some View {
    Section {
      if backup.hasFolder {
        LabeledContent {
          Text(backup.folderName ?? "已选择")
        } label: {
          Label("备份位置", systemImage: "folder")
        }
        LabeledContent {
          Text(backup.lastBackup.map { $0.formatted(.relative(presentation: .named)) } ?? "尚未备份")
        } label: {
          Label("上次备份", systemImage: "clock")
        }
        Button {
          Task {
            if await backup.backupNow(store.state) { store.toast("备份完成") }
          }
        } label: {
          Label {
            Text(backup.isWorking ? "正在备份…" : "立即备份")
          } icon: {
            if backup.isWorking { ProgressView() } else { Image(systemName: "arrow.clockwise.icloud") }
          }
        }
        .disabled(backup.isWorking)
        Button {
          importMode = .folder
          showImporter = true
        } label: {
          Label("更换文件夹", systemImage: "folder.badge.gearshape")
        }
        Button(role: .destructive) {
          backup.clearFolder()
        } label: {
          Label("停止自动备份", systemImage: "xmark.icloud")
        }
      } else {
        Button {
          importMode = .folder
          showImporter = true
        } label: {
          Label {
            VStack(alignment: .leading, spacing: 2) {
              Text("选择备份文件夹")
              Text("推荐选择「iCloud 云盘」中的文件夹").font(.app(.caption)).foregroundStyle(.secondary)
            }
          } icon: {
            Image(systemName: "icloud.and.arrow.up")
          }
        }
      }
      if let error = backup.lastError {
        Text(error).font(.app(.caption)).foregroundStyle(.red)
      }
    } header: {
      Text("自动备份")
    } footer: {
      Text("选好文件夹后，「一天」会在你离开 App 时自动备份全部记录、照片、视频和录音（每 6 小时最多一次），并保留最近 14 天的历史版本。放在 iCloud 云盘里，换手机或重装后都能恢复。")
    }
  }

  private var snapshotSection: some View {
    Section {
      let snapshots = backup.snapshots
      if snapshots.isEmpty {
        Text("还没有快照").foregroundStyle(.secondary)
      } else {
        ForEach(snapshots, id: \.self) { url in
          Button {
            Task { await read(url, source: "本机快照 \(url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "oneday-", with: ""))") }
          } label: {
            HStack {
              Label(url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "oneday-", with: ""), systemImage: "doc.text")
              Spacer()
              Text("恢复").font(.app(.subheadline)).foregroundStyle(.secondary)
            }
          }
        }
      }
    } header: {
      Text("本机快照")
    } footer: {
      Text("每天自动保存一份数据快照，保留 7 天。也可以在「文件」App › 我的 iPhone › 一天 › 自动备份 中找到。")
    }
  }

  private var exportSection: some View {
    Section {
      Button {
        Task { await makePackage() }
      } label: {
        Label {
          VStack(alignment: .leading, spacing: 2) {
            Text("导出完整备份")
            Text("包含照片、视频和录音的文件夹").font(.app(.caption)).foregroundStyle(.secondary)
          }
        } icon: {
          if exportingPackage { ProgressView() } else { Image(systemName: "shippingbox") }
        }
      }
      .disabled(exportingPackage)
      Button {
        webDocument = store.webBackupDocument()
        showWebExporter = true
      } label: {
        Label {
          VStack(alignment: .leading, spacing: 2) {
            Text("导出网页版备份")
            Text("单个 JSON 文件，网页版 OneDay 可以导入（不含视频和录音）").font(.app(.caption)).foregroundStyle(.secondary)
          }
        } icon: {
          Image(systemName: "doc.badge.arrow.up")
        }
      }
    } header: {
      Text("导出")
    }
  }

  // MARK: Actions

  private func makePackage() async {
    exportingPackage = true
    defer { exportingPackage = false }
    let state = store.state
    let result = await Task.detached(priority: .userInitiated) { try? BackupManager.makeExportPackage(state) }.value
    if let result {
      exportPackage = result
      showMover = true
    } else {
      store.toast("导出失败")
    }
  }

  private func read(_ url: URL, source: String) async {
    reading = true
    defer { reading = false }
    let parsed = await Task.detached(priority: .userInitiated) { try? BackupManager.readBackup(at: url) }.value
    if let parsed {
      pendingRestore = PendingRestore(source: source, state: parsed)
    } else {
      store.toast("无法识别这份备份")
    }
  }

  private func isPresented<T>(_ binding: Binding<T?>) -> Binding<Bool> {
    Binding(get: { binding.wrappedValue != nil }, set: { if !$0 { binding.wrappedValue = nil } })
  }
}

// MARK: - Diagnostics

struct DiagnosticsSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var reports: [URL] = []

  var body: some View {
    let state = store.state
    let noteCount = state.notes.values.reduce(0) { $0 + $1.count }
    NavigationStack {
      Form {
        Section("应用") {
          LabeledContent("版本", value: "\(AppInfo.version) (\(AppInfo.build))")
          LabeledContent("系统", value: "iOS \(UIDevice.current.systemVersion)")
        }
        Section("数据") {
          LabeledContent("事项", value: "\(state.tasks.count)")
          LabeledContent("记录", value: "\(noteCount) 条 · \(state.notes.count) 天")
          LabeledContent("计划", value: "\(state.plans.count)")
          LabeledContent("照片、视频和录音", value: "\(state.referencedPhotos.count) 个 · \(MediaStore.totalSizeText)")
          LabeledContent("存储", value: Storage.shared.lastError == nil ? "正常" : "有错误")
          if let error = Storage.shared.lastError {
            Text(error).font(.app(.caption)).foregroundStyle(.red)
          }
        }
        Section {
          if reports.isEmpty {
            Text("没有崩溃或卡顿报告").foregroundStyle(.secondary)
          } else {
            ForEach(reports, id: \.self) { url in
              ShareLink(item: url) {
                Label(url.deletingPathExtension().lastPathComponent, systemImage: "doc.text.magnifyingglass")
                  .lineLimit(1)
              }
            }
            Button("清除报告", role: .destructive) {
              Diagnostics.shared.clear()
              reports = []
            }
          }
        } header: {
          Text("崩溃与卡顿报告")
        } footer: {
          Text("由系统 MetricKit 收集，只保存在本机。遇到问题时，可以点一份报告分享给开发者。")
        }
      }
      .navigationTitle("诊断信息")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
      }
      .onAppear { reports = Diagnostics.shared.reports }
    }
  }
}
