import Combine
import SwiftUI
import UIKit

// MARK: - Design tokens

/// One spacing scale for every screen, so pages share the same rhythm.
enum Spacing {
  /// Side margins of a page.
  static let page: CGFloat = 16
  /// Between page sections.
  static let section: CGFloat = 24
  /// Between sibling cards.
  static let stack: CGFloat = 12
  /// Between a section title and its content.
  static let title: CGFloat = 10
  /// Padding inside cards.
  static let card: CGFloat = 16
  /// Between elements inside a card.
  static let inner: CGFloat = 12
}

enum Radius {
  static let card: CGFloat = 20
  static let flatCard: CGFloat = 12
}

// MARK: - Journal type

extension Font {
  /// Song typeface for journal content (greetings, notes, memories). Scales with Dynamic Type;
  /// tools and settings stay in the system font.
  static func journal(_ style: Font.TextStyle, size: CGFloat, bold: Bool = false) -> Font {
    .custom(bold ? "STSongti-SC-Bold" : "STSongti-SC-Regular", size: size, relativeTo: style)
  }
}

// MARK: - Colors

extension Color {
  init(hex: String) {
    var s = hex.trimmed
    if s.hasPrefix("#") { s.removeFirst() }
    var value: UInt64 = 0x287052
    if s.count == 6, let parsed = UInt64(s, radix: 16) { value = parsed }
    self.init(
      .sRGB,
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255,
      opacity: 1)
  }

  var hexString: String {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
    let c = { (v: CGFloat) in Int((min(max(v, 0), 1) * 255).rounded()) }
    return String(format: "#%02x%02x%02x", c(r), c(g), c(b))
  }

  static let partialDone = Color(hex: "#D7A43C")
}

/// Background and surface colors, ported from the web version's CSS variables.
struct Palette {
  var bg: Color
  var surface: Color
  var line: Color
  var isDark: Bool
  var isMeteor: Bool

  static func make(tone: BgTone, dark: Bool) -> Palette {
    if tone == .meteor {
      return Palette(bg: Color(hex: "#0b1018"), surface: Color(hex: "#151c26"), line: Color(hex: "#2c3949"), isDark: true, isMeteor: true)
    }
    if dark {
      return Palette(bg: Color(hex: "#151a20"), surface: Color(hex: "#20262e"), line: Color(hex: "#323b45"), isDark: true, isMeteor: false)
    }
    switch tone {
    case .cool:
      return Palette(bg: Color(hex: "#f2f5f7"), surface: Color(hex: "#ffffff"), line: Color(hex: "#dfe5e8"), isDark: false, isMeteor: false)
    case .gray:
      return Palette(bg: Color(hex: "#f0f1f1"), surface: Color(hex: "#fbfbfa"), line: Color(hex: "#dedfdd"), isDark: false, isMeteor: false)
    default:
      // Warm paper.
      return Palette(bg: Color(hex: "#f4f0e8"), surface: Color(hex: "#fffcf6"), line: Color(hex: "#e6e0d4"), isDark: false, isMeteor: false)
    }
  }
}

private struct PaletteKey: EnvironmentKey {
  static let defaultValue = Palette.make(tone: .warm, dark: false)
}

private struct VisualStyleKey: EnvironmentKey {
  static let defaultValue = VisualStyle.glass
}

private struct AccentKey: EnvironmentKey {
  static let defaultValue = Color(hex: Settings.defaultAccent)
}

extension EnvironmentValues {
  var palette: Palette {
    get { self[PaletteKey.self] }
    set { self[PaletteKey.self] = newValue }
  }

  var visualStyle: VisualStyle {
    get { self[VisualStyleKey.self] }
    set { self[VisualStyleKey.self] = newValue }
  }

  var accent: Color {
    get { self[AccentKey.self] }
    set { self[AccentKey.self] = newValue }
  }
}

/// True when Liquid Glass should be drawn: the glass style is chosen and the system supports it.
var systemSupportsGlass: Bool {
  if #available(iOS 26.0, *) { return true }
  return false
}

// MARK: - Liquid Glass surfaces

@available(iOS 26.0, *)
private func makeGlass(tint: Color?, interactive: Bool) -> Glass {
  var glass = Glass.regular
  if let tint { glass = glass.tint(tint) }
  if interactive { glass = glass.interactive() }
  return glass
}

private struct SurfaceModifier<S: InsettableShape>: ViewModifier {
  @Environment(\.visualStyle) private var style
  @Environment(\.palette) private var palette
  let shape: S
  var tint: Color?
  var interactive: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if style.usesGlass {
      if #available(iOS 26.0, *) {
        content.glassEffect(makeGlass(tint: tint, interactive: interactive), in: shape)
      } else {
        // Before iOS 26: closest system material.
        content
          .background {
            shape.fill(.ultraThinMaterial)
              .overlay { if let tint { shape.fill(tint.opacity(0.35)) } }
          }
          .overlay { shape.strokeBorder(Color.white.opacity(palette.isDark ? 0.12 : 0.5), lineWidth: 0.6) }
      }
    } else {
      content
        .background { shape.fill(tint ?? palette.surface) }
        .overlay {
          if style == .flat { shape.strokeBorder(palette.line, lineWidth: 1) }
        }
        .shadow(color: .black.opacity(style == .soft && !palette.isDark ? 0.06 : 0), radius: 14, y: 8)
    }
  }
}

extension View {
  /// A content surface: Liquid Glass, or the original soft/flat card.
  func surface(cornerRadius: CGFloat = 22, tint: Color? = nil, interactive: Bool = false) -> some View {
    modifier(SurfaceModifier(
      shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), tint: tint, interactive: interactive))
  }

  func capsuleSurface(tint: Color? = nil, interactive: Bool = false) -> some View {
    modifier(SurfaceModifier(shape: Capsule(), tint: tint, interactive: interactive))
  }

  func circleSurface(tint: Color? = nil, interactive: Bool = false) -> some View {
    modifier(SurfaceModifier(shape: Circle(), tint: tint, interactive: interactive))
  }

  /// Standard card: padding, full width, surface.
  func card(padding: CGFloat = Spacing.card, tint: Color? = nil) -> some View {
    modifier(CardModifier(padding: padding, tint: tint))
  }

  /// Card holding a list of rows: same side inset as `card()`, rows bring their own vertical padding.
  func listCard() -> some View {
    padding(.horizontal, Spacing.card)
      .padding(.vertical, 4)
      .frame(maxWidth: .infinity, alignment: .leading)
      .modifier(CardModifier(padding: 0, tint: nil))
  }

  func oneDayButton(prominent: Bool = false) -> some View {
    modifier(ButtonStyleModifier(prominent: prominent))
  }

  /// Hides the tab bar while scrolling down on iOS 26.
  @ViewBuilder
  func tabBarMinimizesOnScroll() -> some View {
    if #available(iOS 26.0, *) {
      tabBarMinimizeBehavior(.onScrollDown)
    } else {
      self
    }
  }

  func fieldBackground() -> some View {
    modifier(FieldModifier())
  }
}

private struct CardModifier: ViewModifier {
  @Environment(\.visualStyle) private var style
  var padding: CGFloat
  var tint: Color?

  func body(content: Content) -> some View {
    content
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .surface(cornerRadius: style == .flat ? Radius.flatCard : Radius.card, tint: tint)
  }
}

private struct ButtonStyleModifier: ViewModifier {
  @Environment(\.visualStyle) private var style
  var prominent: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if style.usesGlass, systemSupportsGlass {
      if #available(iOS 26.0, *) {
        if prominent {
          content.buttonStyle(.glassProminent)
        } else {
          content.buttonStyle(.glass)
        }
      }
    } else if prominent {
      content.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
    } else {
      content.buttonStyle(.bordered).buttonBorderShape(.capsule)
    }
  }
}

private struct FieldModifier: ViewModifier {
  @Environment(\.palette) private var palette
  @Environment(\.visualStyle) private var style

  func body(content: Content) -> some View {
    content
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(style.usesGlass ? AnyShapeStyle(Color.primary.opacity(0.06)) : AnyShapeStyle(palette.bg))
      }
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(style.usesGlass ? Color.primary.opacity(0.08) : palette.line, lineWidth: 1)
      }
  }
}

/// Groups nearby glass shapes so they blend and morph together (iOS 26).
struct GlassGroup<Inner: View>: View {
  @Environment(\.visualStyle) private var style
  var spacing: CGFloat = 12
  @ViewBuilder var content: () -> Inner

  var body: some View {
    if style.usesGlass {
      if #available(iOS 26.0, *) {
        GlassEffectContainer(spacing: spacing) { content() }
      } else {
        content()
      }
    } else {
      content()
    }
  }
}

// MARK: - Interface size

/// Steps the system Dynamic Type size so "standard" keeps following the user's setting.
/// Reads the real system size (not the inherited one), so applying it again inside a sheet
/// gives the same result instead of stepping twice.
struct UISizeModifier: ViewModifier {
  let size: UISize
  @State private var system = UISizeModifier.currentSystemSize

  private static var currentSystemSize: DynamicTypeSize {
    DynamicTypeSize(UIApplication.shared.preferredContentSizeCategory) ?? .large
  }

  func body(content: Content) -> some View {
    content
      .dynamicTypeSize(resolved)
      .onReceive(NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification)) { _ in
        system = Self.currentSystemSize
      }
  }

  private var resolved: DynamicTypeSize {
    let all = DynamicTypeSize.allCases
    let index = all.firstIndex(of: system) ?? all.firstIndex(of: .large) ?? 3
    let step = size == .compact ? -2 : size == .large ? 2 : 0
    return all[min(max(index + step, 0), all.count - 1)]
  }
}

/// Sheets are hosted separately and do not inherit the interface size, so each one reapplies it.
private struct SheetStyleModifier: ViewModifier {
  @Environment(Store.self) private var store

  func body(content: Content) -> some View {
    content.modifier(UISizeModifier(size: store.settings.uiSize))
  }
}

extension View {
  func oneDaySheet() -> some View { modifier(SheetStyleModifier()) }
}

// MARK: - Background

struct AppBackground: View {
  @Environment(\.palette) private var palette
  @Environment(\.visualStyle) private var style
  @Environment(\.accent) private var accent

  var body: some View {
    ZStack {
      palette.bg
      if palette.isMeteor {
        MeteorSky()
      } else if style.usesGlass {
        // One quiet wash of the accent color gives Liquid Glass something to refract.
        LinearGradient(
          colors: [accent.opacity(palette.isDark ? 0.16 : 0.10), .clear, Color(hex: palette.isDark ? "#3b5f8e" : "#e9c79c").opacity(palette.isDark ? 0.10 : 0.14)],
          startPoint: .topTrailing,
          endPoint: .bottomLeading)
      }
    }
    .ignoresSafeArea()
  }
}

/// The web version's "流星夜" background: a few stars and two meteor streaks.
struct MeteorSky: View {
  private static let stars: [(CGFloat, CGFloat, CGFloat)] = [
    (0.12, 0.20, 1.2), (0.81, 0.14, 1.0), (0.63, 0.42, 1.1), (0.31, 0.66, 0.9),
    (0.48, 0.09, 0.8), (0.9, 0.58, 0.9), (0.2, 0.86, 0.8), (0.72, 0.78, 1.0),
    (0.05, 0.45, 0.7), (0.56, 0.27, 0.7), (0.38, 0.33, 0.6), (0.94, 0.33, 0.6),
  ]

  var body: some View {
    Canvas { ctx, size in
      let glow = Gradient(colors: [Color(hex: "#3b5f8e").opacity(0.35), .clear])
      ctx.fill(
        Path(ellipseIn: CGRect(x: -size.width * 0.2, y: -size.height * 0.1, width: size.width * 0.9, height: size.height * 0.45)),
        with: .radialGradient(glow, center: CGPoint(x: size.width * 0.22, y: size.height * 0.12), startRadius: 0, endRadius: size.width * 0.6))
      for (x, y, r) in Self.stars {
        ctx.fill(
          Path(ellipseIn: CGRect(x: x * size.width, y: y * size.height, width: r * 2, height: r * 2)),
          with: .color(.white.opacity(0.8)))
      }
      drawMeteor(ctx, from: CGPoint(x: size.width * 0.78, y: size.height * 0.1), length: size.width * 0.55, width: 1.6)
      drawMeteor(ctx, from: CGPoint(x: size.width * 0.95, y: size.height * 0.3), length: size.width * 0.35, width: 1)
    }
  }

  private func drawMeteor(_ ctx: GraphicsContext, from head: CGPoint, length: CGFloat, width: CGFloat) {
    let tail = CGPoint(x: head.x - length * 0.88, y: head.y + length * 0.48)
    var path = Path()
    path.move(to: head)
    path.addLine(to: tail)
    ctx.stroke(
      path,
      with: .linearGradient(
        Gradient(colors: [Color(hex: "#e1efff").opacity(0.9), Color(hex: "#86b2e3").opacity(0)]),
        startPoint: head, endPoint: tail),
      style: StrokeStyle(lineWidth: width, lineCap: .round))
  }
}
