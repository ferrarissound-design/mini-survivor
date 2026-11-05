#!/usr/bin/env bash
# Web / Windows / Linux を書き出し、Web版を docs/（GitHub Pages）にコピーする
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/web build/windows build/linux
godot --headless --path . --export-release "Web" build/web/index.html
godot --headless --path . --export-release "Windows" build/windows/mini-survivor.exe
godot --headless --path . --export-release "Linux" build/linux/mini-survivor.x86_64
rm -rf docs && cp -r build/web docs && touch docs/.nojekyll
(cd build/windows && 7z a -t7z -mx=9 ../mini-survivor-windows.7z . >/dev/null)
(cd build/web && zip -qr ../mini-survivor-web.zip .)
echo "書き出し完了。公開するには: git add -A && git commit -m 'update build' && git push"
