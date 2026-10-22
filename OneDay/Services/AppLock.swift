import CryptoKit
import LocalAuthentication
import Observation
import Security
import SwiftUI
import UIKit

enum PasscodeKind: String, CaseIterable, Identifiable {
  case digits6, password
  var id: String { rawValue }
  var label: String { self == .digits6 ? "6 位数字密码" : "字母数字密码" }
}

enum AutoLock: Int, CaseIterable, Identifiable {
  case immediately = 0, oneMinute = 60, fiveMinutes = 300, fifteenMinutes = 900
  var id: Int { rawValue }
  var label: String {
    switch self {
    case .immediately: "立即"
    case .oneMinute: "1 分钟后"
    case .fiveMinutes: "5 分钟后"
    case .fifteenMinutes: "15 分钟后"
    }
  }
}

/// Passcode and Face ID lock. The passcode is stored only as a salted SHA-256 hash in the Keychain
/// (this device only), and the lock screen lives in its own window so it also covers open sheets.
@MainActor
@Observable
final class AppLock {
  static let shared = AppLock()

  private(set) var isLocked = false
  private(set) var isEnabled = false
  private(set) var kind: PasscodeKind = .digits6
  private(set) var failedAttempts = 0
  private(set) var lockedUntil: Date?
  var biometricsEnabled: Bool {
    didSet { UserDefaults.standard.set(biometricsEnabled, forKey: "lock.biometrics") }
  }
  var autoLock: AutoLock {
    didSet { UserDefaults.standard.set(autoLock.rawValue, forKey: "lock.auto") }
  }

  @ObservationIgnored private var backgroundedAt: Date?
  @ObservationIgnored private var coverShown = false

  private init() {
    biometricsEnabled = UserDefaults.standard.bool(forKey: "lock.biometrics")
    autoLock = AutoLock(rawValue: UserDefaults.standard.integer(forKey: "lock.auto")) ?? .immediately
    // Keychain items outlive an uninstall; a fresh install must not inherit an old passcode.
    if !UserDefaults.standard.bool(forKey: "lock.installed") {
      Keychain.delete()
      UserDefaults.standard.set(true, forKey: "lock.installed")
    }
    if let stored = Keychain.read() {
      isEnabled = true
      kind = PasscodeKind(rawValue: stored.kind) ?? .digits6
      isLocked = true
    }
    #if DEBUG
    if UserDefaults.standard.bool(forKey: "OneDayLockPreview") {
      setPasscode("123456", kind: .digits6)
      isLocked = true
    } else if UserDefaults.standard.bool(forKey: "OneDayDemo") {
      removePasscode()
    }
    #endif
  }

  // MARK: Biometrics

  var biometryType: LABiometryType {
    let context = LAContext()
    _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    return context.biometryType
  }

  var biometryName: String {
    switch biometryType {
    case .faceID: "面容 ID"
    case .touchID: "触控 ID"
    case .opticID: "视线 ID"
    default: "生物识别"
    }
  }

  var biometryIcon: String {
    switch biometryType {
    case .touchID: "touchid"
    case .opticID: "opticid"
    default: "faceid"
    }
  }

  var canUseBiometrics: Bool { biometryType != .none }

  func unlockWithBiometrics() async {
    guard isLocked, biometricsEnabled, canUseBiometrics else { return }
    let context = LAContext()
    context.localizedFallbackTitle = "输入密码"
    let ok = (try? await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "解锁「一天」")) ?? false
    if ok { unlocked() }
  }

  // MARK: Passcode

  func setPasscode(_ code: String, kind: PasscodeKind) {
    var salt = Data(count: 16)
    _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
    Keychain.write(.init(kind: kind.rawValue, salt: salt, hash: Self.hash(code, salt: salt)))
    self.kind = kind
    isEnabled = true
    failedAttempts = 0
  }

  func removePasscode() {
    Keychain.delete()
    isEnabled = false
    isLocked = false
    biometricsEnabled = false
    hideWindow()
  }

  func verify(_ code: String) -> Bool {
    guard let stored = Keychain.read() else { return false }
    return Self.hash(code, salt: stored.salt) == stored.hash
  }

  /// Returns false on a wrong code; repeated failures add a growing wait.
  @discardableResult
  func unlock(with code: String) -> Bool {
    if let until = lockedUntil, until > Date() { return false }
    if verify(code) {
      unlocked()
      return true
    }
    failedAttempts += 1
    if failedAttempts >= 5 {
      let wait = min(Double(failedAttempts - 4) * 30, 900)
      lockedUntil = Date().addingTimeInterval(wait)
    }
    UINotificationFeedbackGenerator().notificationOccurred(.error)
    return false
  }

  private func unlocked() {
    isLocked = false
    failedAttempts = 0
    lockedUntil = nil
    hideWindow()
  }

  /// "Forgot passcode": the only way back in without the code is to erase everything.
  func eraseAndReset() {
    Store.shared.restoreAll()
    removePasscode()
  }

  private static func hash(_ code: String, salt: Data) -> Data {
    Data(SHA256.hash(data: salt + Data(code.utf8)))
  }

  // MARK: Scene lifecycle

  func sceneWillResignActive() {
    guard isEnabled else { return }
    showWindow()
  }

  func sceneDidEnterBackground() {
    guard isEnabled else { return }
    if backgroundedAt == nil { backgroundedAt = Date() }
    showWindow()
  }

  func sceneDidBecomeActive() {
    guard isEnabled else { return }
    if let since = backgroundedAt, Date().timeIntervalSince(since) >= Double(autoLock.rawValue) {
      isLocked = true
    }
    backgroundedAt = nil
    if isLocked {
      showWindow()
      Task { await unlockWithBiometrics() }
    } else {
      hideWindow()
    }
  }

  // MARK: Overlay window

  @ObservationIgnored private var window: UIWindow?

  private func showWindow() {
    guard window == nil else { return }
    guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
    let host = UIHostingController(rootView: LockScreen().environment(Store.shared))
    host.view.backgroundColor = .clear
    let w = UIWindow(windowScene: scene)
    w.windowLevel = .alert + 1
    w.rootViewController = host
    w.makeKeyAndVisible()
    window = w
  }

  private func hideWindow() {
    guard let w = window else { return }
    UIView.animate(withDuration: 0.25, animations: { w.alpha = 0 }, completion: { _ in
      w.isHidden = true
      w.windowScene?.windows.first { $0 !== w }?.makeKey()
    })
    window = nil
  }
}

/// Minimal Keychain wrapper for the single passcode record.
private enum Keychain {
  struct Record: Codable {
    var kind: String
    var salt: Data
    var hash: Data
  }

  private static let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.oneday.app.lock",
    kSecAttrAccount as String: "passcode",
  ]

  static func read() -> Record? {
    var q = query
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
    return try? JSONDecoder().decode(Record.self, from: data)
  }

  static func write(_ record: Record) {
    delete()
    guard let data = try? JSONEncoder().encode(record) else { return }
    var q = query
    q[kSecValueData as String] = data
    q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    SecItemAdd(q as CFDictionary, nil)
  }

  static func delete() {
    SecItemDelete(query as CFDictionary)
  }
}
