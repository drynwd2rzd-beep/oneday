import SwiftUI

/// Keypad for 6-digit codes, or a secure field for passwords. Calls `onSubmit` with the full code.
struct PasscodeEntry: View {
  @Environment(\.accent) private var accent
  let kind: PasscodeKind
  var showsBiometrics = false
  var biometryIcon = "faceid"
  var onBiometrics: () -> Void = {}
  let onSubmit: (String) -> Void
  @Binding var errorCount: Int
  @State private var code = ""
  @FocusState private var fieldFocused: Bool

  var body: some View {
    VStack(spacing: 28) {
      if kind == .digits6 {
        HStack(spacing: 18) {
          ForEach(0..<6, id: \.self) { i in
            Circle()
              .fill(i < code.count ? Color.primary : .clear)
              .overlay { Circle().strokeBorder(Color.primary.opacity(0.6), lineWidth: 1.2) }
              .frame(width: 13, height: 13)
          }
        }
        .keyframeAnimator(initialValue: 0.0, trigger: errorCount) { content, x in
          content.offset(x: x)
        } keyframes: { _ in
          KeyframeTrack {
            LinearKeyframe(-14, duration: 0.06)
            LinearKeyframe(12, duration: 0.08)
            LinearKeyframe(-8, duration: 0.08)
            LinearKeyframe(5, duration: 0.07)
            LinearKeyframe(0, duration: 0.06)
          }
        }
        .accessibilityElement()
        .accessibilityLabel("已输入 \(code.count) 位，共 6 位")
        keypad
      } else {
        HStack(spacing: 10) {
          SecureField("密码", text: $code)
            .textContentType(.password)
            .focused($fieldFocused)
            .submitLabel(.go)
            .onSubmit(submit)
            .fieldBackground()
          Button(action: submit) {
            Image(systemName: "arrow.right").font(.body.weight(.semibold)).frame(width: 22, height: 22)
          }
          .oneDayButton(prominent: true)
          .buttonBorderShape(.circle)
          .disabled(code.count < 4)
          .accessibilityLabel("确定")
        }
        .keyframeAnimator(initialValue: 0.0, trigger: errorCount) { content, x in
          content.offset(x: x)
        } keyframes: { _ in
          KeyframeTrack {
            LinearKeyframe(-12, duration: 0.06)
            LinearKeyframe(10, duration: 0.08)
            LinearKeyframe(0, duration: 0.08)
          }
        }
        .onAppear { fieldFocused = true }
        if showsBiometrics {
          Button(action: onBiometrics) {
            Image(systemName: biometryIcon).font(.title)
          }
          .accessibilityLabel("使用生物识别解锁")
        }
      }
    }
    .onChange(of: errorCount) { _, _ in code = "" }
  }

  private var keypad: some View {
    let rows: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["bio", "0", "del"]]
    return VStack(spacing: 14) {
      ForEach(rows, id: \.self) { row in
        HStack(spacing: 22) {
          ForEach(row, id: \.self) { key in
            keyButton(key)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func keyButton(_ key: String) -> some View {
    switch key {
    case "bio":
      if showsBiometrics {
        Button(action: onBiometrics) {
          Image(systemName: biometryIcon).font(.title2).frame(width: 76, height: 76)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("使用生物识别解锁")
      } else {
        Color.clear.frame(width: 76, height: 76)
      }
    case "del":
      Button {
        if !code.isEmpty { code.removeLast() }
      } label: {
        Image(systemName: "delete.left").font(.title2).frame(width: 76, height: 76)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("删除")
    default:
      Button {
        guard code.count < 6 else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        code.append(key)
        if code.count == 6 { submit() }
      } label: {
        Text(key)
          .font(.system(size: 32, weight: .regular, design: .rounded))
          .frame(width: 76, height: 76)
          .circleSurface(interactive: true)
      }
      .buttonStyle(.plain)
    }
  }

  private func submit() {
    let value = code
    guard kind == .digits6 ? value.count == 6 : value.count >= 4 else { return }
    onSubmit(value)
  }
}

/// Shown in its own window above everything (see `AppLock`), also as the app-switcher privacy cover.
struct LockScreen: View {
  @Environment(Store.self) private var store
  private var lock: AppLock { AppLock.shared }
  @State private var errors = 0
  @State private var confirmForgot = false
  @State private var now = Date()

  var body: some View {
    ZStack {
      Color(uiColor: .systemBackground).ignoresSafeArea()
      LinearGradient(colors: [store.accentColor.opacity(0.16), .clear], startPoint: .top, endPoint: .center)
        .ignoresSafeArea()
      if lock.isLocked {
        unlockContent
      } else {
        Image("Logo")
          .resizable()
          .frame(width: 84, height: 84)
          .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
          .accessibilityLabel("一天")
      }
    }
    .environment(\.accent, store.accentColor)
    .environment(\.visualStyle, store.settings.cardStyle)
    .tint(store.accentColor)
    .preferredColorScheme(store.preferredColorScheme)
    .oneDaySheet()
  }

  private var unlockContent: some View {
    VStack(spacing: 24) {
      Spacer()
      Image("Logo")
        .resizable()
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
      VStack(spacing: 6) {
        Text(lock.kind == .digits6 ? "输入密码" : "输入密码解锁").font(.title3.weight(.semibold))
        Text(statusText)
          .font(.subheadline)
          .foregroundStyle(lock.failedAttempts > 0 ? Color.red : .secondary)
          .contentTransition(.numericText())
      }
      PasscodeEntry(
        kind: lock.kind,
        showsBiometrics: lock.biometricsEnabled && lock.canUseBiometrics,
        biometryIcon: lock.biometryIcon,
        onBiometrics: { Task { await lock.unlockWithBiometrics() } },
        onSubmit: { code in
          if !lock.unlock(with: code) { errors += 1 }
        },
        errorCount: $errors
      )
      .disabled(isWaiting)
      .opacity(isWaiting ? 0.4 : 1)
      Spacer()
      Button("忘记密码？") { confirmForgot = true }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(24)
    .task {
      while !Task.isCancelled {
        now = Date()
        try? await Task.sleep(for: .seconds(1))
      }
    }
    .alert("忘记密码", isPresented: $confirmForgot) {
      Button("清除全部数据并重置", role: .destructive) { lock.eraseAndReset() }
      Button("取消", role: .cancel) {}
    } message: {
      Text("密码只保存在这台设备上，无法找回。只能清除「一天」的全部数据后重新开始。如果开启了备份文件夹，之后可以从备份恢复。")
    }
  }

  private var isWaiting: Bool {
    if let until = lock.lockedUntil { return until > now }
    return false
  }

  private var statusText: String {
    if let until = lock.lockedUntil, until > now {
      return "尝试次数过多，请 \(Int(until.timeIntervalSince(now).rounded(.up))) 秒后再试"
    }
    if lock.failedAttempts > 0 { return "密码错误，已尝试 \(lock.failedAttempts) 次" }
    return lock.biometricsEnabled && lock.canUseBiometrics ? "或使用\(lock.biometryName)" : "「一天」已锁定"
  }
}

/// Set or change the passcode: choose a type, enter it twice.
struct PasscodeSetupSheet: View {
  @Environment(\.dismiss) private var dismiss
  var onDone: () -> Void = {}
  @State private var kind: PasscodeKind = .digits6
  @State private var first: String?
  @State private var errors = 0
  @State private var mismatch = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 22) {
        Picker("密码类型", selection: $kind) {
          ForEach(PasscodeKind.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .disabled(first != nil)
        VStack(spacing: 6) {
          Text(first == nil ? "设置新密码" : "再输入一次").font(.title3.weight(.semibold))
          Text(mismatch ? "两次输入不一致，请重新设置" : kind == .digits6 ? "输入 6 位数字" : "至少 4 位，可包含字母和数字")
            .font(.subheadline)
            .foregroundStyle(mismatch ? Color.red : .secondary)
        }
        PasscodeEntry(kind: kind, onSubmit: handle, errorCount: $errors)
          .id("\(kind.rawValue)-\(first == nil)")
        Spacer()
      }
      .padding(24)
      .navigationTitle("密码锁")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
      }
    }
    .interactiveDismissDisabled()
  }

  private func handle(_ code: String) {
    guard let first else {
      self.first = code
      mismatch = false
      return
    }
    if code == first {
      AppLock.shared.setPasscode(code, kind: kind)
      Haptics.success()
      onDone()
      dismiss()
    } else {
      mismatch = true
      self.first = nil
      errors += 1
    }
  }
}

/// Asks for the current passcode before turning the lock off or changing it.
struct PasscodeVerifySheet: View {
  @Environment(\.dismiss) private var dismiss
  let title: String
  let onVerified: () -> Void
  @State private var errors = 0

  var body: some View {
    NavigationStack {
      VStack(spacing: 22) {
        Text(errors > 0 ? "密码错误，请重试" : "输入当前密码")
          .font(.title3.weight(.semibold))
          .foregroundStyle(errors > 0 ? Color.red : .primary)
        PasscodeEntry(kind: AppLock.shared.kind, onSubmit: { code in
          if AppLock.shared.verify(code) {
            dismiss()
            onVerified()
          } else {
            errors += 1
            Haptics.warning()
          }
        }, errorCount: $errors)
        Spacer()
      }
      .padding(24)
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
      }
    }
  }
}
