# 太陽系シミュレーター

macOS 用の太陽系可視化アプリケーション。任意の日時における惑星の配置を黄道面の俯瞰図として描き、
内惑星（水星・金星）の見え方をサイドパネルに表示する。

**macOS Sierra (10.12) から最新版まで、単一のユニバーサルバイナリで動作する。**

## 機能

### 太陽系の俯瞰図

- 水星から冥王星までの位置と軌道を、北黄極側から見下ろした向きで描画
- 日時の指定、再生（0.1〜100 日/秒）、拡大縮小、回転、平行移動
- 天体をダブルクリックすると、その天体が常に画面真下に来るよう視点を固定
- 視点の移動はドラッグで行う。マウスホイールでは視点が動かないようにしてある（ホイールの空回しで意図せず視野がずれるのを防ぐため）

### 内惑星サイドパネル

水星・金星について次を表示する。

「水星の概形 → 数値 → 今後の現象 → 金星の概形 → 数値 → 今後の現象」の順に縦へ並ぶ。

- **概形**（満ち欠け）と**視直径** — 天の北を上・東を左とする星図の向きで描画し、明縁は常に太陽の方向を向く
- **角度スケール** — 円盤の下に、円盤とまったく同じ縮尺で引いた角度の物差しを添えてある。円盤の直径と見比べれば視直径を直接読み取れる。縮尺は惑星ごとに固定してあるので、円盤の大小はそのまま視直径の増減を表し、水星と金星を比べるときはこの物差しを基準にする
- **離角**（東方／西方の別を含む）、**位相角**、**輝面比**、地心距離、日心距離
- **東方最大離角・西方最大離角・内合・外合**の予報時刻（日本標準時）

## ビルドと実行

```bash
./build.sh run
```

`dist/SolarSystemSim.app` が生成され、起動する。Xcode コマンドラインツールが必要。

| コマンド | 動作 |
|---|---|
| `./build.sh` | ビルドして `dist/SolarSystemSim.app` を作る |
| `./build.sh run` | ビルドして起動する |
| `./build.sh verify` | 軌道計算の検証を実行する |
| `./build.sh preview [日時]` | サイドパネルをオフスクリーンで PNG に描き出す |
| `./build.sh preview window [日時]` | ウインドウ全体をオフスクリーンで PNG に描き出す |
| `./build.sh data` | 技術解説の図表に使うデータを生成する |
| `./build.sh dmg` | 配布用 DMG を作る |
| `./build.sh clean` | 生成物を削除する |

### 配布用 DMG

```bash
./build.sh dmg
```

`dist/SolarSystemSim.dmg` が生成される。同梱物は次の 4 点。

| 同梱物 | 内容 |
|---|---|
| `SolarSystemSim.app` | アプリ本体（ユニバーサルバイナリ） |
| `技術解説.pdf` | 理論と実装の解説 |
| `Gatekeeper解除.scpt` | 隔離属性を取り除くスクリプト |
| `Applications` | `/Applications` へのリンク（インストール用） |

DMG を作るには技術解説の PDF が要る。先に
`./build.sh data && (cd docs/tex && latexmk -lualatex 技術解説.tex)` を実行しておくこと。

できあがった DMG は `dist/` ごと git で追跡している。
`dist/SolarSystemSim.app` だけは DMG の中身と重複する 18 MB なので追跡していない
（`.gitignore` の `dist/*.app/` を消せば追跡できる）。

### 初回起動時の Gatekeeper 解除

生成される `.app` は ad-hoc 署名（Apple の開発者証明書による署名・公証なし）のため、
**ダブルクリックでは開けない。** 初回だけ次のいずれかの操作が必要になる。

**方法 0: DMG 同梱のスクリプトを使う（配布版・推奨）**

1. `Gatekeeper解除.scpt` をダブルクリックする（スクリプトエディタが開く）
2. 上部の「実行」（▶）ボタンを押す（キーボードなら `command + R`）

アプリケーションフォルダへのコピー、隔離属性の解除、起動までまとめて行う。
先に手動でドラッグしておく必要はない。
すでにインストール済みなら、置き換えるか既存のものを解除するだけかを尋ねる。

取り除くのはこのアプリに付いた隔離属性だけで、システムのセキュリティ設定は変更せず、
他のアプリの扱いにも影響しない。
スクリプトの中身は [`Tools/dist/Gatekeeper解除.applescript`](Tools/dist/Gatekeeper解除.applescript) で読める。

**なぜ「実行」を押す必要があるのか（ダブルクリックだけで完了しない理由）**

ダブルクリックで自動的に走る形式にはできない。Gatekeeper は
「勝手に実行されうるファイル」をすべて検査するので、アプレット形式の `.app` も
`.command` シェルスクリプトも、署名・公証がなければ同じように止められるからである。
実際 `spctl` で調べると、隔離属性の付いた `.app`・`.command`・`.scpt` はいずれも
`rejected` になる。自動実行できる形式にすると、
「解除スクリプト自体を解除する」堂々巡りになり、かえって手順が増える。

`.scpt` をスクリプトエディタで開いて「実行」を押す形式だけが、
Apple が署名したスクリプトエディタに処理を代行させることでこの堂々巡りを避けられる。
「実行」を押す操作が、Gatekeeper が要求する明示的な同意にあたる。

この一手間を完全になくすには、Apple Developer Program（年 99 ドル）に登録して
アプリを Developer ID で署名し、公証（notarization）を受けるしかない。

**方法 1: 右クリックから開く**

`.app` を右クリック（または control を押しながらクリック）して「開く」を選び、
現れた警告ダイアログで「開く」を押す。2 回目以降は普通にダブルクリックで起動できる。

**方法 2: 隔離属性を外す**

ダウンロードや配布で受け取った場合は隔離属性が付いていることがある。

```bash
xattr -dr com.apple.quarantine /Applications/SolarSystemSim.app
```

**「開発元を確認できないため開けません」と出て「開く」ボタンが無い場合**

- macOS 13 以降 — 「システム設定 > プライバシーとセキュリティ」を開き、
  下の方に出る「"SolarSystemSim" は開発元を確認できないため……」の右の
  **「このまま開く」** を押す
- macOS 12 以前 / Sierra (10.12) — 「システム環境設定 > セキュリティとプライバシー > 一般」の
  **「このまま開く」** を押す。Sierra には「すべてのアプリケーションを許可」の選択肢が
  標準では出ないので、方法 1 の右クリック起動を使うのが確実

自分でビルドした直後の `dist/SolarSystemSim.app` には隔離属性が付かないため、
`./build.sh run` で起動する分にはこの操作は要らない。

### Sierra 対応の仕組み

- **AppKit の単一コードベース。** SwiftUI は macOS 10.15 以降でしか使えないため、Sierra 対応と両立しない。以前は SwiftUI 版と Sierra 版の 2 系統に分かれていたが、AppKit に一本化した
- `x86_64-apple-macosx10.12` と `arm64-apple-macosx11.0` の 2 スライスをビルドし、`lipo` で結合する
- macOS 10.14.4 より前には OS 内に Swift ランタイムが無いため、後方互換ライブラリを `Contents/Frameworks` に同梱する。rpath は `/usr/lib/swift` → `@executable_path/../Frameworks` の順で登録してあり、新しい OS では OS 側のランタイムが使われる

この制約から、`async`/`await`・`actor` および macOS 10.14 以降で追加された API は使用していない。ビルドは `-swift-version 5` で行う。

## 精度

位置計算は JPL Solar System Dynamics 公開の近似ケプラー要素
（*Keplerian Elements for Approximate Positions of the Major Planets*, Table 2b、有効範囲 3000 BC〜3000 AD）による。

`./build.sh verify` はアプリ本体と同じ実装を直接リンクして検証する。主な結果：

| 検証項目 | 結果 |
|---|---|
| ケプラーの第三法則 | 全 9 天体で既知の公転周期と 0.1% 以内 |
| 日心黄緯の最大値 = 軌道傾斜角 | 全 9 天体で 0.02° 以内 |
| 会合周期（内合の間隔・30 区間平均） | 水星 115.62 日／金星 583.91 日（既知 115.88／583.92） |
| 最大離角の変動範囲（10 年分） | 水星 17.89°〜27.81°／金星 45.40°〜47.19°（既知 17.9〜27.8／45.4〜47.1） |

**2026 年に水星に起こる 12 の現象（外合・東方最大離角・内合・西方最大離角の 3 巡）は、国立天文台が公表する日付とすべて一致する。**
金星の東方最大離角も日付・離角ともに一致する（本アプリ 45.89°、公表値 約 45.9°）。

ただし以下は補正していない。教育・可視化の用途を想定しており、観測計画や測位には使えない。

- 光路時間、光行差、大気差、観測地の視差
- 歳差・章動（座標系は J2000.0 に固定）
- 惑星の相互摂動（木星以遠の補正項を除く）

このため位置の誤差は分角のオーダー、合の時刻は 1 時間以内、最大離角の時刻は数時間程度の不確かさをもつ。
アプリが現象時刻を分単位までしか表示せず「概算値」と注記しているのはこのためである。

## ドキュメント

- [`docs/tex/技術解説.pdf`](docs/tex/技術解説.pdf) — 理論と実装の解説。軌道要素から位置を求める手順、離角・位相角・輝面比・視直径の導出、現象時刻の数値探索、精度の検証を扱う
- [`docs/UserGuide.html`](docs/UserGuide.html) — 操作方法

技術解説は LuaLaTeX で組んでいる。再コンパイルするには:

```bash
./build.sh data && cd docs/tex && latexmk -lualatex 技術解説.tex
```

## ディレクトリ構成

```
Sources/                       アプリ本体
  Models.swift                 軌道要素と天体のデータ構造
  NASAElements.swift           JPL の軌道要素の表
  OrbitalMechanics.swift       ケプラー方程式と座標変換
  InnerPlanetPhenomena.swift   離角・位相・視直径と現象時刻の探索
  PhaseDiskView.swift          概形（満ち欠け）の描画
  InnerPlanetPanel.swift       内惑星サイドパネル
  SolarSystemCanvas.swift      俯瞰図の描画と視点操作
  AppUI.swift                  ウインドウとコントロール
  main.swift                   エントリポイント
Tools/
  verify/                      軌道計算の検証
  export_data/                 技術解説の図表データ生成
  panel_preview/               サイドパネル・ウインドウのオフスクリーン描画
  dist/                        Gatekeeper解除スクリプト (配布用)
  icon_generator.swift         アイコン生成
Resources/                     Info.plist、アイコン
docs/                          ドキュメント
build.sh                       ビルドスクリプト
```

`Tools/` の各ツールは `Sources/` の実装を直接リンクする。検証コードや図表データが本体とずれることがない。

## 出典

- E. M. Standish, *Keplerian Elements for Approximate Positions of the Major Planets*, JPL Solar System Dynamics — <https://ssd.jpl.nasa.gov/planets/approx_pos.html>
- C. D. Murray and S. F. Dermott, *Solar System Dynamics*, Cambridge University Press, 1999
- NASA Planetary Fact Sheet — <https://nssdc.gsfc.nasa.gov/planetary/factsheet/>
- 国立天文台 暦計算室 — <https://eco.mtk.nao.ac.jp/koyomi/>
