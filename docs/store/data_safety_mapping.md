# Google Play Data Safety 申告対応表

対象: LiveVoice Box（Google Play）
運営者: LiveVoice Studio
作成根拠: 実コードおよび docs/privacy.md を照合

> **利用方法**: このファイルは Play Console の「データの安全性」入力画面への回答を補助するためのものです。
> 各推奨回答はコードに基づいた判断です。最終的な申告内容はリリースビルドの実挙動と
> Play Console の設問定義（提出時点の最新版）に照らして開発者が確認してください。

---

## 1. データの収集・共有の有無

### 設問: このアプリはユーザーから必須のデータを収集または共有していますか？

**推奨回答: いいえ（収集・共有なし）**

**根拠:**

| 確認項目 | コード根拠 | 判断 |
|---|---|---|
| 外部サーバーへのデータ送信 | `app_logger.dart:2` — `dart:developer` の `log()` のみ使用。HTTP 送信なし | 送信なし |
| LiveVoice Box 運営バックエンド | コード全体に `http`・`dio`・`http_client` 等の HTTP パッケージの import なし（`pubspec.yaml` にも不在） | バックエンドなし |
| 広告 SDK | `pubspec.yaml` に広告パッケージなし | なし |
| アナリティクス SDK | `pubspec.yaml` に Firebase / Amplitude 等なし | なし |
| コメント通報の自動送信 | `ugc_moderation_service.dart:78-99` — `buildReportText()` は文字列生成のみ。送信処理なし | 自動送信なし |
| ttwid Cookie の送信 | `piratetok_live` パッケージが TikTok から取得・使用する一時 Cookie。LiveVoice Box が保存・転送することはない（`docs/privacy.md:58-62` 参照）| LiveVoice Box は送信しない |

> **重要**: TikTok の公開 LIVE 接続（`piratetok_live` 経由）は、接続ライブラリが TikTok のサーバーへリクエストを送る。この通信は LiveVoice Box が制御するサーバーへの送信ではない。ただし **サードパーティライブラリのデータ扱いを申告要件で問われる可能性がある**（→ 要確認項目 C-1 を参照）。

---

## 2. 端末内ストレージに保存されるデータ（SharedPreferences）

以下はすべて端末内にのみ保存され、外部に送信されない。

| SharedPreferences キー | 保存内容 | コード根拠 |
|---|---|---|
| `tikbox_tts_settings_v1` | 読み上げ設定 JSON（speed/pitch/volume/voice/preset/flags） | `tts_provider.dart:11` |
| `tikbox_gift_sound_enabled_v1` | ギフト効果音 ON/OFF（bool） | `tts_provider.dart:12` |
| `tikbox_blocked_users_v1` | ブロックした公開 LIVE ユーザー ID リスト（uniqueId ベース） | `main_provider.dart:11` |
| `tikbox_custom_ng_words_v1` | ユーザー追加 NGワードリスト | `main_provider.dart:12` |
| `tikbox_last_username_v1` | 最後に入力した配信 ID（最大1件） | `main_screen.dart:20` |
| `tikbox_saved_usernames_v1` | 保存した配信 ID 履歴（最大5件） | `main_screen.dart:21` |

**Play Console の設問に対する判断**:
- これらのデータは端末外に送信されない（コード根拠: HTTP クライアント不使用）
- Play Console が「端末内ストレージへの保存」を「収集」と定義する場合は要確認（→ 要確認項目 C-2）

---

## 3. ttwid Cookie の扱い

| 項目 | 内容 |
|---|---|
| Cookie の出所 | TikTok サーバーから `piratetok_live` が受け取る一時サービス Cookie |
| ユーザー認証情報か | **いいえ**。ユーザーがログインして取得するものではない |
| ブラウザ・TikTok アプリから読み取るか | **いいえ**（`docs/privacy.md:55-62`） |
| LiveVoice Box の SharedPreferences に保存するか | **いいえ**（保存コードなし） |
| LiveVoice Box の外部サーバーに送るか | **いいえ** |
| Play Console での扱い | 第三者ライブラリが取得する一時的な接続用 Cookie として、申告が必要か要確認（→ 要確認項目 C-1） |

---

## 4. 診断ログ

`app_logger.dart` は `dart:developer` の `log()` を使用（行1-2）。
- 出力先: OS ログ（Android Logcat）のみ
- 外部送信: なし
- ログに含まれる情報（`live_provider.dart` の AppLogger.info 呼び出し）: 配信 ID、公開ユーザー表示名の一部（要約）、ギフト情報の要約、接続状態
- ログのライフタイム: OS が制御。LiveVoice Box は保持・転送しない

---

## 5. Data Safety 設問への推奨回答

### Section 1: データの収集と共有

| Play Console 設問 | 推奨回答 | 根拠 |
|---|---|---|
| アプリはユーザーデータを収集しますか？ | **いいえ**（第三者ライブラリ考慮後に要確認 C-1） | HTTP クライアント不使用、外部送信なし |
| アプリはユーザーデータを第三者と共有しますか？ | **いいえ** | LiveVoice Box が制御するデータ共有なし |

### Section 2: データの安全性（収集あり と申告した場合）

収集なしの場合はこのセクションは不要。ただし要確認項目 C-1 の判断次第で変わる。

| 想定設問 | 推奨回答 | 根拠 |
|---|---|---|
| 収集データは暗号化して転送しますか？ | 該当なし（送信なし） | — |
| ユーザーはデータ削除を要求できますか？ | ユーザーがアプリのデータを OS 設定からクリアまたはアンインストールすることで削除可能（`docs/privacy.md:121-135`）。サーバー側データなし | — |

### Section 3: アプリの操作

| Play Console 設問 | 推奨回答 |
|---|---|
| アプリは他のアプリまたはデバイスからデータを転送しますか？ | いいえ |
| アプリは位置情報を使用しますか？ | いいえ（Manifest に位置権限なし） |
| アプリは財務情報を取り扱いますか？ | いいえ |
| アプリはメッセージを取り扱いますか？ | いいえ（公開 LIVE コメントは端末表示のみ） |

---

## 6. 要確認項目（人間が最終判断すべき設問）

| # | 要確認内容 | 理由 |
|---|---|---|
| C-1 | `piratetok_live` ライブラリが TikTok に送信するデータが Play Console の「第三者とのデータ共有」定義に該当するか | ライブラリの内部実装は LiveVoice Box のコードでは完全に追えない。Play Console の「第三者ライブラリ」に関する最新ガイドラインを確認すること |
| C-2 | SharedPreferences への保存データが Play Console の「収集」定義に該当するか | Google の定義では「端末外に転送されるデータ」のみが「収集」に該当する場合があるが、定義は更新されることがある |
| C-3 | Foreground Service 宣言の Data Safety 申告への影響 | Play Console で Foreground Service を申告する際に、追加のデータ情報が求められる場合がある（提出時点の要件で確認） |
| C-4 | OS 診断ログ（Logcat）が Play Console の「診断情報の収集」設問に該当するか | ログは端末内・OS 管理であり LiveVoice Box が転送しないが、設問の解釈次第で申告が必要な場合がある |
