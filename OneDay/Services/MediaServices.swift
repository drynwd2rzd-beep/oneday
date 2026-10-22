import AVFoundation
import CoreTransferable
import Observation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Voice recording

@MainActor
@Observable
final class AudioRecorder {
  private(set) var isRecording = false
  private(set) var elapsed: TimeInterval = 0
  private(set) var level: Float = 0

  @ObservationIgnored private var recorder: AVAudioRecorder?
  @ObservationIgnored private var fileName: String?
  @ObservationIgnored private var timer: Timer?

  static let maxDuration: TimeInterval = 10 * 60

  /// Returns false when the microphone is not allowed.
  func start() async -> Bool {
    guard await AVAudioApplication.requestRecordPermission() else { return false }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
      try session.setActive(true)
      let (name, url) = MediaStore.newFileURL(fileExtension: "m4a")
      let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
      ]
      let r = try AVAudioRecorder(url: url, settings: settings)
      r.isMeteringEnabled = true
      r.record(forDuration: Self.maxDuration)
      recorder = r
      fileName = name
      isRecording = true
      elapsed = 0
      timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        Task { @MainActor in self?.tick() }
      }
      return true
    } catch {
      return false
    }
  }

  private func tick() {
    guard let recorder, recorder.isRecording else { return }
    recorder.updateMeters()
    elapsed = recorder.currentTime
    let db = recorder.averagePower(forChannel: 0)
    level = max(0, min(1, (db + 50) / 50))
  }

  /// Stops and returns the recording, or nil if it was too short.
  func stop() -> MediaItem? {
    guard let recorder, let fileName else { return nil }
    let duration = recorder.currentTime
    recorder.stop()
    cleanup()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    guard duration >= 1 else {
      MediaStore.delete(fileName)
      return nil
    }
    return MediaItem(kind: .audio, file: fileName, duration: duration)
  }

  func cancel() {
    recorder?.stop()
    recorder?.deleteRecording()
    cleanup()
  }

  private func cleanup() {
    timer?.invalidate()
    timer = nil
    recorder = nil
    fileName = nil
    isRecording = false
    level = 0
  }
}

// MARK: - Playback

/// Plays one recording at a time across the app.
@MainActor
@Observable
final class AudioPlayback {
  static let shared = AudioPlayback()

  private(set) var current: String?
  private(set) var progress: Double = 0

  @ObservationIgnored private var player: AVAudioPlayer?
  @ObservationIgnored private var timer: Timer?

  func toggle(_ file: String) {
    if current == file {
      stop()
      return
    }
    stop()
    guard MediaStore.exists(file), let p = try? AVAudioPlayer(contentsOf: MediaStore.url(file)) else { return }
    try? AVAudioSession.sharedInstance().setCategory(.playback)
    try? AVAudioSession.sharedInstance().setActive(true)
    p.play()
    player = p
    current = file
    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      Task { @MainActor in
        guard let self, let player = self.player, player.duration > 0 else { return }
        if !player.isPlaying {
          self.stop()
          return
        }
        self.progress = player.currentTime / player.duration
      }
    }
  }

  func stop() {
    player?.stop()
    player = nil
    timer?.invalidate()
    timer = nil
    current = nil
    progress = 0
  }
}

// MARK: - Video import

/// A picked video copied into app storage.
struct PickedVideo: Transferable {
  let item: MediaItem

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .movie) { received in
      let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension.lowercased()
      let name = try MediaStore.importFile(from: received.file, fileExtension: ext)
      let asset = AVURLAsset(url: MediaStore.url(name))
      let seconds = (try? await asset.load(.duration).seconds) ?? 0
      return PickedVideo(item: MediaItem(kind: .video, file: name, duration: seconds.isFinite ? seconds : 0))
    }
  }
}

enum VideoThumbnails {
  private static let cache = NSCache<NSString, UIImage>()

  static func image(for file: String) async -> UIImage? {
    if let cached = cache.object(forKey: file as NSString) { return cached }
    guard MediaStore.exists(file) else { return nil }
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: MediaStore.url(file)))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 480, height: 480)
    guard let (cg, _) = try? await generator.image(at: CMTime(seconds: 0.1, preferredTimescale: 600)) else { return nil }
    let image = UIImage(cgImage: cg)
    cache.setObject(image, forKey: file as NSString)
    return image
  }
}

extension TimeInterval {
  /// "0:42", "12:05"
  var clockText: String {
    let s = Int(self.rounded())
    return String(format: "%d:%02d", s / 60, s % 60)
  }
}
