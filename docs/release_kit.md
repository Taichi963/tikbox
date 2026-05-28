# Store Release Kit - LiveVoice Box

## Store Review Notes

- LiveVoice Box is an unofficial tool and is not affiliated with, endorsed by,
  or sponsored by TikTok, ByteDance, or any live-streaming platform.
- Background audio is used to keep user-started comment reading and sound
  feedback available while the streamer is live.
- Android foreground service and notification permissions are used to show that
  live reading audio is active in the background.
- The app uses the stream ID entered by the user, live comments, and gift events
  for reading, sound, vibration, local settings, and username history.
- Do not describe LiveVoice Box as an official app or official integration.

## App Name

Recommended public name:

LiveVoice Box

Reason:

- avoids implying official platform ownership
- describes the product category without overusing platform trademarks
- still communicates voice/comment reading clearly

## Safe Short Store Description

配信コメントを端末内の読み上げ音声で確認できる、配信者向けの非公式サポートツール。

## Safe Full Store Description

LiveVoice Boxは、配信中の公開コメントを端末内の読み上げ音声で確認しやすくする、
配信者向けの非公式サポートツールです。

主な機能:

- 公開LIVEコメントの読み上げ
- ギフト受信時の短い効果音とバイブレーション
- 読み上げ速度、ピッチ、音量の調整
- ギフト音のON/OFF
- 配信中に読み上げ音声を続けるためのバックグラウンド音声
- 入力したID履歴と設定の端末内保存

重要:

- 本アプリはTikTok/ByteDanceの公式アプリではありません。
- ログイン情報、パスワード、Cookie、ブラウザCookieは取得しません。
- 配信サービス側の仕様変更、通信状態、OSのバックグラウンド制限により、
  接続できない場合があります。

## App Store Review Note Example

This app is an unofficial streamer support tool. It does not request account
login credentials and does not collect cookies. Background audio is used only
to continue user-started comment text-to-speech and short sound feedback while
the streamer is live or using another app.

## Google Play Permission Explanation

- Foreground service media playback: used for active live comment reading audio.
- Notifications: used to show that live reading audio is active.
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
- Store description clearly says the app is unofficial.
