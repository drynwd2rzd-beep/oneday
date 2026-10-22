import SwiftUI
import WidgetKit

/// Previews of the home and lock screen widgets with today's real data, plus how to add them.
struct WidgetGallerySheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent

  var body: some View {
    let real = WidgetSync.snapshot(of: store.state, today: store.today)
    let snapshot = real.total == 0 && store.state.tasks.isEmpty ? WidgetSnapshot.sample : real
    let now = Date()
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.section) {
          VStack(spacing: 10) {
            MascotView(mood: .party, size: 96)
            Text("小日来啦")
              .font(.system(.title2, design: .rounded, weight: .heavy))
            Text("把 OneDay 放到桌面，不打开 App 也能看到今天、直接打勾。")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity)

          section("桌面") {
            HStack(spacing: 14) {
              tile(.systemSmall, snapshot, now, width: 158, height: 158)
              tile(.systemSmall, Self.allDone(snapshot), now, width: 158, height: 158)
            }
            tile(.systemMedium, snapshot, now, width: 338, height: 158)
            tile(.systemLarge, snapshot, now, width: 338, height: 354)
          }

          section("锁屏") {
            HStack(spacing: 18) {
              OneDayWidgetView(family: .accessoryCircular, snapshot: snapshot, date: now, interactive: false)
                .frame(width: 64, height: 64)
              OneDayWidgetView(family: .accessoryRectangular, snapshot: snapshot, date: now, interactive: false)
                .frame(width: 170, height: 64)
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
              LinearGradient(colors: [Color(hex: "#3b4a6b"), Color(hex: "#1c2333")], startPoint: .top, endPoint: .bottom),
              in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .environment(\.colorScheme, .dark)
          }

          section("小日的表情") {
            HStack(spacing: 0) {
              ForEach(MascotMood.allCases, id: \.self) { mood in
                VStack(spacing: 6) {
                  MascotView(mood: mood, size: 54)
                  Text(Self.moodName(mood)).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
              }
            }
            .card()
          }

          section("怎么添加") {
            VStack(alignment: .leading, spacing: 12) {
              step(1, "长按桌面空白的地方，直到图标开始晃动。")
              step(2, "点左上角「编辑」→「添加小组件」。")
              step(3, "搜索「一天」，选一个大小，点「添加小组件」。")
              step(4, "锁屏小组件：长按锁屏 →「自定」→ 点时间下面的方框添加。")
              Text("小组件上可以直接点圆圈打勾，下次打开 App 时会同步。如果小组件一直显示「打开 OneDay 一次」，说明自签工具没有开启 App Group，可以换用 SideStore 或 AltStore 安装。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .card()
          }
        }
        .padding(.horizontal, Spacing.page)
        .padding(.bottom, Spacing.section)
      }
      .background { AppBackground() }
      .navigationTitle("桌面小组件")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
      }
    }
  }

  private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: Spacing.title) {
      Text(title).font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
      content()
    }
  }

  /// A widget at its real size (iPhone 6.1"), scaled down when the screen is narrower.
  private func tile(_ family: WidgetFamily, _ snapshot: WidgetSnapshot, _ date: Date, width: CGFloat, height: CGFloat) -> some View {
    WidgetTile(family: family, snapshot: snapshot, date: date, width: width, height: height)
  }

  private func step(_ n: Int, _ text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Text("\(n)")
        .font(.footnote.weight(.bold))
        .foregroundStyle(.white)
        .frame(width: 22, height: 22)
        .background(accent, in: Circle())
      Text(text).font(.subheadline)
    }
  }

  private static func allDone(_ snapshot: WidgetSnapshot) -> WidgetSnapshot {
    var s = snapshot
    s.today = s.today.map { var t = $0; t.done = true; return t }
    if s.today.isEmpty { s.today = WidgetSnapshot.sample.today.map { var t = $0; t.done = true; return t } }
    return s
  }

  private static func moodName(_ mood: MascotMood) -> String {
    switch mood {
    case .calm: "悠闲"
    case .cheer: "加油"
    case .happy: "开心"
    case .party: "完成啦"
    case .sleepy: "困了"
    }
  }
}

private struct WidgetTile: View {
  @Environment(\.colorScheme) private var scheme
  let family: WidgetFamily
  let snapshot: WidgetSnapshot
  let date: Date
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    OneDayWidgetView(family: family, snapshot: snapshot, date: date, interactive: false)
      .padding(16)
      .frame(width: width, height: height)
      .background(CuteBackground(theme: CuteTheme.make(scheme, accent: snapshot.accent)))
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
      .accessibilityElement(children: .combine)
  }
}
