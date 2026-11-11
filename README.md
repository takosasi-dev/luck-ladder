# LuckLadder

ブラウザで開くだけで遊べる、トランプのハイ&ロー。次の札が今の札より大きいか、小さいか、同じ数字かを当てて、当てた点を「確保」するまで積み上げます。

**▶ 開く: https://takosasi-dev.github.io/luck-ladder/** (インストール不要)

> **開発中です。** 今はタイトル画面と、動作確認用の表示だけがあります。まだ遊べません。

- エンジン: Godot 4.7.2(GDScript、Compatibility レンダラー、Web 書き出し)
- 対応(予定): デスクトップの Chrome・Edge・Firefox、スマホの Chrome(Android)・Safari(iOS)
- お金やチップを賭けるゲームではありません

## 手元で動かす

Godot 4.7.2 で、このフォルダを開きます。テストはヘッドレスで回せます。

```
godot --headless --import
godot --headless --script res://tests/run_tests.gd
godot --headless --export-release "Web" build/web/index.html
```

`main` に push すると、GitHub Actions がテスト → Web 書き出し → GitHub Pages への配置を行います。テストが 1 件でも落ちたら配置しません。

## ライセンス

コードは MIT ライセンス([LICENSE](LICENSE))。同梱フォントは SIL Open Font License 1.1 です([THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md))。
