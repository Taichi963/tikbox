# TikBox Phase 5 — リアルタイム接続実装

## Current Release Notes

- TikBox is an unofficial TikTok LIVE support tool and is not affiliated with, endorsed by, or sponsored by TikTok or ByteDance.
- Current release builds connect by TikTok ID only. Cookie input and browser-cookie extraction are not used.
- Background audio is used to keep comment text-to-speech and gift sound feedback available while streaming.
- TikBox uses the entered TikTok ID, LIVE comments, and gift events for reading, sound, vibration, local settings, and username history.

## ファイル構成

```
phase5/
├── node_server/
│   ├── server.js          # WebSocketサーバー本体
│   └── package.json
└── flutter/lib/
    ├── services/
    │   └── websocket_service.dart   # WS接続管理（低レベル）
    └── features/
        ├── live/
        │   └── live_provider.dart   # Riverpod Notifier（接続・再接続）
        └── main/
            └── main_screen.dart     # 接続UI統合版
```

---

## Nodeサーバーのセットアップ

```bash
cd node_server
npm install
node server.js
# → WebSocket server running on ws://localhost:3000
```

---

## Flutter側のセットアップ

### pubspec.yaml に追加
```yaml
dependencies:
  web_socket_channel: ^3.0.1
```

### IPアドレスの設定
`live_provider.dart` の以下の定数を変更してください。

```dart
const String _kWsUrl = 'ws://192.168.1.10:3000';
// ↑ PCのローカルIPアドレスに変更
```

**IPアドレスの確認方法:**
- Windows: `ipconfig` → IPv4アドレス
- Mac/Linux: `ifconfig` → en0のinet
- Android エミュレーター: `ws://10.0.2.2:3000`

### ファイルの配置
```
lib/
├── services/
│   └── websocket_service.dart   ← 新規追加
└── features/
    ├── live/                    ← フォルダ新規作成
    │   └── live_provider.dart   ← 新規追加
    └── main/
        └── main_screen.dart     ← 既存ファイルを置き換え
```

---

## 接続フロー

```
[メインボタンタップ]
       ↓
[ユーザー名入力ダイアログ]
       ↓
liveProvider.startLive(username)
       ↓
WebSocketService.connect('ws://...')
       ↓ (接続確立)
WS送信: { type: 'connect', username: '...' }
       ↓
[Nodeサーバー] tiktok-live-connector で接続
       ↓
WS受信: { type: 'status', status: 'connected' }
       ↓
mainProvider.startLive()  // ライブON・wakelock有効
       ↓
[コメント到着]
WS受信: { type: 'comment', user: '...', text: '...' }
       ↓
mainProvider.addComment()
       ↓
ttsProvider.enqueueComment()  // TTS読み上げ
```

---

## 再接続ロジック

切断を検知すると自動で再接続を試みます。

| 試行回数 | 待機時間 |
|---|---|
| 1回目 | 1秒 |
| 2回目 | 2秒 |
| 3回目 | 4秒 |
| 4回目 | 8秒 |
| 5回目 | 16秒 |
| 上限超過 | エラー表示・手動再接続 |

---

## バグりやすいポイント

| ポイント | 問題 | 対策 |
|---|---|---|
| `_channel!.ready` の待機忘れ | 未確立のまま送信してクラッシュ | `await _channel!.ready` を必ず入れる |
| `cancelOnError: false` | エラーで購読が切れてメッセージを取りこぼす | `listen()` に明示的に指定 |
| ギフトのストリーク | 1件ずつ読み上げて連発される | Node側で `repeatEnd` チェック |
| `_disposed` チェック漏れ | dispose後にstateを書いてStateError | 全コールバックの先頭で確認 |
| 再接続の無限ループ | エラー→再接続→エラーが永続 | `_kMaxReconnectAttempts` で上限管理 |
| ping/pong忘れ | Wi-Fi切断を数分間検知できない | 20秒ごとにping、5秒でpongタイムアウト |

---

## 実機テスト時の注意

- **Android実機**: PCと同じWi-Fiに接続し、PCのIPを指定
- **iOS実機**: 現行アプリはTikTokへのHTTPS/WSS接続を使います。ATS例外が必要になった場合のみ、理由を整理して追加してください。
- **ファイアウォール**: PCのポート3000を開放してください
