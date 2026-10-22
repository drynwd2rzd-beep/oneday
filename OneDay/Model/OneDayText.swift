import Foundation

struct Motivation: Identifiable, Hashable {
  var id: String { text }
  let text: String
  let author: String
}

enum OneDayText {
  static let quotes = [
    "今天不需要改变人生，认真完成一件事就已经很好。",
    "慢一点没关系，方向没有丢就好。",
    "不要追求完美，把真正重要的事往前推一点。",
    "你不需要证明什么，持续行动就够了。",
    "今天的微小完成，会成为以后回头看的证据。",
    "生活不是冲刺，长期走下去比一时用力更重要。",
    "允许普通的一天，也认真过好普通的一天。",
  ]

  static let motivations = [
    Motivation(text: "完成今天该做的事，本身就是一种了不起的坚持。", author: "OneDay"),
    Motivation(text: "不积跬步，无以至千里。", author: "荀子"),
    Motivation(text: "我们的最大弱点在于放弃，成功的必然之路就是不断地重来一次。", author: "托马斯·爱迪生"),
    Motivation(text: "你不需要跑得很快，只要一直向前。", author: "佚名"),
    Motivation(text: "做你认为正确的事，剩下的交给时间。", author: "佚名"),
  ]

  static let accentColors = ["#287052", "#386b98", "#8057b8", "#c75c88", "#d77b48", "#68717a"]

  static func quote(for date: Date, mode: String) -> String {
    if mode == "static" { return quotes[0] }
    let day = Int(date.timeIntervalSince1970 / 86_400)
    return quotes[((day % quotes.count) + quotes.count) % quotes.count]
  }

  static func motivation(for day: String) -> Motivation {
    let sum = day.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    return motivations[sum % motivations.count]
  }

  static func greeting(_ date: Date = Date()) -> String {
    let h = DayKey.calendar.component(.hour, from: date)
    return h < 11 ? "早上好。" : h < 18 ? "下午好。" : "晚上好。"
  }

  static let help = """
  今天：完成事项、留下记录。记录可以加照片、视频、语音、地点和天气。

  事项：右滑完成，左滑删除。长按可以设置提醒、归入计划。

  计划：长按可以暂停、置顶、归档；轻点编辑并关联每天的事项。

  回顾：时间线、那年今日，以及「完成概览」中的本周报告、全年热力图和每个事项的连续天数。

  撤销：删除或修改后，点提示里的「撤销」，或者摇一摇手机。

  隐私：在「我的 → 隐私与安全」设置密码锁和面容 ID。

  备份：在「我的 → 备份与恢复」选择 iCloud 云盘中的文件夹，之后会自动备份全部内容，换手机也能恢复。
  """

  static let versionNotes = """
  OneDay 1.2

  全新的界面：苹果原生的结构与交互，融合手帐的温度。
  • 界面更克制：去掉页面说明文字和多余的装饰，统一字体层级
  • 「⋯」按钮换成长按菜单，配合左右滑动操作
  • 事项只显示需要的信息：每日重复、提醒时间和所属计划
  • 回顾时间线以照片为主，点开某一天会进入独立页面
  • 问候、记录与回顾使用霞鹜文楷，像翻看自己的手帐
  • 计划卡片更简洁，并显示近 7 天的完成点
  • 「我的」改为系统设置风格的列表
  • 纸张质感的暖白背景，新的标签栏图标

  OneDay 1.1.2

  • 修复勾选事项时「全部 / 进行中 / 已完成」选择条闪烁、选中项跳动的问题
  • 首页更简洁：完成进度并入「今天」标题，记录入口平时收成一行，点一下再展开
  • 去掉单独的「完成情况」卡片
  • 去掉输入框上的格式按钮：之前点了会在文字里出现星号等符号

  OneDay 1.1.1

  • 计划可以关联每天的事项，显示近 7 天完成、累计完成和连续天数
  • 计划新增「暂停」状态，完成后记录完成日期
  • 计划可以设置颜色和图标、置顶、拖动调整顺序
  • 添加事项时可以选择所属计划
  • 编辑记录时可以增删照片、视频、语音和位置
  • 修复「界面大小」在设置面板里不生效的问题，各档差别更明显
  • 统一全部页面的间距与对齐，首页问候区更简洁
  • 超大字号下事项信息排版更整齐

  OneDay 1.1

  • 数据改用 SQLite 数据库，只保存改动的部分，数据再多也不会变慢
  • 摇一摇撤销；删除和修改后可以在提示中直接撤销
  • 事项、计划和记录支持左右滑动操作
  • 密码锁（6 位数字或字母数字密码）与面容 ID，多任务界面自动遮挡
  • 自动备份到 iCloud 云盘文件夹，含照片、视频和录音；本机每日快照
  • 记录支持视频、语音、地点与天气，文字支持粗体、斜体等格式
  • 首页新增「那年今日」
  • 完成概览新增本周报告、全年热力图和每个事项的连续天数
  • 全新图标（支持深色与着色模式）、首次使用引导、统一的极简界面
  • 本机崩溃与卡顿诊断；后台刷新让提醒和备份持续生效

  OneDay 1.0

  • 使用 SwiftUI 完全重写，适配 iOS 26 液态玻璃，可切换经典样式
  • 通知系统：早晨计划、晚间未完成、记录提醒与事项定时提醒
  • 完全兼容网页版 v0.6 的 JSON 备份
  """

  static var credits: String {
    let license = Bundle.main.url(forResource: "LXGWWenKai-OFL", withExtension: "txt")
      .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    return """
    记录与回顾中的字体基于「霞鹜文楷」（LXGW WenKai），只保留了常用汉字，并以「OneDay Journal」为名随 App 分发。感谢作者 LXGW 与 Klee 项目。

    天气数据来自 Open-Meteo。

    —— 字体许可证 ——

    \(license)
    """
  }
}
