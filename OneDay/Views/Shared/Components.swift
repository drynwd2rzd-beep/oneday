import SwiftUI

// MARK: - Layout helpers

struct SectionHeader: View {
  let title: String
  var actionTitle: String?
  var action: (() -> Void)?

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .font(.app(.title3).weight(.bold))
        .accessibilityAddTraits(.isHeader)
      Spacer()
      if let actionTitle, let action {
        Button(action: action) {
          HStack(spacing: 3) {
            Text(actionTitle)
            Image(systemName: "chevron.right").font(.app(.caption).weight(.semibold))
          }
          .font(.app(.subheadline))
          .foregroundStyle(.secondary)
        }
      }
    }
  }
}

/// Segmented control whose labels may change (e.g. counts) without the selection jumping.
/// The system segmented picker rebuilds itself whenever a label changes, which made the
/// highlight flicker to the wrong segment when tasks were checked off.
struct SegmentedBar<Value: Hashable>: View {
  struct Option: Identifiable {
    let value: Value
    let title: String
    var id: Value { value }
  }

  let options: [Option]
  @Binding var selection: Value
  @Namespace private var namespace

  var body: some View {
    HStack(spacing: 2) {
      ForEach(options) { option in
        let selected = option.value == selection
        Button {
          guard !selected else { return }
          Haptics.tap()
          withAnimation(.snappy(duration: 0.25)) { selection = option.value }
        } label: {
          Text(option.title)
            .font(.app(.subheadline).weight(selected ? .semibold : .regular).monospacedDigit())
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .contentTransition(.numericText())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
              if selected {
                Capsule()
                  .fill(Color(uiColor: .systemBackground))
                  .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                  .matchedGeometryEffect(id: "selection", in: namespace)
              }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
      }
    }
    .padding(3)
    .background(Color.secondary.opacity(0.12), in: Capsule())
  }
}

struct EmptyText: View {
  let text: String
  init(_ text: String) { self.text = text }

  var body: some View {
    Text(text)
      .font(.app(.subheadline))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 6)
  }
}

struct PageIntro: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title).font(.app(.body).weight(.medium))
      Text(subtitle).font(.app(.subheadline)).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// Wraps subviews onto new lines, used for tag chips.
struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
    for view in subviews {
      let size = view.sizeThatFits(.unspecified)
      if x > 0 && x + size.width > maxWidth {
        y += rowHeight + spacing
        x = 0
        rowHeight = 0
      }
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
      widest = max(widest, x - spacing)
    }
    return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
    for view in subviews {
      let size = view.sizeThatFits(.unspecified)
      if x > bounds.minX && x + size.width > bounds.maxX {
        y += rowHeight + spacing
        x = bounds.minX
        rowHeight = 0
      }
      view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}

// MARK: - Tags

struct TagChip: View {
  @Environment(\.accent) private var accent
  let title: String
  var selected = false
  var onDelete: (() -> Void)?
  let action: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      Button(action: action) {
        Text(title).font(.app(.subheadline).weight(.medium)).lineLimit(1)
      }
      .buttonStyle(.plain)
      if let onDelete {
        Button(action: onDelete) {
          Image(systemName: "xmark").font(.app(.caption2).weight(.bold))
        }
        .buttonStyle(.plain)
        .opacity(0.7)
        .accessibilityLabel("删除标签 \(title)")
      }
    }
    .foregroundStyle(selected ? Color.white : Color.primary)
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .capsuleSurface(tint: selected ? accent : nil, interactive: true)
    .animation(.snappy, value: selected)
  }
}

struct TagLabel: View {
  @Environment(\.accent) private var accent
  let tag: String

  var body: some View {
    Text("# \(tag)")
      .font(.app(.caption).weight(.bold))
      .foregroundStyle(accent)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(accent.opacity(0.14), in: Capsule())
  }
}

// MARK: - Tasks

struct TaskList: View {
  let tasks: [TaskItem]
  let day: String

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
        if index > 0 { Divider().padding(.leading, 40) }
        TaskRow(task: task, day: day)
      }
    }
  }
}

struct ReminderSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  let task: TaskItem
  @State private var time = DayKey.dateToday(minutes: 9 * 60)

  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker("提醒时间", selection: $time, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        } footer: {
          Text(task.repeatMode == .daily ? "每天这个时间提醒，当天已完成则不提醒。" : "在这件事当天的这个时间提醒。")
        }
      }
      .navigationTitle(task.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") {
            store.setReminder(DayKey.minutes(of: time), for: task.id)
            Task { await ensureNotificationsOn(store) }
            dismiss()
          }
        }
      }
    }
    .presentationDetents([.medium])
    .onAppear {
      if let r = task.reminder { time = DayKey.dateToday(minutes: r) }
    }
  }
}

/// Task reminders need notifications; turn them on (asking permission) the first time one is set.
@MainActor
func ensureNotificationsOn(_ store: Store) async {
  if !store.settings.notifications.enabled || !NotificationManager.shared.isAuthorized {
    if await store.enableNotifications() {
      store.updateNotifications { $0.taskReminders = true }
    }
  } else if !store.settings.notifications.taskReminders {
    store.updateNotifications { $0.taskReminders = true }
  }
}

// MARK: - Calendar

struct CalendarMonthView: View {
  @Environment(Store.self) private var store
  @Environment(\.accent) private var accent
  @Binding var month: Date
  let selected: String?
  let marker: (String) -> Color?
  let onSelect: (String) -> Void

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
  private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

  var body: some View {
    VStack(spacing: 14) {
      HStack {
        monthButton("chevron.left", label: "上个月", by: -1)
        Spacer()
        Text(DayKey.monthLabel(month))
          .font(.app(.headline))
          .contentTransition(.numericText())
        Spacer()
        monthButton("chevron.right", label: "下个月", by: 1)
      }
      LazyVGrid(columns: columns, spacing: 6) {
        ForEach(weekdays, id: \.self) { name in
          Text(name).font(.app(.caption).weight(.medium)).foregroundStyle(.secondary)
        }
        ForEach(0..<DayKey.leadingBlanks(month), id: \.self) { _ in
          Color.clear.frame(height: 42)
        }
        ForEach(1...DayKey.daysInMonth(month), id: \.self) { day in
          dayCell(day)
        }
      }
    }
  }

  private func monthButton(_ icon: String, label: String, by value: Int) -> some View {
    Button {
      withAnimation(.snappy) { month = DayKey.shiftMonth(month, by: value) }
    } label: {
      Image(systemName: icon)
        .font(.app(.body).weight(.semibold))
        .frame(width: 22, height: 22)
    }
    .oneDayButton()
    .buttonBorderShape(.circle)
    .accessibilityLabel(label)
  }

  private func dayCell(_ day: Int) -> some View {
    let key = DayKey.key(month, day: day)
    let isSelected = key == selected
    let isToday = key == store.today
    let dot = marker(key)
    return Button {
      Haptics.tap()
      onSelect(key)
    } label: {
      VStack(spacing: 3) {
        Text("\(day)")
          .font(.app(.callout).weight(isSelected || isToday ? .bold : .regular))
          .foregroundStyle(isSelected ? Color.white : isToday ? accent : Color.primary)
          .frame(width: 36, height: 36)
          .background {
            if isSelected {
              Circle().fill(accent)
            } else if isToday {
              Circle().strokeBorder(accent.opacity(0.6), lineWidth: 1.2)
            }
          }
        Circle()
          .fill(dot ?? .clear)
          .frame(width: 5, height: 5)
      }
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(DayKey.fullDate(key))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

// MARK: - Photos

struct PhotoRef: Identifiable, Hashable {
  let name: String
  var id: String { name }
}

struct PhotoThumb: View {
  let name: String

  var body: some View {
    Color.secondary.opacity(0.12)
      .aspectRatio(1, contentMode: .fit)
      .overlay {
        if let image = MediaStore.image(name) {
          Image(uiImage: image).resizable().scaledToFill()
        } else {
          Image(systemName: "photo").foregroundStyle(.secondary)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}

struct PhotoLightbox: View {
  @Environment(\.dismiss) private var dismiss
  let name: String
  @State private var zoomed = false
  @GestureState private var pull: CGSize = .zero

  var body: some View {
    let progress = min(1, abs(pull.height) / 300)
    ZStack(alignment: .topTrailing) {
      Color.black.opacity(1 - progress * 0.7).ignoresSafeArea()
      if let image = MediaStore.image(name) {
        ZoomableImage(image: image, zoomed: $zoomed)
          .ignoresSafeArea()
          .offset(y: pull.height)
          .scaleEffect(1 - progress * 0.2)
          // Swipe down to close, only while not zoomed (the zoom view pans then).
          .simultaneousGesture(
            DragGesture(minimumDistance: 12)
              .updating($pull) { value, state, _ in
                if !zoomed && value.translation.height > 0 { state = value.translation }
              }
              .onEnded { value in
                if !zoomed && value.translation.height > 120 { dismiss() }
              },
            including: zoomed ? .subviews : .all)
          .accessibilityLabel("记录照片")
          .accessibilityHint("双指缩放，双击放大，向下轻扫关闭")
      }
      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark").font(.app(.body).weight(.semibold)).frame(width: 24, height: 24)
      }
      .oneDayButton()
      .buttonBorderShape(.circle)
      .environment(\.colorScheme, .dark)
      .padding(20)
      .opacity(1 - progress)
      .accessibilityLabel("关闭图片预览")
    }
    .animation(.snappy, value: pull == .zero)
    .environment(\.visualStyle, .glass)
  }
}

/// UIScrollView-based zoom, like Photos: pinch around the fingers, bounce at the limits,
/// double-tap to zoom into the tapped point and back.
struct ZoomableImage: UIViewRepresentable {
  let image: UIImage
  @Binding var zoomed: Bool

  func makeCoordinator() -> Coordinator { Coordinator(zoomed: $zoomed) }

  func makeUIView(context: Context) -> UIScrollView {
    let scroll = CenteringScrollView()
    scroll.delegate = context.coordinator
    scroll.minimumZoomScale = 1
    scroll.maximumZoomScale = 4
    scroll.bouncesZoom = true
    scroll.showsVerticalScrollIndicator = false
    scroll.showsHorizontalScrollIndicator = false
    scroll.contentInsetAdjustmentBehavior = .never
    scroll.backgroundColor = .clear
    scroll.panGestureRecognizer.isEnabled = false
    let imageView = UIImageView(image: image)
    imageView.contentMode = .scaleAspectFit
    imageView.isUserInteractionEnabled = true
    scroll.addSubview(imageView)
    scroll.imageView = imageView
    context.coordinator.imageView = imageView
    let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped(_:)))
    doubleTap.numberOfTapsRequired = 2
    scroll.addGestureRecognizer(doubleTap)
    return scroll
  }

  func updateUIView(_ scroll: UIScrollView, context: Context) {
    context.coordinator.zoomed = $zoomed
    if let imageView = context.coordinator.imageView, imageView.image !== image {
      imageView.image = image
      scroll.setZoomScale(1, animated: false)
      scroll.setNeedsLayout()
    }
  }

  @MainActor
  final class Coordinator: NSObject, UIScrollViewDelegate {
    var zoomed: Binding<Bool>
    weak var imageView: UIImageView?

    init(zoomed: Binding<Bool>) { self.zoomed = zoomed }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
      let isZoomed = scrollView.zoomScale > 1.01
      // At 1x the pan belongs to SwiftUI (swipe down to close).
      scrollView.panGestureRecognizer.isEnabled = isZoomed
      if zoomed.wrappedValue != isZoomed { zoomed.wrappedValue = isZoomed }
      scrollView.setNeedsLayout()
    }

    @objc func doubleTapped(_ tap: UITapGestureRecognizer) {
      guard let scroll = tap.view as? UIScrollView, let imageView else { return }
      if scroll.zoomScale > 1.01 {
        scroll.setZoomScale(1, animated: true)
      } else {
        let point = tap.location(in: imageView)
        let scale: CGFloat = 2.5
        let size = CGSize(width: scroll.bounds.width / scale, height: scroll.bounds.height / scale)
        scroll.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: true)
      }
    }
  }
}

/// Fits the image to the screen at 1x and keeps it centered while zooming.
private final class CenteringScrollView: UIScrollView {
  weak var imageView: UIImageView?
  private var lastBounds: CGSize = .zero

  override func layoutSubviews() {
    super.layoutSubviews()
    guard let imageView, let image = imageView.image, bounds.width > 0, bounds.height > 0 else { return }
    if bounds.size != lastBounds {
      lastBounds = bounds.size
      let fit = min(bounds.width / image.size.width, bounds.height / image.size.height)
      let size = CGSize(width: image.size.width * fit, height: image.size.height * fit)
      let zoom = zoomScale
      zoomScale = 1
      imageView.frame = CGRect(origin: .zero, size: size)
      contentSize = size
      zoomScale = zoom
    }
    let w = imageView.frame.width, h = imageView.frame.height
    contentInset = UIEdgeInsets(
      top: max(0, (bounds.height - h) / 2), left: max(0, (bounds.width - w) / 2),
      bottom: max(0, (bounds.height - h) / 2), right: max(0, (bounds.width - w) / 2))
  }
}

// MARK: - Settings rows

/// A row in the style of the Settings app: tinted icon tile, title, current value, chevron.
/// Icon, title and value of a settings row; every icon uses the accent so the list stays calm.
struct SettingLabel: View {
  @Environment(\.accent) private var accent
  let icon: String
  let title: String
  var value: String?

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.app(.subheadline).weight(.semibold))
        .foregroundStyle(.white)
        .frame(width: 29, height: 29)
        .background(accent, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
      Text(title).foregroundStyle(.primary)
      Spacer(minLength: 8)
      if let value {
        Text(value).foregroundStyle(.secondary).lineLimit(1)
      }
    }
  }
}

struct SettingRow: View {
  let icon: String
  let title: String
  var value: String?
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        SettingLabel(icon: icon, title: title, value: value)
        Image(systemName: "chevron.right")
          .font(.app(.footnote).weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

struct AvatarView: View {
  @Environment(\.palette) private var palette
  let name: String
  var size: CGFloat = 64

  var body: some View {
    Group {
      if let image = MediaStore.image(name) {
        Image(uiImage: image).resizable().scaledToFill()
      } else {
        ZStack {
          Color(hex: "#20262e")
          Image(systemName: "person.fill")
            .resizable()
            .scaledToFit()
            .padding(size * 0.22)
            .foregroundStyle(Color(hex: "#6b7682"))
        }
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .overlay { Circle().strokeBorder(Color.white.opacity(palette.isDark ? 0.15 : 0.7), lineWidth: 2) }
    .accessibilityLabel("头像")
  }
}
