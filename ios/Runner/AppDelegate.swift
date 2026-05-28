import Flutter
import UIKit
import AVFoundation

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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
