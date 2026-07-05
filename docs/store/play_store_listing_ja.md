# Google Play 掲載文（日本語）

運営者名義: LiveVoice Studio
対象プラットフォーム: Google Play（Android）
言語: 日本語

---

## アプリ名（30文字以内）

```
LiveVoice Box
```

（13文字。英字のため文字数に余裕あり）

---

## 短い説明（80文字以内）

```
ライブ配信のコメント・ギフトをリアルタイムで読み上げる配信者向けサポートアプリ。
```

（40文字）

---

## 詳細説明（4000文字以内）

```
LiveVoice Boxは、ライブ配信中の公開コメントを音声で確認しやすくする、配信者向けの非公式サポートツールです。

■ 主な機能

【コメント読み上げ】
- 公開LIVEコメントを端末の音声合成（TTS）でリアルタイムに読み上げます
- 読み上げ速度・ピッチ・音量を個別に調整できます
- 配信者名読み上げのON/OFFが選べます
- コメント用・ギフト用に別々の読み上げボイスを設定できます
- 同じユーザーの同じコメントを短時間に重複して読まない重複除去機能搭載

【ギフト通知音・バイブレーション】
- ギフト受信時に効果音とバイブレーションでお知らせします
- ギフトの金額に応じてバイブレーションの強さが3段階で変わります
- バイブレーションはON/OFFで切り替えられます
- 効果音プリセット（バランス・ド派手・やさしい）から選べます

【バックグラウンド再生】
- アプリをバックグラウンドにしても、ユーザーが開始した読み上げを継続します
- スクリーンオフ中も読み上げが続きます
- フォアグラウンドサービス通知で動作状態を確認できます

【コメントフィルタリング・ブロック機能（UGCモデレーション）】
- 固定NGワードを自動でフィルタリングします
- ユーザーが追加したNGワードも端末内に保存・適用されます
- 特定のユーザーをブロックすると、そのコメントが読み上げ・表示されなくなります
- 公開LIVEユーザーIDでのブロックはアプリをアンインストールするまで保持されます
- 不適切なコメントをアプリ内から通報文としてまとめてメール送信できます

【セッション統計・ハイライト】
- 読み上げセッション中のコメント数・ギフト数・フォロー数・いいね数を集計します
- ギフト贈与上位3名のランキングを表示します
- コメント急増・いいねラッシュ・大型ギフトなどのハイライトを記録します
- セッション終了後にスコアとまとめを確認できます

【配信ID管理】
- 配信者の@IDまたはTikTok配信URLを入力して接続します
- 直近5件の配信IDを保存・呼び出しできます

■ ご注意

本アプリはTikTokまたはByteDanceの公式アプリではありません。TikTokおよびByteDanceとは提携・承認・スポンサー関係にありません。

本アプリはTikTokのログイン情報、パスワード、既存のブラウザCookieを取得しません。公開LIVE接続時に接続ライブラリがTikTokから未認証接続用の一時的なCookieを取得して使用しますが、これはユーザーのログイン情報ではなく、LiveVoice Boxのデータベースには保存されません。

配信サービス側の仕様変更、配信状態、通信環境、端末のバックグラウンド設定により、接続や読み上げが利用できない場合があります。
```

（約850文字。4000文字以内に余裕あり）

---

## TikTok/ByteDance 非提携の明記

詳細説明末尾の「ご注意」セクションに記載済み。
`docs/privacy.md` および `docs/terms.md` と内容が整合していることを確認。

---

## 掲載情報（その他）

| 項目 | 内容 |
|---|---|
| カテゴリ | ツール（Tools）または ビデオプレーヤー&エディタ |
| コンテンツレーティング | 未入力（Play Console でアンケート回答が必要） |
| プライバシーポリシー URL | https://taichi963.github.io/tikbox/privacy.html |
| 価格 | 有料・買い切り（金額は Play Console で設定） |
| 配信国 | Play Console で設定（要確認） |
| 連絡先メール | zeb0kui3ackwv4pft1us@gmail.com |

---

## 作成根拠（file:line）

| 機能 | コード根拠 |
|---|---|
| コメント読み上げ | lib/services/tts_service.dart, lib/features/live/live_provider.dart:363 |
| ギフト通知 | lib/features/live/live_provider.dart:385 |
| バイブレーション3段階 | lib/features/live/live_provider.dart:803-810 |
| バックグラウンド再生 | lib/services/tts_service.dart:77-86 (audio_service) |
| NGワード固定リスト | lib/services/ugc_moderation_service.dart:26-33 |
| NGワードユーザー追加 | lib/features/main/main_provider.dart:620 |
| ブロック機能 | lib/features/main/main_provider.dart:584 |
| セッション統計 | lib/features/main/main_provider.dart:58-335 |
| ギフトランキング上位3名 | lib/features/main/main_provider.dart:124-137 |
| 配信ID保存（最大5件） | lib/features/main/main_screen.dart:21 (_maxSavedUsernames = 5) |
| 効果音プリセット3種 | lib/models/tts_settings.dart:1-18 (SoundPreset) |
| 重複除去 | lib/services/comment_deduplicator.dart |
