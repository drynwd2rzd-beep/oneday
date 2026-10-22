import CoreLocation
import Foundation

struct PlaceStamp {
  var place: String
  var latitude: Double
  var longitude: Double
  var weather: String?
}

/// One-shot location + reverse geocoding, plus current weather from Open-Meteo
/// (free, no account; only the rounded coordinates are sent).
@MainActor
final class LocationWeather: NSObject, CLLocationManagerDelegate {
  static let shared = LocationWeather()

  enum Failure: Error, LocalizedError {
    case denied, unavailable
    var errorDescription: String? {
      self == .denied ? "没有位置权限，可以在系统设置中允许「一天」使用位置。" : "暂时无法获取位置。"
    }
  }

  private let manager = CLLocationManager()
  private var authContinuation: CheckedContinuation<Void, Never>?
  private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

  private override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  func stamp() async throws -> PlaceStamp {
    if manager.authorizationStatus == .notDetermined {
      await withCheckedContinuation { cont in
        authContinuation = cont
        manager.requestWhenInUseAuthorization()
      }
    }
    switch manager.authorizationStatus {
    case .denied, .restricted: throw Failure.denied
    default: break
    }
    let location: CLLocation? = await withCheckedContinuation { cont in
      locationContinuation = cont
      manager.requestLocation()
    }
    guard let location else { throw Failure.unavailable }
    let place = await placeName(for: location)
    let weather = await Self.weather(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    return PlaceStamp(
      place: place, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, weather: weather)
  }

  private func placeName(for location: CLLocation) async -> String {
    let marks = try? await CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "zh_CN"))
    guard let mark = marks?.first else { return "当前位置" }
    let parts = [mark.locality ?? mark.administrativeArea, mark.subLocality ?? mark.name].compactMap { $0 }
    return parts.isEmpty ? "当前位置" : parts.uniqued().joined(separator: " · ")
  }

  nonisolated static func weather(latitude: Double, longitude: Double) async -> String? {
    let lat = (latitude * 100).rounded() / 100
    let lon = (longitude * 100).rounded() / 100
    guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code&timezone=auto") else { return nil }
    struct Response: Decodable {
      struct Current: Decodable {
        let temperature_2m: Double
        let weather_code: Int
      }
      let current: Current
    }
    var request = URLRequest(url: url)
    request.timeoutInterval = 8
    guard let (data, _) = try? await URLSession.shared.data(for: request),
          let response = try? JSONDecoder().decode(Response.self, from: data) else { return nil }
    return "\(describe(response.current.weather_code)) \(Int(response.current.temperature_2m.rounded()))°"
  }

  /// WMO weather codes used by Open-Meteo.
  nonisolated static func describe(_ code: Int) -> String {
    switch code {
    case 0: "晴"
    case 1, 2: "多云"
    case 3: "阴"
    case 45, 48: "雾"
    case 51...57: "毛毛雨"
    case 61, 63, 80, 81: "雨"
    case 65, 82: "大雨"
    case 66, 67: "冻雨"
    case 71, 73, 75, 77, 85, 86: "雪"
    case 95...99: "雷雨"
    default: "天气"
    }
  }

  static func symbol(for weather: String) -> String {
    if weather.hasPrefix("晴") { return "sun.max" }
    if weather.hasPrefix("多云") { return "cloud.sun" }
    if weather.hasPrefix("阴") { return "cloud" }
    if weather.hasPrefix("雾") { return "cloud.fog" }
    if weather.hasPrefix("雷") { return "cloud.bolt.rain" }
    if weather.contains("雪") { return "cloud.snow" }
    if weather.contains("雨") { return "cloud.rain" }
    return "thermometer.medium"
  }

  // MARK: CLLocationManagerDelegate

  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    Task { @MainActor in
      if manager.authorizationStatus != .notDetermined {
        authContinuation?.resume()
        authContinuation = nil
      }
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    let last = locations.last
    Task { @MainActor in
      locationContinuation?.resume(returning: last)
      locationContinuation = nil
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Task { @MainActor in
      locationContinuation?.resume(returning: nil)
      locationContinuation = nil
    }
  }
}
