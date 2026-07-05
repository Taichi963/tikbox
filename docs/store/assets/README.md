# docs/store/assets/

このディレクトリは Google Play / App Store 提出用のグラフィックアセットを格納します。

---

## Feature Graphic（Google Play 必須）

| ファイル | 内容 |
|---|---|
| `feature_graphic_v1.svg` | 案1: ネオンバー＋チャットバブル＋中央テキスト（ダークネイビー×シアン×マゼンタ） |
| `feature_graphic_v2.svg` | 案2: グラデーションバンド＋横波形（シンプル・テキスト中心） |

**必要サイズ**: 1024 × 500 px（JPG または PNG、α チャンネルなし）  
**SVG は Play Store に直接アップロードできません。** 下記手順で PNG に変換してください。

---

## SVG → PNG 変換手順（ブラウザ使用・追加ツール不要）

1. SVG ファイルをブラウザ（Chrome / Safari）で開く
2. ブラウザコンソール（F12 → Console）で以下を実行:

```javascript
// ブラウザコンソールに貼り付けて実行
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

3. `feature_graphic.png` がダウンロードされます
4. 画像サイズが 1024×500 であることを確認して Play Console にアップロード

---

## Figma / Inkscape を使う場合

| ツール | 手順 |
|---|---|
| **Inkscape**（無料） | ファイル → エクスポート → PNG エクスポート → 幅1024・高さ500を指定 → エクスポート |
| **Figma**（無料プラン可） | SVG をインポート → フレームサイズを 1024×500 に設定 → エクスポート → PNG 2x |
| **Canva**（有料機能を使わない場合） | SVG を直接アップロードして 1024×500 のデザインに配置 → PNG でダウンロード |

---

## 色見本（ブランドカラー）

| 役割 | 16進数 |
|---|---|
| 背景（ダークネイビー） | `#0B0D1E` |
| ネオンシアン（主） | `#00D4FF` |
| ネオンマゼンタ（副） | `#CC00FF` |
| テキスト白 | `#FFFFFF` |
| 薄テキスト（キャプション） | `#8899BB` |

アプリアイコン（`assets/icon/app_icon.png`）の配色と整合させています。

---

## 注意事項

- Feature Graphic には TikTok のロゴ・商標を含めない（Play ポリシー違反）
- 開発者の本名（Taichi Shimizu）を含めない
- Play Store アップロード前に実際の PNG を確認し、日本語テキストが正しくレンダリングされているか目視確認すること
  （SVG 内の日本語フォントはブラウザのシステムフォントに依存するため、環境によって見た目が異なる可能性がある）
