#!/usr/bin/env bash
# Export bản Web và (tuỳ chọn) đẩy lên itch.io.
#
#   ./tools/build_web.sh          -> chỉ export ra build/web + build/soi-sung-suc-web.zip
#   ./tools/build_web.sh serve    -> export rồi mở server thử ở http://localhost:8000
#   ./tools/build_web.sh push     -> export rồi đẩy lên itch.io bằng butler
#
# Lần đầu push: chạy `butler login` một lần, và đặt ITCH_TARGET bên dưới
# (hoặc: ITCH_TARGET=tenban/soi-sung-suc ./tools/build_web.sh push).
set -euo pipefail

ITCH_TARGET="${ITCH_TARGET:-}"   # TODO: điền "<tên-itch>/<tên-game>" sau khi tạo trang itch.io
GODOT="${GODOT:-godot}"          # Godot 4.7.2

cd "$(dirname "$0")/.."
OUT=build/web
ZIP=build/soi-sung-suc-web.zip

echo "==> Export Web..."
rm -rf "$OUT" "$ZIP"
mkdir -p "$OUT"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true  # import asset mới (font, ảnh...)
"$GODOT" --headless --path . --export-release "Web" "$OUT/index.html"
[[ -f "$OUT/index.html" ]] || { echo "Export thất bại (thiếu export templates 4.7.2?)"; exit 1; }
(cd "$OUT" && zip -qr "../$(basename "$ZIP")" .)
echo "==> Xong: $OUT/ và $ZIP ($(du -h "$ZIP" | cut -f1))"

case "${1:-}" in
  serve)
    echo "==> Mở http://localhost:8000 (Ctrl+C để tắt)"
    python3 -m http.server 8000 --directory "$OUT"
    ;;
  push)
    [[ -n "$ITCH_TARGET" ]] || { echo "Chưa đặt ITCH_TARGET (vd: tenban/soi-sung-suc)"; exit 1; }
    VERSION="$(git describe --tags --always --dirty 2>/dev/null || date +%Y%m%d-%H%M)"
    echo "==> Đẩy lên itch.io: $ITCH_TARGET:html5 (version $VERSION)"
    butler push "$OUT" "$ITCH_TARGET:html5" --userversion "$VERSION"
    ;;
esac
