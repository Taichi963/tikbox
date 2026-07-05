# LiveVoice Box — VOICEVOX 統合設計メモ

Status: 調査・計画のみ（未実装）  
対象リリース: v1.0.0 以降の将来アップデート  
公開名義: LiveVoice Studio

このメモは将来の設計判断を整理するものであり、VOICEVOX の採用、統合方式、利用可能な音声、商用利用、再配布可否を確定するものではない。v1.0.0 は現在の端末標準 TTS（`flutter_tts`）のまま提出し、本メモに基づく変更を含めない。

## 先に決めるべき重大な判断

1. **クラウド方式かオンデバイス方式か**
   - コメント本文を端末外へ送信するか、エンジンと音声モデルをアプリ側へ同梱するかを決める。
   - この判断は、プライバシー文書、Data Safety / App Privacy、運用費、アプリサイズ、バックグラウンド再生方式に直結する。
2. **どの音声を、どのイベントへ適用するか**
   - 全コメント、ギフトのみ、プレミアムギフトのみ、試聴のみ、など適用範囲を決める。
   - 採用する話者・スタイルごとに利用条件を確認する。
3. **ライセンス確認の結果**
   - VOICEVOX エンジン／コア、音声モデル、各キャラクターの規約を分けて確認する。
   - 買い切り有料アプリへの組み込み、バイナリ・モデル再配布、生成音声の利用、クレジット、禁止事項を人間が公式情報で確認する。

上記3点が確定するまで、依存追加、UI追加、音声モデル同梱、サーバー構築には進まない。

## 1. 現在のTTS構造と拡張ポイント

### 1.1 現在の責務境界

| 現在の責務 | コード根拠 | 将来の検討点 |
|---|---|---|
| TTSキュー、初期化、再試行、優先度、サニタイズ | `lib/services/tts_service.dart:26-112`, `232-267`, `289-490` | エンジンに依存しないオーケストレーションとして維持できる範囲を確定する |
| AudioServiceの生成 | `lib/services/tts_service.dart:77-90` | エンジン選択後もAudioServiceを一元管理するか決める |
| 実際の端末TTS | `lib/services/background_tts_handler.dart:40-42`, `60-104`, `106-155` | `FlutterTts` 直結部分を端末TTS実装として分離する候補 |
| バックグラウンドkeep-aliveとメディア状態 | `lib/services/background_tts_handler.dart:44-58`, `106-155` | 合成済み音声を再生する方式でも状態遷移とkeep-aliveを壊さない境界が必要 |

`TtsService` はキューからアイテムを取り出し、`LiveVoiceBoxAudioHandler.speakItem` へ渡している（`lib/services/tts_service.dart:405-451`）。一方、`LiveVoiceBoxAudioHandler` は `FlutterTts` を直接所有し（`lib/services/background_tts_handler.dart:40-42`）、話速・ピッチ・音量・voiceを設定して発話する（同 `106-155`）。

したがって、`TtsEngine`（既存アーキテクチャ文書では `SpeechEngine`）抽象をこの間に置く案は構造上検討可能である。既存文書にも `SpeechRequest`、`SpeechEngine`、`DeviceSpeechEngine`、`ExternalSpeechEngine` の案がある（`docs/architecture.md:230-245`）。

ただし、VOICEVOX が音声データを生成し、そのデータを別のプレイヤーで再生する方式になる場合、`FlutterTts` の単純な差し替えでは足りない。次の責務境界を方式決定後に確定する必要がある。

- テキストから音声データを生成する責務
- 生成音声を再生・停止・スキップする責務
- AudioServiceのmedia item / playback stateを更新する責務
- 発話完了を`TtsService`へ返す責務
- keep-alive音源と生成音声を切り替える責務

### 1.2 `TtsSettings.voiceKey` の流用可能性

現在のvoiceは `Map<String, String>` で保持され、`name|locale|identifier` を一意キーとしている（`lib/models/tts_settings.dart:28-36`, `135-137`）。コメント用とギフト用のvoiceはJSONへ永続化される（同 `118-132`, `139-175`）。

この「表示用データとは別に安定した識別キーを作る」という仕組みはVOICEVOXにも流用候補となる。ただし現在のキー項目だけでVOICEVOXの話者・スタイルを一意に識別できるかは**要確認**である。

方式決定時に確認する識別要素：

- engine/source（端末標準TTSかVOICEVOXか）
- speaker識別子
- style識別子
- モデルまたは互換性バージョン
- locale

既存 `identifier` に名前空間付き識別子を格納するか、voiceモデル自体を拡張するかは未決定とする。既存保存値との後方互換性も確認対象である。

### 1.3 永続化とvoice discovery

現在は次の順序で設定を復元している。

1. SharedPreferencesから設定JSONを読む（`lib/features/main/tts_provider.dart:33-51`）。
2. 端末の利用可能voiceを取得する（同 `58-59`）。
3. 保存済みvoiceが現在の一覧に無ければ解除する（同 `60-70`）。
4. 設定を保存し、`TtsService`へ反映する（同 `71-74`）。

VOICEVOX追加時は、端末voiceとVOICEVOX voiceをいつ・どこから列挙するか、未対応環境やライセンス未同意状態のvoiceを一覧へ含めない条件を決める必要がある。設定更新の入口は `TtsSettingsNotifier.setCommentVoice`（同 `135-145`）であり、現在は利用可能voice keyとの一致を要求する（同 `147-155`）。

### 1.4 設定UI

現在の設定UIは、`availableVoices`をvoice keyでDropdownへ展開し（`lib/features/main/main_screen.dart:765-823`）、選択時に試聴（同 `823-853`）、確定時に `setCommentVoice` を呼ぶ（同 `857-867`）。空の選択値は「端末の標準ボイス」である（同 `804-808`）。

VOICEVOX追加時の変更想定箇所：

- voice一覧をsource別に表示する箇所
- VOICEVOX opt-in状態と対応状況を表示する箇所
- VOICEVOX voiceの試聴経路
- comment voice / gift voiceの適用範囲設定
- 未対応・初期化失敗時に端末標準TTSへ戻ったことを示す状態

現在のUIにギフト専用voiceを直接選択する操作は確認できない。モデルには `giftVoice` が存在し（`lib/models/tts_settings.dart:34-35`）、ギフト読み上げは `giftVoice ?? commentVoice` を使用する（`lib/features/live/live_provider.dart:737-751`）。将来の適用範囲設計では、この現状を前提にする。

### 1.5 既存キュー・優先度・サニタイズの再利用

既存処理はエンジン呼び出し前に実行されているため、抽象境界を `speakItem` 呼び出し付近に置く場合は再利用候補となる。

- サニタイズ：enqueue前に実行（`lib/services/tts_service.dart:304-324`, `327-345`）
- 優先度：priority降順、同順位は作成時刻順（同 `482-488`）
- キュー上限：既定20件（同 `29-40`, `475-480`）
- preview：高優先度で先頭へ入れ、再生中ならskip（同 `293-301`, `327-352`）
- stopAll：再試行を止め、generation更新、queue clear（同 `384-403`）
- 再入防止：`_isPlaying` とgeneration（同 `405-451`）

再利用の可否は、VOICEVOXの「生成」と「再生」のどこまでを1件の発話完了として待つかに依存する。生成ジョブだけを先行並列化する場合は、現在の単一 `_isPlaying` 状態では生成中・再生待ち・再生中を区別できないため、方式決定後に状態モデルを確認する。

## 2. 統合方式の比較

以下は判断材料であり、採用結論ではない。数値は方式・モデル・端末・サーバー構成が未確定のため**確認できない／要計測**とする。

| 項目 | クラウド方式 | オンデバイス方式 |
|---|---|---|
| 概要 | LiveVoice Studioまたは選定サービス上でエンジンを動かし、API経由で音声を取得 | エンジン・必要なランタイム・音声モデルを端末上で実行 |
| 現実性 | API、ホスティング、監視、容量制御、障害対応、利用条件の確認が必要 | Android/iOS向けバイナリ・モデルの提供可否、CPU/メモリ、OS制約の確認が必要 |
| 継続コスト | サーバー、帯域、保守、監視の継続費が発生。金額は要見積り | サーバー費は不要だが、モバイル対応・同梱・更新・端末互換性の保守が必要 |
| 通信 | 読み上げ対象テキストの送信と音声受信が必要 | 音声生成自体は通信不要にできる可能性。実際の配布・初期取得方式は要決定 |
| レイテンシ | 往復通信、待ち行列、サーバー合成時間に依存。実数は要計測 | 端末性能、モデル、発話長に依存。実数は要実機計測 |
| 障害点 | ネットワーク、API、認証、レート制限、サーバー障害 | 初期化失敗、メモリ不足、CPU負荷、OSバックグラウンド制限 |
| プライバシー | コメント本文等を端末外へ送るため現在の設計前提を変更 | 端末内処理だけなら現在の「運営サーバーへ送信しない」方向を維持可能。ただし実装・依存の通信を別途監査 |
| 文書・ストア申告 | Privacy Policy、Terms、Data Safety、App Privacy、保持・削除・委託先・送信先等の全面再監査が必要 | 同梱物・依存が外部送信しないことを確認できれば変更範囲を限定できる可能性。要再監査 |
| アプリサイズ | クライアント増分は比較的小さい可能性があるが、確定値は要ビルド計測 | エンジン・ランタイム・モデル同梱により大幅増となる可能性。現在の約42MBからの増加量は選定物で要計測 |
| オフライン | 不可 | 端末内に必要物が揃えば可能性あり。実現可否は要確認 |
| データ管理 | 送信内容、ログ、キャッシュ、保持期間、削除、アクセス制御が必要 | 音声キャッシュを持つ場合は端末内保存量と削除条件が必要 |

現在のPrivacy Policyは、コメントとギフトを実行中メモリで扱うこと（`docs/privacy.md:41-43`）、設定等を端末内に保存し運営サーバーへアップロードしないこと（同 `64-75`）、運営バックエンドおよびexternal cloud TTSが無いこと（同 `80-92`）を明記している。

したがってクラウド方式では、現在のprivacy.mdおよびそれを根拠にしたData Safety / App Privacy申告をそのまま使用できない。送信データ、送信先、目的、保持、削除、セキュリティ、第三者提供、障害ログ、キャッシュ、ユーザー同意を含む全面再監査が必要になる。

オンデバイス方式についても「通信しない」「モバイルで動く」「特定サイズ内に収まる」とは現時点で断定しない。採用候補の公式配布物と実機プロトタイプで確認する。

## 3. リアルタイム性の設計論点

TikTok LIVEのコメントは連続流入し、コメント読み上げは重複除去後にTTSキューへ入る（`lib/features/live/live_provider.dart:638-659`）。ギフトは通常コメントより高いpriorityで `enqueueFirst` される（同 `746-751`, `lib/services/tts_service.dart:327-352`）。

VOICEVOXの生成時間が端末標準TTSより長いかどうか、およびその差は方式・端末・話者・文章長に依存するため**要計測**である。設計時は少なくとも次を測る。

- 短文／30文字上限付近の合成時間
- 初回起動（cold）と連続生成（warm）の差
- コメント流入レートに対するqueue滞留時間
- 生成中キャンセルとstopの完了時間
- Android/iOSのforeground/background差
- CPU、メモリ、発熱、電池、音切れ
- クラウドの場合のネットワーク別往復時間とタイムアウト率

現状の上限20件はメモリ上限であると同時に古い低優先度発話を捨てる仕組みである（`lib/services/tts_service.dart:40`, `475-488`）。VOICEVOX統合時に決める論点：

- 合成待ちも20件へ含めるか、再生待ちだけを数えるか
- queueから取り出した後に生成失敗したアイテムの扱い
- 最大許容待ち時間と、期限切れコメントの破棄条件
- ギフト等の高優先度イベントが生成中コメントを中断できるか
- 生成リクエストの同時実行数
- 音声キャッシュの有無、上限、削除条件、ライセンス上の可否
- タイムアウト・未対応・初期化失敗時に端末標準TTSへ戻す条件
- フォールバック時に二重読み上げを防ぐrequest ID / generation管理

### 適用範囲の選択肢

| 選択肢 | 確認する性質 |
|---|---|
| 全コメント | 最大の生成頻度。追従性、コスト、キュー破棄の影響が最も大きい |
| ギフトのみ | 発話頻度を限定しやすい。現在のgift優先度経路との対応を確認 |
| 高額／特別ギフトのみ | さらに限定可能。判定条件と利用者への表示が必要 |
| コメントは標準TTS、ギフトはVOICEVOX | 2エンジン併用時のAudioService、stop、音声競合を確認 |
| 試聴のみ | 統合検証は限定できるが、LIVE中の価値・規約上の扱いは別途確認 |

適用範囲は未決定とする。

## 4. オプトイン設計

制約：**既定値は端末標準TTS。VOICEVOXを明示的に有効化したユーザーだけが使用し、標準TTSのみのユーザーのキュー・音声・設定・プライバシーを変えない。**

将来設定モデルで区別する候補状態：

- engine: device / voicevox
- voicevoxEnabled: 明示的opt-in
- selected voice / speaker / style
- apply scope: all / gift / special gift 等
- fallback enabled / fallback reason
- environment support: supported / unsupported / unavailable / initializing
- license or attribution acknowledgementが必要か：**要確認**

安全側の状態遷移：

1. 初期状態はdevice engine。
2. VOICEVOXが未対応、初期化失敗、必要物不足、通信不可（クラウド方式）の場合はVOICEVOXを使用可能として表示しない。
3. 明示的opt-in後も、1件ごとの失敗時に標準TTSへ戻すか、読み上げを破棄するかを設定仕様として確定する。
4. opt-out時は未処理のVOICEVOX生成要求を止め、以後の発話をdevice engineへ限定する。
5. 保存済みVOICEVOX voiceが利用不能になった場合は、現在のvoice availability検証（`lib/features/main/tts_provider.dart:58-70`, `147-155`）と同等の安全な無効化を行う。

UI上は、現在の「端末の標準ボイス」（`lib/features/main/main_screen.dart:804-808`）を既定のまま維持し、VOICEVOXは別sourceとして明示する。具体的な画面文言・配置は実装フェーズで確定し、このメモではUI変更を行わない。

## 5. ライセンス・規約の要人間確認リスト

以下はすべて**要確認**であり、このメモは利用可否を断定しない。確認日時、対象バージョン、URL、判断者、必要なクレジット文を記録してから実装判断を行う。

### 5.1 VOICEVOXソフトウェア／エンジン／コア

- 買い切り有料アプリへの組み込み可否
- Android/iOSアプリへのバイナリ組み込み可否
- エンジン、コア、辞書、モデル等の再配布可否と条件
- 改変、静的／動的リンク、ネットワーク提供に関する条件
- 生成音声の商用利用条件
- 必須クレジットの正確な文言と表示場所
- NOTICE、ライセンス本文、ソース提供等の義務
- クラウドAPIとして提供する場合の条件
- バージョンごとの差分と規約改定時の扱い

公式確認先：

- VOICEVOX公式サイト: https://voicevox.hiroshiba.jp/
- VOICEVOXソフトウェア利用規約: https://voicevox.hiroshiba.jp/term/
- VOICEVOX Engine公式リポジトリ: https://github.com/VOICEVOX/voicevox_engine
- VOICEVOX Core公式リポジトリ: https://github.com/VOICEVOX/voicevox_core

各リポジトリでは、採用するtag/commitのLICENSE、README、依存ライセンスを個別に確認する。

### 5.2 各キャラクター／音声ライブラリ

- 採用する各キャラクターの個別利用規約
- キャラクター名・画像・立ち絵・ロゴを使用する場合の条件
- 生成音声のみを使用する場合の条件
- 買い切り有料アプリでの利用条件
- クレジット表記義務と正確な表記
- 禁止用途、年齢区分、広告・宣伝上の制約
- 音声モデルの同梱・再配布可否
- クラウド上で音声生成する場合の可否
- 複数話者・スタイルごとの条件差

公式確認の入口：

- VOICEVOX「ボイボ寮」: https://voicevox.hiroshiba.jp/dormitory/
- 上記公式ページから各話者・音声ライブラリの公式規約へ遷移し、採用対象ごとに確認する。

「ずんだもん」等の個別キャラクターについても、VOICEVOX共通規約だけで判断せず、権利者が示す最新の個別規約を確認する。商用利用、再配布、クレジットについて本メモでは断定しない。

### 5.3 アプリ内・ストア上の表記

- アプリ内クレジットの表示場所
- Store listing / Privacy Policy / Terms / Support / LICENSE noticesへの記載要否
- 音声選択UIでの話者名・商標・画像利用可否
- 生成音声であることの表示要否
- 購入画面または機能説明で必要な注意事項

## 6. 実装ステップ（将来フェーズ）

この節は順序の計画であり、v1.0.0では実施しない。

### ① TtsEngine抽象の導入

- `SpeechRequest` / `TtsEngine` の責務を確定
- 現在の`FlutterTts`処理をdevice engineとして境界内へ移す
- queue、priority、sanitize、generation、AudioService、keep-aliveの既存挙動を固定
- device engineだけで既存テストと実機挙動が不変であることを確認

### ② VOICEVOXエンジン連携

- クラウド／オンデバイス決定後にのみ開始
- synthesize、play、stop、cancel、timeout、初期化、対応環境判定を実装対象として定義
- 公式ライセンス確認結果を実装条件へ反映

### ③ voice一覧への統合

- source / speaker / styleを一意に識別
- `TtsSettings.voiceKey`との互換方式を確定
- voice discoveryと保存済みvoiceのavailability検証を拡張

### ④ 設定UIとopt-in

- 既定値deviceを維持
- VOICEVOXの明示的有効化
- 適用範囲とvoice選択
- 未対応環境では安全に無効表示

### ⑤ フォールバック

- 失敗種別、timeout、queue期限、opt-out時の遷移を定義
- 標準TTSへ戻す場合の二重読み上げ防止
- stop / skip / stopAll / 接続終了時の生成キャンセル

### ⑥ 全体テスト

- unit、provider、queue、AudioService、platform、実機、長時間、プライバシー、ストア申告を再検証
- Android/iOSのRelease Buildと実配信を確認

## 7. 規模感と既存テストへの影響

これは新機能かつ複数責務をまたぐ大規模変更であり、v1.0.0の最小差分原則とは分離して扱う。工数・アプリサイズ・サーバー費・性能値は方式未決定のため**確認できない**。

現行107件テストのうち、少なくとも次の領域に追加・変更影響が想定される。

| テスト領域 | 現在の根拠 | 将来確認する内容 |
|---|---|---|
| sanitize | `test/tts_sanitize_test.dart` | engineに関係なく同じ入力制限が適用されること |
| voice key / settings | `test/tts_settings_test.dart` | deviceとVOICEVOXのキー衝突防止、旧JSON復元、無効voice解除 |
| queue / priority | `lib/services/tts_service.dart:304-352`, `405-488` | 生成待ち、再生待ち、gift優先、20件上限、期限切れ |
| live event routing | `test/comment_model_test.dart`, `lib/features/live/live_provider.dart:638-751` | comment/gift適用範囲、fallback、二重読み上げ防止 |
| stop / skip | `lib/services/tts_service.dart:355-403` | 合成中・再生中のcancel、generation整合 |
| settings provider | `lib/features/main/tts_provider.dart:33-86`, `135-155` | opt-in既定値、永続化、未対応環境の無効化 |
| AudioService / background | `lib/services/background_tts_handler.dart` | device/VOICEVOX切替、keep-alive、画面OFF、割込み、route change |

追加が必要となるテスト候補：

- fake device engine / fake VOICEVOX engineによる契約テスト
- engine選択とopt-inのproviderテスト
- synthesize timeout / failure / cancel / fallbackテスト
- queue上限到達時の生成ジョブ破棄テスト
- 高優先度ギフトによる中断テスト
- voice一覧マージとキー衝突テスト
- 旧v1.0.0設定JSONからの移行テスト
- unsupported environmentテスト
- クラウド方式の場合、送信payload・ログ非混入・保持条件のテスト
- オンデバイス方式の場合、モデル不足・初期化失敗・メモリ圧迫時のテスト

実数のテスト件数は実装範囲確定後に決める。現行107件を減らす前提にはしない。

## 8. 実装開始前ゲート

次が揃うまで実装開始判定をしない。

- [ ] クラウド／オンデバイス方式の決定
- [ ] 対象プラットフォームと最低対応端末の決定
- [ ] 対象話者・スタイル・適用イベントの決定
- [ ] エンジン／コア／モデル／各キャラクター規約の人間確認記録
- [ ] 必須クレジット文と表示場所の確定
- [ ] プライバシー／Data Safety／App Privacy影響判定
- [ ] アプリサイズまたはサーバー費の実測・見積り
- [ ] レイテンシ、CPU、メモリ、発熱、電池の試験計画
- [ ] fallbackとqueue期限の仕様確定
- [ ] v1.0.0ブランチ／タグと分離された開発計画

## 9. このメモで確認していないこと

- VOICEVOXまたは個別音声の商用利用可否
- 有料アプリへの組み込み可否
- エンジン、コア、モデルの再配布可否
- モバイルOS上での実行可否
- 実際の合成速度、CPU、メモリ、電池、アプリサイズ
- サーバー費用、必要帯域、同時接続数
- Apple／Googleの最新申告・審査判断

これらはすべて**要確認**である。
