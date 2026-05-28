# LiveVoice Box

LiveVoice Box is an unofficial live-stream comment reading assistant for
streamers. It reads public live comments aloud, plays short gift feedback
sounds, and can keep reading audio active while the streamer is using other
apps.

## Important Notice

- LiveVoice Box is not an official app and is not affiliated with, endorsed by,
  or sponsored by TikTok, ByteDance, or any live-streaming platform.
- The app does not ask for login credentials.
- The app does not collect passwords, cookies, browser cookies, or app cookies.
- The app does not provide a guaranteed connection. Public live connection
  behavior may change depending on the streaming service, network state, OS
  background limits, or device settings.
- Background audio is used only to continue comment reading and sound feedback
  while the user has started a live reading session.

## Main Features

- Live comment text-to-speech using the device's Japanese TTS voices.
- Gift sound and short vibration feedback.
- Gift sound ON/OFF and volume settings.
- Username history stored locally on the device.
- Heartbeat and lifecycle logs for release-device troubleshooting.
- Android foreground service and iOS background audio support for reading audio.

## Privacy Summary

LiveVoice Box uses the entered stream ID only to start the selected public live
connection. Live comments and gift events are processed inside the app for
reading, sound, and vibration.

Stored locally on the device:

- app settings
- TTS settings
- gift sound/vibration settings
- username history

Not collected by the app:

- login ID or password
- cookies
- browser/app session cookies
- private messages
- payment information

If analytics, a backend server, or external TTS is added in the future, the
privacy policy and store privacy declarations must be updated before release.

## Permissions And Background Audio

Android permissions are used for:

- `INTERNET`: connect to the selected public live stream.
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK`: keep the reading
  audio service visible while active.
- `POST_NOTIFICATIONS`: show the active reading notification on supported
  Android versions.
- `WAKE_LOCK`: support stable reading during a live session.
- `VIBRATE`: provide optional short gift vibration feedback.

iOS background audio is used to continue user-started reading audio during a
live session. It must not be described as a silent keep-alive feature in store
text.

## Store Review Positioning

Recommended wording:

> LiveVoice Box is an unofficial tool for streamers that reads public live
> comments aloud using on-device text-to-speech. It does not require login
> credentials and does not collect cookies. Background audio is used so the
> streamer can continue hearing comment reading while using other apps during a
> live session.

Avoid wording that implies:

- official partnership or official integration
- guaranteed live connection
- account login, cookie extraction, or browser-cookie access
- user tracking, viewer surveillance, or identity matching
- silent background keep-alive as a product feature

## Release Checks

Before store submission, confirm on real release builds:

- `flutter analyze --no-pub` has no issues.
- Android signed AAB builds successfully.
- iOS Archive/IPA builds successfully on macOS with a valid signing team.
- iPhone screen-off background test keeps heartbeat and reading audio stable.
- Android screen-off background test keeps notification, heartbeat, and reading
  audio stable.
- Gift sound, gift vibration, comment reading, reconnect, and Stop behavior work
  on physical devices.
