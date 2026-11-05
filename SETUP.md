# 開発環境の記録と復元手順

クラウドPCが作り直されても、この手順でミニ・サバイバーの開発環境を元に戻せます。

## 記録した環境（2026-11-05 時点）

| 項目 | 内容 |
|---|---|
| OS | Debian GNU/Linux 13 (trixie), x86_64 |
| CPU / メモリ / GPU | 8コア / 15GB / GPUなし（Mesa llvmpipe のソフトウェア描画） |
| Godot | **4.7.2-stable**（標準版・非.NET）`4.7.2.stable.official.ed1daf0bf` |
| Godot 本体の場所 | `/opt/godot/Godot_v4.7.2-stable_linux.x86_64`（`/usr/local/bin/godot` にリンク） |
| エクスポートテンプレート | `~/.local/share/godot/export_templates/4.7.2.stable/`（Web・Windows・Linux・macOS・Android・iOS） |
| レンダラー | Compatibility（OpenGL 3, `gl_compatibility`）。Vulkan系はGPUなしだと非常に重い |
| Mesa | 25.0.7（`libgl1-mesa-dri`, `mesa-vulkan-drivers`） |
| ffmpeg | 7.1.5（プレイ動画の変換用） |
| p7zip-full | 16.02（Windows版の圧縮用） |
| fonts-noto-cjk | 20240730（日本語フォントの元データ） |
| fonttools | 4.65.0（`pyftsubset` でフォントを必要な文字だけに縮小） |
| GitHub CLI | gh 2.103.0 |

### 注意点
- **aptミラー**: この環境ではプロキシの都合で `deb.debian.org` が失敗するため、`/etc/apt/sources.list.d/debian.sources` を `https://cdn-fastly.deb.debian.org` に書き換えています（セットアップスクリプトが自動で行います）。
- Godotのダウンロードは公式GitHubリリースから取得し、SHA-512で検証しています。

## 復元手順

```bash
# 1. GitHubにログイン（ブラウザでデバイスコードを入力）
gh auth login --hostname github.com --git-protocol https --web

# 2. ソースを取得
cd /workspace
gh repo clone ferrarissound-design/mini-survivor
cd mini-survivor

# 3. 開発環境を自動セットアップ（Godot・テンプレート・必要パッケージ）
bash tools/setup_env.sh
```

## よく使うコマンド

```bash
# エディタを開く（デスクトップ上で）
DISPLAY=:4 godot --editor --rendering-driver opengl3 --path /workspace/mini-survivor

# ヘッドレスでエラーチェック
godot --headless --path . --quit-after 600

# 全プラットフォーム書き出し + docs/ 更新
bash tools/build_all.sh

# 公開（GitHub Pages は main ブランチの /docs を配信）
git add -A && git commit -m "update" && git push
```

## 公開先
- ゲーム: https://ferrarissound-design.github.io/mini-survivor/
- ソース: https://github.com/ferrarissound-design/mini-survivor
