# LiveVoice Box v1.0.0 — リリース完遂ロードマップ

作成日: 2026-06-29  
運営者: LiveVoice Studio

> このドキュメントは「残りすべての人間作業」を迷わず実行するための作業手順書です。
> コードを読む必要がある箇所は参照先ファイルを明示しています。

---

## 現在地（2026-06-29 時点）

| 項目 | 状態 |
|---|---|
| コード品質 | analyze 0件 / test 107件 ✓ |
| Android AAB | 42.4 MB 生成済み ✓ |
| iOS ビルド | 未（Mac 環境で別途）|
| 施行日 | **確定** `July 5, 2026`（docs/privacy.md:5・docs/terms.md:5）|
| GitHub Pages | 未確認（push 後に確認）|
| ストア申請 | 未 |
| v1.0.0 タグ | ローカルのみ存在（push 未）|

---

## フェーズ一覧

| # | フェーズ | 担当環境 | 所要目安 | 不可逆 |
|---|---|---|---|---|
| 0 | 未コミット差分の整理・コミット | PC | 10分 | 低 |
| 1 | 施行日の決定とドキュメント更新 | PC | 20分 | 中 |
| 2 | GitHub Pages 疎通確認 | PC（ブラウザ）| 5分 | — |
| 3 | Android 実機動作検証 | Android 実機 | 30〜60分 | — |
| 4 | スクリーンショット撮影 + Feature Graphic PNG | PC + Android 実機 | 30分 | — |
| 5 | Google Play Console 登録・審査提出 | ストア管理画面 | 60〜120分 | **高** |
| 6 | Mac セットアップ・iOS ビルド | Mac | 30〜60分 | 低 |
| 7 | iPhone 実機動作検証 | iPhone 実機 | 30〜60分 | — |
| 8 | piratetok_live Privacy Manifest 確認 | Mac（Xcode） | 10分 | — |
| 9 | App Store Connect 登録・審査提出 | ストア管理画面 | 60〜120分 | **高** |

---

## フェーズ 0 — 未コミット差分の整理・コミット

**担当**: PC  
**前提**: なし  
**所要目安**: 10分  
**不可逆**: なし（ローカル commit のみ）

### 現在の未コミット差分（`git status --short` より）

```
M  README.md
M  ios/Runner.xcodeproj/project.pbxproj
M  pubspec.yaml
?? android/app/src/main/res/drawable-{hdpi,mdpi,xhdpi,xxhdpi,xxxhdpi}/
?? android/app/src/main/res/mipmap-anydpi-v26/
?? android/app/src/main/res/values/colors.xml
?? docs/store/
```

### 推奨コミット分割

**コミット A: Adaptive Icon（まとめてコミット）**

```bash
git add pubspec.yaml
git add android/app/src/main/res/
git add ios/Runner.xcodeproj/project.pbxproj
git commit -m "chore: generate Android adaptive icon"
```

生成内容:
- `mipmap-anydpi-v26/ic_launcher.xml` — 背景 `#0B0D1E`・前景 `app_icon.png`・16% inset
- `drawable-*/ic_launcher_foreground.png` — 各 dpi 前景画像
- `values/colors.xml` — 背景色 `#0B0D1E`

**コミット B: ストア提出資料＋README（まとめてコミット）**

```bash
git add docs/store/
git add README.md
git commit -m "docs: add store submission materials and update release checklist"
```

追加される docs/store/ ファイル:
- `play_store_listing_ja.md` — Google Play 掲載文
- `app_store_listing_ja.md` — App Store 掲載文
- `data_safety_mapping.md` — Data Safety 申告対応表（コード根拠付き）
- `app_privacy_mapping.md` — App Privacy 申告対応表
- `release_notes_v1.0.0.md` — リリースノート
- `screenshot_guide.md` — スクリーンショット撮影ガイド
- `piratetok_live_privacy_check.md` — iOS Privacy Manifest 調査結果
- `release_roadmap.md` — 本ファイル
- `assets/feature_graphic_v1.svg` — Feature Graphic 案1
- `assets/feature_graphic_v2.svg` — Feature Graphic 案2
- `assets/README.md` — PNG 変換手順

### v1.0.0 タグと HEAD の関係について

- `v1.0.0` タグ → `669535b`（"chore: secure repository release files"）
- 現在の HEAD → `b877086`（"chore: ignore CLAUDE.md"）
- 上記コミット A・B を追加した後は HEAD がさらに進む

**タグの扱い（判断が必要）:**  
GitHub Pages は main ブランチの最新 commit を配信する。タグの位置はページ公開に影響しない。  
選択肢:
- タグはそのまま（コードのリリース点として保存）→ 簡単
- 施行日（`July 5, 2026` 確定済み）に合わせてタグを同コミットに移動する → 整合性が取りやすい

どちらでも Play Store / App Store 提出は可能。施行日確定後に決めてよい。

---

## フェーズ 1 — 施行日の決定とドキュメント更新

**担当**: PC  
**前提**: フェーズ 0 のコミット後  
**所要目安**: 20分  
**不可逆**: 中（public push 後は GitHub Pages に即時反映）

### 1-1. 施行日を決める

施行日 = アプリが App Store / Google Play で実際にダウンロード可能になる日。  
ストア審査（5〜14日）が完了してから公開日が確定するため、以下 2 通りの方針がある:

| 方針 | 内容 | 推奨 |
|---|---|---|
| **先行記入** | 提出前に「目標リリース日」を仮設定して記入 → 審査通過後に日付が概ね合う | 手間が少ない |
| **後から更新** | 審査通過後に公開日が確定してから記入 → より正確 | 厳密だが2回 push が必要 |

どちらを選ぶかは **人間が決める**。このロードマップでは「先行記入」を前提に手順を記載する。

### 1-2. 変更するファイルと箇所（必須）

**`docs/privacy.md`**

| 行番号 | 変更内容 |
|---|---|
| 5行目 | 施行日プレースホルダー → `July 5, 2026` に置換済み |
| 15〜16行目 | 以下の段落を**丸ごと削除**: `"The developer/operator name and effective date must be completed before this policy is submitted to an app store."` |

> 注: 「developer/operator name」は既に `LiveVoice Studio` 確定済み。15〜16行目の注記はリリース前ドラフト用の案内文であり、公開前に削除が必要。

**`docs/terms.md`**

| 行番号 | 変更内容 |
|---|---|
| 5行目 | 施行日プレースホルダー → `July 5, 2026`（privacy.md と同じ日付）に置換済み |
| 17〜18行目 | 以下の段落を**丸ごと削除**: `"The missing operator, effective-date, and governing-law information must be completed before these terms are submitted to an app store."` |

> 注: 「governing-law」は既に日本語で確定済み（terms.md:15）。「operator」も確定済み。削除して問題ない。

**`docs/privacy.md`（任意・精度向上）**

| 行番号 | 現状 | 推奨変更 |
|---|---|---|
| 71行目前後 | `saved stream ID history` | `saved stream ID history (up to 5 entries)` |

根拠: `lib/features/main/main_screen.dart` の `_maxSavedUsernames = 5`。プライバシーポリシーの正確性向上のための任意補足。

### 1-3. 変更後の確認

```bash
grep -n "EFFECTIVE_DATE" docs/privacy.md docs/terms.md
# → 何も出力されなければ OK
grep -n "開発者本名" docs/privacy.md docs/terms.md docs/support.md
# → 何も出力されなければ OK（本名を検索語に置き換えて実行）
```

### 1-4. コミット・push（不可逆：push 後 GitHub Pages に即時反映）

```bash
git add docs/privacy.md docs/terms.md
git commit -m "docs: set v1.0.0 effective date"
git push origin main
git push origin v1.0.0   # タグを push（まだしていない場合）
```

---

## フェーズ 2 — GitHub Pages 疎通確認

**担当**: PC（ブラウザ）  
**前提**: フェーズ 1 の push 完了後（GitHub Actions のデプロイが走る場合は 1〜3分待つ）  
**所要目安**: 5分  
**不可逆**: なし

- [ ] `https://taichi963.github.io/tikbox/privacy.html` がブラウザで開き、施行日が表示される
- [ ] `https://taichi963.github.io/tikbox/terms.html` が開く
- [ ] `https://taichi963.github.io/tikbox/support.html` が開く
- [ ] 各ページに未置換のプレースホルダー文字列が残っていない（施行日は `July 5, 2026` で表示される）
- [ ] 各ページに本名が表示されていない

**つまずきポイント:**  
GitHub Pages がまだ有効になっていない場合は、リポジトリ Settings → Pages → Source を `main` ブランチに設定する必要がある。  
デプロイ直後は CDN キャッシュで古い内容が表示される場合がある（5分待ってから確認）。

---

## フェーズ 3 — Android 実機動作検証

**担当**: Android 実機  
**前提**: リリース AAB（`build/app/outputs/bundle/release/app-release.aab`）または APK から実機インストール  
**所要目安**: 30〜60分  
**不可逆**: なし

> APK の方が実機インストールが簡単: `flutter build apk --release --no-tree-shake-icons` を実行してから `adb install build/app/outputs/apk/release/app-release.apk`

### 動作確認チェックリスト

**アイコン表示**
- [ ] ホーム画面でアイコンが表示される
- [ ] Adaptive Icon が不自然に切れていない（ランチャーのマスク形状に注意）

**基本動作**
- [ ] アプリ起動後、配信 ID 入力欄が表示される
- [ ] 配信 ID（@username）を入力して接続できる（実際の配信が必要、または失敗時エラーメッセージが表示される）
- [ ] コメントが届くと読み上げが開始される
- [ ] 読み上げ速度・ピッチ・音量スライダーが反映される
- [ ] 停止ボタンで読み上げが即座に止まる

**バックグラウンド・スクリーンオフ**
- [ ] アプリをバックグラウンドにしても読み上げが継続する
- [ ] 画面オフでも読み上げが継続する
- [ ] フォアグラウンドサービス通知が表示される（Android 13+: 通知権限を許可した場合）

**ギフト**
- [ ] ギフト受信時に効果音が鳴る
- [ ] ギフト受信時にバイブレーションが発生する（設定 ON の場合）

**Bluetooth オーディオ**
- [ ] Bluetooth イヤホン/スピーカー接続時に読み上げ音声がそちらに出る
- [ ] 接続・切断しても読み上げが止まらない（または適切に停止する）

**音声割り込み回復**
- [ ] 電話着信後に読み上げが再開する（またはユーザーが再度開始できる）

**再接続**
- [ ] 接続が切れた後に自動再接続が試みられる（最大 6回・指数バックオフ）

**モデレーション**
- [ ] ブロックユーザー設定が保持される（アプリ再起動後も）
- [ ] NGワードが適用される

**セッション統計**
- [ ] セッション終了後に統計画面が表示される

---

## フェーズ 4 — スクリーンショット撮影 + Feature Graphic PNG

**担当**: PC + Android 実機  
**前提**: フェーズ 3 の動作確認後  
**所要目安**: 30分  
**不可逆**: なし

詳細は [screenshot_guide.md](screenshot_guide.md) を参照。

### 必須スクリーンショット（Android・最低 2枚）

- [ ] S1: メイン画面（接続前）— 配信 ID 入力欄・接続ボタンが見える状態
- [ ] S2: 接続中・コメント受信中 — コメントが流れている状態

### 推奨スクリーンショット（Android・追加）

- [ ] S4: 設定パネル — 速度・ピッチ・音量スライダー、ボイス選択
- [ ] S5: セッション統計 — コメント数・ギフトランキング

### スクリーンショットサイズ確認

Play Store 電話: 最短辺 320px〜最長辺 3840px（縦向き推奨、長辺が短辺の 2倍以内）

### Feature Graphic PNG 書き出し（1024×500 必須）

1. `docs/store/assets/feature_graphic_v1.svg` をブラウザで開く
2. F12 → Console に以下を貼り付けて実行:

```javascript
const svg = document.querySelector('svg');
const canvas = document.createElement('canvas');
canvas.width = 1024; canvas.height = 500;
const ctx = canvas.getContext('2d');
const img = new Image();
img.onload = () => {
  ctx.drawImage(img, 0, 0);
  const a = document.createElement('a');
  a.download = 'feature_graphic.png';
  a.href = canvas.toDataURL('image/png');
  a.click();
};
img.src = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(svg.outerHTML)));
```

3. ダウンロードされた `feature_graphic.png` が 1024×500 かを確認
4. 日本語フォントが正しく表示されているか目視確認（文字化けがある場合は `feature_graphic_v2.svg` も試す）

**代替手段**: Inkscape → ファイル > PNG にエクスポート → 幅 1024・高さ 500 を指定

---

## フェーズ 5 — Google Play Console 登録・審査提出

**担当**: ストア管理画面（ブラウザ）  
**前提**: フェーズ 2 の GitHub Pages 確認 + フェーズ 4 のスクリーンショット準備完了  
**所要目安**: 60〜120分  
**不可逆**: **高**（申請後・審査中はアプリ情報の主要変更が制限される）

### 5-1. Play Console でアプリを作成

- [ ] [play.google.com/console](https://play.google.com/console) にログイン
- [ ] 「アプリを作成」→ 言語: 日本語 / アプリ名: `LiveVoice Box` / アプリ or ゲーム: アプリ / 無料 or 有料: 有料
- [ ] ストア掲載情報を入力（[play_store_listing_ja.md](play_store_listing_ja.md) からコピー）:
  - [ ] 短い説明（80文字以内）
  - [ ] 詳細説明（4000文字以内）

### 5-2. グラフィック資産

- [ ] Feature Graphic: `feature_graphic.png`（1024×500）をアップロード
- [ ] スクリーンショット: 電話用に S1・S2 を最低 2枚アップロード

### 5-3. コンテンツレーティング

- [ ] コンテンツレーティングのアンケートに回答（「ユーティリティ」カテゴリ程度の内容）
- [ ] 未成年への性的コンテンツ等は「なし」で回答

### 5-4. 対象ユーザー・コンテンツ

- [ ] 対象年齢: 成人（17歳以上）または適切な年齢を選択
- [ ] コンテンツの対象: 全般

### 5-5. データの安全性（Data Safety）★重要・判断が必要

**[data_safety_mapping.md](data_safety_mapping.md) を開きながら入力**

設問 1「このアプリはデータを収集・共有しますか？」

→ **「いいえ（データを収集・共有しない）」を推奨**

根拠: LiveVoice Box は外部 HTTP クライアントを持たず、ユーザーデータをいかなる LiveVoice Studio のサーバーにも送信しない（コード確認済み）。SharedPreferences は端末内のみ。

> **判断が必要な点（C-1）**: Play Console が「第三者とのデータ共有」として `piratetok_live` ライブラリ経由の TikTok への接続を含めるよう求めてくる可能性がある。設問を読んで「**ユーザーの個人情報を**第三者と共有するか」という文脈であれば「いいえ」。「アプリがサードパーティサーバーと通信するか」という文脈なら「はい（TikTok公開 LIVE 接続）」と解釈しうる。**設問の文言を読んで最終判断すること。**

**フォアグラウンドサービス（FGS）の申告**:

- [ ] 「フォアグラウンドサービスを使用する」→「はい」
- [ ] タイプ: **「メディアの再生」（Media playback）**
- [ ] 説明欄（英語）に以下を記入:

```
The app uses a media playback foreground service to continue user-initiated
text-to-speech reading of public LIVE comments while the app is backgrounded.
The service is started only when the user explicitly begins a reading session,
and it stops when the user stops the session or closes the app.
```

- [ ] 機能を示す動画 / スクリーンショット: バックグラウンド読み上げの様子を録画（FGS のユースケースを示すものが必要な場合がある）

### 5-6. アプリのカテゴリ・価格

- [ ] カテゴリ: **ツール**（または「ビデオプレーヤー&エディタ」）
- [ ] 価格: 有料→金額を設定（配信国ごとに調整可能）
- [ ] 国・地域: 配信国を選択

### 5-7. プライバシーポリシー

- [ ] プライバシーポリシー URL: `https://taichi963.github.io/tikbox/privacy.html`
- [ ] フェーズ 2 で疎通確認済みであること

### 5-8. AAB のアップロード

- [ ] 「本番」リリーストラック → 「新しいリリースを作成」
- [ ] AAB ファイル: `build/app/outputs/bundle/release/app-release.aab`（42.4 MB）をアップロード
- [ ] バージョン名: `1.0.0`・バージョンコード: `3` であることを確認
- [ ] リリースノート（[release_notes_v1.0.0.md](release_notes_v1.0.0.md) からコピー）

### 5-9. 審査提出

- [ ] すべての必須セクションが緑（✓）になったことを確認
- [ ] 「審査に送信」

**つまずきポイント:**
- FGS の動画提出を求められる場合がある（バックグラウンド再生の様子を録画）
- 「このアプリは未成年者向けですか？」→ No
- AAB 署名が正しくない場合はビルドエラー。`android/key.properties` が正しく配置されているか確認

---

## フェーズ 6 — Mac セットアップ・iOS ビルド

**担当**: Mac  
**前提**: フェーズ 0〜1 のコミット・push 完了後、Mac に pull  
**所要目安**: 30〜60分（初回の場合 + pod install 次第で長くなる）  
**不可逆**: なし

### 6-1. 最新コードを取得

```bash
git pull origin main
flutter pub get
cd ios && pod install && cd ..
```

### 6-2. iOS 最小バージョン確認 ★ 要確認

現状: `IPHONEOS_DEPLOYMENT_TARGET = 13.0`（`ios/Runner.xcodeproj/project.pbxproj` より）

**問題**: Apple は新規提出アプリに対して最小 iOS バージョンの要件を更新している。  
2025年5月時点では「iOS 17以降」が必要とされていたが、2026年6月現在の正確な要件は **App Store Review Guidelines（提出時点のもの）で必ず確認すること**（推測で答えない）。

**確認先**: https://developer.apple.com/ios/submit/

**対処手順（13.0 が要件を下回る場合）:**

1. Xcode で `ios/Runner.xcodeproj` を開く
2. プロジェクトナビゲータ → Runner プロジェクト → Build Settings → iOS Deployment Target
3. 必要な最小バージョンに変更（例: `17.0`）
4. `pod install`（最小バージョン変更で Podfile が更新される可能性）
5. ビルド確認: `flutter build ipa --release --no-tree-shake-icons` もしくは Xcode Archive

**バージョン変更後の追加確認:**
```bash
flutter pub deps 2>&1 | grep "ios"
# 各パッケージの iOS 最小バージョンが新しい minimum を超えていないか確認
```
主要パッケージ（flutter_tts, audio_service, audioplayers, wakelock_plus）が新しい minimum をサポートしているか確認。  
→ **もし対応していないパッケージがあれば、pubspec.yaml のバージョンアップが必要（このロードマップの範囲外・別途判断）**

### 6-3. Archive と TestFlight アップロード

- [ ] Xcode → Product → Archive（Release スキーム）
- [ ] Archive 成功後、Organizer → 「Distribute App」→ 「App Store Connect」→ TestFlight
- [ ] アップロード完了後、App Store Connect → TestFlight でビルドが処理されるのを待つ（通常 15〜60分）

**または CLI:**
```bash
flutter build ipa --release --no-tree-shake-icons
# ipa を Transporter.app または xcrun altool でアップロード
```

---

## フェーズ 7 — iPhone 実機動作検証

**担当**: iPhone 実機（TestFlight ビルドで検証）  
**前提**: フェーズ 6 の TestFlight アップロード完了  
**所要目安**: 30〜60分  
**不可逆**: なし

- [ ] TestFlight からインストールして起動
- [ ] 配信 ID 入力・接続動作
- [ ] コメント読み上げ
- [ ] バックグラウンドでの読み上げ継続（iOS Background Audio）
- [ ] 停止操作で読み上げが即座に止まる
- [ ] AirPods / Bluetooth ルーティング
- [ ] 音声割り込み（着信等）後の回復
- [ ] ギフト効果音・バイブレーション
- [ ] 再接続動作
- [ ] アプリをフォアグラウンドに戻したとき正常に動作する

**iOS 固有のつまずきポイント:**
- Background Audio が Silent スイッチでミュートになる: 予想される仕様（ユーザーが明示的に音を消している場合は止まる）
- AVAudioSession が他のアプリ（音楽など）と競合する場合の動作を確認する

---

## フェーズ 8 — piratetok_live Privacy Manifest 確認（任意・推奨）

**担当**: Mac（Xcode）  
**前提**: フェーズ 6 の Archive 完了後  
**所要目安**: 10分  
**不可逆**: なし

**背景**: Windows 上での調査で「`piratetok_live` は純 Dart パッケージで PrivacyInfo.xcprivacy を持たず、iOS Required Reason API を使用していない」と確認済み（[piratetok_live_privacy_check.md](piratetok_live_privacy_check.md)）。  
Xcode の Privacy Manifest Aggregation で最終確認することを推奨する。

### 確認手順

1. Xcode Organizer → Archive を選択 → 「Generate Privacy Report」ボタンをクリック（Xcode 15以降）
2. 出力された Privacy Report に `piratetok_live` が **NSUserDefaults / File timestamps / System boot time / Disk space / Active keyboard** 等の Required Reason API を使用していないことを確認
3. レポートに予期しない API 使用がある場合は、`PrivacyInfo.xcprivacy` への追記または申告が必要

**予想結果**: 追加対応不要（ソースコード確認済み）。念のための確認。

---

## フェーズ 9 — App Store Connect 登録・審査提出

**担当**: ストア管理画面（ブラウザ）  
**前提**: フェーズ 7 の iPhone 実機検証 + フェーズ 8（任意）完了  
**所要目安**: 60〜120分  
**不可逆**: **高**

### 9-1. App Store Connect でアプリを作成

- [ ] [appstoreconnect.apple.com](https://appstoreconnect.apple.com) にログイン
- [ ] 「マイ App」→「+」→「新規 App」
  - プラットフォーム: iOS
  - 名前: `LiveVoice Box`
  - プライマリ言語: 日本語
  - バンドル ID: `com.taichi963.tikbox`（Developer Portal で作成済みの場合は選択）
  - SKU: 任意（例: `livevoicebox`）

### 9-2. App 情報・掲載文の入力

**[app_store_listing_ja.md](app_store_listing_ja.md) を開きながら入力**

- [ ] 名前: `LiveVoice Box`
- [ ] サブタイトル: `LIVE配信 コメント読み上げサポート`
- [ ] プロモーションテキスト: 79文字のテキスト
- [ ] 説明: 説明文をコピー
- [ ] キーワード（100文字以内）: `ライブ配信,読み上げ,TTS,コメント,ギフト,配信者,LIVE,音声,バックグラウンド,TikTok`
- [ ] サポート URL: `https://taichi963.github.io/tikbox/support.html`
- [ ] マーケティング URL（任意）
- [ ] プライバシーポリシー URL: `https://taichi963.github.io/tikbox/privacy.html`
- [ ] カテゴリ: ユーティリティ
- [ ] 価格: 有料（金額を設定）

### 9-3. スクリーンショット（iPhone 必須）

- [ ] iPhone 6.7インチ（1290×2796 px）を最低 1枚アップロード（他サイズの代表として使用可）
- [ ] スクリーンショット内に本名・TikTok ロゴが含まれていないことを確認

### 9-4. App のプライバシー ★重要・判断が必要

**[app_privacy_mapping.md](app_privacy_mapping.md) を開きながら入力**

「このアプリはデータを収集しますか？」→ **「データを収集しない」を推奨**

根拠: 外部送信コードなし・HTTP クライアント不使用・SharedPreferences は端末内のみ（コード確認済み）。

> **判断が必要な点（C-1〜C-4）**: [app_privacy_mapping.md](app_privacy_mapping.md) の「要確認項目」セクションを確認した上で最終決定すること。「公開 LIVE コメントをアプリ内で処理・表示すること」や「TikTok 公開 uniqueId をブロックリストとして保存すること」が Apple の定義する「収集」に該当するかを、設問の文言で最終判断すること。

### 9-5. ビルドを追加

- [ ] TestFlight でアップロード済みのビルド（バージョン 1.0.0、ビルド番号 3）を選択
- [ ] 輸出コンプライアンス: 暗号化アルゴリズムを使用するか → **「はい（標準暗号化のみ）」または「いいえ」**（HTTPS を使用するアプリは「はい・標準暗号化のみ」を選ぶのが一般的）

### 9-6. 審査へ提出

- [ ] 年齢制限: アンケートに回答
- [ ] 「審査に提出」

---

## 判断まとめ（C-1〜C-5）

| # | 設問 | コード事実 | 推奨スタンス | 変わりうる条件 |
|---|---|---|---|---|
| C-1 | `piratetok_live` の TikTok 通信が「第三者とのデータ共有」に該当するか | ユーザーの個人情報を含む送信なし。公開 LIVE 接続のみ | 「共有なし」「収集なし」 | 設問が「第三者のサーバーと通信するか」という文脈なら要検討 |
| C-2 | SharedPreferences への保存が「収集」に該当するか | 端末外送信なし。端末内のみ | 「収集なし」（Google・Apple ともに端末内保存は収集外） | ほぼ確実に問題なし |
| C-3 | Foreground Service / OS ログの申告 | FGS: MediaPlayback タイプ。OS ログは外部未送信 | Play Store: FGS を申告（必須）。OS ログは申告不要 | Play Console の設問次第 |
| C-4 | ttwid が Apple の「追跡」定義に該当しないか | `NSPrivacyTracking = false`、UserDefaults 保存なし | 「追跡なし」で申告。審査でメッセージが来た場合は説明文を送る | — |
| C-5 | `piratetok_live` に PrivacyInfo.xcprivacy が必要か | 純 Dart パッケージ、iOS Required Reason API 未使用 | 不要（コード調査済み）。Xcode Aggregation で最終確認推奨 | フレーズ8で確認 |

**C-4 審査問い合わせへの回答例（英語）:**
```
The library (piratetok_live) requests a temporary, service-issued cookie (ttwid)
from TikTok to establish a public WebSocket connection.
This cookie is not stored in UserDefaults or any persistent storage.
It is not used to track users across apps or websites.
LiveVoice Box does not use it for advertising, fingerprinting, or profiling.
NSPrivacyTracking is declared as false in PrivacyInfo.xcprivacy.
```

---

## iOS 最小バージョン（13.0）が要件を下回る場合の対処

**判断が必要**: 提出時点の App Store Review Guidelines で現在要件を確認してから作業すること。

```
対処手順:
1. Xcode → Runner プロジェクト → Build Settings → iOS Deployment Target を変更
2. cd ios && pod install && cd ..
3. flutter build ipa --release --no-tree-shake-icons
4. Archive を再作成
5. TestFlight に再アップロード
6. フェーズ 7 の実機検証を再実施
```

**pubspec.yaml の変更は不要**（iOS Deployment Target は pbxproj で管理）。  
ただし、変更後に `flutter analyze --no-pub` で 0件・`flutter test --no-pub` で 107件を再確認すること。

---

## 審査期間と現実的な公開見込み

| ストア | 初回審査期間（目安）| 推奨提出順 |
|---|---|---|
| Google Play | 7〜14日（初回は長め、2〜3日の場合も）| **先に提出** |
| App Store | 24〜72時間（初回は 1〜2週間になる場合も）| Google Play 後に提出 |

> 上記はあくまで目安。実際の審査期間はストアのレビュー混雑状況・アプリ内容・審査員の判断により変動する。断定しない。

**Android 先行を推奨する理由:**
- Google Play の審査は App Store より予測しにくく、拒否理由が具体的でない場合がある
- Android で問題なく通過 → iOS 提出という順序にすると、共通のリスク（TikTok 非公式接続・FGS 申告等）を Android で先に確認できる
- App Store 審査で「Android と同等の機能が確認できる」という実績があると、審査官の質問に答えやすい

**審査拒否時の対応：**
- FGS 関連: FGS の用途説明を詳細化・動画を用意
- TikTok 非公式接続: 「非公式・非提携」の説明を強化、実際の動作動画を提出
- プライバシー申告: 拒否理由に応じて C-1〜C-5 の申告を見直す

---

## このロードマップを全部終えたらリリース完了

以下を全て完了したとき、LiveVoice Box v1.0.0 のリリース作業は完了です。

- [x] コード完成（analyze 0件・test 107件）
- [x] AAB 生成（42.4 MB）
- [x] ストア提出資料作成（docs/store/ 全ファイル）
- [x] Adaptive Icon 生成
- [x] Feature Graphic SVG 作成
- [x] piratetok_live Privacy Manifest 調査完了
- [ ] 未コミット差分のコミット（フェーズ 0）
- [ ] 施行日確定・ドキュメント更新・push（フェーズ 1）
- [ ] GitHub Pages 疎通確認（フェーズ 2）
- [ ] Android 実機動作検証（フェーズ 3）
- [ ] スクリーンショット・Feature Graphic PNG 準備（フェーズ 4）
- [ ] Google Play Console 登録・審査提出（フェーズ 5）
- [ ] Mac iOS ビルド・TestFlight（フェーズ 6）
- [ ] iPhone 実機動作検証（フェーズ 7）
- [ ] App Store Connect 登録・審査提出（フェーズ 9）

**残るのは審査結果待ちのみです。**

---

*運営者: LiveVoice Studio*  
*このロードマップに記載の判断事項（施行日・iOS最小バージョン・Data Safety/App Privacy 申告内容）はすべて開発者本人が決定するものです。*
