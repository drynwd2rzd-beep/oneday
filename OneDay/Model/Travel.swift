import Foundation

/// A place 小日 travels to, drawn as a postcard from simple shapes and SF Symbols.
struct Destination: Identifiable, Hashable {
  let id: String
  /// "西湖", shown big on the card.
  let name: String
  /// "杭州", shown on the postmark.
  let region: String
  /// The landmark in the middle of the picture.
  let symbol: String
  /// Small things scattered in the sky or on the ground.
  let extra: String
  /// Sky gradient, top to bottom (hex).
  let sky: (String, String)
  let ground: String
  /// Color of the landmark (hex).
  let ink: String
  /// Stars and a moon instead of the sun.
  var night = false
  /// What 小日 writes on the back.
  let message: String

  static func == (a: Destination, b: Destination) -> Bool { a.id == b.id }
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// A postcard that has arrived: the `number`th trip, received on `day`.
struct Postcard: Identifiable, Hashable {
  let number: Int
  let destination: Destination
  let day: String
  var id: Int { number }
}

/// 小日 sets off on a trip after every few active days and sends a postcard from each place.
/// Like growth, postcards come only from history, so nothing extra is stored or lost.
enum Travel {
  /// Active days (anything done or written) per trip; they don't have to be in a row.
  static let daysPerTrip = 7

  static let destinations: [Destination] = [
    Destination(
      id: "westlake", name: "西湖", region: "杭州", symbol: "sailboat.fill", extra: "leaf.fill",
      sky: ("#bfe3e8", "#f6efd9"), ground: "#7fb6b0", ink: "#3d6f73",
      message: "湖边的风好温柔，我坐了一下午的船。"),
    Destination(
      id: "guilin", name: "漓江", region: "桂林", symbol: "mountain.2.fill", extra: "cloud.fill",
      sky: ("#cfe7da", "#f3f0dc"), ground: "#6aa58a", ink: "#3f7a62",
      message: "山像一幅水墨画，我看得发呆了。"),
    Destination(
      id: "chengdu", name: "熊猫基地", region: "成都", symbol: "pawprint.fill", extra: "leaf.fill",
      sky: ("#d9ecd0", "#f7f1dc"), ground: "#8cbf73", ink: "#3b3b3b",
      message: "见到熊猫啦！它比我还要圆。"),
    Destination(
      id: "seoul", name: "演唱会", region: "首尔", symbol: "music.mic", extra: "sparkles",
      sky: ("#f5c6d8", "#fdeef3"), ground: "#c7a4c8", ink: "#7b5aa6",
      message: "在首尔听了一场演唱会，æ 的灯牌好亮！"),
    Destination(
      id: "kyoto", name: "红叶", region: "京都", symbol: "house.lodge.fill", extra: "leaf.fill",
      sky: ("#f6d2c4", "#fbefe3"), ground: "#c98a5f", ink: "#b5523b",
      message: "红叶落在我头上，我决定就这样戴着它。"),
    Destination(
      id: "iceland", name: "极光", region: "冰岛", symbol: "mountain.2.fill", extra: "sparkles",
      sky: ("#183450", "#3f7f7a"), ground: "#d9e6ef", ink: "#9fe3c9", night: true,
      message: "极光在天上跳舞，我也跟着跳了一会儿。"),
    Destination(
      id: "xiamen", name: "鼓浪屿", region: "厦门", symbol: "beach.umbrella.fill", extra: "music.note",
      sky: ("#9fd6e8", "#fdf0d8"), ground: "#f1d9a6", ink: "#e07f52",
      message: "岛上到处是钢琴声和海风。"),
    Destination(
      id: "santorini", name: "圣托里尼", region: "希腊", symbol: "house.fill", extra: "sun.max.fill",
      sky: ("#8ec9f2", "#e9f6fd"), ground: "#f7f7f2", ink: "#3f7fc4",
      message: "白房子蓝屋顶，像住在明信片里。"),
    Destination(
      id: "lhasa", name: "布达拉宫", region: "拉萨", symbol: "building.columns.fill", extra: "cloud.fill",
      sky: ("#8ec5f0", "#e3f1fb"), ground: "#b9a27a", ink: "#a8473f",
      message: "天离我好近，云伸手就能摸到。"),
    Destination(
      id: "paris", name: "街角咖啡馆", region: "巴黎", symbol: "cup.and.saucer.fill", extra: "heart.fill",
      sky: ("#c9d8f0", "#f8ece0"), ground: "#c9b29a", ink: "#7a5a43",
      message: "喝了杯热可可，看路人慢慢走过。"),
    Destination(
      id: "harbin", name: "冰雪大世界", region: "哈尔滨", symbol: "house.lodge.fill", extra: "snowflake",
      sky: ("#cfe0f2", "#f3f7fb"), ground: "#ffffff", ink: "#5f93c7",
      message: "冰灯亮起来的时候，冷也变得好看了。"),
    Destination(
      id: "sahara", name: "撒哈拉", region: "摩洛哥", symbol: "tent.fill", extra: "sparkles",
      sky: ("#2b2f5c", "#d98f6b"), ground: "#e4b07a", ink: "#8a4b2f", night: true,
      message: "沙漠的星星特别多，想分你一半。"),
    Destination(
      id: "hokkaido", name: "薰衣草田", region: "北海道", symbol: "camera.macro", extra: "camera.macro",
      sky: ("#d5c8ef", "#f6eefb"), ground: "#b49ad8", ink: "#7d5fb8",
      message: "花田一望无际，我现在闻起来香香的。"),
    Destination(
      id: "swiss", name: "雪山缆车", region: "瑞士", symbol: "cablecar.fill", extra: "snowflake",
      sky: ("#a8d4f0", "#eef7fd"), ground: "#7fbf6a", ink: "#c94a4a",
      message: "坐缆车上雪山，空气是甜的。"),
    Destination(
      id: "dali", name: "洱海", region: "大理", symbol: "cloud.fill", extra: "leaf.fill",
      sky: ("#a6d3f2", "#f3f9fd"), ground: "#7fae7a", ink: "#ffffff",
      message: "苍山洱海，云走得比我还慢。"),
    Destination(
      id: "maldives", name: "珊瑚海", region: "马尔代夫", symbol: "fish.fill", extra: "drop.fill",
      sky: ("#7fd3e0", "#e8fbfb"), ground: "#3fb5c4", ink: "#f29a4a",
      message: "和小鱼一起游泳，它们一点都不怕我。"),
    Destination(
      id: "giza", name: "金字塔", region: "埃及", symbol: "triangle.fill", extra: "sun.max.fill",
      sky: ("#f9d9a0", "#fdf1d8"), ground: "#e2b878", ink: "#c79a52",
      message: "金字塔好高，我在它的影子里乘凉。"),
    Destination(
      id: "newyork", name: "城市夜景", region: "纽约", symbol: "building.2.fill", extra: "sparkles",
      sky: ("#34406b", "#f2a77c"), ground: "#5c6474", ink: "#2b3148", night: true,
      message: "城市的灯一盏盏亮起来，好像在说加油。"),
    Destination(
      id: "tulips", name: "郁金香", region: "荷兰", symbol: "bicycle", extra: "camera.macro",
      sky: ("#bfe0f5", "#fbf5e6"), ground: "#e86a6a", ink: "#3b5f8a",
      message: "郁金香排成彩虹，我骑车穿过去。"),
    Destination(
      id: "kenya", name: "草原", region: "肯尼亚", symbol: "tree.fill", extra: "sun.max.fill",
      sky: ("#f7b267", "#fde4b8"), ground: "#d4a85a", ink: "#6b5a2e",
      message: "长颈鹿低头看我，我们互相打了招呼。"),
    Destination(
      id: "sydney", name: "海边", region: "悉尼", symbol: "figure.surfing", extra: "sun.max.fill",
      sky: ("#9fdcf5", "#fff3d6"), ground: "#f3d79c", ink: "#2f7fa8",
      message: "学会了冲浪的第一步：站起来。"),
    Destination(
      id: "moon", name: "月球", region: "太空", symbol: "moon.fill", extra: "sparkles",
      sky: ("#0f1730", "#2c3866"), ground: "#c9c9d6", ink: "#f5e6a8", night: true,
      message: "这次走得有点远。我在月亮上看到了地球，还有你。"),
  ]
}

extension AppState {
  /// Postcards received by `today`, oldest first: one on every `daysPerTrip`th active day.
  /// After the last place, 小日 starts over from the first one.
  func postcards(today: String) -> [Postcard] {
    let days = activeDays.filter { $0 <= today }
    let places = Travel.destinations
    return stride(from: Travel.daysPerTrip, through: days.count, by: Travel.daysPerTrip).enumerated().map { index, count in
      Postcard(number: index + 1, destination: places[index % places.count], day: days[count - 1])
    }
  }

  /// Active days still needed before the next postcard arrives.
  func daysToNextPostcard(today: String) -> Int {
    let count = activeDays.filter { $0 <= today }.count
    return Travel.daysPerTrip - count % Travel.daysPerTrip
  }
}
