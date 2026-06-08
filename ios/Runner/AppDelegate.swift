import Flutter
import UIKit
import AVFoundation
import AudioToolbox

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
      try session.setActive(true)
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleAudioSessionInterruption),
        name: AVAudioSession.interruptionNotification,
        object: session
      )
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleAudioSessionRouteChange),
        name: AVAudioSession.routeChangeNotification,
        object: session
      )
    } catch {
      NSLog("LiveVoice Box audio session setup failed: \(error.localizedDescription)")
    }

    GeneratedPluginRegistrant.register(with: self)
    configureGiftVibrationChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureGiftVibrationChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      NSLog("LiveVoice Box gift vibration channel setup skipped: no FlutterViewController")
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.taichi963.tikbox/gift_vibration",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "vibrateGift" else {
        result(FlutterMethodNotImplemented)
        return
      }

      let arguments = call.arguments as? [String: Any]
      let value = arguments?["value"] as? Int ?? 0
      DispatchQueue.main.async {
        self?.playGiftVibration(value: value)
        result(true)
      }
    }
  }

  private func playGiftVibration(value: Int) {
    if #available(iOS 10.0, *) {
      let style: UIImpactFeedbackGenerator.FeedbackStyle = value >= 100 ? .heavy : .medium
      let generator = UIImpactFeedbackGenerator(style: style)
      generator.prepare()
      generator.impactOccurred()
    }
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
  }

  @objc private func handleAudioSessionInterruption(_ notification: Notification) {
    let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
    let optionValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
    let typeText = typeValue.map { String($0) } ?? "unknown"
    let optionText = optionValue.map { String($0) } ?? "none"
    NSLog(
      "LiveVoice Box audio session interruption: type=\(typeText) options=\(optionText)"
    )
  }

  @objc private func handleAudioSessionRouteChange(_ notification: Notification) {
    let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
    let reasonText = reasonValue.map { String($0) } ?? "unknown"
    NSLog(
      "LiveVoice Box audio session route change: reason=\(reasonText)"
    )
  }
}
