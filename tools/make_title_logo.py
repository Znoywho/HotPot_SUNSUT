"""Logo pixel mập "SÔI SÙNG SỤC" cho menu chính (chạy: python3 tools/make_title_logo.py).
: mỗi chữ là lưới ô (nét dày 2 ô), tô gradient theo hàng,
viền nâu 1 ô, bóng đỏ lệch xuống 2 ô, rồi phóng to bằng nearest. Bản B thay Ô = nồi lẩu, chấm Ụ = quả ớt."""
from PIL import Image

TOP = 3        # số hàng dành cho dấu phía trên
BODY = 10      # chiều cao thân chữ
BOTTOM = 3     # hàng cho dấu chấm dưới
H = (TOP + BODY + BOTTOM) * 2 + 4 + 3

GLYPHS = {
 'S': [".######.", "########", "##....##", "##......", "#######.", ".#######", "......##", "##....##", "########", ".######."],
 'O': [".######.", "########", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "########", ".######."],
 'I': ["######", "######", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "######", "######"],
 'U': ["##....##"] * 8 + ["########", ".######."],
 'N': ["##....##", "###...##", "####..##", "#####.##", "##.#####", "##..####", "##...###", "##....##", "##....##", "##....##"],
 'G': [".######.", "########", "##....##", "##......", "##..####", "##..####", "##....##", "##....##", "########", ".######."],
 'C': [".######.", "########", "##....##", "##......", "##......", "##......", "##......", "##....##", "########", ".######."],
}
CIRCUMFLEX = ["..##..", ".####.", "##..##"]
GRAVE = ["##....", ".##...", "..##.."]
DOT = ["##", "##"]

# Hình pixel có màu sẵn.
PALETTE = {'r': (204, 52, 40), 'R': (150, 30, 26), 'o': (255, 150, 40), 'y': (255, 214, 80), 'g': (90, 170, 70),
           'k': (122, 36, 30), 'h': (90, 30, 24), 'f': (255, 120, 30), 'F': (255, 210, 70), 'w': (250, 246, 236)}
POT_STEAM = ["..w...w...w..", ".w...w...w...", "..w...w...w.."]
POT = ["rrrrrrrrrrrrr", "royoogoyogoor", "RRRRRRRRRRRRR", "hkkkkkkkkkkkh", "hkkkkkkkkkkkh", ".kkkkkkkkkkk.",
       ".kkkkkkkkkkk.", "..kkkkkkkkk..", "...FfF.FfF...", "...f.f.f.f..."]
CHILI = ["..g.", "rrrr", ".rr."]

FILL_BANDS = [(255, 236, 140), (255, 236, 140), (255, 214, 90), (255, 196, 64), (255, 180, 52),
              (255, 162, 44), (250, 142, 38), (244, 124, 34), (236, 108, 30), (228, 96, 28)]  # theo hàng thân chữ
ACCENT_FILL = (255, 236, 140)
OUTLINE = (58, 24, 16)
SHADOW = (140, 40, 26)
SCALE = 4


CELL = 2  # mỗi ô của mẫu chữ = 2x2 ô lưới, để viền 1 ô không lấp lỗ trong chữ


def pot_cells():
    """Nồi lẩu nhìn từ trên: vành tròn (đọc như chữ O) + nước lẩu + đồ nhúng + 2 quai + 3 làn hơi (dấu mũ).
    Trả về (lưới {(x, y): màu} gốc tại góc trái trên phần thân, bề rộng)."""
    W, Hh, ring = 16, 20, 4
    clay, clay_hi, clay_lo = (196, 62, 44), (232, 98, 66), (138, 36, 28)
    broth, broth_lo = (255, 146, 40), (232, 112, 30)
    cells = {}
    def inside(x, y, w, h, r):  # hình chữ nhật bo góc bán kính r
        cx = min(max(x, r), w - 1 - r)
        cy = min(max(y, r), h - 1 - r)
        return (x - cx) ** 2 + (y - cy) ** 2 <= r * r + r
    for y in range(Hh):
        for x in range(W):
            if not inside(x, y, W, Hh, 5):
                continue
            ix, iy = x - ring, y - ring
            if 0 <= ix < W - 2 * ring and 0 <= iy < Hh - 2 * ring and inside(ix, iy, W - 2 * ring, Hh - 2 * ring, 2):
                cells[(x + 2, y)] = broth_lo if (ix + iy) % 5 == 0 else broth
            else:
                cells[(x + 2, y)] = clay_hi if (x + y < 9) else (clay_lo if x + y > 26 else clay)
    items = [((7, 6), (255, 226, 110), 2, 2), ((11, 9), (250, 246, 236), 2, 2), ((8, 12), (90, 170, 70), 3, 1),
             ((12, 13), (214, 40, 36), 1, 2), ((7, 15), (255, 226, 110), 2, 1), ((10, 6), (90, 170, 70), 1, 2)]
    for (x0, y0), col, w, h in items:
        for dy in range(h):
            for dx in range(w):
                cells[(x0 + dx, y0 + dy)] = col
    for y in range(7, 12):  # quai hai bên
        for x in (0, 1, 18, 19):
            if y in (7, 11) or x in (0, 19):
                cells[(x, y)] = (90, 30, 24)
    steam = (250, 246, 236)
    wiggle = [1, 0, 0, 1, 1, 0]  # lệch ngang từng hàng -> làn hơi uốn lượn
    for sx in (5, 10, 15):  # 3 làn hơi dày 2 ô thay dấu mũ
        for i, y in enumerate(range(-7, -1)):
            for dx in range(2):
                cells[(sx + wiggle[i] + dx, y)] = steam
    return cells, 20


def tomato_cells():
    """Quả cà chua tròn có cuống xanh, thay dấu nặng dưới Ụ."""
    rows = [".gg.", "rRrr", "rrrd", ".dd."]
    col = {'g': (90, 170, 70), 'r': (226, 52, 40), 'R': (255, 130, 110), 'd': (170, 30, 24)}
    return {(c, r): col[p] for r, row in enumerate(rows) for c, p in enumerate(row) if p != '.'}, 4


def chili_grave_cells():
    """Quả ớt nằm chéo từ trên-trái xuống dưới-phải (đúng hướng dấu huyền), cuống xanh ở đầu trên."""
    rows = ["gg......", ".grr....", "..rRrr..", "...rrrr.", "....rrr.", ".....rr."]
    col = {'g': (90, 170, 70), 'r': (214, 40, 36), 'R': (255, 120, 100)}
    return {(c, r): col[p] for r, row in enumerate(rows) for c, p in enumerate(row) if p != '.'}, 8


def build(words, use_icons):
    """Trả về lưới {(x, y): màu} của cả dòng chữ (chưa viền / bóng)."""
    cells = {}
    top = TOP * CELL
    body = BODY * CELL
    def put_mask(mask, x0, y0, color_of_row):
        for r, row in enumerate(mask):
            for c, p in enumerate(row):
                if p == '#':
                    for dy in range(CELL):
                        for dx in range(CELL):
                            cells[(x0 + c * CELL + dx, y0 + r * CELL + dy)] = color_of_row(r)
    x = 0
    for word in words:
        for ch in word:
            base = {'Ô': 'O', 'Ù': 'U', 'Ụ': 'U'}.get(ch, ch)
            if ch == 'Ô' and use_icons:
                # Nồi lẩu nhìn phía trước (bản đầu), mỗi ô phóng 2x2 như nét chữ; hơi nước nằm chỗ dấu mũ.
                for r, row in enumerate(POT_STEAM):
                    for c, p in enumerate(row):
                        if p != '.':
                            for dy in range(CELL):
                                for dx in range(CELL):
                                    cells[(x + c * CELL + dx, r * CELL + dy)] = PALETTE[p]
                for r, row in enumerate(POT):
                    for c, p in enumerate(row):
                        if p != '.':
                            for dy in range(CELL):
                                for dx in range(CELL):
                                    cells[(x + c * CELL + dx, top + r * CELL + dy)] = PALETTE[p]
                x += len(POT[0]) * CELL + 3
                continue
            glyph = GLYPHS[base]
            w = len(glyph[0]) * CELL
            put_mask(glyph, x, top, lambda r: FILL_BANDS[r])
            mark = CIRCUMFLEX if ch == 'Ô' else GRAVE if ch == 'Ù' and not use_icons else None
            if ch == 'Ù' and use_icons:
                chili, cw = chili_grave_cells()
                for (px, py), col in chili.items():
                    cells[(x + (w - cw) // 2 - 1 + px, py - 3)] = col
            if mark:
                put_mask(mark, x + (w - len(mark[0]) * CELL) // 2, 0, lambda r: ACCENT_FILL)
            if ch == 'Ụ':
                if use_icons:
                    tomato, tw = tomato_cells()
                    for (px, py), col in tomato.items():
                        cells[(x + (w - tw) // 2 + px, top + body + 2 + py)] = col
                else:
                    put_mask(DOT, x + (w - 2 * CELL) // 2, top + body + 2, lambda r: FILL_BANDS[-1])
            x += w + 3  # khoảng cách giữa chữ
        x += 5  # thêm khoảng giữa hai từ
    return cells, x - 8


def render(words, use_icons):
    """Viền 1 ô quanh mọi ô có màu, bóng lệch xuống 2 ô, phóng to SCALE lần."""
    cells, width = build(words, use_icons)
    pad = 2
    W, Hh = width + pad * 2, H + pad * 2 + 2
    grid = {(x + pad, y + pad + 3): c for (x, y), c in cells.items() if y >= -pad - 3}
    outline = set()
    for (x, y) in grid:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = (x + dx, y + dy)
                if n not in grid: outline.add(n)
    solid = set(grid) | outline
    shadow = {(x, y + 2) for (x, y) in solid if (x, y + 2) not in solid} | {(x, y + 1) for (x, y) in solid if (x, y + 1) not in solid}
    img = Image.new('RGBA', (W, Hh), (0, 0, 0, 0))
    for p in shadow: img.putpixel(p, SHADOW + (255,))
    for p in outline: img.putpixel(p, OUTLINE + (255,))
    for p, c in grid.items(): img.putpixel(p, c + (255,))
    return img


if __name__ == "__main__":
    out = "assets/sprites/scenery/title_pixel.png"
    render(["SÔI", "SÙNG", "SỤC"], True).save(out)
    print("Đã ghi", out)
