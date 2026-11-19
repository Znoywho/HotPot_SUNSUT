#!/usr/bin/env python3
"""Vẽ ảnh pixel cho màn kết quả: Game Over (quán đóng cửa ban đêm) và sổ tổng kết ngày (đạt / trượt KPI).

Ra assets/sprites/ui/result/ (1 điểm ảnh = 3 px, cùng cỡ với cuốn sổ; trăng/sao = 4 px như phong cảnh):
- board_wood.png     tấm biển gỗ treo (StyleBoxTexture 9 ô, phần giữa và cạnh lát lặp): ván ngang, khung gỗ, ke sắt 4 góc
- rope.png           đoạn dây thừng lát dọc (treo tấm biển); rope_knot.png nút buộc + đinh ở mép biển
- cold_pot.png       nồi lẩu nguội: tô lại từ book/hotpot.png (bỏ khói, màu lạnh, nứt, mạng nhện), cùng cỡ để thay thế
- lantern_off.png    đèn lồng đỏ tắt đèn, có tua
- moon.png, star.png trăng khuyết + sao nhấp nháy cho trời đêm Game Over
- firework.png       dải 7 khung pháo hoa trắng (Godot tô màu bằng modulate), bắn sau cuốn sổ khi đạt KPI
- pill.png           nhãn tiêu đề sổ ("Tổng kết ngày 8", "Kết quả") bo góc kiểu pixel
- book_button.png, book_button_pressed.png  nút trong sổ ("Đến cửa hàng »") bo góc kiểu pixel
- stamp_frame.png    khung con dấu trắng mực loang (Godot tô xanh / đỏ bằng modulate)

Chạy từ thư mục gốc project: python tools/make_result_art.py
"""
import math
import random

from PIL import Image

OUT_DIR = "assets/sprites/ui/result/"
HOTPOT = "assets/sprites/ui/book/hotpot.png"
UI_SCALE = 3  # 1 điểm ảnh = 3 px (như cuốn sổ)
SKY_SCALE = 4  # trăng / sao theo cỡ điểm ảnh của phong cảnh (scenes/main_menu: PIXEL = 4)
CLEAR = (0, 0, 0, 0)

# Gỗ biển hiệu ban đêm: tối để chữ kem đọc rõ (tương phản ~9:1).
WOOD_OUTLINE = (40, 22, 14)
FRAME = (104, 64, 36)
FRAME_LIT = (138, 88, 50)
FRAME_DARK = (64, 38, 22)
INNER_EDGE = (48, 28, 18)
PLANKS = [(92, 58, 34), (86, 54, 32), (96, 61, 36)]
PLANK_TOP = (106, 68, 40)
GRAIN = (84, 52, 30)  # vân / mạch gần màu ván: chữ trên biển không bị rối
SEAM = (66, 40, 24)
IRON = (78, 78, 90)
IRON_LIT = (130, 130, 145)
IRON_DARK = (46, 46, 56)
RIVET = (200, 200, 212)
NAIL = (150, 150, 162)

ROPE = (196, 160, 104)
ROPE_DARK = (140, 108, 64)
ROPE_OUTLINE = (74, 47, 34)

# Sổ: cùng màu gạch cam của nhãn / nút cũ (book_theme.tres) để chữ kem giữ nguyên.
RUST = (163, 70, 26)
RUST_LIT = (194, 98, 48)
RUST_SHADE = (120, 52, 20)
RUST_PRESSED = (117, 50, 19)
BOOK_OUTLINE = (74, 47, 34)


class Canvas:
    """Lưới điểm ảnh nhỏ; save() phóng to số nguyên lần (nearest) cho nét pixel sắc."""

    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w, h), CLEAR)

    def put(self, x, y, color):
        """Tô 1 điểm (bỏ qua nếu ra ngoài khung)."""
        if 0 <= x < self.img.width and 0 <= y < self.img.height:
            self.img.putpixel((x, y), color if len(color) == 4 else color + (255,))

    def rect(self, x0, y0, x1, y1, color):
        """Tô hình chữ nhật [x0, x1] × [y0, y1] (tính cả 2 đầu)."""
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, color)

    def save(self, name, scale=UI_SCALE):
        """Lưu ảnh phóng scale lần vào OUT_DIR."""
        big = self.img.resize((self.img.width * scale, self.img.height * scale), Image.NEAREST)
        big.save(OUT_DIR + name)
        print("wrote", OUT_DIR + name, big.size)


def rounded_inset(y, h, radius_steps):
    """Bậc bo góc pixel: số điểm thụt vào ở hàng y của khối cao h (radius_steps = thụt ở hàng 0, 1, 2...)."""
    row = min(y, h - 1 - y)
    return radius_steps[row] if row < len(radius_steps) else 0


# --- Tấm biển gỗ ---------------------------------------------------------------

BOARD_MARGIN = 7  # điểm ảnh; Godot: texture_margin = 7 × 3 = 21 px
BOARD_TILE = (32, 24)  # ô ván lặp ở giữa: 3 tấm ván cao 8


def draw_board():
    """Tấm biển: khung gỗ sáng trên tối dưới, viền trong tối, 3 tấm ván có vân và mạch nối so le, ke sắt 4 góc."""
    m = BOARD_MARGIN
    tw, th = BOARD_TILE
    w, h = tw + 2 * m, th + 2 * m
    c = Canvas(w, h)
    c.rect(0, 0, w - 1, h - 1, WOOD_OUTLINE)
    c.rect(1, 1, w - 2, h - 2, FRAME)
    c.rect(1, 1, w - 2, 1, FRAME_LIT)  # mép trên được trăng chiếu
    c.rect(1, 1, 1, h - 2, FRAME_LIT)
    c.rect(1, h - 2, w - 2, h - 2, FRAME_DARK)
    c.rect(w - 2, 1, w - 2, h - 2, FRAME_DARK)
    c.rect(m - 1, m - 1, w - m, h - m, INNER_EDGE)
    rng = random.Random(7)
    for plank in range(3):
        y0 = m + plank * 8
        color = PLANKS[plank]
        c.rect(m, y0, m + tw - 1, y0 + 6, color)
        c.rect(m, y0, m + tw - 1, y0, PLANK_TOP)
        c.rect(m, y0 + 7, m + tw - 1, y0 + 7, SEAM)
        # Vân gỗ: vệt ngang ngắn, quấn vòng theo bề ngang ô lặp để lát liền mạch.
        for _ in range(2):
            gx, gy, length = rng.randrange(tw), y0 + rng.randrange(2, 6), rng.randrange(3, 7)
            for i in range(length):
                c.put(m + (gx + i) % tw, gy, GRAIN)
        # Mạch nối 2 tấm ván, so le giữa các hàng.
        joint = (plank * 11 + 5) % tw
        c.rect(m + joint, y0 + 1, m + joint, y0 + 6, SEAM)
    for cx, cy in [(1, 1), (w - 6, 1), (1, h - 6), (w - 6, h - 6)]:
        c.rect(cx, cy, cx + 4, cy + 4, IRON_DARK)
        c.rect(cx, cy, cx + 3, cy + 3, IRON)
        c.rect(cx, cy, cx + 3, cy, IRON_LIT)
        c.put(cx + 2, cy + 2, RIVET)
    c.save("board_wood.png")


def draw_rope():
    """Đoạn dây thừng xoắn 4 điểm ảnh, cao 8 (lát dọc), và nút buộc + đinh ở mép biển."""
    c = Canvas(4, 8)
    for y in range(8):
        twist = (y // 2) % 2 == 0
        c.put(0, y, ROPE_OUTLINE)
        c.put(3, y, ROPE_OUTLINE)
        c.put(1, y, ROPE if twist else ROPE_DARK)
        c.put(2, y, ROPE_DARK if twist else ROPE)
    c.save("rope.png")
    k = Canvas(8, 7)
    for y in range(7):
        inset = rounded_inset(y, 7, [2, 1])
        k.rect(inset, y, 7 - inset, y, ROPE_OUTLINE)
        if 0 < y < 6:
            k.rect(inset + 1, y, 6 - inset, y, ROPE if y < 3 else ROPE_DARK)
    k.rect(3, 3, 4, 4, IRON_DARK)
    k.put(3, 3, NAIL)
    k.save("rope_knot.png")


# --- Nồi lẩu nguội -----------------------------------------------------------------

# Màu nồi lẩu sôi (book/hotpot.png) -> màu nguội, tối, ngả xanh xám.
COLD_COLORS = {
    (165, 143, 120): None,  # khói -> bỏ
    (74, 47, 34): (44, 40, 48),  # viền
    (198, 40, 40): (92, 84, 84),  # nước lẩu nguội đóng váng
    (224, 75, 44): (110, 100, 96),
    (242, 163, 58): (140, 128, 112),  # váng mỡ
    (102, 187, 106): (96, 120, 96),  # rau héo
    (244, 232, 204): (170, 166, 156),
    (210, 122, 60): (120, 112, 120),  # thân nồi
    (180, 96, 44): (92, 86, 98),
    (138, 70, 32): (66, 60, 72),
}
CRACK = (36, 32, 40)
WEB = (196, 196, 210)


def draw_cold_pot():
    """Tô lại nồi lẩu của sổ sang bản nguội: bỏ khói, màu lạnh, vết nứt trên thân, mạng nhện góc phải."""
    src = Image.open(HOTPOT).convert("RGBA")
    small = src.resize((src.width // UI_SCALE, src.height // UI_SCALE), Image.NEAREST)
    c = Canvas(small.width, small.height)
    for y in range(small.height):
        for x in range(small.width):
            p = small.getpixel((x, y))
            if p[3] == 0:
                continue
            cold = COLD_COLORS.get(p[:3], p[:3])
            if cold is not None:
                c.put(x, y, cold)
    for x, y in [(23, 24), (22, 25), (22, 26), (23, 27), (24, 28), (23, 29), (22, 30), (22, 31), (21, 32), (24, 26)]:
        c.put(x, y, CRACK)
    # Mạng nhện giăng giữa quai phải và miệng nồi.
    for i in range(6):
        c.put(42 - i, 14, WEB)  # sợi ngang
        c.put(42, 14 + i, WEB)  # sợi dọc
        c.put(42 - i, 14 + i, WEB)  # sợi chéo
    for x, y in [(39, 15), (40, 16), (41, 17), (38, 16), (39, 18), (40, 19)]:
        c.put(x, y, WEB)
    c.save("cold_pot.png")


def draw_lantern_off():
    """Đèn lồng đỏ đã tắt: thân tròn tối có nan, nắp và đáy vàng xỉn, dây treo trên, tua dưới."""
    w, h = 20, 38
    c = Canvas(w, h)
    outline, body, rib, lit = (44, 24, 20), (120, 36, 32), (88, 26, 24), (150, 52, 44)
    cap, cap_dark, tassel, tassel_dark = (128, 100, 52), (90, 70, 36), (120, 44, 36), (84, 30, 26)
    c.rect(9, 0, 10, 3, outline)  # dây treo
    c.rect(5, 4, 14, 7, outline)
    c.rect(6, 5, 13, 5, cap)
    c.rect(6, 6, 13, 6, cap_dark)
    top, body_h = 8, 19
    for y in range(top, top + body_h):
        inset = rounded_inset(y - top, body_h, [5, 3, 2, 1, 1])
        c.rect(inset, y, w - 1 - inset, y, outline)
        if inset + 1 <= w - 2 - inset:
            c.rect(inset + 1, y, w - 2 - inset, y, body)
            c.put(inset + 2, y, lit)
    for x in (7, 12):
        c.rect(x, top + 1, x, top + body_h - 2, rib)
    c.rect(5, top + body_h, 14, top + body_h + 2, outline)
    c.rect(6, top + body_h, 13, top + body_h + 1, cap_dark)
    c.rect(9, top + body_h + 3, 10, h - 1, tassel)
    for x in (7, 8, 11, 12):
        c.rect(x, h - 5, x, h - 1, tassel_dark if x in (7, 12) else tassel)
    c.save("lantern_off.png")


# --- Trời đêm ----------------------------------------------------------------------

def draw_moon_and_star():
    """Trăng khuyết vàng nhạt có miệng hố, và 1 ngôi sao hình chữ thập."""
    size = 18
    c = Canvas(size, size)
    light, shade, crater = (252, 242, 204), (226, 210, 160), (214, 196, 148)
    r = 8.2
    for y in range(size):
        for x in range(size):
            dx, dy = x - 8.5, y - 8.5
            inside = dx * dx + dy * dy <= r * r
            bite = (dx - 5) ** 2 + (dy + 3) ** 2 <= (r - 1) ** 2  # khuyết phía trên phải
            if inside and not bite:
                near_bite = (dx - 4) ** 2 + (dy + 2.5) ** 2 <= (r + 0.5) ** 2
                c.put(x, y, shade if near_bite else light)
    for x, y in [(4, 9), (5, 12), (7, 14)]:
        c.put(x, y, crater)
    c.save("moon.png", SKY_SCALE)
    s = Canvas(7, 7)
    tip, core = (255, 236, 170, 200), (255, 252, 230)
    for i in range(7):
        s.put(3, i, tip if i in (0, 6) else core)
        s.put(i, 3, tip if i in (0, 6) else core)
    s.save("star.png", SKY_SCALE)


# --- Pháo hoa ----------------------------------------------------------------------

FIREWORK_FRAMES = 7
FIREWORK_SIZE = 32


def draw_firework():
    """Dải 7 khung: chớp sáng giữa -> vòng tia nở to (có vệt đuôi) -> tàn rơi thưa dần. Màu trắng để tô modulate."""
    sheet = Canvas(FIREWORK_SIZE * FIREWORK_FRAMES, FIREWORK_SIZE)
    radii = [2, 5, 8, 11, 13, 14, 15]
    alphas = [255, 255, 255, 255, 230, 170, 110]
    rays = 12
    center = FIREWORK_SIZE / 2 - 0.5
    for f in range(FIREWORK_FRAMES):
        ox = f * FIREWORK_SIZE
        a = alphas[f]
        if f == 0:  # chớp sáng hình chữ thập
            sheet.rect(ox + 13, 15, ox + 18, 16, (255, 255, 255, 255))
            sheet.rect(ox + 15, 13, ox + 16, 18, (255, 255, 255, 255))
        fall = max(0, f - 3)  # tàn rơi xuống
        for k in range(rays):
            if f >= 5 and k % 2 == 1:
                continue  # tàn thưa dần
            ang = 2 * math.pi * k / rays
            for back, alpha in ((0, a), (2, a // 2), (4, a // 4)):
                if f < 2 and back > 0:
                    continue
                rr = radii[f] - back
                if rr <= 0:
                    continue
                x = round(center + math.cos(ang) * rr)
                y = round(center + math.sin(ang) * rr) + fall
                if back == 0 and 1 <= f <= 4:  # đầu tia dày 2x2 cho dễ thấy
                    sheet.rect(ox + x, y, ox + x + 1, y + 1, (255, 250, 230, alpha))
                else:
                    sheet.put(ox + x, y, (255, 250, 230, alpha))
            if 2 <= f <= 4:  # vòng trong nhỏ hơn cho dày
                ang2 = ang + math.pi / rays
                rr = radii[f] * 0.55
                sheet.put(ox + round(center + math.cos(ang2) * rr), round(center + math.sin(ang2) * rr) + fall,
                          (255, 255, 255, a))
    sheet.save("firework.png")


# --- Sổ: nhãn, nút, con dấu ----------------------------------------------------------

def draw_pill():
    """Nhãn tiêu đề sổ: khối gạch cam bo góc bậc thang, viền tối, mép trên sáng, mép dưới tối."""
    w, h = 12, 14
    c = Canvas(w, h)
    for y in range(h):
        inset = rounded_inset(y, h, [3, 1, 1])
        c.rect(inset, y, w - 1 - inset, y, BOOK_OUTLINE)
        if 0 < y < h - 1:
            c.rect(inset + 1, y, w - 2 - inset, y, RUST_LIT if y == 1 else (RUST_SHADE if y == h - 2 else RUST))
    c.save("pill.png")


def draw_book_button(pressed):
    """Nút trong sổ: như nhãn nhưng có gờ dày phía dưới (nổi lên); bấm thì tối đi và gờ sang phía trên (lún xuống)."""
    w, h = 14, 16
    c = Canvas(w, h)
    for y in range(h):
        inset = rounded_inset(y, h, [3, 1, 1])
        c.rect(inset, y, w - 1 - inset, y, BOOK_OUTLINE)
        if 0 < y < h - 1:
            if pressed:
                color = RUST_SHADE if y <= 2 else RUST_PRESSED
            else:
                color = RUST_LIT if y == 1 else (RUST_SHADE if y >= h - 3 else RUST)
            c.rect(inset + 1, y, w - 2 - inset, y, color)
    c.save("book_button_pressed.png" if pressed else "book_button.png")


STAMP_MARGIN = 6  # Godot: texture_margin = 18 px


def draw_stamp_frame():
    """Khung con dấu trắng: viền ngoài dày 2 có chỗ mực bị hở (lặp mỗi 6 điểm để lát liền), viền trong mảnh."""
    m = STAMP_MARGIN
    size = 2 * m + 6
    c = Canvas(size, size)
    white = (255, 255, 255)
    c.rect(0, 0, size - 1, 1, white)
    c.rect(0, size - 2, size - 1, size - 1, white)
    c.rect(0, 0, 1, size - 1, white)
    c.rect(size - 2, 0, size - 1, size - 1, white)
    c.rect(3, 3, size - 4, 3, white)
    c.rect(3, size - 4, size - 4, size - 4, white)
    c.rect(3, 3, 3, size - 4, white)
    c.rect(size - 4, 3, size - 4, size - 4, white)
    for i in range(m, size - m):  # mực hở trên cạnh (phần lát lặp)
        if (i - m) % 6 == 2:
            c.put(i, 0, CLEAR)
            c.put(i, size - 1, CLEAR)
            c.put(0, i, CLEAR)
            c.put(size - 1, i, CLEAR)
        if (i - m) % 6 == 4:
            c.put(i, 3, CLEAR)
            c.put(size - 4, i, CLEAR)
    c.put(0, 0, CLEAR)  # góc mòn
    c.put(size - 1, size - 1, CLEAR)
    c.save("stamp_frame.png")


if __name__ == "__main__":
    import os

    os.makedirs(OUT_DIR, exist_ok=True)
    draw_board()
    draw_rope()
    draw_cold_pot()
    draw_lantern_off()
    draw_moon_and_star()
    draw_firework()
    draw_pill()
    draw_book_button(False)
    draw_book_button(True)
    draw_stamp_frame()
