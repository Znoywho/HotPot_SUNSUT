#!/usr/bin/env python3
"""Vẽ bộ ảnh pixel phong cảnh + nút dùng chung (1 điểm ảnh = 4 px màn hình). Đang dùng ở menu chính.

Phong cảnh tách lớp để ghép và cho chuyển động trong Godot (assets/sprites/scenery/):
- sky.png               trời 432x180 (dải xanh ngả tím)
- sun.png, sun_glow.png mặt trời + quầng sáng
- cloud_big.png, cloud_small.png  mây trôi
- landscape.png         432x180 (giữa 320 là phần màn 16:9 thấy), phía trời trong suốt: núi giữa có quán lẩu lớn trên đỉnh (xa, phủ sương),
                        dãy núi xa bo tròn, đồi trái (trâu gặm cỏ), đồi phải (chỗ nhân viên đánh quái), đồng cỏ
- restaurant_grand.png  quán lẩu lớn nhiều tầng mái (bản rõ nét, không sương) để màn khác dùng lại
- kitchen_clutter.png   rổ rau củ + thớt bày thịt, cà chua cắm dao, nồi chồng phía sau,
                        ghép từ ảnh trong assets/sprites/kitchen/
Nút bát giác đỏ viền kem (StyleBoxTexture 9 ô, xem scenes/common/pixel_button.gd):
- assets/sprites/ui/button_red_normal.png, button_red_pressed.png, button_red_disabled.png

Chạy từ thư mục gốc project: python tools/make_menu_art.py
"""
import math
import random

from PIL import Image, ImageDraw

SCENERY_DIR = "assets/sprites/scenery/"
UI_DIR = "assets/sprites/ui/"
KITCHEN_DIR = "assets/sprites/kitchen/"
SIDE = 56  # Nới thêm mỗi bên cho màn rộng (điện thoại ~2.2:1); màn 16:9 cắt đúng phần này nên nhìn như ảnh 320.
W, H = 320 + 2 * SIDE, 180
MEADOW_TOP = 112  # Đồng cỏ bắt đầu ở đây (~ 38% chiều cao từ dưới lên như ảnh mẫu).

# Trời: xanh ở trên ngả tím rồi sáng dần xuống chân trời (mỗi màu là một dải, chuyển dải bằng ô cờ).
SKY_BANDS = [(92, 132, 206), (112, 140, 212), (138, 146, 214), (164, 156, 214), (188, 172, 218), (210, 192, 222)]
CLOUD = (232, 226, 240)
CLOUD_SHADE = (196, 186, 222)
SUN = (255, 244, 196)
SUN_EDGE = (255, 218, 120)
SUN_GLOW = (255, 236, 190)
HAZE = (104, 146, 116)  # Dãy đồi xa phủ cây (xanh ngả sương).
RANGE = (132, 162, 162)  # Dãy núi cao xa nhất: xanh pha nhiều sương (nhạt gần màu trời cho thấy rất xa).
RANGE_LIT = (150, 176, 170)
RANGE_SHADE = (118, 148, 152)
RANGE_RIDGE = (110, 140, 146)
RANGE_ROUND = 24  # Bán kính bo tròn đỉnh núi (điểm ảnh).
# Đỉnh núi xa (x, y đỉnh, độ dốc): cao nhất dồn về hai bên, trũng sau quán để quán vẫn nổi trên trời.
RANGE_PEAKS = [(20, 30, 0.9), (92, 18, 0.8), (150, 40, 0.9), (282, 34, 0.85), (356, 14, 0.75), (420, 32, 0.9)]
GRASS_TUFT = (126, 184, 78)
GRASS_TUFT_DARK = (70, 122, 56)
# Chỗ trâu đứng gặm cỏ trên đồi trái (khớp buffalo_feet trong scenes/main_menu/main_menu.gd).
GRAZING_SPOTS = [(66, 77), (88, 76.5), (108, 81)]
HAZE_TINT = (176, 170, 214)  # Màu sương phủ lên quán ở xa.
HAZE_AMOUNT = 0.35  # Quán xa pha 35% màu sương.
MOUNTAIN = (70, 108, 92)  # Núi giữa ở xa nên ngả xanh xám.
MOUNTAIN_LIT = (92, 128, 100)
HILL_RIGHT = (86, 150, 64)  # Đồi phải gần hơn, xanh tươi.
HILL_RIGHT_LIT = (112, 172, 74)
HILL_RIGHT_EDGE = (58, 112, 52)
TREE = (30, 62, 44)
TREE_LIGHT = (44, 82, 52)
TREE_FAR = (60, 92, 80)
MEADOW = (112, 170, 62)
MEADOW_DARK = (82, 138, 52)
MEADOW_LIGHT = (140, 192, 84)
MEADOW_SHADOW = (66, 112, 50)

# Màu quán lấy từ nền nhà hàng trong game (gạch, mái hiên) để cùng bảng màu.
BRICK = (163, 93, 62)
BRICK_LIGHT = (171, 97, 65)
MORTAR = (92, 51, 34)
OUTLINE = (62, 36, 22)
ROOF = (150, 45, 38)
ROOF_LIGHT = (196, 52, 43)
ROOF_DARK = (100, 30, 28)
PILLAR = (170, 40, 36)
GOLD = (240, 190, 70)
CREAM = (241, 227, 196)
GLASS_GLOW = (255, 214, 120)
WOOD = (122, 79, 40)
WOOD_DARK = (74, 44, 26)
STONE = (150, 140, 125)
STONE_DARK = (95, 80, 62)

# Núi giữa: đỉnh bằng rộng (chỗ đặt quán) ở x = 160 ± PLATEAU_HALF, cao PLATEAU_Y.
MOUNTAIN_CENTER = 160 + SIDE
PLATEAU_HALF = 30
PLATEAU_Y = 66
RESTAURANT_SIZE = (84, 40)  # Ảnh quán; đáy ảnh đặt đúng mặt đỉnh núi.
LANTERN_SPOTS = [(2, 22), (78, 22), (14, 10), (66, 10)]  # Góc trái trên đèn lồng trong ảnh quán.
LANTERN_BODY = (236, 80, 56)  # Đèn lồng sáng (không phủ sương) cho nổi trên quán mờ.

# Chữ "LẨU" pixel 3x8 trên biển quán ("X" = điểm tô). Ẩ có dấu mũ + dấu hỏi phía trên.
SIGN_GLYPHS = {
    "L": ["...", "...", "...", "X..", "X..", "X..", "X..", "XXX"],
    "Ẩ": ["XX.", ".X.", "X.X", ".X.", "X.X", "XXX", "X.X", "X.X"],
    "U": ["...", "...", "...", "X.X", "X.X", "X.X", "X.X", "XXX"],
}


# --- Đường cong địa hình ---------------------------------------------------------------------------
def mountain_curve(x: float) -> float:
    """Núi giữa: y = PLATEAU_Y trên đỉnh bằng, ra ngoài y = PLATEAU_Y + 0.0045 * (|x - 160| - PLATEAU_HALF)^2."""
    d = max(0.0, abs(x - MOUNTAIN_CENTER) - PLATEAU_HALF)
    return PLATEAU_Y + 0.0045 * d ** 2


def left_hill_curve(x: float) -> float:
    """Đồi trái (trâu gặm cỏ), cùng kiểu đồi phải: y = 72 + 0.005 * (x - 80)^2 (đỉnh ở x = 80)."""
    return 72 + 0.005 * (x - 24 - SIDE) ** 2


def right_hill_curve(x: float) -> float:
    """Đồi bên phải (nhân viên đánh quái trên đỉnh), thấp hơn núi giữa: y = 70 + 0.005 * (x - 356)^2 (đỉnh ở x = 356)."""
    return 70 + 0.005 * (x - 300 - SIDE) ** 2


def range_curve(x: float) -> float:
    """Dãy núi cao xa nhất, đỉnh bo tròn: y = min theo từng đỉnh của peak_y(x) + gợn 1.5 * sin(x / 3)."""
    return min(peak_y(p, x) for p in RANGE_PEAKS) + 1.5 * math.sin(x / 3)


def peak_y(peak: tuple, x: float) -> float:
    """Một đỉnh bo tròn: y = đỉnh_y + dốc * (sqrt((x - đỉnh_x)^2 + R^2) - R); gần đỉnh cong như vòm, xa ra thành sườn thẳng."""
    px, py, slope = peak
    return py + slope * (math.hypot(x - px, RANGE_ROUND) - RANGE_ROUND)


def nearest_peak(x: float) -> tuple:
    """Đỉnh tạo nên đường núi tại cột x (đỉnh cho y nhỏ nhất) - để biết x nằm sườn trái hay sườn phải."""
    return min(RANGE_PEAKS, key=lambda p: peak_y(p, x))


def draw_mountain_range(d: ImageDraw.ImageDraw, rng: random.Random) -> None:
    """Dãy núi cao xa: sườn trái sáng, sườn phải tối, viền đỉnh sáng, vài vệt khe núi chéo xuống từ đỉnh."""
    for x in range(W):
        top = round(range_curve(x))
        px = nearest_peak(x)[0]
        d.line((x, top, x, MEADOW_TOP), fill=RANGE_LIT if x < px else RANGE_SHADE)
        d.point((x, top), fill=RANGE_LIT)
        for y in range(top + 6, MEADOW_TOP, 4):  # chấm lưới thưa pha màu giữa cho sườn đỡ phẳng (không xếp chéo)
            if x % 3 == (y // 4) % 3:
                d.point((x, y), fill=RANGE)
    for px, py, slope in RANGE_PEAKS:  # khe núi: 2 vệt chéo từ gần đỉnh đi xuống
        for side in (-1, 1):
            x, y = px + side * 3, py + 4
            for _ in range(rng.randint(10, 18)):
                d.point((round(x), y), fill=RANGE_RIDGE)
                x += side * rng.uniform(0.6, 1.2)
                y += 1


def draw_grass_tufts(d: ImageDraw.ImageDraw, rng: random.Random) -> None:
    """Cỏ cao trên đồi trái: bụi dày quanh chỗ trâu gặm + rải khắp mặt đồi. Mỗi bụi vài nét dọc 2–4 điểm ảnh."""
    spots = [(gx + rng.uniform(-10, 10), gy + rng.uniform(-1, 3)) for gx, gy in GRAZING_SPOTS for _ in range(14)]
    for _ in range(70):
        x = rng.uniform(4, 150)
        top = left_hill_curve(x)
        if top < MEADOW_TOP - 4:
            spots.append((x, rng.uniform(top + 3, MEADOW_TOP)))
    for x, y in spots:
        x, y = round(x), round(y)
        for blade in range(rng.randint(2, 4)):
            bx = x + blade - 1
            h = rng.randint(2, 4)
            d.line((bx, y, bx, y - h + 1), fill=GRASS_TUFT_DARK)
            d.point((bx + rng.choice((-1, 0, 1)), y - h), fill=GRASS_TUFT)


def haze_curve(x: float) -> float:
    """Dãy núi xa mờ: y = 70 + 6 * sin(x / 17) + 4 * sin(x / 7)."""
    return 70 + 6 * math.sin(x / 17) + 4 * math.sin(x / 7)


# --- Trời, mây, mặt trời ---------------------------------------------------------------------------
def dither_band(d: ImageDraw.ImageDraw, y0: int, y1: int, color_a, color_b) -> None:
    """Tô dải y0..y1 màu a, hàng cuối ô cờ a/b để chuyển màu kiểu pixel."""
    d.rectangle((0, y0, W, y1), fill=color_a)
    for x in range(0, W, 2):
        d.point((x + (y1 % 2), y1), fill=color_b)


def make_sky() -> Image.Image:
    """Lớp trời riêng (đặt sau cùng, mây và mặt trời bay trước nó)."""
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    band = 70 // len(SKY_BANDS) + 1
    for i, color in enumerate(SKY_BANDS):
        dither_band(d, i * band, (i + 1) * band, color, SKY_BANDS[min(i + 1, len(SKY_BANDS) - 1)])
    d.rectangle((0, len(SKY_BANDS) * band, W, H), fill=SKY_BANDS[-1])
    return img


def make_sun() -> Image.Image:
    """Mặt trời tròn 14x14: lõi kem, mép vàng đậm."""
    img = Image.new("RGBA", (14, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((0, 0, 13, 13), fill=SUN_EDGE)
    d.ellipse((1, 1, 12, 12), fill=SUN)
    d.point((4, 3), fill=(255, 255, 240))
    return img


def make_sun_glow() -> Image.Image:
    """Quầng sáng 30x30 quanh mặt trời: 2 vòng ô cờ thưa dần ra ngoài (pixel không dùng mờ)."""
    img = Image.new("RGBA", (30, 30), (0, 0, 0, 0))
    for y in range(30):
        for x in range(30):
            r = math.hypot(x - 14.5, y - 14.5)
            if r < 10 and (x + y) % 2 == 0:
                img.putpixel((x, y), SUN_GLOW + (200,))
            elif r < 14 and x % 2 == 0 and y % 2 == 0:
                img.putpixel((x, y), SUN_GLOW + (140,))
    return img


def make_cloud(width: int, puffs: int, seed: int) -> Image.Image:
    """Mây dẹt: vài cụm elip chồng nhau, đáy phẳng có viền bóng tím."""
    rng = random.Random(seed)
    height = 12
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(puffs):
        cx = 6 + i * (width - 12) // max(1, puffs - 1)
        r = rng.randint(3, 5)
        d.ellipse((cx - r * 2 + 2, height - 3 - r * 2, cx + r * 2 - 2, height - 3), fill=CLOUD)
    d.rectangle((2, height - 5, width - 3, height - 3), fill=CLOUD)
    d.line((3, height - 2, width - 4, height - 2), fill=CLOUD_SHADE)
    return img


# --- Quán lẩu lớn ----------------------------------------------------------------------------------
def draw_brick_wall(d: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int) -> None:
    """Tường gạch: viên 6x3 xếp so le, mạch vữa tối, viền ngoài đậm."""
    d.rectangle((x0, y0, x1, y1), fill=BRICK)
    for row, y in enumerate(range(y0, y1 + 1, 3)):
        d.line((x0, y, x1, y), fill=MORTAR)
        shift = 3 if row % 2 else 0
        for x in range(x0 + shift, x1 + 1, 6):
            d.line((x, y, x, min(y + 2, y1)), fill=MORTAR)
            if x + 2 <= x1 and y + 1 <= y1:
                d.point((x + 2, y + 1), fill=BRICK_LIGHT)
    d.rectangle((x0, y0, x1, y1), outline=OUTLINE)


def draw_roof(d: ImageDraw.ImageDraw, x0: int, x1: int, base: int, height: int) -> None:
    """Mái ngói đỏ hình thang chìa 4 điểm ảnh ra hai bên, vạch ngói, nóc sáng, đầu mái vểnh kiểu Á Đông."""
    for i in range(height):
        d.line((x0 - 4 + i, base - i, x1 + 4 - i, base - i), fill=ROOF if i % 2 else ROOF_DARK)
    for x in range(x0 - 2, x1 + 3, 4):
        d.line((x, base - height + 2, x, base - 1), fill=ROOF_DARK)
    top = base - height + 1
    d.line((x0 - 4 + height - 1, top, x1 + 4 - height + 1, top), fill=ROOF_LIGHT)
    d.line((x0 - 4, base, x1 + 4, base), fill=OUTLINE)
    d.line((x0 - 6, base - 2, x0 - 5, base - 1), fill=ROOF_DARK)
    d.line((x1 + 6, base - 2, x1 + 5, base - 1), fill=ROOF_DARK)


def draw_lantern(d: ImageDraw.ImageDraw, x: int, y: int) -> None:
    """Đèn lồng đỏ treo dưới mái (3x6)."""
    d.point((x + 1, y), fill=OUTLINE)
    d.rectangle((x, y + 1, x + 2, y + 4), fill=ROOF_LIGHT)
    d.point((x + 1, y + 2), fill=GLASS_GLOW)
    d.point((x + 1, y + 5), fill=GOLD)


def draw_sign_text(d: ImageDraw.ImageDraw, text: str, x: int, y: int) -> None:
    """Viết chữ pixel 3x8 (gồm 3 hàng dấu phía trên) bắt đầu từ góc (x, y), mỗi chữ cách 1 cột."""
    for i, char in enumerate(text):
        for row, line in enumerate(SIGN_GLYPHS[char]):
            for col, cell in enumerate(line):
                if cell == "X":
                    d.point((x + i * 4 + col, y + row), fill=ROOF_LIGHT)


def draw_lantern_glow(img: Image.Image, x: int, y: int) -> None:
    """Đèn lồng sáng: quầng vàng ô cờ 9x10 quanh đèn rồi thân đỏ tươi, lõi vàng."""
    glow = Image.new("RGBA", (9, 10), (0, 0, 0, 0))
    for gy in range(10):
        for gx in range(9):
            if (gx + gy) % 2 == 0 and math.hypot(gx - 4, gy - 4.5) < 4.6:
                glow.putpixel((gx, gy), GLASS_GLOW + (110,))
    img.alpha_composite(glow, (x - 3, y - 2))
    d = ImageDraw.Draw(img)
    d.point((x + 1, y), fill=OUTLINE)
    d.rectangle((x, y + 1, x + 2, y + 4), fill=LANTERN_BODY)
    d.line((x + 1, y + 2, x + 1, y + 3), fill=GLASS_GLOW)
    d.point((x + 1, y + 5), fill=GOLD)


def make_restaurant(with_lanterns: bool = True) -> Image.Image:
    """Quán lẩu lớn 84x40: nền đá bậc thềm, tầng trệt gạch có cột đỏ + cửa lớn, mái tầng 1 rộng,
    tầng 2 nhỏ hơn, mái tầng 2, chòi nóc có chóp vàng, biển LẨU trước mái tầng 1, đèn lồng ở các đầu mái."""
    w, h = RESTAURANT_SIZE
    cx = w // 2
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Nền đá + bậc thềm giữa.
    d.rectangle((2, h - 4, w - 3, h - 1), fill=STONE, outline=STONE_DARK)
    d.rectangle((cx - 8, h - 4, cx + 7, h - 1), fill=CREAM, outline=STONE_DARK)
    d.line((cx - 8, h - 2, cx + 7, h - 2), fill=STONE)
    # Tầng trệt: tường gạch, cột đỏ, cửa sổ sáng, cửa lớn giữa.
    draw_brick_wall(d, 8, 22, w - 9, h - 5)
    for x in range(8, w - 8, 13):
        d.rectangle((x, 22, x + 1, h - 5), fill=PILLAR)
    for x in range(12, w - 12, 13):
        if abs(x + 2 - cx) > 8:
            d.rectangle((x, 26, x + 4, 31), fill=GLASS_GLOW, outline=WOOD_DARK)
    d.rectangle((cx - 6, 26, cx + 5, h - 5), fill=WOOD_DARK)
    d.rectangle((cx - 5, 27, cx + 4, h - 5), fill=GLASS_GLOW)
    d.line((cx, 27, cx, h - 5), fill=WOOD)
    # Tầng 2 + cửa sổ nhỏ.
    draw_brick_wall(d, 18, 9, w - 19, 17)
    for x in range(22, w - 22, 8):
        d.rectangle((x, 11, x + 3, 14), fill=GLASS_GLOW, outline=WOOD_DARK)
    draw_roof(d, 6, w - 7, 21, 6)  # mái tầng 1
    draw_roof(d, 18, w - 19, 9, 5)  # mái tầng 2
    draw_roof(d, 34, w - 35, 4, 4)  # chòi nóc
    d.line((cx - 1, 0, cx, 0), fill=GOLD)  # chóp vàng
    # Biển LẨU dựng trước mái tầng 1.
    d.rectangle((cx - 9, 12, cx + 8, 21), fill=CREAM, outline=WOOD_DARK)
    draw_sign_text(d, "LẨU", cx - 5, 13)
    if with_lanterns:
        for x, y in LANTERN_SPOTS:
            draw_lantern(d, x, y)
    return img


def hazed(img: Image.Image, amount: float) -> Image.Image:
    """Pha màu sương: màu mới = màu cũ * (1 - amount) + HAZE_TINT * amount, giữ nguyên độ trong suốt."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = tuple(round(c * (1 - amount) + t * amount) for c, t in zip((r, g, b), HAZE_TINT)) + (a,)
    return out


# --- Phong cảnh ------------------------------------------------------------------------------------
def fill_under(d: ImageDraw.ImageDraw, curve, color, bottom=MEADOW_TOP + 4) -> None:
    """Tô từ đường cong xuống tới bottom cho từng cột x."""
    for x in range(W):
        top = round(curve(x))
        if top < bottom:
            d.line((x, top, x, bottom), fill=color)


def draw_trees(d: ImageDraw.ImageDraw, curve, xs, rng: random.Random, color=TREE, light=TREE_LIGHT) -> None:
    """Cụm cây lá kim mọc dọc sườn: tam giác nhọn cao 6–11 điểm ảnh, mép trái sáng."""
    for x in xs:
        base = round(curve(x)) + rng.randint(1, 4)
        h = rng.randint(6, 11)
        for i in range(h):
            half = i * 2 // 5
            y = base - h + i
            d.line((x - half, y, x + half, y), fill=color)
            d.point((x - half, y), fill=light)


def draw_near_hill(d: ImageDraw.ImageDraw, curve, rng: random.Random) -> None:
    """Đồi gần (dùng cho cả đồi trái và đồi phải): thân xanh tươi, mép cỏ đậm, dải nắng dưới mép, chấm cỏ."""
    xs = []
    for x in range(W):
        top = round(curve(x))
        if top >= MEADOW_TOP + 4:
            continue
        xs.append(x)
        d.line((x, top, x, MEADOW_TOP + 4), fill=HILL_RIGHT)
        d.point((x, top), fill=HILL_RIGHT_EDGE)
        d.line((x, top + 1, x, top + 2), fill=HILL_RIGHT_LIT)
    for _ in range(60):
        x = rng.choice(xs)
        y = round(curve(x)) + 4 + rng.randrange(40)
        if y < MEADOW_TOP:
            d.point((x, y), fill=HILL_RIGHT_EDGE)


def draw_meadow(d: ImageDraw.ImageDraw, rng: random.Random) -> None:
    """Đồng cỏ phía trước: mép trên gợn sóng, vệt cỏ sáng nằm ngang, nét cỏ đậm, vài mảng bóng tối."""
    for x in range(W):
        top = MEADOW_TOP + round(2 * math.sin(x / 23))
        d.line((x, top, x, H), fill=MEADOW)
        d.point((x, top), fill=MEADOW_LIGHT)
    for _ in range(14):  # mảng bóng tối dẹt
        x, y = rng.randrange(W), rng.randrange(MEADOW_TOP + 10, H)
        w = rng.randint(10, 26)
        d.ellipse((x, y, x + w, y + w // 5 + 1), fill=MEADOW_SHADOW)
    for _ in range(90):  # vệt sáng ngang
        x, y = rng.randrange(W), rng.randrange(MEADOW_TOP + 3, H)
        d.line((x, y, x + rng.randint(3, 9), y), fill=MEADOW_LIGHT)
    for _ in range(260):  # nét cỏ đậm chéo
        x, y = rng.randrange(W), rng.randrange(MEADOW_TOP + 3, H)
        d.line((x, y, x + 1, y - 1), fill=MEADOW_DARK)


def make_landscape() -> Image.Image:
    """Ghép từ xa tới gần trên nền trong suốt: dãy núi xa, đồi xa, núi giữa + quán (phủ sương),
    đồi trái (trâu, cỏ cao), đồi phải (nhân viên đánh quái), đồng cỏ."""
    rng = random.Random(7)  # Cố định seed để chạy lại ra đúng ảnh cũ.
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_mountain_range(d, rng)
    fill_under(d, haze_curve, HAZE)
    fill_under(d, mountain_curve, MOUNTAIN)
    for x in range(W):  # sườn trái núi giữa được nắng
        if x < MOUNTAIN_CENTER:
            top = round(mountain_curve(x))
            d.line((x, top, x, top + 2 + (MOUNTAIN_CENTER - x) // 20), fill=MOUNTAIN_LIT)
    draw_trees(d, mountain_curve, [x + SIDE for x in (100, 108, 116, 206, 214, 222)], rng, TREE_FAR, MOUNTAIN_LIT)
    rw, rh = RESTAURANT_SIZE
    rx, ry = MOUNTAIN_CENTER - rw // 2, PLATEAU_Y - rh + 1
    img.alpha_composite(hazed(make_restaurant(with_lanterns=False), HAZE_AMOUNT), (rx, ry))
    for x, y in LANTERN_SPOTS:  # đèn lồng vẽ sau lớp sương nên vẫn sáng rõ dù quán ở xa
        draw_lantern_glow(img, rx + x, ry + y)
    draw_near_hill(d, left_hill_curve, rng)
    draw_trees(d, left_hill_curve, [x + SIDE for x in (-44, -36, 118, 126)], rng)
    draw_grass_tufts(d, rng)
    draw_near_hill(d, right_hill_curve, rng)
    draw_trees(d, right_hill_curve, [x + SIDE for x in (236, 244, 350, 360)], rng)
    draw_meadow(d, rng)
    return img


# --- Đồ bếp: rổ rau + thớt -------------------------------------------------------------------------------------
# (tên ảnh trong assets/sprites/kitchen, x, y) trên khung 124x84, vẽ từ sau ra trước.
# Rổ bên trái: rau củ cắm vào rổ, chỉ ~7 điểm ảnh chân rau khuất sau miệng rổ (miệng rổ ở hàng 9 của ảnh basket_front).
# Thớt bên phải: nồi chồng ở mép sau thớt, thịt bò, cà chua bổ đôi, rau thái, thịt lát bày trên mặt thớt.
CLUTTER_SIZE = (124, 84)
CLUTTER_LAYOUT = [
    ("board_big", 52, 46),
    ("pot_empty", 88, 22),
    ("pot_spicy", 86, 2),
    ("beef_slab", 60, 58),
    ("tomato_half", 94, 60),
    ("greens_cut", 106, 70),
    ("beef_slice", 78, 72),
    ("basket_clean", 0, 52),
    ("greens_dirty", 2, 36),
    ("mushroom_dirty", 30, 37),
    ("enoki_dirty", 18, 37),
    ("basket_front", 0, 52),
]
TOMATO_SPOT = (62, 24)  # Quả cà chua cắm dao đặt ở góc sau bên trái mặt thớt (góc trái trên ảnh 32x32).
KNIFE_SIZE = (26, 7)  # Thu nhỏ dao (gốc 36x10) cho cân với quả cà chua.
KNIFE_ANGLE = 58  # Xoay dao (độ, ngược chiều kim đồng hồ) cho mũi chĩa xuống, cắm vào quả.


def make_kitchen_clutter() -> Image.Image:
    """Rổ rau củ + thớt bày đồ ăn, nồi chồng sau thớt, quả cà chua bị dao cắm (nửa dưới quả vẽ đè lên mũi dao)."""
    img = Image.new("RGBA", CLUTTER_SIZE, (0, 0, 0, 0))
    for name, x, y in CLUTTER_LAYOUT:
        img.alpha_composite(Image.open(KITCHEN_DIR + name + ".png").convert("RGBA"), (x, y))
    tomato = Image.open(KITCHEN_DIR + "tomato_dirty.png").convert("RGBA")
    tx, ty = TOMATO_SPOT
    img.alpha_composite(tomato, (tx, ty))
    knife = Image.open(KITCHEN_DIR + "knife_big.png").convert("RGBA").resize(KNIFE_SIZE, Image.NEAREST)
    knife = knife.rotate(KNIFE_ANGLE, Image.NEAREST, expand=True)
    tip = max(((x, y) for y in range(knife.height) for x in range(knife.width) if knife.getpixel((x, y))[3]),
              key=lambda p: p[1])  # điểm thấp nhất = mũi dao
    center = (tx + 16, ty + 20)  # mũi dao cắm sâu tới giữa quả
    assert center[0] - tip[0] >= 0 and center[1] - tip[1] >= 0, "cán dao không được lọt ra ngoài khung ảnh"
    img.alpha_composite(knife, (center[0] - tip[0], center[1] - tip[1]))
    front = tomato.crop((0, 18, 32, 32))  # nửa dưới quả đè lên lưỡi dao -> trông như dao ngập trong quả
    img.alpha_composite(front, (tx, ty + 18))
    return img


# --- Nút bát giác ----------------------------------------------------------------------------------
BUTTON_W, BUTTON_H = 40, 14  # cỡ gốc, phóng 4 lần khi lưu
BUTTON_SCALE = 4
CHAMFER = 4  # góc vát
BUTTON_STYLES = {
    # tên: (viền ngoài, viền trong, thân, sáng trên, tối dưới)
    "normal": ((70, 22, 26), (250, 228, 196), (204, 58, 52), (232, 98, 82), (160, 40, 40)),
    "pressed": ((70, 22, 26), (226, 196, 164), (168, 42, 40), (186, 58, 50), (130, 30, 32)),
    "disabled": ((60, 50, 50), (180, 170, 160), (130, 112, 108), (150, 132, 126), (110, 96, 92)),
}


def octagon_inside(x: int, y: int, inset: int) -> bool:
    """Điểm (x, y) có nằm trong hình bát giác vát góc CHAMFER, thụt vào inset điểm ảnh không."""
    if x < inset or y < inset or x >= BUTTON_W - inset or y >= BUTTON_H - inset:
        return False
    dx = min(x - inset, BUTTON_W - 1 - inset - x)
    dy = min(y - inset, BUTTON_H - 1 - inset - y)
    return dx + dy >= CHAMFER - inset // 2


def make_button(style: str) -> Image.Image:
    """Nút bát giác: viền ngoài tối, viền trong kem, thân đỏ với 2 hàng sáng trên / tối dưới."""
    outline, border, body, light, dark = BUTTON_STYLES[style]
    img = Image.new("RGBA", (BUTTON_W, BUTTON_H), (0, 0, 0, 0))
    for y in range(BUTTON_H):
        for x in range(BUTTON_W):
            if not octagon_inside(x, y, 0):
                continue
            if not octagon_inside(x, y, 1):
                color = outline
            elif not octagon_inside(x, y, 2):
                color = border
            elif y <= 3:
                color = light
            elif y >= BUTTON_H - 4:
                color = dark
            else:
                color = body
            img.putpixel((x, y), color + (255,))
    return img.resize((BUTTON_W * BUTTON_SCALE, BUTTON_H * BUTTON_SCALE), Image.NEAREST)


if __name__ == "__main__":
    restaurant = make_restaurant()
    landscape = make_landscape()
    assert landscape.getpixel((W // 2, 0))[3] == 0, "phía trời của phong cảnh phải trong suốt"
    assert right_hill_curve(300 + SIDE) > PLATEAU_Y, "quán phải nằm trên đồi cao nhất"
    assert hazed(restaurant, 0.0).tobytes() == restaurant.tobytes(), "pha sương 0% phải giữ nguyên ảnh"
    restaurant.save(SCENERY_DIR + "restaurant_grand.png")
    landscape.save(SCENERY_DIR + "landscape.png")
    make_kitchen_clutter().save(SCENERY_DIR + "kitchen_clutter.png")
    make_sky().save(SCENERY_DIR + "sky.png")
    make_sun().save(SCENERY_DIR + "sun.png")
    make_sun_glow().save(SCENERY_DIR + "sun_glow.png")
    make_cloud(48, 4, 1).save(SCENERY_DIR + "cloud_big.png")
    make_cloud(30, 3, 2).save(SCENERY_DIR + "cloud_small.png")
    for name in BUTTON_STYLES:
        button = make_button(name)
        assert button.getpixel((0, 0))[3] == 0, "góc nút phải trong suốt (vát góc)"
        button.save(UI_DIR + "button_red_%s.png" % name)
    print("Đã ghi ảnh vào", SCENERY_DIR, "và", UI_DIR)
