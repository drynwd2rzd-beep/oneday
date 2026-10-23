import SwiftUI

// MARK: - 今天 → 复盘

/// The evening 复盘 on 今天: from 20:00 (or once written), yesterday's in the morning if it was
/// skipped, and the weekly review on Sunday and Monday until it is written.
struct TodayReflectionModule: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent

  var body: some View {
    let today = store.today
    let force = store.forceReflectionPrompts
    let hour = DayKey.calendar.component(.hour, from: Date())
    let weekday = DayKey.calendar.component(.weekday, from: DayKey.date(today))  // 1 = Sunday
    let yesterday = DayKey.add(days: -1, to: today)
    let showToday = force || hour >= 20 || store.state.reflectionNote(on: today) != nil
    let showYesterday = !force && hour < 12 && store.state.reflectionNote(on: yesterday) == nil && hasActivity(yesterday)
    let week = weekday == 2 ? DayKey.add(days: -7, to: DayKey.weekStart(today)) : DayKey.weekStart(today)
    let showWeek = (force || weekday == 1 || weekday == 2)
      && store.state.weekReflections[week] == nil
      && store.state.weekSummary(start: week, today: today).hasActivity
    if showToday || showYesterday || showWeek {
      VStack(alignment: .leading, spacing: Spacing.title) {
        SectionHeader(title: "复盘")
        VStack(spacing: Spacing.stack) {
          if showYesterday {
            Button {
              store.reflection = .day(yesterday)
            } label: {
              HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath").foregroundStyle(accent)
                Text("补写昨天的复盘").foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.app(.footnote).weight(.semibold)).foregroundStyle(.tertiary)
              }
              .font(.app(.body))
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .card()
          }
          if showToday { DayReflectionCard(day: today) }
          if showWeek { WeekReflectionCard(start: week) }
        }
      }
    }
  }

  private func hasActivity(_ day: String) -> Bool {
    !store.state.moments(on: day).isEmpty || store.state.tasks.contains { $0.isDone(on: day) }
  }
}

// MARK: - Browsing weekly reviews

/// The weekly review with ‹ › to look back at earlier weeks (from the first week with any
/// activity) and forward again to this one.
struct WeekReviewBrowser: View {
  @Environment(Store.self) private var store
  @State private var week: String

  init(start: String) {
    _week = State(initialValue: DayKey.weekStart(start))
  }

  var body: some View {
    let current = DayKey.weekStart(store.today)
    let firstActive = store.state.activeDays.first.map(DayKey.weekStart) ?? current
    let earliest = min(firstActive, store.state.weekReflections.keys.min() ?? current)
    WeekReflectionSheet(
      start: week,
      reflection: store.state.weekReflections[week],
      canGoBack: week > earliest,
      canGoForward: week < current
    ) { delta in
      week = DayKey.add(days: 7 * delta, to: week)
    }
    .id(week)
  }
}

// MARK: - 回顾 → 记录

/// One line at the top of the timeline to write this week's review any day.
struct ThisWeekEntry: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent

  var body: some View {
    let start = DayKey.weekStart(store.today)
    let week = store.state.weekSummary(start: start, today: store.today)
    Button {
      store.reflection = .week(start)
    } label: {
      HStack(spacing: 10) {
        Image(systemName: "calendar.badge.clock").foregroundStyle(accent)
        VStack(alignment: .leading, spacing: 2) {
          Text("本周复盘").font(.app(.body)).foregroundStyle(.primary)
          Text(store.state.weekReflections[start] == nil
            ? "\(DayKey.weekRange(start)) · 完成 \(week.completions) 次"
            : "\(DayKey.weekRange(start)) · 已写好 ✓ · 往前翻看以前的复盘")
            .font(.app(.caption))
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right").font(.app(.footnote).weight(.semibold)).foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .card()
  }
}

/// A written weekly review as it appears in the timeline, above that week's days.
struct WeekNoteCard: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  let start: String

  var body: some View {
    let reflection = store.state.weekReflections[start]
    Button {
      store.reflection = .week(start)
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
          Label("一周复盘", systemImage: "calendar.badge.clock")
            .font(.app(.footnote).weight(.semibold))
            .foregroundStyle(accent)
          Text(DayKey.weekRange(start)).font(.app(.footnote)).foregroundStyle(.secondary)
          Spacer()
          Image(systemName: "chevron.right").font(.app(.footnote).weight(.semibold)).foregroundStyle(.tertiary)
        }
        Text(summary(reflection))
          .font(.journal(.body, size: 17))
          .foregroundStyle(.primary)
          .lineLimit(3)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .card()
  }

  private func summary(_ r: WeekReflection?) -> String {
    guard let r else { return "" }
    if !r.gains.isEmpty { return r.gains }
    if !r.problems.isEmpty { return r.problems }
    return "下周重点：" + r.nextItems.joined(separator: "、")
  }
}

private struct DayReflectionCard: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  let day: String

  var body: some View {
    let summary = store.state.daySummary(day)
    let text = store.state.reflectionNote(on: day)?.text
    Button {
      store.reflection = .day(day)
    } label: {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .firstTextBaseline) {
          Text("今日复盘").font(.app(.headline))
          Text("\(DayKey.shortDate(day)) \(DayKey.weekday(day))")
            .font(.app(.caption))
            .foregroundStyle(.secondary)
          Spacer()
          Image(systemName: text == nil ? "square.and.pencil" : "chevron.right")
            .font(.app(.subheadline).weight(.semibold))
            .foregroundStyle(text == nil ? accent : Color(uiColor: .tertiaryLabel))
        }
        DaySummaryLine(summary: summary)
        if let text {
          Text(text)
            .font(.journal(.body, size: 17))
            .lineSpacing(4)
            .lineLimit(4)
            .multilineTextAlignment(.leading)
            .foregroundStyle(.primary)
        } else {
          Text("今天过得怎么样？写几句给自己。")
            .font(.journal(.body, size: 16))
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .card()
    .accessibilityHint(text == nil ? "写今天的复盘" : "查看或修改今天的复盘")
  }
}

/// "完成 4/6 · 2 条记录 · 🙂"
private struct DaySummaryLine: View {
  let summary: DaySummary

  var body: some View {
    HStack(spacing: 12) {
      if summary.total > 0 {
        Label("完成 \(summary.done.count)/\(summary.total)", systemImage: "checkmark.circle")
      }
      if summary.notes > 0 {
        Label("\(summary.notes) 条记录", systemImage: "text.quote")
      }
      MoodBadge(value: summary.mood, size: 15)
      if summary.total == 0 && summary.notes == 0 {
        Text("这一天没有事项和记录")
      }
    }
    .labelStyle(CompactLabelStyle())
    .font(.app(.caption))
    .foregroundStyle(.secondary)
  }
}

private struct WeekReflectionCard: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  let start: String

  var body: some View {
    let week = store.state.weekSummary(start: start, today: store.today)
    let reflection = store.state.weekReflections[start]
    let diff = week.completions - week.lastWeekCompletions
    Button {
      store.reflection = .week(start)
    } label: {
      VStack(alignment: .leading, spacing: Spacing.inner) {
        HStack(alignment: .firstTextBaseline) {
          Text("本周复盘").font(.app(.headline))
          Text(DayKey.weekRange(start)).font(.app(.caption)).foregroundStyle(.secondary)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.app(.subheadline).weight(.semibold))
            .foregroundStyle(.tertiary)
        }
        HStack(alignment: .bottom, spacing: 16) {
          VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
              Text("\(week.completions)")
                .font(.app(size: 34, weight: .bold))
                .contentTransition(.numericText())
              Text("次完成").font(.app(.subheadline)).foregroundStyle(.secondary)
            }
            Text(diff == 0 ? "和上周同期持平" : diff > 0 ? "比上周同期多 \(diff) 次" : "比上周同期少 \(-diff) 次")
              .font(.app(.caption))
              .foregroundStyle(diff >= 0 ? accent : .secondary)
          }
          Spacer(minLength: 8)
          WeekBars(week: week, today: store.today)
            .frame(width: 140, height: 52)
        }
        if let reflection, !reflection.gains.isEmpty {
          Text(reflection.gains)
            .font(.journal(.body, size: 16))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
        } else {
          HStack(spacing: 4) {
            Text(week.isCurrent ? "周末花几分钟，回顾这一周" : "这周还没有复盘")
              .foregroundStyle(.secondary)
            Spacer()
            Text("开始复盘").fontWeight(.medium).foregroundStyle(accent)
          }
          .font(.app(.subheadline))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .card()
  }
}

/// Seven small bars, one per weekday, height = completions that day.
private struct WeekBars: View {
  @Environment(\.accent) private var accent
  let week: WeekSummary
  let today: String

  var body: some View {
    let top = max(1, week.dayDone.max() ?? 1)
    HStack(alignment: .bottom, spacing: 6) {
      ForEach(Array(week.days.enumerated()), id: \.element) { i, day in
        VStack(spacing: 4) {
          GeometryReader { geo in
            VStack {
              Spacer(minLength: 0)
              RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(day > today ? Color.secondary.opacity(0.12) : day == today ? accent : accent.opacity(0.4))
                .frame(height: max(3, geo.size.height * CGFloat(week.dayDone[i]) / CGFloat(top)))
            }
          }
          Text(DayKey.weekdayLetters[i])
            .font(.app(size: 9, weight: day == today ? .bold : .regular))
            .foregroundStyle(day == today ? accent : .secondary)
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("本周每天完成次数：" + week.dayDone.map(String.init).joined(separator: "、"))
  }
}

// MARK: - Daily reflection sheet

/// Free writing for one day, with that day's tasks and records alongside.
struct DayReflectionSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent
  let day: String
  private let original: String
  private let originalMood: Int?
  @State private var text: String
  @State private var mood: Int?
  @State private var confirmDiscard = false
  @FocusState private var focused: Bool

  init(day: String, note: NoteEntry?) {
    self.day = day
    original = note?.text ?? ""
    originalMood = note?.mood
    _text = State(initialValue: note?.text ?? "")
    _mood = State(initialValue: note?.mood)
  }

  private var changed: Bool { text.trimmed != original || mood != originalMood }

  var body: some View {
    let summary = store.state.daySummary(day)
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.stack) {
          VStack(alignment: .leading, spacing: 4) {
            Text(DayKey.weekday(day))
              .font(.app(.footnote).weight(.medium))
              .foregroundStyle(.secondary)
            Text(DayKey.fullDate(day))
              .font(.journal(.title, size: 26, bold: true))
          }
          .accessibilityElement(children: .combine)

          if summary.total > 0 || summary.notes > 0 {
            VStack(alignment: .leading, spacing: 10) {
              DaySummaryLine(summary: summary)
              ForEach(summary.done) { task in
                taskLine(task.title, done: true)
              }
              ForEach(summary.open) { task in
                taskLine(task.title, done: false)
              }
            }
            .card()
          }

          DayMomentsCard(day: day)

          VStack(alignment: .leading, spacing: 12) {
            Label("复盘", systemImage: "moon.stars")
              .font(.app(.footnote).weight(.semibold))
              .foregroundStyle(.secondary)
            TextField("回头看看今天：做成了什么，卡在了哪里，明天想怎么做……", text: $text, axis: .vertical)
              .font(.journal(.body, size: 18))
              .lineSpacing(6)
              .lineLimit(10...)
              .focused($focused)
              .accessibilityLabel("复盘内容")
              .accessibilityIdentifier("reflection-text")
            Divider()
            Text("今天整体的心情").font(.app(.footnote)).foregroundStyle(.secondary)
            MoodPicker(selection: $mood)
          }
          .card()
        }
        .padding(.horizontal, Spacing.page)
        .padding(.vertical, Spacing.stack)
      }
      .scrollDismissesKeyboard(.interactively)
      .background { AppBackground() }
      .navigationTitle(day == store.today ? "今日复盘" : "每日复盘")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") {
            if changed { confirmDiscard = true } else { dismiss() }
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") {
            store.saveDayReflection(day: day, text: text, mood: mood)
            dismiss()
          }
          .fontWeight(.semibold)
          .disabled(!changed)
        }
      }
      .interactiveDismissDisabled(changed)
      .confirmationDialog("放弃这次修改？", isPresented: $confirmDiscard, titleVisibility: .visible) {
        Button("放弃修改", role: .destructive) { dismiss() }
        Button("继续编辑", role: .cancel) {}
      }
      .onAppear { if original.isEmpty { focused = true } }
    }
  }

  private func taskLine(_ title: String, done: Bool) -> some View {
    HStack(spacing: 10) {
      Image(systemName: done ? "checkmark.circle.fill" : "circle")
        .foregroundStyle(done ? accent : Color(uiColor: .tertiaryLabel))
      Text(title)
        .foregroundStyle(done ? .primary : .secondary)
    }
    .font(.app(.subheadline))
    .accessibilityElement(children: .combine)
    .accessibilityValue(done ? "已完成" : "未完成")
  }
}

// MARK: - Weekly review sheet

private struct DayRef: Identifiable {
  let day: String
  var id: String { day }
}

/// The week's numbers first, then three questions; "下周重点" can become next week's tasks.
struct WeekReflectionSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent
  let start: String
  private let original: WeekReflection
  private let canGoBack: Bool
  private let canGoForward: Bool
  /// Moves to the week before (-1) or after (+1); nil hides the arrows.
  private let onShift: ((Int) -> Void)?
  @State private var draft: WeekReflection
  @State private var editingDay: DayRef?
  @State private var confirmDiscard = false

  init(
    start: String, reflection: WeekReflection?,
    canGoBack: Bool = false, canGoForward: Bool = false, onShift: ((Int) -> Void)? = nil
  ) {
    self.start = start
    let initial = reflection ?? WeekReflection(updatedAt: 0)
    original = initial
    self.canGoBack = canGoBack
    self.canGoForward = canGoForward
    self.onShift = onShift
    _draft = State(initialValue: initial)
  }

  private var changed: Bool {
    draft.gains.trimmed != original.gains || draft.problems.trimmed != original.problems || draft.next.trimmed != original.next
  }

  var body: some View {
    let week = store.state.weekSummary(start: start, today: store.today)
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.stack) {
          HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
              Text(week.isCurrent ? "本周" : String(start.prefix(4)) + " 年")
                .font(.app(.footnote).weight(.medium))
                .foregroundStyle(.secondary)
              Text(DayKey.weekRange(start))
                .font(.journal(.title, size: 26, bold: true))
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            if let onShift {
              weekButton("chevron.left", label: "上一周", enabled: canGoBack) { shift(-1, onShift) }
              weekButton("chevron.right", label: "下一周", enabled: canGoForward) { shift(1, onShift) }
            }
          }

          WeekNumbers(week: week)
          WeekDaysCard(week: week, today: store.today) { editingDay = DayRef(day: $0) }
          if !week.tasks.isEmpty { WeekTasksCard(week: week) }
          if !week.plans.isEmpty { WeekPlansCard(week: week) }

          Text("复盘")
            .font(.app(.title3).weight(.bold))
            .accessibilityAddTraits(.isHeader)
            .padding(.top, Spacing.section - Spacing.stack)
          question("本周收获", prompt: "这周最值得记住的事、进步和收获", text: $draft.gains)
          question("遇到的问题", prompt: "哪里没做好？卡住你的是什么？", text: $draft.problems)
          VStack(alignment: .leading, spacing: 10) {
            questionField("下周重点", prompt: "每行一件事", text: $draft.next)
            focusButton
          }
          .card()
        }
        .padding(.horizontal, Spacing.page)
        .padding(.vertical, Spacing.stack)
      }
      .scrollDismissesKeyboard(.interactively)
      .background { AppBackground() }
      .navigationTitle("一周复盘")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") {
            if changed { confirmDiscard = true } else { dismiss() }
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") {
            store.saveWeekReflection(week: start, draft)
            dismiss()
          }
          .fontWeight(.semibold)
          .disabled(!changed)
        }
      }
      .interactiveDismissDisabled(changed)
      .confirmationDialog("放弃这次修改？", isPresented: $confirmDiscard, titleVisibility: .visible) {
        Button("放弃修改", role: .destructive) { dismiss() }
        Button("继续编辑", role: .cancel) {}
      }
      .sheet(item: $editingDay) { ref in
        DayReflectionSheet(day: ref.day, note: store.state.reflectionNote(on: ref.day)).oneDaySheet()
      }
    }
  }

  private func weekButton(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.app(.body).weight(.semibold))
        .foregroundStyle(enabled ? accent : Color.secondary.opacity(0.3))
        .frame(width: 36, height: 36)
        .background(accent.opacity(enabled ? 0.1 : 0.04), in: Circle())
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .accessibilityLabel(label)
  }

  /// What was written stays: it is saved before turning the page.
  private func shift(_ delta: Int, _ onShift: (Int) -> Void) {
    if changed { store.saveWeekReflection(week: start, draft) }
    Haptics.tap()
    onShift(delta)
  }

  private func question(_ title: String, prompt: String, text: Binding<String>) -> some View {
    questionField(title, prompt: prompt, text: text).card()
  }

  private func questionField(_ title: String, prompt: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.app(.headline))
      TextField(prompt, text: text, axis: .vertical)
        .font(.journal(.body, size: 17))
        .lineSpacing(5)
        .lineLimit(3...)
        .accessibilityLabel(title)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// Monday after this week, or today when that has already passed.
  private var focusDay: String {
    max(DayKey.add(days: 7, to: start), store.today)
  }

  @ViewBuilder
  private var focusButton: some View {
    let items = draft.nextItems
    if !items.isEmpty {
      let plans = store.state.activePlans
      let label = Label("把 \(items.count) 件加入 \(DayKey.shortDate(focusDay)) 的事项", systemImage: "plus.circle")
        .font(.app(.subheadline).weight(.medium))
        .foregroundStyle(accent)
      if plans.isEmpty {
        Button { store.addFocusTasks(items, on: focusDay, planId: nil) } label: { label }
          .buttonStyle(.plain)
      } else {
        Menu {
          Button("不属于计划") { store.addFocusTasks(items, on: focusDay, planId: nil) }
          Section("归入计划") {
            ForEach(plans) { plan in
              Button {
                store.addFocusTasks(items, on: focusDay, planId: plan.id)
              } label: {
                Label(plan.title, systemImage: plan.symbol)
              }
            }
          }
        } label: {
          label
        }
      }
    }
  }
}

private struct WeekNumbers: View {
  @Environment(\.accent) private var accent
  let week: WeekSummary

  var body: some View {
    let diff = week.completions - week.lastWeekCompletions
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 0) {
        number("\(week.completions)", "次完成")
        number(week.rate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—", "完成率")
        number("\(week.noteDays)", "天有记录")
        number("\(week.reflectionDays.count)", "天复盘")
      }
      Text(diff == 0 ? "完成次数和上周同期持平" : diff > 0 ? "比上周同期多完成 \(diff) 次" : "比上周同期少完成 \(-diff) 次")
        .font(.app(.subheadline))
        .foregroundStyle(diff >= 0 ? accent : .secondary)
    }
    .card()
  }

  private func number(_ value: String, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .font(.app(.title2).weight(.bold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(label).font(.app(.caption)).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// Each day of the week: completions, mood and the daily reflection, tappable to write one.
private struct WeekDaysCard: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  let week: WeekSummary
  let today: String
  let onDay: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.inner) {
      Text("每一天").font(.app(.headline))
      WeekBars(week: week, today: today)
        .frame(height: 64)
      HStack(spacing: 6) {
        ForEach(Array(week.moods.enumerated()), id: \.offset) { _, mood in
          Group {
            if let face = mood.flatMap(Mood.init(average:)) {
              MoodFace(level: face.rawValue, size: 20)
            } else {
              Circle().fill(Color.secondary.opacity(0.2)).frame(width: 5, height: 5)
            }
          }
          .frame(maxWidth: .infinity, minHeight: 20)
        }
      }
      .accessibilityHidden(true)
      Divider()
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(week.days.enumerated()), id: \.element) { i, day in
          if day <= today {
            dayRow(day, letter: DayKey.weekdayLetters[i])
          }
        }
      }
    }
    .card()
  }

  private func dayRow(_ day: String, letter: String) -> some View {
    let text = store.state.reflectionNote(on: day)?.text
    return Button {
      onDay(day)
    } label: {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text("周" + letter)
          .font(.app(.subheadline).weight(.medium))
          .foregroundStyle(day == today ? accent : .secondary)
          .frame(width: 32, alignment: .leading)
        Text(text ?? "写这天的复盘")
          .font(text == nil ? .app(.subheadline) : .journal(.body, size: 16))
          .foregroundStyle(text == nil ? Color(uiColor: .tertiaryLabel) : .primary)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: text == nil ? "plus" : "chevron.right")
          .font(.app(.caption).weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(.vertical, 8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(DayKey.fullDate(day))，\(text ?? "还没有复盘")")
  }
}

/// A row per task with seven marks: done, missed, or not scheduled.
private struct WeekTasksCard: View {
  @Environment(\.accent) private var accent
  let week: WeekSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 0) {
        Text("打卡").font(.app(.headline))
        Spacer(minLength: 8)
        marksRow { i in
          Text(DayKey.weekdayLetters[i]).font(.app(.caption2)).foregroundStyle(.secondary)
        }
      }
      ForEach(week.tasks) { row in
        HStack(spacing: 0) {
          Text(row.title)
            .font(.app(.subheadline))
            .lineLimit(1)
          Spacer(minLength: 8)
          marksRow { i in mark(row.marks[i]) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.title)，本周完成 \(row.doneCount) 次")
      }
    }
    .card()
  }

  private func marksRow<Content: View>(@ViewBuilder _ content: @escaping (Int) -> Content) -> some View {
    HStack(spacing: 4) {
      ForEach(0..<7, id: \.self) { i in
        content(i).frame(width: 16)
      }
    }
  }

  @ViewBuilder
  private func mark(_ value: Bool?) -> some View {
    switch value {
    case .some(true): Circle().fill(accent).frame(width: 10, height: 10)
    case .some(false): Circle().strokeBorder(Color.secondary.opacity(0.45), lineWidth: 1.2).frame(width: 10, height: 10)
    case .none: Circle().fill(Color.secondary.opacity(0.12)).frame(width: 4, height: 4)
    }
  }
}

private struct WeekPlansCard: View {
  @Environment(\.accent) private var accent
  let week: WeekSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("计划").font(.app(.headline))
      ForEach(week.plans) { row in
        HStack(spacing: 10) {
          Image(systemName: row.plan.symbol)
            .foregroundStyle(row.plan.color.map { Color(hex: $0) } ?? accent)
            .frame(width: 22)
          Text(row.plan.title).lineLimit(1)
          Spacer()
          Text(row.completions == 0 ? "本周没有推进" : "本周完成 \(row.completions) 次")
            .font(.app(.subheadline))
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
      }
    }
    .card()
  }
}

// MARK: - The day's notes inside its 复盘

/// What was left during the day, so the 复盘 is written looking at it instead of repeating it.
private struct DayMomentsCard: View {
  @Environment(Store.self) private var store
  let day: String

  var body: some View {
    let moments = store.state.moments(on: day)
    VStack(alignment: .leading, spacing: 12) {
      Label(day == store.today ? "今天留下的" : "这天留下的", systemImage: "text.quote")
        .font(.app(.footnote).weight(.semibold))
        .foregroundStyle(.secondary)
      if moments.isEmpty {
        Text("这一天还没有留下记录。")
          .font(.app(.subheadline))
          .foregroundStyle(.tertiary)
      } else {
        ForEach(moments) { note in
          HStack(alignment: .top, spacing: 10) {
            Text(note.time.isEmpty ? "·" : note.time)
              .font(.app(.caption).monospacedDigit())
              .foregroundStyle(.secondary)
              .frame(width: 40, alignment: .leading)
            Text(excerpt(note))
              .font(.journal(.body, size: 16))
              .lineLimit(3)
              .frame(maxWidth: .infinity, alignment: .leading)
            if let photo = note.photos.first {
              PhotoThumb(name: photo).frame(width: 44, height: 44)
            }
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .card()
  }

  private func excerpt(_ note: NoteEntry) -> String {
    if !note.text.isEmpty { return MarkdownText.plain(note.text) }
    if !note.photos.isEmpty { return "留下了照片" }
    if note.media.contains(where: { $0.kind == .video }) { return "留下了视频" }
    return "留下了一段语音"
  }
}
