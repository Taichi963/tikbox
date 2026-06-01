# Store Release Kit - LiveVoice Box

## Store Review Notes

- LiveVoice Box is an unofficial tool and is not affiliated with, endorsed by,
  or sponsored by TikTok, ByteDance, or any live-streaming platform.
- Background audio is used to keep user-started comment reading and short sound
  feedback available while the streamer is live.
- Android foreground service and notification permissions are used to show that
  live reading audio is active in the background.
- The app uses the stream ID entered by the user, live comments, and gift events
  for reading, sound, vibration, local settings, and username history.
- Users should use the app for their own live stream or streams they are
  authorized to support.
- Do not describe LiveVoice Box as an official app or official integration.

## App Name

Recommended public name:

LiveVoice Box

Reason:

- avoids implying official platform ownership
- describes the product category without overusing platform trademarks
- still communicates voice/comment reading clearly

## Safe Short Store Description

LiveVoice Boxは、ライブ配信中のコメント読み上げとギフト通知音を
サポートする非公式の配信補助アプリです。

## Safe Full Store Description

LiveVoice Boxは、ライブ配信中の公開コメントを端末内の読み上げ音声で
確認しやすくする、配信者向けの非公式サポートツールです。

主な機能:

- 公開LIVEコメントの読み上げ
- ギフト受信時の短い通知音とバイブレーション
- 読み上げ速度、ピッチ、音量の調整
- ギフト音のON/OFF
- ユーザーが開始した読み上げ音声を続けるためのバックグラウンド音声
- 入力した配信ID履歴と設定の端末内保存

重要:

- 本アプリはTikTok/ByteDanceの公式アプリではありません。
- TikTokのログイン情報、パスワード、Cookie、ブラウザCookieは取得しません。
- ユーザー自身の配信、または許可された配信の補助用途で利用してください。
- 配信サービス側の仕様変更、配信状態、通信環境、OSのバックグラウンド制限により、
  接続や読み上げを利用できない場合があります。

## App Store Review Note Example

LiveVoice Box is an unofficial streamer support tool and is not affiliated with
TikTok, ByteDance, or any live-streaming platform. The app does not request
account login credentials, passwords, cookies, browser cookies, or app cookies.
Background audio is used only to continue user-started comment text-to-speech
and short sound feedback while the streamer is live or using another app.
Users are expected to use the app for their own live stream or streams they are
authorized to support.

## Google Play Permission Explanation

- Foreground service media playback: used while the user has started live
  comment reading audio.
- Notifications: used to show that live reading audio is active in the
  background.
- Vibration: used only for optional short gift feedback.
- Wake lock: used to reduce interruptions during an active live reading session.

## Words To Avoid

- 公式
- 公式連携
- guaranteed connection
- cookie acquisition
- browser cookie extraction
- login automation
- silent keep-alive
- viewer tracking
- account monitoring

## Required Manual Checks Before Submission

- Android signed AAB builds successfully.
- Android release device keeps foreground notification visible during reading.
- iOS Archive/IPA builds successfully with the correct signing team.
- iPhone screen-off background reading works on a physical device.
- Store privacy declarations match `docs/privacy.md`.
- Store terms match `docs/terms.md`.
- Store description clearly says the app is unofficial.
