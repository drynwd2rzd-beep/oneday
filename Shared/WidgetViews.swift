import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Look

/// Cream paper, cocoa ink and the user's accent: soft, sticker-like colors for the widgets.
struct CuteTheme {
  let bg: Color
  let bgSpot: Color
  let card: Color
  let ink: Color
  let soft: Color
  let line: Color
  let accent: Color

  static func make(_ scheme: ColorScheme, accent hex: String) -> CuteTheme {
    let accent = Color.fromHex(hex) ?? Color(red: 0.16, green: 0.44, blue: 0.32)
    if scheme == .dark {
      return CuteTheme(
        bg: Color(red: 0.17, green: 0.14, blue: 0.13), bgSpot: Color(red: 1, green: 0.8, blue: 0.4).opacity(0.08),
        card: Color.white.opacity(0.07), ink: Color(red: 1, green: 0.95, blue: 0.87),
        soft: Color(red: 0.76, green: 0.67, blue: 0.57), line: Color.white.opacity(0.14), accent: accent)
    }
    return CuteTheme(
      bg: Color(red: 1, green: 0.965, blue: 0.9), bgSpot: Color(red: 1, green: 0.8, blue: 0.4).opacity(0.18),
      card: Color.white.opacity(0.75), ink: Color(red: 0.29, green: 0.2, blue: 0.15),
      soft: Color(red: 0.6, green: 0.52, blue: 0.45), line: Color(red: 0.94, green: 0.87, blue: 0.77), accent: accent)
  }
}

extension Color {
  /// `#rrggbb`, or nil.
  static func fromHex(_ hex: String) -> Color? {
    let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
    return Color(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
  }
}

private extension Font {
  static func cute(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
    .system(size: size, weight: weight, design: .rounded)
  }
}

/// Paper with two soft sun spots.
struct CuteBackground: View {
  let theme: CuteTheme

  var body: some View {
    ZStack {
      theme.bg
      GeometryReader { geo in
        Circle().fill(theme.bgSpot)
          .frame(width: geo.size.width * 0.7)
          .position(x: geo.size.width * 1.0, y: geo.size.height * 1.05)
        Circle().fill(theme.bgSpot)
          .frame(width: geo.size.width * 0.28)
          .position(x: geo.size.width * 0.02, y: geo.size.height * 0.02)
      }
    }
  }
}

// MARK: - Widget content

/// Everything a OneDay widget can show, chosen by family. Shared by the widget extension and the
/// in-app preview (where `interactive` is false).
struct OneDayWidgetView: View {
  @Environment(\.colorScheme) private var scheme
  let family: WidgetFamily
  let snapshot: WidgetSnapshot
  let date: Date
  var interactive = true
  /// Replaces 小日's line when there is nothing to show (no shared data yet, or none possible).
  var notice: String?

  var body: some View {
    let theme = CuteTheme.make(scheme, accent: snapshot.accent)
    let mood = MascotMood.of(snapshot, at: date)
    switch family {
    case .accessoryCircular: circular
    case .accessoryRectangular: rectangular
    case .accessoryInline: inline
    case .systemMedium: MediumCute(snapshot: snapshot, mood: mood, theme: theme, interactive: interactive, notice: notice)
    case .systemLarge, .systemExtraLarge:
      LargeCute(snapshot: snapshot, mood: mood, theme: theme, date: date, interactive: interactive, notice: notice)
    default: SmallCute(snapshot: snapshot, mood: mood, theme: theme, notice: notice)
    }
  }

  private var circular: some View {
    Gauge(value: snapshot.progress) {
      Image(systemName: "sun.max.fill")
    } currentValueLabel: {
      if snapshot.total == 0 {
        Image(systemName: "sun.max.fill")
      } else if snapshot.allDone {
        Image(systemName: "checkmark")
      } else {
        Text("\(snapshot.doneCount)/\(snapshot.total)").font(.cute(13, .heavy))
      }
    }
    .gaugeStyle(.accessoryCircularCapacity)
    .widgetAccentable()
  }

  private var rectangular: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 4) {
        Image(systemName: snapshot.allDone ? "checkmark.seal.fill" : "sun.max.fill")
        Text(snapshot.total == 0 ? "今天" : "今天 \(snapshot.doneCount)/\(snapshot.total)")
      }
      .font(.cute(15, .heavy))
      .widgetAccentable()
      Text(nextLine)
        .font(.cute(13, .semibold))
        .lineLimit(1)
      if snapshot.total > 0 {
        ProgressView(value: snapshot.progress).tint(.primary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var inline: some View {
    Label(
      snapshot.total == 0 ? "今天很自由" : "今天 \(snapshot.doneCount)/\(snapshot.total) · \(snapshot.next?.title ?? "全部完成")",
      systemImage: "sun.max")
  }

  private var nextLine: String {
    if let next = snapshot.next { return "下一件：\(next.title)" }
    return snapshot.allDone ? "全部完成啦 ✿" : "今天没有安排"
  }
}

// MARK: Small

private struct SmallCute: View {
  let snapshot: WidgetSnapshot
  let mood: MascotMood
  let theme: CuteTheme
  let notice: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .top, spacing: 0) {
        MascotView(mood: mood, size: 64)
          .offset(x: -4, y: -4)
        Spacer(minLength: 0)
        VStack(alignment: .trailing, spacing: -2) {
          Text(snapshot.total == 0 ? "–" : "\(snapshot.doneCount)/\(snapshot.total)")
            .font(.cute(26, .heavy))
            .foregroundStyle(theme.ink)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
          Text("今天")
            .font(.cute(12))
            .foregroundStyle(theme.soft)
        }
      }
      Spacer(minLength: 0)
      SpeechBubble(text: notice ?? mood.line(for: snapshot), theme: theme, size: 13)
      ChunkyBar(progress: snapshot.progress, theme: theme)
    }
    .widgetURL(URL(string: "oneday://today"))
  }
}

// MARK: Medium

private struct MediumCute: View {
  let snapshot: WidgetSnapshot
  let mood: MascotMood
  let theme: CuteTheme
  let interactive: Bool
  let notice: String?

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(spacing: 6) {
        MascotView(mood: mood, size: 74)
        Text(notice ?? mood.line(for: snapshot))
          .font(.cute(12))
          .foregroundStyle(theme.ink)
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .minimumScaleFactor(0.8)
        ChunkyBar(progress: snapshot.progress, theme: theme)
      }
      .frame(width: 104)

      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .firstTextBaseline) {
          Text("今天").font(.cute(16, .heavy)).foregroundStyle(theme.ink)
          Spacer()
          if snapshot.total > 0 {
            Text("\(snapshot.doneCount)/\(snapshot.total)")
              .font(.cute(13, .heavy))
              .foregroundStyle(theme.accent)
          }
        }
        if snapshot.total == 0 {
          Spacer(minLength: 0)
          Text("没有安排的事项，\n留下一点今天吧。")
            .font(.cute(13, .semibold))
            .foregroundStyle(theme.soft)
          CaptureLink(theme: theme)
          Spacer(minLength: 0)
        } else {
          ForEach(snapshot.today.prefix(4)) { task in
            TaskLine(task: task, day: snapshot.day, theme: theme, interactive: interactive)
          }
          if snapshot.total > 4 {
            Text("还有 \(snapshot.total - 4) 件…")
              .font(.cute(11, .semibold))
              .foregroundStyle(theme.soft)
          }
          Spacer(minLength: 0)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .widgetURL(URL(string: "oneday://today"))
  }
}

// MARK: Large

private struct LargeCute: View {
  let snapshot: WidgetSnapshot
  let mood: MascotMood
  let theme: CuteTheme
  let date: Date
  let interactive: Bool
  let notice: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        MascotView(mood: mood, size: 72)
        VStack(alignment: .leading, spacing: 4) {
          Text(greeting).font(.cute(20, .heavy)).foregroundStyle(theme.ink)
          SpeechBubble(text: notice ?? mood.line(for: snapshot), theme: theme, size: 12)
        }
        Spacer(minLength: 0)
        ProgressRing(snapshot: snapshot, theme: theme)
          .frame(width: 54, height: 54)
      }

      VStack(alignment: .leading, spacing: 7) {
        if snapshot.total == 0 {
          Text("今天没有安排的事项。")
            .font(.cute(14, .semibold))
            .foregroundStyle(theme.soft)
            .frame(maxWidth: .infinity, minHeight: 60)
        } else {
          ForEach(snapshot.today.prefix(6)) { task in
            TaskLine(task: task, day: snapshot.day, theme: theme, interactive: interactive)
          }
          if snapshot.total > 6 {
            Text("还有 \(snapshot.total - 6) 件…").font(.cute(11, .semibold)).foregroundStyle(theme.soft)
          }
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(theme.line, lineWidth: 1.5))

      Spacer(minLength: 0)

      HStack(spacing: 8) {
        Sticker(theme: theme) {
          Image(systemName: "flame.fill").foregroundStyle(Color(red: 1, green: 0.55, blue: 0.25))
          Text(snapshot.streakDays > 0 ? "连续 \(snapshot.streakDays) 天" : "开始打卡").font(.cute(13, .heavy))
          Text(snapshot.streakTitle ?? "每日事项").font(.cute(10, .semibold)).foregroundStyle(theme.soft).lineLimit(1)
        }
        Sticker(theme: theme) {
          WeekBars(week: snapshot.week, theme: theme).frame(height: 22)
          Text("最近 7 天").font(.cute(10, .semibold)).foregroundStyle(theme.soft)
        }
        if snapshot.wroteToday {
          Sticker(theme: theme) {
            Text(snapshot.mood.map(Self.face) ?? "📝").font(.system(size: 18))
            Text("写了记录").font(.cute(13, .heavy))
            Text("今天").font(.cute(10, .semibold)).foregroundStyle(theme.soft)
          }
        } else {
          Link(destination: URL(string: "oneday://capture")!) {
            Sticker(theme: theme, highlighted: true) {
              Image(systemName: "square.and.pencil").foregroundStyle(theme.accent)
              Text("写一条").font(.cute(13, .heavy))
              Text("留下今天").font(.cute(10, .semibold)).foregroundStyle(theme.soft)
            }
          }
        }
      }
      .foregroundStyle(theme.ink)
    }
    .widgetURL(URL(string: "oneday://today"))
  }

  private var greeting: String {
    switch SharedDay.calendar.component(.hour, from: date) {
    case 5..<11: "早上好"
    case 11..<13: "中午好"
    case 13..<18: "下午好"
    case 18..<22: "晚上好"
    default: "夜深了"
    }
  }

  static func face(_ mood: Int) -> String {
    ["😞", "🙁", "😐", "🙂", "😄"][min(max(mood, 1), 5) - 1]
  }
}

// MARK: - Pieces

private struct TaskLine: View {
  let task: WidgetTask
  let day: String
  let theme: CuteTheme
  let interactive: Bool

  var body: some View {
    HStack(spacing: 8) {
      if interactive {
        Button(intent: ToggleTaskIntent(taskId: task.id, day: day)) { checkbox }
          .buttonStyle(.plain)
      } else {
        checkbox
      }
      Text(task.title)
        .font(.cute(14, .semibold))
        .strikethrough(task.done, color: theme.soft)
        .foregroundStyle(task.done ? theme.soft : theme.ink)
        .lineLimit(1)
      Spacer(minLength: 0)
      if let color = task.color.flatMap(Color.fromHex) {
        Circle().fill(color).frame(width: 6, height: 6)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityValue(task.done ? "已完成" : "未完成")
  }

  private var checkbox: some View {
    ZStack {
      Circle()
        .fill(task.done ? theme.accent : theme.card)
      Circle()
        .stroke(task.done ? theme.accent : theme.soft.opacity(0.7), lineWidth: 2)
      if task.done {
        Image(systemName: "checkmark")
          .font(.system(size: 10, weight: .black))
          .foregroundStyle(.white)
      }
    }
    .frame(width: 20, height: 20)
  }
}

/// A rounded speech bubble with a little tail, pointing up-left at 小日.
private struct SpeechBubble: View {
  let text: String
  let theme: CuteTheme
  var size: CGFloat = 13

  var body: some View {
    Text(text)
      .font(.cute(size))
      .foregroundStyle(theme.ink)
      .lineLimit(1)
      .minimumScaleFactor(0.75)
      .padding(.horizontal, 9)
      .padding(.vertical, 5)
      .background(theme.card, in: Capsule())
      .overlay(Capsule().stroke(theme.line, lineWidth: 1.5))
  }
}

/// A thick, rounded progress bar with an outline, like a sticker.
private struct ChunkyBar: View {
  let progress: Double
  let theme: CuteTheme

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(theme.line.opacity(0.7))
        Capsule()
          .fill(theme.accent)
          .frame(width: progress <= 0 ? 0 : max(10, geo.size.width * progress))
      }
    }
    .frame(height: 9)
    .accessibilityLabel("完成进度")
    .accessibilityValue("\(Int((progress * 100).rounded()))%")
  }
}

private struct ProgressRing: View {
  let snapshot: WidgetSnapshot
  let theme: CuteTheme

  var body: some View {
    ZStack {
      Circle().stroke(theme.line, lineWidth: 7)
      Circle()
        .trim(from: 0, to: snapshot.progress)
        .stroke(theme.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
        .rotationEffect(.degrees(-90))
      if snapshot.allDone {
        Image(systemName: "checkmark").font(.system(size: 18, weight: .black)).foregroundStyle(theme.accent)
      } else {
        Text(snapshot.total == 0 ? "–" : "\(snapshot.doneCount)/\(snapshot.total)")
          .font(.cute(14, .heavy))
          .foregroundStyle(theme.ink)
          .minimumScaleFactor(0.6)
      }
    }
  }
}

private struct WeekBars: View {
  let week: [Int]
  let theme: CuteTheme

  var body: some View {
    let top = max(1, week.max() ?? 1)
    HStack(alignment: .bottom, spacing: 3) {
      ForEach(Array(week.enumerated()), id: \.offset) { i, value in
        Capsule()
          .fill(i == week.count - 1 ? theme.accent : theme.accent.opacity(0.4))
          .frame(width: 5, height: max(4, 22 * CGFloat(value) / CGFloat(top)))
      }
    }
    .frame(maxWidth: .infinity, alignment: .center)
  }
}

private struct Sticker<Content: View>: View {
  let theme: CuteTheme
  var highlighted = false
  @ViewBuilder let content: Content

  var body: some View {
    VStack(spacing: 2) { content }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      .padding(.horizontal, 4)
      .background(highlighted ? theme.accent.opacity(0.12) : theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(highlighted ? theme.accent.opacity(0.5) : theme.line, style: StrokeStyle(lineWidth: 1.5, dash: highlighted ? [4, 3] : [])))
  }
}

private struct CaptureLink: View {
  let theme: CuteTheme

  var body: some View {
    Link(destination: URL(string: "oneday://capture")!) {
      Label("写一条记录", systemImage: "square.and.pencil")
        .font(.cute(13, .heavy))
        .foregroundStyle(theme.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.accent.opacity(0.12), in: Capsule())
    }
  }
}
