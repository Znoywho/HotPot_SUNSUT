"""Tạo font chữ thường của game từ Ark Pixel 12px (bản latin, ~5 MB) -> file nhỏ chỉ giữ chữ Latin + tiếng Việt.

Ark thiếu "›" "‹" (game dùng làm đầu dòng): lấy nửa trái của "»" "«" (mỗi mũi tên là các ô pixel riêng) ghép thành.
Tải font gốc: https://github.com/TakWolf/ark-pixel-font/releases (gói ark-pixel-font-12px-proportional-ttf).
Chạy: pip install fonttools && python make_ark_pixel_vi.py <ark-pixel-12px-proportional-latin.ttf>
"""
import sys
from pathlib import Path

from fontTools import subset
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

OUT = Path(__file__).with_name("ArkPixel12-Vietnamese.ttf")
# ASCII, Latin-1, Latin mở rộng A (Đđ, Ăă...), Ơơ Ưư, dấu tổ hợp, chữ Việt dựng sẵn, dấu câu (tiền ghi "đ" thường).
UNICODES = [*range(0x20, 0x7F), *range(0xA0, 0x180), *range(0x1A0, 0x1B1), *range(0x300, 0x324),
            *range(0x1EA0, 0x1EFA), *range(0x2010, 0x2040)]
CHEVRON_WIDTH = 300  # đơn vị font (100 = 1 pixel): một mũi tên của » rộng 3 pixel.
CHEVRON_GAP = 100    # chừa 1 pixel trống bên phải, giống khoảng chừa của các chữ khác.


def add_single_chevron(font: TTFont, double_char: str, single_char: str) -> None:
    """Ghép glyph `single_char` (›) từ các ô pixel nằm trong mũi tên trái của `double_char` (»)."""
    glyf, hmtx, cmap = font["glyf"], font["hmtx"], font.getBestCmap()
    source = glyf[cmap[ord(double_char)]]
    pen = TTGlyphPen(None)
    start = 0
    for end in source.endPtsOfContours:
        points = source.coordinates[start:end + 1]
        start = end + 1
        if max(x for x, _ in points) > CHEVRON_WIDTH:
            continue  # ô pixel thuộc mũi tên phải -> bỏ
        pen.moveTo(points[0])
        for point in points[1:]:
            pen.lineTo(point)
        pen.closePath()
    name = f"uni{ord(single_char):04X}"
    font.setGlyphOrder(font.getGlyphOrder() + [name])
    glyf[name] = pen.glyph()
    hmtx[name] = (CHEVRON_WIDTH + CHEVRON_GAP, 0)
    for table in font["cmap"].tables:
        if table.isUnicode():
            table.cmap[ord(single_char)] = name


def build(source_path: str) -> None:
    """Cắt font gốc còn bộ ký tự tiếng Việt, thêm › ‹, ghi ra OUT."""
    font = TTFont(source_path)
    options = subset.Options()
    options.layout_features = ["*"]
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=UNICODES)
    subsetter.subset(font)
    font.save(OUT)
    font = TTFont(OUT)  # nạp lại bản đã cắt để bảng hmtx khớp thứ tự glyph mới trước khi thêm glyph
    add_single_chevron(font, "»", "›")
    add_single_chevron(font, "«", "‹")
    font.save(OUT)
    # Tự kiểm: đủ mọi chữ tiếng Việt + ký tự game dùng.
    vietnamese = "aàáảãạăằắẳẵặâầấẩẫậđeèéẻẽẹêềếểễệiìíỉĩịoòóỏõọôồốổỗộơờớởỡợuùúủũụưừứửữựyỳýỷỹỵ"
    needed = vietnamese + vietnamese.upper() + "0123456789·»«›‹–%"
    cmap = TTFont(OUT).getBestCmap()
    missing = [c for c in needed if ord(c) not in cmap]
    assert not missing, f"Thiếu ký tự: {missing}"
    print(f"{OUT.name}: {OUT.stat().st_size // 1024} KB, {len(cmap)} ký tự")


if __name__ == "__main__":
    build(sys.argv[1])
