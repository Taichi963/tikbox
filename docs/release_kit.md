# Store Release Kit - LiveVoice Box

## Submission Status

The following submission fields must be completed before submission:

- developer/operator: `LiveVoice Studio`
- effective date: `[EFFECTIVE_DATE]`
- governing law and jurisdiction: `本規約は日本法に準拠し、本サービスに関して紛争が生じた場合、東京地方裁判所を第一審の専属的合意管轄裁判所とします。`

The following review items also remain to be completed:

- evidence that access to and display of public LIVE data is permitted under
  the applicable third-party service terms
- App Store Connect privacy responses
- Google Play Data safety responses
- Google Play foreground-service declaration and demonstration video

## App Name

LiveVoice Box

This name describes the app without presenting it as an official TikTok or
ByteDance product.

## Safe Short Store Description

LiveVoice Boxは、ライブ配信中のコメント読み上げとギフト通知音をサポートする非公式の配信補助アプリです。

## Safe Full Store Description

LiveVoice Boxは、ライブ配信中の公開コメントを端末の読み上げサービスで確認しやすくする、配信者向けの非公式サポートツールです。

主な機能:

- 公開LIVEコメントの読み上げ
- ギフト受信時の短い通知音とバイブレーション
- 読み上げ速度、ピッチ、音量の調整
- ギフト通知音とギフトバイブレーションのON/OFF
- ユーザーが開始した読み上げ音声を継続するためのバックグラウンド音声
- 入力した配信ID履歴と設定の端末内保存

重要:

- 本アプリはTikTokまたはByteDanceの公式アプリではなく、両社から承認、提供、スポンサーを受けたものではありません。
- TikTokのログイン情報、パスワード、既存のブラウザCookie、ログインCookieは取得しません。
- 公開LIVE接続時に、接続ライブラリがTikTokから未認証接続用の`ttwid` Cookieを一時的に取得して使用します。このCookieはログイン情報ではなく、LiveVoice BoxのSharedPreferencesやデータベースには保存されません。
- ユーザー自身の配信、または利用を許可された配信の補助用途で利用してください。
- 配信サービス側の仕様変更、配信状態、通信環境、端末状態、OSのバックグラウンド制限により、接続や読み上げを利用できない場合があります。

## App Store Review Notes

LiveVoice Box is an unofficial streamer support tool. It is not affiliated
with, endorsed by, approved by, or sponsored by TikTok, ByteDance, or any other
live-streaming platform.

The app does not require a TikTok login and does not request passwords or read
existing browser, login, or TikTok app cookies. The bundled LIVE connection
library obtains a service-issued `ttwid` cookie through an unauthenticated
request and uses it for the public WebSocket connection. It is not a user login
credential and is not saved by LiveVoice Box in SharedPreferences or an app
database.

The reviewer can enter the @ID or URL of a currently active public LIVE. If the
selected account is not live, the connection may time out or fail.

Public live comments, public user display names, and public gift events are
received through the live connection and processed for display, text-to-speech,
short sound feedback, and optional vibration. App settings and saved stream IDs
are stored locally using SharedPreferences. The app does not operate a backend
user database, analytics service, or advertising service.

The Android release includes local comment moderation. Fixed and user-added
blocked words prevent matching comments from display, comment sound, and
text-to-speech. Public LIVE users can be blocked locally. The report screen
prepares a report containing the selected public display name, public LIVE user
reference, comment, time, and reason. The support email, subject, and report
body are copied for the user to paste into their email app and send to the
operator. It is not uploaded or sent automatically. The prepared report does
not include cookies, `ttwid`, device IDs, complete internal logs, login
credentials, or authentication information.

Background audio is used only to continue user-started comment text-to-speech
and short sound feedback during an active live-reading session. It is not used
for hidden monitoring or silent background data collection.

Users are expected to use the app for their own live stream or a stream they are
authorized to support. Connection availability is not guaranteed.

Evidence that this app's access to and display of public LIVE data is permitted
under the applicable third-party service terms: 未確認

Reviewer contact: zeb0kui3ackwv4pft1us@gmail.com

Privacy-policy URL: https://taichi963.github.io/tikbox/privacy.html

## Google Play Permission And Foreground-Service Explanation

- `INTERNET`: connects to the selected public LIVE and receives public comments
  and gift events.
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK`: continues
  user-started comment reading audio when the app is not in the foreground.
- `POST_NOTIFICATIONS`: shows that the live-reading audio service is active on
  supported Android versions.
- `VIBRATE`: provides optional short gift vibration feedback when enabled.
- `WAKE_LOCK`: reduces interruptions during a user-started live-reading
  session.

The Play Console foreground-service declaration must:

- identify media playback as the declared foreground-service type
- explain that the user starts the live-reading session
- explain the impact if reading audio is delayed or interrupted
- include a video showing how the user starts the feature, backgrounds the app,
  observes the notification, and stops the session

## Privacy And Data Safety Alignment

Store disclosures must match `docs/privacy.md`:

- stream IDs and app settings are stored locally
- user-added blocked words and blocked public LIVE user IDs are stored locally
- public comments, public user display names, and public gift events are
  processed for app functionality
- prepared comment reports are copied to the clipboard and are not transmitted
  automatically by LiveVoice Box; the user sends them to
  zeb0kui3ackwv4pft1us@gmail.com using their email app
- diagnostic operating-system logs may contain stream IDs, public display
  names, gift information, and connection/audio states
- the bundled LIVE connection library uses a transient service-issued `ttwid`
  cookie, but does not read or store the user's existing login cookies
- no LiveVoice Box-operated backend, analytics SDK, or advertising SDK is
  included
- no passwords or authenticated user-session cookies are requested

Whether individual data types must be declared as "collected" in App Store
Connect or Google Play depends on each store's definitions and the behavior of
the live service, device TTS provider, and bundled third-party libraries. Final
console answers are 未確認 and must be validated against the release build.

## Words To Avoid

- 公式
- 公式連携
- approved TikTok integration
- guaranteed connection
- no cookies are used
- browser cookie extraction
- login automation
- silent keep-alive
- viewer tracking
- account monitoring

## Required Manual Checks Before Submission

- Android signed AAB builds successfully.
- Android release device keeps the foreground notification visible during
  active reading.
- Google Play foreground-service declaration and demonstration video are
  complete.
- iOS Archive/IPA builds successfully with the correct signing team.
- The TestFlight build passes physical-device background-audio testing.
- The public privacy-policy URL works without login and is not a PDF.
- The privacy policy is linked in App Store Connect and is easily accessible
  from the app.
- App Store Connect privacy responses and Google Play Data safety responses
  match the release build.
- Cookie and identifier disclosures account for the transient service-issued
  `ttwid` used by the bundled LIVE connection library.
- Store screenshots and descriptions show the actual app and do not imply an
  official relationship with TikTok or ByteDance.
- Authorization evidence required for access to third-party service content is
  available if requested during App Review.
- The developer/operator has reviewed the final Privacy Policy and Terms of Use.
