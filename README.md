# ミニ・サバイバー (Mini Survivor) v0.1

Godot 4.7.2 / Compatibility renderer で作ったヴァンサバ風ミニゲーム。10分生き残ればクリア。

## 操作
- PC: WASD / 矢印キー / ゲームパッド左スティック・十字キーで移動。Esc / P / Start で一時停止。レベルアップは クリック・Enter・1〜3キー。
- スマホ: 画面のどこでもタッチ＆ドラッグでフローティング仮想スティック。ボタンはすべてタップ可能。右上の II で一時停止。
- 攻撃は自動。

## 武器 (各 Lv.5 まで)
- 魔法弾: 最も近い敵へ自動発射 (初期武器)
- 回転ブレード: 周囲を回る手裏剣
- 聖なるオーラ: 周囲に継続ダメージ＋押し返し
- 貫通ナイフ: 移動方向へ貫通する投げナイフ

## 強化
移動速度 / 最大HP / 回収範囲 / 攻撃力 / クールダウン / 再生 (全部最大なら HP回復)

## 敵
スライム (標準) / コウモリ (速い・弱い, 0:30〜) / ゴーレム (遅い・硬い, 1:30〜) / オーガ (ボス, 3:00から2分ごと)。毎分「大群」ウェーブ。

## デバッグ用引数 (`--` の後)
`--autoplay` 自動移動＋自動選択, `--shots` スクショ保存, `--shot-prefix=X`, `--timeskip=秒`, `--fight-shot-after=秒`, `--stats` 5秒ごとの統計, `--touchtest` タッチ入力の自己テスト。

例: `godot --path . --write-movie out/gameplay.avi --fixed-fps 30 --quit-after 750 -- --autoplay --timeskip=240`

## フォント
`fonts/NotoSansJP-Bold-subset.otf` は Noto Sans CJK JP Bold (SIL OFL 1.1, Debian fonts-noto-cjk) のサブセット。
文字を追加したら `tools/make_font.sh` で再生成する (スクリプト中の文字＋かな・英数字を収録)。

## 開発環境

環境の記録と復元手順は [SETUP.md](SETUP.md) を参照してください。
