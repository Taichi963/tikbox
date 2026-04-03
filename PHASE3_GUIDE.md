# TikBox フェーズ3 — TTS実装ガイド

## 追加・変更ファイル一覧

```
lib/
├── services/
│   └── tts_service.dart          ★新規 — TTSエンジン本体
├── models/
│   ├── settings_model.dart       ★更新 — TTS設定フィールド追加
│   └── comment_model.dart        ★更新 — CommentType / ttsText 追加
├── features/
│   ├── main/
│   │   ├── main_provider.dart    ★更新 — TTS連携・wakelock統合
│   │   ├── tts_provider.dart     ★新規 — TTS Riverpod Notifier
│   │   └── tts_control_bar.dart  ★新規 — 再生コントロールUI
│   └── settings/
│       ├── settings_provider.dart ★更新 — TTS設定の保存/読込
│       └── tts_settings_section.dart ★新規 — 設定画面TTSセクション
pubspec.yaml                      ★更新 — 依存パッケージ追加
```

---

## 既存ファイルへの統合手順

### 1. `main_screen.dart` — コントロールバーを追加

```dart
import '../main/tts_control_bar.dart';

// Scaffold の bottomNavigationBar or body の末尾に追加:
bottomNavigationBar: const TtsControlBar(),
```

### 2. `settings_screen.dart` — TTS設定セクションを追加

```dart
import '../settings/tts_settings_section.dart';

// ListView の中に追加:
const TtsSettingsSection(),
```

### 3. コメント受信時に `addComment()` を呼ぶ

```dart
// WebSocket やポーリング等でコメントが来たら:
ref.read(mainProvider.notifier).addComment(comment);
// → 内部で自動的に TTS キューへ転送される
```

---

## アーキテクチャ図

```
CommentSource (WebSocket / API)
        │
        ▼
  MainNotifier.addComment()
        │
        ├─► comments リスト更新 → UI
        │
        └─► TtsNotifier.enqueueComment()
                  │
                  ▼
            TtsService (flutter_tts)
                  │ キュー管理
                  ▼
            FlutterTts.speak()
                  │
                  ▼ コールバック
            TtsNotifier state 更新 → TtsControlBar UI
```

---

## TtsService キュー動作

| 状態 | 動作 |
|------|------|
| 再生中でない | `enqueue()` → 即座に `speak()` 開始 |
| 再生中 | キューに追加、完了後に自動で次を再生 |
| `skip()` | 現在の読み上げ中止 → 次のキューへ |
| `stopAll()` | キュー全クリア + 読み上げ停止 |
| `clearQueue()` | 現在読み上げ中は続行、次以降をクリア |

---

## 設定値の範囲

| 設定項目 | 型 | 範囲 | デフォルト |
|--------|-----|------|---------|
| `ttsRate` | double | 0.1〜2.0 | 1.0 |
| `ttsPitch` | double | 0.5〜2.0 | 1.0 |
| `ttsVolume` | double | 0.0〜1.0 | 1.0 |
| `ttsMinLength` | int | 0〜20 | 1 |
| `ttsMaxLength` | int | 10〜200 | 50 |
| `ttsMaxQueueSize` | int | 5〜100 | 30 |

---

## Android 設定（android/app/src/main/AndroidManifest.xml）

```xml
<!-- 画面スリープ防止（wakelock_plus 用） -->
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

## iOS 設定（ios/Runner/Info.plist）

```xml
<!-- バックグラウンド音声（TTS） -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```
