# App Store App Privacy 申告対応表

対象: LiveVoice Box（App Store）
運営者: LiveVoice Studio
作成根拠: 実コード・PrivacyInfo.xcprivacy・Info.plist・docs/privacy.md を照合

> **利用方法**: このファイルは App Store Connect の「App のプライバシー」入力画面への回答を補助するためのものです。
> 最終的な申告内容はリリースビルドの実挙動と App Store Connect の設問定義（提出時点の最新版）に照らして開発者が確認してください。

---

## 1. PrivacyInfo.xcprivacy の内容確認

ファイル: `ios/Runner/PrivacyInfo.xcprivacy`

| 宣言項目 | 値 | 整合確認 |
|---|---|---|
| `NSPrivacyAccessedAPICategoryUserDefaults` | 理由 `CA92.1`（アプリのデフォルト値として使用） | SharedPreferences = UserDefaults 使用（`tts_provider.dart:34`）と整合 ✓ |
| `NSPrivacyCollectedDataTypes` | 空配列 | データ収集なし ✓ |
| `NSPrivacyTracking` | false | トラッキングなし ✓ |
| `NSPrivacyTrackingDomains` | 空配列 | トラッキングドメインなし ✓ |

---

## 2. App Tracking Transparency（ATT）の要否

**ATT は不要。**

根拠:
- `NSPrivacyTracking = false`（`ios/Runner/PrivacyInfo.xcprivacy:18`）
- アプリはユーザーを他社アプリ・ウェブサイトにわたって追跡しない
- 広告 SDK・フィンガープリント・クロスアプリ識別子を使用しない（`pubspec.yaml` で確認）
- `NSUserTrackingUsageDescription` を Info.plist に宣言しないことが正しい（現状通り）

---

## 3. App Privacy 設問への推奨回答

### データの収集（Data Collection）

| Apple 設問 | 推奨回答 | 根拠 |
|---|---|---|
| このアプリはユーザーからデータを収集しますか？ | **いいえ（データを収集しない）** | HTTP クライアント不使用（`pubspec.yaml`）。外部送信コードなし（`app_logger.dart:1` — `dart:developer` のみ） |

収集なしを選択した場合は、以下のカテゴリ設問は表示されないか「該当なし」となる。

### 収集データのカテゴリ別確認（収集なしでも念のため）

| カテゴリ | 収集するか | 根拠 |
|---|---|---|
| 連絡先 | なし | 連絡先アクセス権限なし（`Info.plist` 確認） |
| ヘルス/フィットネス | なし | HealthKit 不使用 |
| 財務情報 | なし | 決済 SDK 不使用 |
| 位置情報 | なし | 位置権限なし |
| 機密情報 | なし | — |
| 連絡先 | なし | — |
| ユーザーコンテンツ | 要確認（→ C-1） | 公開 LIVE コメントを端末上で処理するが、収集・送信はしない |
| 閲覧履歴 | なし | — |
| 検索履歴 | なし | — |
| 識別子 | 要確認（→ C-2） | `uniqueId`（TikTok の公開 LIVE ユーザー ID）を SharedPreferences に保存するが、外部送信しない |
| 購入 | なし | — |
| 使用状況データ | 要確認（→ C-3） | OS ログに接続状態等を書き込む（端末内のみ） |
| 診断 | 要確認（→ C-3） | 同上 |
| その他のデータ | なし（上記に該当しない） | — |

---

## 4. 端末内ストレージ（収集に該当しないが把握しておく内容）

SharedPreferences (= UserDefaults) に保存されるデータ一覧:

| 保存内容 | コード根拠 | Apple の定義での扱い |
|---|---|---|
| 読み上げ設定（速度・ピッチ・音量・ボイス選択等） | `tts_provider.dart:11` | ユーザー設定の端末内保存（外部未送信） |
| ギフト効果音 ON/OFF | `tts_provider.dart:12` | 同上 |
| ブロックユーザー ID（TikTok 公開 uniqueId） | `main_provider.dart:11` | 同上（→ 要確認 C-2） |
| ユーザー追加 NGワード | `main_provider.dart:12` | 同上 |
| 最後に入力した配信 ID | `main_screen.dart:20` | 同上 |
| 保存した配信 ID 履歴（最大5件） | `main_screen.dart:21` | 同上 |

---

## 5. ttwid Cookie の App Privacy における扱い

| 項目 | 内容 |
|---|---|
| Cookie の出所 | TikTok サーバーが `piratetok_live` ライブラリに返す一時サービス Cookie |
| ユーザー認証情報か | いいえ |
| ユーザーのブラウザ・TikTok アプリから読み取るか | いいえ（`docs/privacy.md:55-62`） |
| LiveVoice Box の UserDefaults に保存するか | いいえ |
| LiveVoice Box の外部サーバーに送るか | いいえ |
| App Privacy での扱い | 第三者ライブラリが使用する一時 Cookie として、「追跡」に使用していないことを確認（→ 要確認 C-4） |

---

## 6. 要確認項目（人間が最終判断すべき設問）

| # | 要確認内容 | 理由 |
|---|---|---|
| C-1 | 公開 LIVE コメント（受信してアプリ内で表示・読み上げ）が Apple の「ユーザーコンテンツ」収集に該当するか | コメントは端末メモリに保持され外部送信しないが、Apple の定義では処理自体が「収集」とみなされる場合がある。App Store Connect の最新定義を確認すること |
| C-2 | TikTok 公開 uniqueId（ユーザーID）の UserDefaults 保存が Apple の「識別子」収集に該当するか | `main_provider.dart:11` でブロックリストとして保存。Apple は「デバイス ID またはその他の識別子」を収集に含めることがある |
| C-3 | OS ログへの書き込み（`dart:developer` の `log()`）が「診断データ」収集に該当するか | ログは端末内・OS 管理。LiveVoice Box は転送しないが、Apple の設問がアプリのログ書き込みを「収集」とみなすかは要確認 |
| C-4 | `piratetok_live` ライブラリの ttwid 使用が「追跡」の Apple 定義に該当しないか | `NSPrivacyTracking = false` と宣言済みだが、ライブラリの内部動作を Apple が問い合わせる可能性がある（審査時に要説明） |
| C-5 | App Store Connect のプライバシー回答画面で「第三者ライブラリ」として `piratetok_live` の申告が求められるか | 2024年以降、Apple はサードパーティ SDK の PrivacyInfo.xcprivacy を要求している。`piratetok_live` が独自の PrivacyInfo を持つかを確認すること（提出時点の要件で要確認） |
