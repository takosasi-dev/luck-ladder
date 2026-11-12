# LuckLadder

ブラウザで開くだけで遊べる、トランプのハイ&ロー。次の札が今の札より大きいか、小さいか、同じ数字かを当てて、当てた点を「確保」するまで積み上げます。

**▶ 開く: https://takosasi-dev.github.io/luck-ladder/** (インストール不要)

> **開発中です。** 1 人用の「ラン」を最後まで遊べます。今日の山札・実績の一覧・記録・コレクション・対戦は、これから足します。調整値は、まだ人に遊んでもらって決めた値ではありません。

- エンジン: Godot 4.7.2(GDScript、Compatibility レンダラー、Web 書き出し)
- 対応(予定): デスクトップの Chrome・Edge・Firefox、スマホの Chrome(Android)・Safari(iOS)。スマホの実機では、まだ確かめていません
- お金やチップを賭けるゲームではありません
- 記録はブラウザの中にだけ残ります

## 遊び方

- 山札 52 枚を 1 枚ずつめくります。次の札が今の札より **大きい(HIGH)**、**小さい(LOW)**、**同じ数字(同じ)** のどれかを当てます。A がいちばん小さく、K がいちばん大きい。
- ボタンの `+356` は、当たったときにもらえる点です。当たりにくい側ほど大きくなります。
- 当てた点は「ポット」に貯まり、**確保** を押すまで自分の点になりません。外すとポットは 0 になり、ライフが 1 減ります。
- 連続で当てるほど倍率が上がり、3 連続ごとにライフが 1 戻ります。確保すると連続は 0 に戻ります。
- ライフ(4 個)が無くなったら終わり。山札を最後までめくり切ると「完走」です。

| 操作 | キーボード | タッチ・マウス |
|---|---|---|
| HIGH | ↑ か W | ボタン、または札を上へはじく |
| LOW | ↓ か S | ボタン、または札を下へはじく |
| 同じ | → か D | ボタン |
| 確保 | スペース | ボタン |
| 一時停止 | Esc | 左上のボタン |

音量(BGM と効果音は別々)、演出の強さ、めくりの速さ、残り札の表示は「設定」で変えられます。

## 手元で動かす

Godot 4.7.2 で、このフォルダを開きます。テストはヘッドレスで回せます。

```
godot --headless --import
godot --headless --script res://tests/run_tests.gd
godot --headless --export-release "Web" build/web/index.html
```

`main` に push すると、GitHub Actions がテスト → Web 書き出し → GitHub Pages への配置を行います。テストが 1 件でも落ちたら配置しません。

効果音と BGM は、スクリプトで作った物をコミットしてあります。作り直すときは Python 3 で次を実行します(BGM は ffmpeg が要ります。PATH に入れるか、環境変数 `FFMPEG` で場所を渡します)。

```
python tools/gen_sfx.py
python tools/gen_bgm.py
```

## ライセンス

コードと自作の素材(効果音・BGM・マークの絵)は MIT ライセンス([LICENSE](LICENSE))。同梱フォント(Noto Sans JP、Playfair Display)は SIL Open Font License 1.1 です([THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md))。
