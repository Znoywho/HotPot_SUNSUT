"""Font tiêu đề pixel mập: chữ IN HOA tiếng Việt (đủ dấu) + số + vài dấu câu, cho thẻ chuyển buổi và màn Game Over.

Chạy:  py assets/fonts/pixel_title/make_pixel_title_font.py [--preview]

Cùng kiểu logo menu "SÔI SÙNG SỤC" (tools/make_title_logo.py): nét dày 2 px, viền tối 1 px quanh chữ,
bóng đổ lệch xuống 1 px, thân chữ tô theo dải màu từ sáng (trên) xuống tối (dưới), không khử răng cưa.
Mỗi bảng màu ra 1 font BMFont (<variant>.fnt + <variant>.png) để Godot import; khi hiện phải phóng
NGUYÊN lần (cỡ chữ = NATIVE_SIZE x 2, 3, 4...) để điểm ảnh không méo.

Dấu tiếng Việt ghép tự động: tách NFD thành chữ gốc + dấu (unicodedata), mỗi dấu một mặt nạ riêng.
Dấu thanh đi với dấu mũ (Ấ Ầ Ẩ) đặt lệch bên phải dấu mũ như chữ Việt in; dấu ngã + mũ (Ẫ) và dấu thanh
+ trăng (Ắ Ằ Ẳ Ẵ) thì chồng lên trên. Ơ Ư có móc ở góc trên phải. Đ = D + gạch ngang thân trái.
Tự vẽ hoàn toàn bằng code, không lấy từ font của ai (repo công khai).
--preview ghi thêm _tmp_test/pixel_title_preview.png (thư mục đã gitignore) để xem trước.
"""
import sys
import unicodedata
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]

CAP = 12  # chiều cao thân chữ in hoa (hàng 0..11)
TOP = -8  # hàng trên cùng của ô chữ: viền trên của dấu cao nhất (dấu thanh chồng trên dấu trăng / ngã trên mũ)
BOTTOM = 16  # hàng dưới cùng: bóng đổ dưới dấu nặng
LINE_H = BOTTOM - TOP + 1  # 25
BASE = CAP - TOP  # 20: từ mép trên ô tới chân thân chữ
NATIVE_SIZE = LINE_H  # "size" trong .fnt; Godot phóng theo cỡ chữ / NATIVE_SIZE
GAP = 1  # px trống giữa 2 chữ, ngoài viền
SPACE = 6  # bề rộng dấu cách (gồm cả khoảng hở)
ATLAS_W = 512

# --- Mặt nạ thân chữ: '#' = nét, cao CAP hàng (dấu phẩy thòng thêm 1 hàng) --------------------------------
GLYPHS = {
    'A': [".######.", "########", "##....##", "##....##", "##....##", "##....##", "########", "########", "##....##", "##....##", "##....##", "##....##"],
    'B': ["#######.", "########", "##....##", "##....##", "##...##.", "#######.", "########", "##....##", "##....##", "##....##", "########", "#######."],
    'C': [".######.", "########", "##....##", "##......", "##......", "##......", "##......", "##......", "##......", "##....##", "########", ".######."],
    'D': ["#######.", "########", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "########", "#######."],
    'E': ["#######", "#######", "##.....", "##.....", "##.....", "######.", "######.", "##.....", "##.....", "##.....", "#######", "#######"],
    'F': ["#######", "#######", "##.....", "##.....", "##.....", "######.", "######.", "##.....", "##.....", "##.....", "##.....", "##....."],
    'G': [".######.", "########", "##....##", "##......", "##......", "##..####", "##..####", "##....##", "##....##", "##....##", "########", ".######."],
    'H': ["##....##", "##....##", "##....##", "##....##", "##....##", "########", "########", "##....##", "##....##", "##....##", "##....##", "##....##"],
    'I': ["######", "######", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "######", "######"],
    'J': ["...#####", "...#####", "......##", "......##", "......##", "......##", "......##", "......##", "##....##", "##....##", "########", ".######."],
    'K': ["##....##", "##...###", "##..###.", "##.###..", "#####...", "####....", "####....", "#####...", "##.###..", "##..###.", "##...###", "##....##"],
    'L': ["##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "#######", "#######"],
    'M': ["##......##", "###....###", "####..####", "##.####.##", "##..##..##", "##......##", "##......##", "##......##", "##......##", "##......##", "##......##", "##......##"],
    'N': ["##....##", "###...##", "####..##", "####..##", "##.##.##", "##.##.##", "##..####", "##..####", "##...###", "##....##", "##....##", "##....##"],
    'O': [".######.", "########", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "########", ".######."],
    'P': ["#######.", "########", "##....##", "##....##", "##....##", "########", "#######.", "##......", "##......", "##......", "##......", "##......"],
    'Q': [".######.", "########", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##.##.##", "##..####", "#######.", ".#######"],
    'R': ["#######.", "########", "##....##", "##....##", "##....##", "########", "#######.", "##.###..", "##..###.", "##...###", "##....##", "##....##"],
    'S': [".######.", "########", "##....##", "##......", "##......", "#######.", ".#######", "......##", "......##", "##....##", "########", ".######."],
    'T': ["########", "########", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...", "...##..."],
    'U': ["##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "########", ".######."],
    'V': ["##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "###..###", ".##..##.", ".######.", "..####..", "..####..", "...##..."],
    'W': ["##......##", "##......##", "##......##", "##......##", "##......##", "##..##..##", "##..##..##", "##.####.##", "##########", "####..####", "###....###", "##......##"],
    'X': ["##....##", "##....##", "###..###", ".######.", "..####..", "...##...", "...##...", "..####..", ".######.", "###..###", "##....##", "##....##"],
    'Y': ["##....##", "##....##", "##....##", "###..###", ".######.", "..####..", "...##...", "...##...", "...##...", "...##...", "...##...", "...##..."],
    'Z': ["########", "########", ".....###", "....###.", "....###.", "...###..", "..###...", ".###....", ".###....", "###.....", "########", "########"],
    'Đ': [".#######.", ".########", ".##....##", ".##....##", ".##....##", "#####..##", "#####..##", ".##....##", ".##....##", ".##....##", ".########", ".#######."],
    '0': [".#####.", "#######", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "#######", ".#####."],
    '1': ["..##..", ".###..", "####..", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "######", "######"],
    '2': [".######.", "########", "##....##", "......##", "......##", ".#######", "#######.", "##......", "##......", "##......", "########", "########"],
    '3': [".######.", "########", "##....##", "......##", "......##", "..#####.", "..######", "......##", "......##", "##....##", "########", ".######."],
    '4': ["....###.", "...####.", "..##.##.", ".##..##.", "##...##.", "########", "########", ".....##.", ".....##.", ".....##.", ".....##.", ".....##."],
    '5': ["########", "########", "##......", "##......", "#######.", "########", "......##", "......##", "......##", "##....##", "########", ".######."],
    '6': [".######.", "########", "##....##", "##......", "##......", "#######.", "########", "##....##", "##....##", "##....##", "########", ".######."],
    '7': ["########", "########", "......##", ".....###", "....###.", "...###..", "..###...", "..##....", "..##....", "..##....", "..##....", "..##...."],
    '8': [".######.", "########", "##....##", "##....##", "##....##", ".######.", "########", "##....##", "##....##", "##....##", "########", ".######."],
    '9': [".######.", "########", "##....##", "##....##", "##....##", "########", ".#######", "......##", "......##", "##....##", "########", ".######."],
    '!': ["##", "##", "##", "##", "##", "##", "##", "##", "..", "..", "##", "##"],
    '?': [".######.", "########", "##....##", "......##", ".....###", "...####.", "...###..", "...##...", "...##...", "........", "...##...", "...##..."],
    '.': ["..", "..", "..", "..", "..", "..", "..", "..", "..", "..", "##", "##"],
    ',': ["..", "..", "..", "..", "..", "..", "..", "..", "..", "..", "##", "##", "#."],
    ':': ["..", "..", "..", "##", "##", "..", "..", "..", "..", "..", "##", "##"],
    '·': ["..", "..", "..", "..", "..", "##", "##", "..", "..", "..", "..", ".."],
    '-': ["......", "......", "......", "......", "......", "######", "######", "......", "......", "......", "......", "......"],
    '+': ["......", "......", "......", "..##..", "..##..", "######", "######", "..##..", "..##..", "......", "......", "......"],
    '%': ["##....##", "##...###", ".....##.", "....###.", "....##..", "...###..", "..###...", "..##....", ".###....", ".##.....", "###...##", "##....##"],
    '/': ["....##", "....##", "...###", "...##.", "..###.", "..##..", "..##..", ".###..", ".##...", "###...", "##....", "##...."],
    '(': ["..##", ".###", "###.", "##..", "##..", "##..", "##..", "##..", "##..", "###.", ".###", "..##"],
    ')': ["##..", "###.", ".###", "..##", "..##", "..##", "..##", "..##", "..##", ".###", "###.", "##.."],
}

# --- Dấu (mặt nạ nhỏ, nét 2 px theo bậc thang) -----------------------------------------------------------
ACUTE = ["..##", ".##.", "##.."]
GRAVE = ["##..", ".##.", "..##"]
HOOK = ["###.", "..##", ".##."]  # dấu hỏi: móc nhỏ như dấu ? không chấm
TILDE = [".###...#", "#...###."]  # dấu ngã: sóng 2 hàng, đỉnh và đáy rộng 3 px cho rõ hình "~"
CIRCUMFLEX = ["..##..", ".####.", "##..##"]
CIRCUMFLEX_LOW = [".####.", "##..##"]  # mũ thấp 2 hàng khi có dấu ngã chồng lên trên (Ẫ Ễ Ỗ)
BREVE = ["##..##", ".####."]
DOT = ["##", "##"]
HORN = [".##", "###"]  # móc của Ơ Ư, gắn vào góc trên phải

TONE_MARKS = {"́": ACUTE, "̀": GRAVE, "̉": HOOK, "̃": TILDE}
VOWELS = "AĂÂEÊIOÔƠUƯY"
TONES = ["", "̀", "́", "̉", "̃", "̣"]  # ngang, huyền, sắc, hỏi, ngã, nặng


def charset():
    chars = [chr(c) for c in range(ord('A'), ord('Z') + 1)] + ['Đ']
    for v in VOWELS:
        for t in TONES:
            c = unicodedata.normalize("NFC", v + t)
            if len(c) == 1 and c not in chars:
                chars.append(c)
    chars += list("0123456789!?.,:·-+%/()")
    return chars


# --- Bảng màu: [sáng nhất (hàng trên cùng), dải 1..4 từ sáng tới tối], viền, bóng ---------------------------
# Quy tắc (skill pixel-art-studio): đổi sắc >= 30 độ dọc dải, viền tối hơn màu tối nhất, nắng chiếu từ trên.
VARIANTS = {
    "morning": (["#fff6d8", "#ffe79a", "#ffc96b", "#ffa155", "#f07a48"], "#3a1a10", "#8a3a1c"),  # bình minh: kem bơ -> đào -> cam
    "noon": (["#fffbe8", "#fff1a0", "#ffd36b", "#f6b443", "#e07a2a"], "#3a1810", "#8c2a1a"),  # nắng trưa: trắng vàng -> vàng -> hổ phách
    "evening": (["#ffe6c8", "#ffbf8a", "#ff8f6a", "#e8627a", "#b8457e"], "#2a1030", "#5c1a46"),  # hoàng hôn: hồng cam -> san hô -> mận
    "shop": (["#eafff4", "#b8f2d6", "#7ed9c0", "#4fb8ac", "#3a8896"], "#10282a", "#1c4a4c"),  # rạng đông: bạc hà -> ngọc -> lam
    "game_over": (["#ffc4a8", "#ff9270", "#e8583f", "#c03a30", "#8a2430"], "#1a0a08", "#3a1210"),  # biển hiệu tắt: đỏ cam -> đỏ -> đỏ rượu
}


def hex_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def row_color(fills, y):
    """Màu nét theo hàng: hàng 0 sáng nhất, rồi 4 dải 3-3-3-2 hàng; dấu trên lấy dải 1, dấu dưới lấy dải 3."""
    if y < 0:
        return fills[1]
    if y == 0:
        return fills[0]
    if y >= CAP:
        return fills[3]
    return fills[min(4, 1 + (y - 1) // 3)]


def put(cells, mask, x0, y0):
    for r, row in enumerate(mask):
        for c, p in enumerate(row):
            if p == '#':
                cells[(x0 + c, y0 + r)] = True


def compose(ch):
    """Lưới ô nét {(x, y)} của 1 ký tự; y = 0 là mép trên thân chữ."""
    cells = {}
    if ch in GLYPHS:
        put(cells, GLYPHS[ch], 0, 0)
        return cells
    nfd = unicodedata.normalize("NFD", ch)
    base, marks = nfd[0], nfd[1:]
    body = GLYPHS[base]
    w = len(body[0])
    put(cells, body, 0, 0)
    vowel = CIRCUMFLEX if "̂" in marks else BREVE if "̆" in marks else None
    tone = next((TONE_MARKS[m] for m in marks if m in TONE_MARKS), None)
    if "̛" in marks:  # móc Ơ Ư: chạm góc trên phải thân chữ
        put(cells, HORN, w - 1, -2)
    if vowel is CIRCUMFLEX:
        cx = (w - 6) // 2
        if tone is TILDE:
            put(cells, CIRCUMFLEX_LOW, cx, -3)
            put(cells, TILDE, (w - len(TILDE[0])) // 2, -7)  # ngã chồng trên mũ, cách 1 hàng
        elif tone is not None:
            put(cells, CIRCUMFLEX, cx - 1, -4)
            put(cells, tone, cx + 4, -7)  # sắc / huyền / hỏi ở góc trên phải dấu mũ, không chạm mũ
        else:
            put(cells, CIRCUMFLEX, cx, -4)
    elif vowel is BREVE:
        put(cells, BREVE, (w - 6) // 2, -3)
        if tone is not None:
            put(cells, tone, (w - len(tone[0])) // 2, -7)  # dấu thanh chồng trên dấu trăng
    elif tone is TILDE:
        put(cells, TILDE, (w - len(TILDE[0])) // 2, -4)  # ngã chỉ 2 hàng: nhích lên cho sóng không dính sát chữ
    elif tone is not None:
        put(cells, tone, (w - len(tone[0])) // 2, -len(tone) - 1)
    if "̣" in marks:
        put(cells, DOT, (w - 2) // 2, CAP + 1)
    return cells


def render_glyph(ch, variant):
    """Ảnh RGBA cao LINE_H của 1 ký tự: nét tô dải màu + viền 8 hướng + bóng lệch xuống 1 px."""
    fills_hex, outline_hex, shadow_hex = VARIANTS[variant]
    fills = [hex_rgb(h) for h in fills_hex]
    outline_c, shadow_c = hex_rgb(outline_hex), hex_rgb(shadow_hex)
    cells = compose(ch)
    xs = [x for x, _ in cells]
    min_x, max_x = min(xs), max(xs)
    outline = set()
    for (x, y) in cells:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = (x + dx, y + dy)
                if n not in cells:
                    outline.add(n)
    solid = set(cells) | outline
    shadow = {(x, y + 1) for (x, y) in solid if (x, y + 1) not in solid}
    width = max_x - min_x + 3
    img = Image.new("RGBA", (width, LINE_H), (0, 0, 0, 0))

    def px(p, color):
        x, y = p[0] - min_x + 1, p[1] - TOP
        assert 0 <= y < LINE_H, f"{ch!r}: hàng {p[1]} ra ngoài ô chữ"
        img.putpixel((x, y), color + (255,))

    for p in shadow:
        px(p, shadow_c)
    for p in outline:
        px(p, outline_c)
    for (x, y) in cells:
        px((x, y), row_color(fills, y))
    return img


def build_font(variant, chars):
    glyphs = {ch: render_glyph(ch, variant) for ch in chars}
    # Xếp ảnh vào atlas theo hàng, cách nhau 1 px trong suốt.
    placements = {}
    x = y = 0
    for ch, g in glyphs.items():
        if x + g.width > ATLAS_W:
            x, y = 0, y + LINE_H + 1
        placements[ch] = (x, y)
        x += g.width + 1
    height = y + LINE_H
    atlas_h = 1
    while atlas_h < height:
        atlas_h *= 2
    atlas = Image.new("RGBA", (ATLAS_W, atlas_h), (0, 0, 0, 0))
    for ch, g in glyphs.items():
        atlas.paste(g, placements[ch])
    png_name = f"{variant}.png"
    atlas.save(HERE / png_name)
    lines = [
        f'info face="PixelTitle {variant}" size={NATIVE_SIZE} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0',
        f"common lineHeight={LINE_H} base={BASE} scaleW={ATLAS_W} scaleH={atlas_h} pages=1 packed=0 alphaChnl=0 redChnl=0 greenChnl=0 blueChnl=0",
        f'page id=0 file="{png_name}"',
        f"chars count={len(glyphs) + 1}",
        f"char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance={SPACE} page=0 chnl=15",
    ]
    for ch, g in glyphs.items():
        gx, gy = placements[ch]
        lines.append(f"char id={ord(ch)} x={gx} y={gy} width={g.width} height={LINE_H} xoffset=0 yoffset=0 xadvance={g.width + GAP} page=0 chnl=15")
    (HERE / f"{variant}.fnt").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")  # LF: chạy lại trên Windows không đổi file
    return glyphs


def text_image(glyphs, text, scale):
    width = sum(SPACE if c == ' ' else glyphs[c].width + GAP for c in text)
    img = Image.new("RGBA", (max(1, width), LINE_H), (0, 0, 0, 0))
    x = 0
    for c in text:
        if c == ' ':
            x += SPACE
            continue
        g = glyphs[c]
        img.alpha_composite(g, (x, 0))
        x += g.width + GAP
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


def preview(all_glyphs):
    rows = [
        ("morning", "NGÀY 12 · SÁNG", "#7ec8f0", 4),
        ("noon", "TRƯA", "#8fd4f4", 4),
        ("evening", "CHIỀU TỐI", "#6a4a7a", 4),
        ("shop", "CỬA HÀNG NÂNG CẤP", "#2a4060", 4),
        ("game_over", "QUÁN ĐÓNG CỬA", "#3a2418", 3),
        ("noon", "ẤẦẨẪẬ ẮẰẲẴẶ ỐỒỔỖỘ ỚỜỞỠỢ", "#8fd4f4", 2),
        ("evening", "ỨỪỬỮỰ ÝỲỶỸỴ ĐƯƠ 0123456789 ·!?%", "#6a4a7a", 2),
        ("morning", "ABCDEFGHIJKLMNOPQRSTUVWXYZ (+-/.,:)", "#7ec8f0", 2),
    ]
    images = [(text_image(all_glyphs[v], t, s), bg) for v, t, bg, s in rows]
    pad = 16
    w = max(i.width for i, _ in images) + pad * 2
    h = sum(i.height + pad for i, _ in images) + pad
    sheet = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    y = pad // 2
    for img, bg in images:
        band = Image.new("RGBA", (w, img.height + pad), hex_rgb(bg) + (255,))
        band.alpha_composite(img, (pad, pad // 2))
        sheet.alpha_composite(band, (0, y))
        y += img.height + pad
    out = ROOT / "_tmp_test" / "pixel_title_preview.png"
    out.parent.mkdir(exist_ok=True)
    sheet.save(out)
    return out


if __name__ == "__main__":
    chars = charset()
    all_glyphs = {v: build_font(v, chars) for v in VARIANTS}
    print(f"Wrote {len(VARIANTS)} fonts x {len(chars)} glyphs to {HERE.relative_to(ROOT)}")
    if "--preview" in sys.argv:
        print("Preview:", preview(all_glyphs).relative_to(ROOT))
