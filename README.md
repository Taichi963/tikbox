# LiveVoice Box

LiveVoice Box is an unofficial live-stream comment reading assistant for
streamers. It reads public live comments aloud through the device's configured
text-to-speech service, plays short gift feedback sounds, and supports
user-started reading audio while the app is in the background.

## Important Notice

- LiveVoice Box is not an official app and is not affiliated with, endorsed by,
  approved by, or sponsored by TikTok, ByteDance, or any live-streaming
  platform.
- The app does not ask for TikTok login credentials.
- The app does not collect passwords or read existing browser, login, or TikTok
  app cookies.
- The bundled LIVE connection library obtains a temporary service-issued
  `ttwid` cookie through an unauthenticated request for the public LIVE
  connection. It is not a user login credential and LiveVoice Box does not save
  it in SharedPreferences or an app database.
- The app does not guarantee a public LIVE connection. Availability may vary
  because of stream status, network conditions, service changes, operating
  system restrictions, or device settings.
- Users should use the app only for their own stream or a stream they are
  authorized to support.

## Main Features

- Public live-comment text-to-speech.
- Gift sound and optional short vibration feedback.
- Bronze, Silver, Gold, and Heart Me gift sound feedback.
- Gift sound, vibration, voice, speed, pitch, and volume settings.
- Saved stream ID history stored locally on the device.
- Local blocked-word filtering and public LIVE user blocking.
- Comment report preparation for the published support email. The user copies
  the recipient, subject, and report body and sends it from their email app.
- Android foreground service and iOS background audio for user-started reading
  audio.

## Privacy Summary

LiveVoice Box uses the entered stream ID to connect to the selected public LIVE.
Public comments, public user display names, and public gift events are received
through the live connection and processed for display, reading, sound, and
vibration.

Stored locally using SharedPreferences:

- app and TTS settings
- gift sound and vibration settings
- saved stream ID history

The app does not include a LiveVoice Box-operated backend, account system,
advertising SDK, or analytics SDK. Diagnostic operating-system logs may contain
the entered stream ID, public user display names, gift information, and
connection or audio state details.

The full current documentation is available in:

- [Privacy Policy](docs/privacy.md)
- [Terms of Use](docs/terms.md)
- [Store Release Kit](docs/release_kit.md)

Submission information:

- Operator: `[OPERATOR_NAME]`
- Support email: zeb0kui3ackwv4pft1us@gmail.com
- Privacy Policy: https://taichi963.github.io/tikbox/privacy.html
- Support: https://taichi963.github.io/tikbox/support.html
- Terms: https://taichi963.github.io/tikbox/terms.html

## Permissions And Background Audio

Android permissions are used for:

- `INTERNET`: connect to the selected public LIVE.
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK`: continue
  user-started reading audio when the app is not in the foreground.
- `POST_NOTIFICATIONS`: show the active reading notification on supported
  Android versions.
- `WAKE_LOCK`: reduce interruptions during an active reading session.
- `VIBRATE`: provide optional short gift vibration feedback.

iOS background audio is used to continue user-started reading audio during an
active session. It must not be described as hidden monitoring or a silent
background keep-alive feature.

## Store Review Positioning

Recommended wording:

> LiveVoice Box is an unofficial tool for streamers that reads public live
> comments aloud using the device's configured text-to-speech service. It does
> not require TikTok login credentials and does not collect passwords or read
> existing browser or login cookies. Background audio is used to continue
> user-started comment reading during an active live session.

Avoid wording that implies:

- official partnership, approval, or integration
- guaranteed public LIVE connection
- account login, cookie extraction, or browser-cookie access
- viewer tracking, surveillance, or identity matching
- hidden background processing

## Release Checks

Before store submission, confirm:

- `flutter analyze --no-pub` has no issues.
- Android signed AAB and iOS Archive/IPA builds succeed.
- TestFlight and Android release builds pass physical-device tests.
- Screen-off reading, foreground notification, audio interruption, Bluetooth,
  AirPods, vibration, real gifts, reconnect, and Stop behavior are verified.
- A public HTTPS privacy-policy URL and current support contact are available.
- App Store Connect privacy responses, Google Play Data safety responses, and
  the Google Play foreground-service declaration match the release build.
