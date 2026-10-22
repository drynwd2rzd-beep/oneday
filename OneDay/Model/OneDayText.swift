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
  今天：记录当天的想法并完成事项。

  事项：查看今日、日历和完成统计；添加事项时可以设置提醒时间。

  计划：管理长期方向，可完成或归档。

  回顾：只回看真实记录，不把人生变成任务成绩单。可按标签或文字搜索。

  通知：在「我的 → 通知提醒」中开启早晨计划、晚间未完成和记录提醒。通知里可以直接标记事项完成。

  数据：所有内容只保存在这台设备上，可在「数据管理」中导出备份，也可以导入网页版 OneDay 的备份文件。
  """

  static let versionNotes = """
  OneDay 1.0 · iOS 原生版

  • 使用 SwiftUI 完全重写，原生 iOS 应用
  • 适配 iOS 26 液态玻璃：标签栏、导航栏、按钮、卡片与弹出面板
  • 「显示偏好」可在液态玻璃与原版经典样式之间切换
  • 新增通知系统：早晨计划、晚间未完成、记录提醒与事项定时提醒
  • 通知中可直接完成事项或稍后提醒，图标角标显示未完成数量
  • 照片以文件形式保存，不再占用网页存储空间
  • 首页模块支持拖动排序
  • 回顾搜索支持标签与文字
  • 完全兼容网页版 v0.6 的 JSON 备份
  """
}
