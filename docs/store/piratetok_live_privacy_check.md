# piratetok_live — iOS Privacy Manifest 調査結果

対象: `piratetok_live` 0.1.5  
調査日: 2026-06-29  
調査方法: pub キャッシュのソースコードを直接読んで判断（Mac 不要・コード読解のみ）

> **結論（C-5 への回答）**: `piratetok_live` は **PrivacyInfo.xcprivacy を持たない純 Dart パッケージ**。
> iOS の Required Reason API を使用していないため、Apple が求める Privacy Manifest を個別に用意する必要は**ない**と判断する。
> ただし、Apple の審査ポリシーは変更されることがある。提出時点の App Store Review Guidelines で最終確認を行うこと。

---

## 1. パッケージ構成

キャッシュパス: `C:\Users\...\AppData\Local\Pub\Cache\hosted\pub.dev\piratetok_live-0.1.5`

| ディレクトリ / ファイル | 有無 |
|---|---|
| `lib/` | ✓ あり（Dart ソースのみ） |
| `ios/` | **なし** |
| `android/` | **なし** |
| `PrivacyInfo.xcprivacy` | **なし** |
| native `.h`/`.m`/`.swift`/`.kt`/`.java` | **なし** |
| `pubspec.yaml` の外部依存 | **なし**（dev dep のみ: `lints`, `test`） |

`piratetok_live` は **Dart のみで実装された純粋なクロスプラットフォームパッケージ**。
iOS 固有のネイティブコードは存在しない。

---

## 2. 使用する OS API・ネットワーク

### 2a. `dart:io` によるネットワーク通信

| ファイル | 通信先 | 目的 | コード根拠 |
|---|---|---|---|
| `lib/src/auth/ttwid.dart:22` | `GET https://www.tiktok.com/` | 公開 LIVE 接続用の ttwid Cookie 取得 | `client.getUrl(Uri.parse('https://www.tiktok.com/'))` |
| `lib/src/http/api.dart:69` | `GET https://www.tiktok.com/api-live/user/room` | ユーザーが LIVE 配信中かを確認 | `Uri.https('www.tiktok.com', '/api-live/user/room', params)` |
| `lib/src/http/api.dart:149` | `GET https://webcast.tiktok.com/webcast/room/info/` | ルーム情報取得 | `Uri.https('webcast.tiktok.com', '/webcast/room/info/', params)` |
| `lib/src/connection/wss.dart:50` | TikTok WebSocket サーバー（wssUrl） | LIVE イベントストリーム受信 | `RawWebSocket.connect(wssUrl, headers: headers, ...)` |

- 使用クライアント: `dart:io` の `HttpClient`（外部パッケージなし）
- iOS では Flutter の標準 HTTP スタックを通じて実行される（iOS の `URLSession` が内部で使用されるが、これはアプリの通信として扱われる）

### 2b. `Platform.localeName`（`lib/src/http/ua.dart:48`）

デバイスのシステムロケール（言語・地域）を取得し、TikTok API へのリクエストパラメータ（`app_language`, `browser_language`）に使用。  
iOS では `[NSLocale currentLocale]` に相当するが、**Apple の Required Reason API リストに「ロケール取得」は含まれていない**。

### 2c. タイムゾーン取得（`lib/src/http/ua.dart:17-42`）

`Platform.environment['TZ']` → `/etc/timezone` → `/etc/localtime` を順に試みる。  
iOS では `/etc/timezone` は存在せず、シンボリックリンクも通常アクセス不可。実際には `Platform.environment['TZ']` が空の場合は `'UTC'` にフォールバックする（iOS での実挙動）。  
これも Apple の Required Reason API には該当しない。

### 2d. ランダム User-Agent（`lib/src/http/ua.dart:4-11`）

TikTok API へのリクエストに Firefox / Chrome 系のデスクトップ UA 文字列をランダムで使用（配列から選択）。  
**注意**: この UA 偽装は TikTok の非公式 API に対するアクセス手段。審査時に Apple が動作を確認した場合、TikTok の公式アプリをシミュレートするように見える可能性がある。アプリの説明文に「非公式ツール・TikTok との提携なし」を明記している（`README.md:12-18`）ため、このリスクは説明文で対処済み。

---

## 3. Apple が要求する Privacy Manifest（Required Reason API）との照合

Apple が PrivacyInfo.xcprivacy に記載を求める「Required Reason API」カテゴリ:

| API カテゴリ | piratetok_live の使用 | 判断 |
|---|---|---|
| `NSUserDefaults` (UserDefaults) | **使用なし** | 申告不要 |
| ファイルタイムスタンプ API (`stat`, `getattrlist` 等) | **使用なし** | 申告不要 |
| システム起動時刻 (`sysctl` 等) | **使用なし** | 申告不要 |
| ディスク空き容量 (`statfs` 等) | **使用なし** | 申告不要 |
| アクティブキーボードリスト | **使用なし** | 申告不要 |

→ **piratetok_live は iOS の Required Reason API を一切使用していない。**

---

## 4. Apple の「サードパーティ SDK の Privacy Manifest 要件」との関係

Apple の要件は主に以下を対象とする:
- 静的ライブラリ（`.a`）・XCFramework
- Swift Package Manager のバイナリターゲット
- **iOS ネイティブコードを含む** Cocoapods / SPM パッケージ

`piratetok_live` はネイティブコードを持たない Dart パッケージ。Flutter の `dart:io` レイヤーを通じてのみ動作するため、Apple が想定する「サードパーティ SDK」の定義に該当しない。

---

## 5. 実際に申告が必要なのは「アプリ自身の PrivacyInfo.xcprivacy」のみ

`ios/Runner/PrivacyInfo.xcprivacy` は LiveVoice Box 自体の宣言として:
- `NSPrivacyAccessedAPICategoryUserDefaults: CA92.1` ← **アプリ（Flutter shared_preferences）が UserDefaults を使用**
- `NSPrivacyCollectedDataTypes: []` ← データ収集なし
- `NSPrivacyTracking: false`

これは `piratetok_live` の通信を含むアプリ全体の通信についても包含している（アプリのネットワークアクセスはアプリとして申告）。

---

## 6. 結論と人間が確認すべき事項

| 結論 | 状態 |
|---|---|
| `piratetok_live` は PrivacyInfo.xcprivacy を持つか | **なし（確認済み）** |
| iOS Required Reason API を使用するか | **しない（コード確認済み）** |
| 独自の Privacy Manifest を用意する必要があるか | **不要**（コード読解による判断）|
| App Store Connect で「第三者 SDK の Privacy Manifest」として申告が必要か | **不要**と判断（最終確認は提出時点の Guidelines で） |

**人間が Mac で行うべき確認（任意）:**

Xcode の Privacy Manifest Aggregation を実行すると、アプリおよびすべての依存パッケージが使用している Required Reason API の一覧が自動生成される。  
コマンド: Xcode → Product → Archive → 生成した IPA を Instruments または `privacyinfo` ツールで検査。

この操作で `piratetok_live` が UserDefaults 等を想定外に呼び出していないことを確認できるが、ソースコード調査の結果上は問題なし。
