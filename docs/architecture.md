# TikBox Architecture Notes

このドキュメントは、現在のTikBoxの責務境界を記録し、将来のサブスクリプション、Premium Voice、ギフト音パック、Theme、外部TTS追加時に触る場所を明確にするためのものです。

現在はMVP公開前の安定化フェーズです。実装変更よりも、release実機テスト、バックグラウンド安定性、ストア提出準備を優先します。

## 1. 現在の構成

TikBoxはFlutter + Riverpod構成です。主な層は次の通りです。

- `lib/features/`: 画面単位・機能単位のProviderとUIを置く。
- `lib/services/`: TTS、AudioService、効果音、ログなど、アプリ全体で使う処理を置く。
- `lib/models/`: コメント、TTS設定などのデータ構造を置く。
- `lib/widgets/`: コメント表示、ギフト演出、ネオンUIなどの表示部品を置く。
- `android/`, `ios/`: foreground service、background audio、署名、権限などのプラットフォーム設定を置く。
- `test/`: 現在は効果音WAV生成、gift tier境界値、TTS設定復元、基本Widget表示を確認している。

## 2. features / services / models / widgets の責務

### features

`features` はユーザー操作、接続状態、画面表示、設定UIを扱います。

- `features/live/live_provider.dart`: LIVE接続とイベント処理の中心。
- `features/main/main_provider.dart`: メイン画面用の軽い表示状態。接続中ユーザー名とコメント一覧を保持する。
- `features/main/main_screen.dart`: メインUI、username履歴、設定UI、voice preview導線を持つ。
- `features/main/tts_provider.dart`: `TtsSettings` の保存・復元、効果音/TTSサービスへの設定反映を持つ。

### services

`services` はプラットフォーム機能や音処理に近い処理を扱います。

- `tts_service.dart`: TTS queue、AudioService初期化、voice一覧取得、sanitize、再生要求の入口。
- `background_tts_handler.dart`: AudioHandler、flutter_tts実再生、keep-alive、playbackStateを扱う。
- `effect_sound_service.dart`: コメント音、ギフト音、gift tier、AudioPool、ducking、音生成を扱う。
- `app_logger.dart`: 共通ログ出力。

### models

`models` は永続化や表示・読み上げに使うデータ構造を扱います。

- `CommentModel`: 通常コメントとギフトコメントを表現する。
- `TtsSettings`: rate、pitch、音量、プリセット、keepScreenOn、gift vibration、voice設定などを表現する。

### widgets

`widgets` は表示専用に近い部品を扱います。

- `comment_animation.dart`: コメント表示。
- `gift_animation.dart`: ギフト演出。
- `neon_effect.dart`: ネオン調UI共通部品。

## 3. live_provider.dart の責務

現在の `live_provider.dart` は、次の責務をまとめて持っています。

- username正規化。
- `TikTokLiveClient` の作成、接続、切断。
- `connected`, `disconnected`, `reconnecting`, `error`, `chat`, `gift` イベント処理。
- reconnect timer、接続遅延ログ、diagnostic heartbeat。
- Stop後に再接続しないための `_manualStopRequested` 管理。
- コメント受信時の `CommentModel` 作成、コメント音、コメントTTS enqueue。
- ギフト受信時の coin値解決、gift sound trigger、gift vibration、gift TTS enqueue。
- app resume時のstale接続再試行。

MVPでは1ファイルに集約されていることで挙動を追いやすいです。ただし将来、AIリアクション、Analytics、ギフト演出、課金制限を追加すると最初に肥大化します。

release前は接続方式やreconnect構造を大きく触らないでください。

## 4. tts_service.dart の責務

現在の `tts_service.dart` は、次の責務を持っています。

- `AudioService.init` による `LiveVoiceBoxAudioHandler` の初期化。
- TTS queue管理、優先度ソート、queue上限管理。
- `stopAll`, `skip`, playback generation管理。
- コメント本文のsanitizeと読み上げ可能判定。
- 日本語voice一覧取得、voice正規化、voice preview。
- `TtsSettings` のrate、pitch、volume、voiceを再生要求に反映。

現在は端末内 `flutter_tts` 前提です。外部TTSやAI Voiceを入れる前に、TTS engineの境界を設計する必要があります。

release前はqueue制御、generation、AudioService初期化を大きく触らないでください。

## 5. background_tts_handler.dart の責務

現在の `background_tts_handler.dart` は、次の責務を持っています。

- `BaseAudioHandler` 実装。
- `flutter_tts` の実再生。
- iOS/Android向けTTS audio session設定。
- TTS start / complete / error handler。
- connection active中のplaybackState維持。
- keep-alive音の生成、ループ再生、停止、復旧。
- Background heartbeatログ。
- stop/skip時のTTS停止とkeep-alive復旧。

ここはiOS/Androidの実機依存が最も強い層です。コードだけではbackground安定性を保証できません。

release前は実機テストを優先し、推測でAudioHandlerやkeep-alive方式を作り直さないでください。

## 6. effect_sound_service.dart の責務

現在の `effect_sound_service.dart` は、次の責務を持っています。

- コメント音とギフト音のWAV生成。
- `AudioPool` の初期化と再生。
- `giftSoundEnabled` と `effectVolume` の反映。
- gift coin値から `_GiftSoundTier` を判定。
- small / medium / large / ultraRare の音分岐。
- combo streakに応じた音分岐。
- TTS中のducking。
- Web audio unlock用prime処理。

現在は生成音・tier policy・playbackが1ファイルにまとまっています。ギフト音パックや有料音源を追加する前に、sound catalogとtier policyの分離を検討してください。

release前は音量、ducking、AudioPool構造を大きく触らないでください。

## 7. main_screen.dart の責務

現在の `main_screen.dart` は、次の責務を持っています。

- メイン画面UI。
- username入力、username正規化、username履歴保存・削除。
- 接続/停止ボタン。
- 接続状態表示、エラー表示、コメント一覧、ギフト演出表示。
- 読み上げ設定のbottom sheet。
- voice選択、voice preview、voice決定。
- rate、pitch、音量、gift sound、gift vibration、keepScreenOnなどの設定UI。
- 非公式/プライバシー説明ダイアログ。

MVPでは1画面で完結しているため使いやすいです。ただし設定項目、Theme、Premium導線が増えると最初に肥大化します。

release前はUI構造の大幅変更を避けてください。

## 8. 今は触らない方が良い箇所

release前に触らない方が良い箇所は次の通りです。

- `live_provider.dart` の接続方式、reconnect、Stop後再接続抑止。
- `background_tts_handler.dart` のAudioHandler、playbackState、keep-alive。
- `tts_service.dart` のqueue、generation、AudioService初期化。
- `effect_sound_service.dart` のAudioPool、ducking、giftSoundEnabled/effectVolume反映。
- Android/iOSのbackground audio / foreground service設定。ただし審査やビルドで明確な不足がある場合は最小修正のみ。

これらはrelease実機品質に直結します。問題が未確定の場合は、修正ではなくログ確認を優先します。

## 9. 将来分離する候補

MVP公開後、次の順番で小さく分離すると安全です。

1. `docs/architecture.md` で責務境界を維持する。
2. username正規化、gift tier判定などの純粋ロジックをテストしやすい形に寄せる。
3. `FeatureFlags` を追加し、実験機能やPremium導線のON/OFFを集約する。
4. `EntitlementProvider` を追加し、サブスク/Premium判定を集約する。
5. `VoiceDefinition` / `VoiceCatalog` を追加し、voice表示・保存・Premium制限を整理する。
6. `GiftSoundCatalog` / `GiftSoundPolicy` を追加し、音源とtier policyを分ける。
7. `SettingsRepository` を追加し、SharedPreferences直依存を隠す。
8. `AppThemeTokens` を追加し、Theme切替の影響範囲を減らす。
9. 外部TTS導入前に `SpeechEngine` 抽象を設計する。

## 10. サブスク追加時の推奨位置

サブスクを追加する場合、最初に追加する境界は `EntitlementProvider` です。

推奨位置:

- `lib/features/entitlement/entitlement_provider.dart`
- `lib/models/entitlement_state.dart`

注意点:

- Premium判定を `main_screen.dart` や `effect_sound_service.dart` に直接散らさない。
- UIは `EntitlementProvider` を読むだけにする。
- voice、gift sound、themeなどの制限はFeatureごとのcatalog側で判定できるようにする。
- 課金SDK導入はMVP公開後に行う。release前には入れない。

## 11. Premium Voice追加時の推奨位置

Premium Voiceを追加する前に、voiceを `Map<String, String>` のままUIに直接渡す構造から、表示用定義を分けることを検討します。

推奨位置:

- `lib/models/voice_definition.dart`
- `lib/services/voice_catalog.dart`

注意点:

- 端末内voice、Premium voice、外部TTS voiceを同じUIで扱う場合、sourceを明示する。
- 既存の端末内日本語voiceを壊さない。
- 決定済みvoiceの保存形式を変える場合はmigrationが必要。

## 12. ギフト音パック追加時の推奨位置

ギフト音パックを追加する場合、`effect_sound_service.dart` から次を分けると安全です。

推奨位置:

- `lib/models/gift_sound_tier.dart`
- `lib/services/gift_sound_policy.dart`
- `lib/services/gift_sound_catalog.dart`

分離候補:

- coin値からtierを決めるpolicy。
- tierからtone nameを選ぶcatalog。
- 実際にAudioPoolで鳴らすplayer。

注意点:

- `giftSoundEnabled` と `effectVolume` は必ず維持する。
- TTS/keep-alive/AudioServiceに影響する変更は避ける。
- 音源を外部配信する場合はキャッシュ、ライセンス、ストア審査を別途確認する。

## 13. Theme変更時の推奨位置

Theme切替を追加する場合、まず直接指定されている色やglowをtoken化します。

推奨位置:

- `lib/theme/app_theme_tokens.dart`
- `lib/theme/app_theme_provider.dart`

注意点:

- `main_screen.dart` と `widgets/` に直接色指定が多いため、一括変更は避ける。
- 最初は既存Neon themeをtoken化するだけにする。
- Creator ThemeやSeasonal Themeは、token化後に追加する。

## 14. 外部TTS追加前に必要な設計

外部TTSやAI Voiceを追加する前に、端末内TTSと外部TTSの境界を分ける必要があります。

推奨設計:

- `SpeechRequest`: text、language、voice、rate、pitch、volumeを持つ。
- `SpeechEngine`: speak/stop/previewなどの抽象。
- `DeviceSpeechEngine`: 現在のflutter_tts実装。
- `ExternalSpeechEngine`: 将来の外部TTS/AI Voice実装。

注意点:

- コメント本文を外部APIへ送る場合、プライバシーとストア審査リスクが上がる。
- 外部TTSは通信遅延、失敗時fallback、バックグラウンド再生、キャッシュ設計が必要。
- release前には導入しない。

## 15. release前は実機テスト優先

release前に優先するべきことは次の通りです。

- iPhone screen off 10分。
- Android screen off 10分。
- Bluetooth / AirPods / route change。
- interruption / 着信 / Siri。
- Stop後に再接続しないこと。
- Live heartbeat / Background heartbeatの継続。
- TTS、ギフト音、ギフトバイブの実機確認。
- release buildでのクラッシュ確認。

コードレビューだけでは、iOS/Androidのbackground安定性は保証できません。OS依存の問題は必ず「実機確認が必要」として扱います。

## 16. 守るべき原則

- MVP公開前は安定性を最優先する。
- 未確認の実機問題をコード上の問題として断定しない。
- 接続方式、TTS queue、AudioHandler、keep-alive、reconnectは推測で大きく変更しない。
- 将来拡張は、まず薄い境界層を追加してから行う。
- Premium/AI/外部TTS/Analyticsは、プライバシーとストア審査を確認してから追加する。
