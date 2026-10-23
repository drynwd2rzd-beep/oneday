import SwiftUI

// MARK: - What 小日 says

struct MascotLine: Equatable {
  let id: String
  let text: String
  /// Growth news: tapping opens the growth page instead of just closing the bubble.
  let opensGrowth: Bool
}

/// Picks at most one thing for 小日 to say on 今天, most important first. Growth news is
/// remembered per device so it is said once; anything else can be tapped away for the day.
@MainActor
enum MascotSpeech {
  private static let seenStageKey = "mascotSeenStage"
  private static let seenOutfitsKey = "mascotSeenOutfits"
  private static let dismissedKey = "mascotDismissed"

  static func line(state: AppState, today: String, growth: Growth, now: Date = Date()) -> MascotLine? {
    let defaults = UserDefaults.standard
    // First run: whatever 小日 already has is not news.
    if defaults.object(forKey: seenStageKey) == nil { markGrowthSeen(growth) }
    let seenStage = defaults.integer(forKey: seenStageKey)
    let seenOutfits = Set(defaults.stringArray(forKey: seenOutfitsKey) ?? [])
    let dismissed = Set(defaults.stringArray(forKey: dismissedKey) ?? [])

    let list = state.tasks(on: today)
    let done = list.filter { $0.isDone(on: today) }.count
    let hour = DayKey.calendar.component(.hour, from: now)
    let activeToday = done > 0 || !(state.notes[today] ?? []).isEmpty
    let milestones = [3, 7, 14, 21, 30, 50, 100, 200, 365]

    var candidates: [MascotLine] = []
    if growth.stage.rawValue > seenStage {
      candidates.append(MascotLine(id: "stage\(growth.stage.rawValue)", text: "我长出\(growth.stage.name)啦！", opensGrowth: true))
    }
    if let outfit = growth.unlocked.first(where: { !seenOutfits.contains($0.rawValue) }) {
      candidates.append(MascotLine(id: "outfit-\(outfit.rawValue)", text: "解锁了\(outfit.name)，点我换上～", opensGrowth: true))
    }
    if growth.droopy {
      candidates.append(MascotLine(id: "droopy", text: "好久不见，我有点渴了…", opensGrowth: false))
    }
    if !list.isEmpty && done == list.count {
      candidates.append(MascotLine(id: "alldone", text: "全部完成啦，今天也很棒！", opensGrowth: false))
    }
    if activeToday && milestones.contains(growth.streak) {
      candidates.append(MascotLine(id: "streak\(growth.streak)", text: "连续 \(growth.streak) 天了！", opensGrowth: false))
    }
    if hour >= 20 && activeToday && state.reflectionNote(on: today) == nil {
      candidates.append(MascotLine(id: "reflect", text: "要不要复盘一下今天？", opensGrowth: false))
    }
    if (5..<11).contains(hour) && !list.isEmpty && done == 0 {
      candidates.append(MascotLine(id: "morning", text: "今天有 \(list.count) 件事，一起加油", opensGrowth: false))
    }
    if growth.today > 0 {
      candidates.append(MascotLine(id: "sunshine", text: "今天收集了 \(growth.today) 份阳光", opensGrowth: true))
    }
    return candidates.first { !dismissed.contains("\(today)|\($0.id)") }
  }

  static func dismiss(_ line: MascotLine, today: String) {
    let defaults = UserDefaults.standard
    // Keep only today's entries.
    var list = (defaults.stringArray(forKey: dismissedKey) ?? []).filter { $0.hasPrefix(today + "|") }
    list.append("\(today)|\(line.id)")
    defaults.set(list, forKey: dismissedKey)
  }

  static func markGrowthSeen(_ growth: Growth) {
    let defaults = UserDefaults.standard
    defaults.set(growth.stage.rawValue, forKey: seenStageKey)
    defaults.set(growth.unlocked.map(\.rawValue), forKey: seenOutfitsKey)
  }
}

/// 小日's words, in a bubble whose tail points at the ring.
struct MascotBubble: View {
  @Environment(\.palette) private var palette
  @Environment(\.accent) private var accent
  let line: MascotLine
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Text(line.text)
          .font(.app(.subheadline).weight(.medium))
          .foregroundStyle(.primary)
          .multilineTextAlignment(.leading)
        if line.opensGrowth {
          Image(systemName: "chevron.right").font(.app(.caption).weight(.bold)).foregroundStyle(accent)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.sun.opacity(0.5), lineWidth: 1))
      .overlay(alignment: .trailing) {
        BubbleTail()
          .fill(palette.surface)
          .overlay(BubbleTail().stroke(Color.sun.opacity(0.5), lineWidth: 1))
          .frame(width: 8, height: 12)
          .offset(x: 7)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("小日说：\(line.text)")
    .accessibilityHint(line.opensGrowth ? "打开小日的成长" : "关闭")
  }
}

private struct BubbleTail: Shape {
  func path(in rect: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: rect.minX, y: rect.minY))
    p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
    p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    return p
  }
}

// MARK: - Growth page

/// 小日 now, sunshine towards the next stage, the road ahead, how to earn it, and outfits.
struct GrowthSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent

  var body: some View {
    let growth = store.state.growth(today: store.today)
    let worn = store.state.settings.mascotOutfit.flatMap(MascotOutfit.init(rawValue:))
    NavigationStack {
      ScrollView {
        VStack(spacing: Spacing.section) {
          VStack(spacing: 8) {
            MascotView(mood: growth.droopy ? .sleepy : .happy, size: 150, stage: growth.stage.rawValue, outfit: worn, droopy: growth.droopy)
            Text(growth.stage.name)
              .font(.app(.title2).weight(.bold))
            Text("连续活跃 \(growth.streak) 天 · 最长 \(growth.bestStreak) 天")
              .font(.app(.subheadline))
              .foregroundStyle(.secondary)
          }
          .padding(.top, 8)

          sunshineCard(growth)
          stagesCard(growth)
          rulesCard
          outfitsCard(growth, worn: worn)
        }
        .padding(.horizontal, Spacing.page)
        .padding(.bottom, Spacing.section)
      }
      .background { AppBackground() }
      .navigationTitle("小日的成长")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
      }
      .onAppear { MascotSpeech.markGrowthSeen(growth) }
    }
  }

  private func sunshineCard(_ growth: Growth) -> some View {
    VStack(alignment: .leading, spacing: Spacing.inner) {
      HStack(alignment: .lastTextBaseline, spacing: 6) {
        Image(systemName: "sun.max.fill").foregroundStyle(Color.sun)
        Text("\(growth.sunshine)")
          .font(.app(size: 34, weight: .bold))
          .contentTransition(.numericText())
        Text("阳光").font(.app(.subheadline)).foregroundStyle(.secondary)
        Spacer()
        if growth.today > 0 {
          Text("今天 +\(growth.today)")
            .font(.app(.subheadline).weight(.semibold))
            .foregroundStyle(Color.sun)
        }
      }
      ProgressView(value: growth.progress)
        .tint(Color.sun)
      Text(growth.next.map { "再收集 \(growth.toNext) 份阳光，就会长出\($0.name)" } ?? "已经长到最高啦，谢谢你一直照顾我")
        .font(.app(.footnote))
        .foregroundStyle(.secondary)
    }
    .card()
  }

  private func stagesCard(_ growth: Growth) -> some View {
    VStack(alignment: .leading, spacing: Spacing.inner) {
      Text("成长路线").font(.app(.headline))
      HStack(spacing: 0) {
        ForEach(GrowthStage.allCases) { stage in
          let reached = stage.rawValue <= growth.stage.rawValue
          VStack(spacing: 4) {
            MascotView(mood: .calm, size: 44, stage: stage.rawValue)
              .saturation(reached ? 1 : 0)
              .opacity(reached ? 1 : 0.4)
            Text(stage.name)
              .font(.app(.caption2).weight(stage == growth.stage ? .bold : .regular))
              .foregroundStyle(stage == growth.stage ? Color.primary : Color.secondary)
            Text("\(stage.threshold)")
              .font(.app(.caption2).monospacedDigit())
              .foregroundStyle(.tertiary)
          }
          .frame(maxWidth: .infinity)
          .accessibilityElement(children: .combine)
          .accessibilityValue(reached ? "已达成" : "需要 \(stage.threshold) 份阳光")
        }
      }
    }
    .card()
  }

  private var rulesCard: some View {
    VStack(alignment: .leading, spacing: Spacing.inner) {
      Text("怎样收集阳光").font(.app(.headline))
      ForEach(Growth.rules, id: \.title) { rule in
        HStack(spacing: 10) {
          Image(systemName: rule.icon).foregroundStyle(accent).frame(width: 22)
          Text(rule.title).font(.app(.subheadline))
          Spacer()
          Text(rule.points).font(.app(.subheadline).weight(.semibold)).foregroundStyle(Color.sun)
        }
        .accessibilityElement(children: .combine)
      }
      Text("阳光只会增加。几天没来，小日只会有点想你。")
        .font(.app(.footnote))
        .foregroundStyle(.secondary)
    }
    .card()
  }

  private func outfitsCard(_ growth: Growth, worn: MascotOutfit?) -> some View {
    VStack(alignment: .leading, spacing: Spacing.inner) {
      Text("装扮").font(.app(.headline))
      LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
        ForEach(MascotOutfit.allCases) { outfit in
          outfitTile(outfit, growth: growth, worn: worn)
        }
      }
    }
    .card()
  }

  private func outfitTile(_ outfit: MascotOutfit, growth: Growth, worn: MascotOutfit?) -> some View {
    let unlocked = growth.isUnlocked(outfit)
    let wearing = worn == outfit
    let need = growth.requirement(outfit)
    return Button {
      guard unlocked else { return }
      Haptics.tap()
      store.setOutfit(wearing ? nil : outfit)
    } label: {
      VStack(spacing: 6) {
        MascotView(mood: .happy, size: 64, stage: growth.stage.rawValue, outfit: outfit)
          .saturation(unlocked ? 1 : 0)
          .opacity(unlocked ? 1 : 0.45)
        Text(outfit.name).font(.app(.subheadline).weight(.semibold))
        Group {
          if wearing {
            Text("戴着呢").foregroundStyle(accent)
          } else if unlocked {
            Text("点击戴上").foregroundStyle(.secondary)
          } else {
            Label(lockText(outfit, need: need), systemImage: "lock.fill").foregroundStyle(.secondary)
          }
        }
        .font(.app(.caption))
        .labelStyle(CompactLabelStyle())
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(
        wearing ? accent.opacity(0.1) : Color.secondary.opacity(0.06),
        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(wearing ? accent : Color.clear, lineWidth: 1.5))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(outfit.name)
    .accessibilityValue(wearing ? "戴着" : unlocked ? "已解锁" : lockText(outfit, need: need))
  }

  private func lockText(_ outfit: MascotOutfit, need: (current: Int, target: Int, unit: String)) -> String {
    let what = outfit == .glasses ? "记录" : "连续"
    return "\(what) \(min(need.current, need.target))/\(need.target) \(need.unit)"
  }
}
