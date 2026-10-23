import SwiftUI

// MARK: - What 小日 says

struct MascotLine: Equatable {
  let id: String
  let text: String
  /// Growth news: tapping opens the growth page instead of just closing the bubble.
  var opensGrowth = false
  /// Shows the five mood faces to tap.
  var asksMood = false
}

/// Picks at most one thing for 小日 to say on 今天, most important first. Growth news is
/// remembered per device so it is said once; anything else can be tapped away for the day.
@MainActor
enum MascotSpeech {
  private static let seenStageKey = "mascotSeenStage"
  private static let seenOutfitsKey = "mascotSeenOutfits"
  private static let seenChallengeKey = "mascotSeenChallenge"
  private static let dismissedKey = "mascotDismissed"

  /// Festival outfits are news once per festival.
  private static func seenKey(_ outfit: MascotOutfit, today: String) -> String {
    guard outfit.isFestival, let w = Festivals.window(of: outfit, around: today) else { return outfit.rawValue }
    return outfit.rawValue + "@" + w.start
  }

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
    let challenge = growth.challenge

    var candidates: [MascotLine] = []
    if growth.stage.rawValue > seenStage {
      candidates.append(MascotLine(id: "stage\(growth.stage.rawValue)", text: "我长出\(growth.stage.name)啦！", opensGrowth: true))
    }
    if let outfit = growth.unlocked.first(where: { !seenOutfits.contains(seenKey($0, today: today)) }) {
      let text = outfit.isFestival ? "节日限定：\(outfit.name)可以戴啦" : "解锁了\(outfit.name)，点我换上～"
      candidates.append(MascotLine(id: "outfit-\(outfit.rawValue)", text: text, opensGrowth: true))
    }
    if challenge.done && defaults.string(forKey: seenChallengeKey) != challenge.week {
      candidates.append(MascotLine(id: "challengeDone", text: "本周挑战完成，+\(WeeklyChallenge.bonus) 阳光！", opensGrowth: true))
    }
    if growth.droopy {
      candidates.append(MascotLine(id: "droopy", text: "好久不见，我有点渴了…"))
    }
    if !list.isEmpty && done == list.count {
      candidates.append(MascotLine(id: "alldone", text: "全部完成啦，今天也很棒！"))
    }
    if activeToday && milestones.contains(growth.streak) {
      candidates.append(MascotLine(id: "streak\(growth.streak)", text: "连续 \(growth.streak) 天了！"))
    }
    if hour >= 12 && state.mood(on: today) == nil {
      candidates.append(MascotLine(id: "mood", text: "今天心情怎么样？", asksMood: true))
    }
    if hour >= 20 && activeToday && state.reflectionNote(on: today) == nil {
      candidates.append(MascotLine(id: "reflect", text: "要不要复盘一下今天？"))
    }
    if DayKey.weekdayIndex(today) == 1 && !challenge.done {
      candidates.append(MascotLine(id: "challenge", text: "本周挑战：\(challenge.title)", opensGrowth: true))
    }
    if (5..<11).contains(hour) && !list.isEmpty && done == 0 {
      candidates.append(MascotLine(id: "morning", text: "今天有 \(list.count) 件事，一起加油"))
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
    let seen = Set(defaults.stringArray(forKey: seenOutfitsKey) ?? [])
    defaults.set(Array(seen.union(growth.unlocked.map { seenKey($0, today: growth.day) })), forKey: seenOutfitsKey)
    if growth.challenge.done { defaults.set(growth.challenge.week, forKey: seenChallengeKey) }
  }
}

/// 小日's words, in a bubble whose tail points at the ring.
struct MascotBubble: View {
  @Environment(\.palette) private var palette
  @Environment(\.accent) private var accent
  let line: MascotLine
  let action: () -> Void
  /// For a mood question: the face that was tapped (1…5).
  var onMood: (Int) -> Void = { _ in }

  var body: some View {
    Group {
      if line.asksMood {
        VStack(alignment: .leading, spacing: 8) {
          Text(line.text)
            .font(.app(.subheadline).weight(.medium))
          HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { level in
              Button {
                onMood(level)
              } label: {
                MoodFace(level: level, size: 28)
              }
              .buttonStyle(.plain)
              .accessibilityLabel("心情：\(Mood(rawValue: level)?.label ?? "")")
            }
          }
        }
      } else {
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
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("小日说：\(line.text)")
        .accessibilityHint(line.opensGrowth ? "打开小日的成长" : "关闭")
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

/// 小日 now and what is in reach; the rest folds away until asked for.
struct GrowthSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent
  @State private var showLocked = false
  @State private var showStages = false
  @State private var showRules = false

  var body: some View {
    let growth = store.state.growth(today: store.today)
    let worn = store.mascotOutfit
    let plant = store.mascotPlant
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: Spacing.stack) {
            VStack(spacing: 8) {
              MascotView(
                mood: growth.droopy ? .sleepy : .happy, size: 150, stage: growth.stage.rawValue,
                outfit: worn, droopy: growth.droopy, plant: plant)
              Text(growth.stage.name)
                .font(.app(.title2).weight(.bold))
              Text("连续活跃 \(growth.streak) 天 · 最长 \(growth.bestStreak) 天")
                .font(.app(.subheadline))
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)

            sunshineCard(growth)
            plantRow(plant)
            outfitsCard(growth, worn: worn, plant: plant).id("outfits")
            folded("成长路线", isOpen: $showStages) { stages(growth, plant: plant) }
            folded("怎样收集阳光", isOpen: $showRules) { rules }
          }
          .padding(.horizontal, Spacing.page)
          .padding(.bottom, Spacing.section)
        }
        #if DEBUG
        .onAppear {
          if UserDefaults.standard.bool(forKey: "OneDayOutfits") {
            showLocked = true
            proxy.scrollTo("outfits", anchor: .top)
          }
        }
        #endif
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

  // MARK: Sunshine and the weekly challenge

  private func sunshineCard(_ growth: Growth) -> some View {
    let challenge = growth.challenge
    return VStack(alignment: .leading, spacing: Spacing.inner) {
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
      Divider()
      HStack(spacing: 10) {
        Image(systemName: challenge.done ? "flag.checkered" : "flag")
          .foregroundStyle(challenge.done ? Color.sun : accent)
        VStack(alignment: .leading, spacing: 2) {
          Text("本周挑战").font(.app(.caption)).foregroundStyle(.secondary)
          Text(challenge.title).font(.app(.subheadline).weight(.medium))
        }
        Spacer()
        Text(challenge.done ? "完成 +\(WeeklyChallenge.bonus)" : "\(min(challenge.progress, challenge.target))/\(challenge.target)")
          .font(.app(.subheadline).weight(.semibold).monospacedDigit())
          .foregroundStyle(challenge.done ? Color.sun : .secondary)
      }
      .accessibilityElement(children: .combine)
    }
    .card()
  }

  // MARK: Plant

  private func plantRow(_ plant: MascotPlant) -> some View {
    HStack(spacing: 10) {
      Image(systemName: "leaf.fill").foregroundStyle(accent)
      Text("品种").font(.app(.body))
      Spacer()
      Menu {
        Picker("品种", selection: Binding(get: { store.mascotPlant }, set: { store.setPlant($0) })) {
          ForEach(MascotPlant.allCases) { Text($0.name).tag($0) }
        }
      } label: {
        HStack(spacing: 4) {
          Text(plant.name)
          Image(systemName: "chevron.up.chevron.down").font(.app(.caption))
        }
        .font(.app(.body))
        .foregroundStyle(.secondary)
      }
      .accessibilityLabel("品种：\(plant.name)")
    }
    .card()
  }

  // MARK: Outfits

  private func outfitsCard(_ growth: Growth, worn: MascotOutfit?, plant: MascotPlant) -> some View {
    // Festival outfits only show around their festival.
    let all = MascotOutfit.allCases.filter { !$0.isFestival || Festivals.isNear($0, today: growth.day) }
    let ready = all.filter(growth.isUnlocked)
    let locked = all.filter { !growth.isUnlocked($0) }
    return VStack(alignment: .leading, spacing: Spacing.inner) {
      Text("装扮").font(.app(.headline))
      if ready.isEmpty {
        Text("坚持几天，就能解锁第一件装扮。")
          .font(.app(.subheadline))
          .foregroundStyle(.secondary)
      } else {
        outfitGrid(ready, growth: growth, worn: worn, plant: plant)
      }
      if !locked.isEmpty {
        Button {
          withAnimation(.snappy) { showLocked.toggle() }
        } label: {
          HStack(spacing: 6) {
            Text("更多装扮 \(locked.count)")
            Image(systemName: "chevron.right")
              .font(.app(.caption).weight(.semibold))
              .rotationEffect(.degrees(showLocked ? 90 : 0))
            Spacer()
          }
          .font(.app(.subheadline).weight(.medium))
          .foregroundStyle(.secondary)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        if showLocked {
          outfitGrid(locked, growth: growth, worn: worn, plant: plant)
        }
      }
      if all.contains(where: \.isAeSeries) && (showLocked || ready.contains(where: \.isAeSeries)) {
        Text("æ 系列灵感来自 aespa 的赛博、银色和宇宙风格。")
          .font(.app(.caption))
          .foregroundStyle(.tertiary)
      }
    }
    .card()
  }

  private func outfitGrid(_ outfits: [MascotOutfit], growth: Growth, worn: MascotOutfit?, plant: MascotPlant) -> some View {
    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
      ForEach(outfits) { outfit in
        outfitTile(outfit, growth: growth, worn: worn, plant: plant)
      }
    }
  }

  private func outfitTile(_ outfit: MascotOutfit, growth: Growth, worn: MascotOutfit?, plant: MascotPlant) -> some View {
    let unlocked = growth.isUnlocked(outfit)
    let wearing = worn == outfit
    return Button {
      guard unlocked else { return }
      Haptics.tap()
      store.setOutfit(wearing ? nil : outfit)
    } label: {
      VStack(spacing: 6) {
        MascotView(mood: .happy, size: 64, stage: growth.stage.rawValue, outfit: outfit, plant: plant)
          .saturation(unlocked ? 1 : 0)
          .opacity(unlocked ? 1 : 0.45)
        HStack(spacing: 4) {
          Text(outfit.name).font(.app(.subheadline).weight(.semibold))
          if outfit.isAeSeries { Text("æ").font(.app(.caption).weight(.bold)).foregroundStyle(accent) }
          if outfit.isFestival { Text("限定").font(.app(.caption2).weight(.bold)).foregroundStyle(Color.sun) }
        }
        Group {
          if wearing {
            Text("戴着呢").foregroundStyle(accent)
          } else if unlocked {
            Text(outfit.isFestival ? "节日这周可以戴" : "点击戴上").foregroundStyle(.secondary)
          } else {
            Label(growth.lockText(outfit), systemImage: "lock.fill").foregroundStyle(.secondary)
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
    .accessibilityValue(wearing ? "戴着" : unlocked ? "已解锁" : growth.lockText(outfit))
  }

  // MARK: Folded sections

  private func folded<Content: View>(_ title: String, isOpen: Binding<Bool>, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: Spacing.inner) {
      Button {
        withAnimation(.snappy) { isOpen.wrappedValue.toggle() }
      } label: {
        HStack {
          Text(title).font(.app(.headline)).foregroundStyle(.primary)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.app(.footnote).weight(.semibold))
            .foregroundStyle(.tertiary)
            .rotationEffect(.degrees(isOpen.wrappedValue ? 90 : 0))
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityValue(isOpen.wrappedValue ? "已展开" : "已收起")
      if isOpen.wrappedValue { content() }
    }
    .card()
  }

  private func stages(_ growth: Growth, plant: MascotPlant) -> some View {
    HStack(spacing: 0) {
      ForEach(GrowthStage.allCases) { stage in
        let reached = stage.rawValue <= growth.stage.rawValue
        VStack(spacing: 4) {
          MascotView(mood: .calm, size: 44, stage: stage.rawValue, plant: plant)
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

  private var rules: some View {
    VStack(alignment: .leading, spacing: Spacing.inner) {
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
  }
}
