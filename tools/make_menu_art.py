#!/usr/bin/env python3
"""Vẽ bộ ảnh pixel phong cảnh + nút dùng chung (1 điểm ảnh = 4 px màn hình). Đang dùng ở menu chính.

Phong cảnh tách lớp để ghép và cho chuyển động trong Godot (assets/sprites/scenery/):
- sky.png               trời 432x180 (dải xanh ngả tím)
- sun.png, sun_glow.png mặt trời + quầng sáng
- cloud_big.png, cloud_small.png  mây trôi
- landscape.png         432x180 (giữa 320 là phần màn 16:9 thấy), phía trời trong suốt: núi giữa có quán lẩu lớn trên đỉnh (xa, phủ sương),
                        dãy núi xa bo tròn, đồi trái (trâu gặm cỏ), đồi phải (chỗ nhân viên đánh quái), đồng cỏ
- restaurant_grand.png  quán lẩu lớn nhiều tầng mái (bản rõ nét, không sương) để màn khác dùng lại
- door_leaf.png         một cánh cửa quán (đã phủ sương cho khớp), Godot đặt 2 cánh đè lên ô cửa sáng và mở ra khi vào game
- cat_dance_orange/black/grey.png  3 mèo đứng 2 chân nhảy (dải 8 khung 24x28), góc trái menu
- buffalo_dance.png     trâu Thần Tài (áo đỏ viền vàng, mũ cánh chuồn, cầm thỏi vàng) nhảy cùng điệu,
                        đứng sau 3 mèo (dải 8 khung 50x54)
- shadow_cat.png, shadow_buffalo.png  bóng dưới chân đội nhảy (cùng kiểu bóng chung của nhân vật)
                        (đặt quanh bếp lò nồi lẩu góc trái menu)
- kitchen_clutter.png   (không còn dùng ở menu) rổ rau củ + thớt bày thịt, cà chua cắm dao, nồi chồng phía sau,
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
CLOUD_LIGHT = (252, 248, 255)  # Mép trên mây được nắng.
CLOUD_DEEP = (170, 160, 206)  # Đáy mây đậm nhất.
SUN = (255, 244, 196)
SUN_EDGE = (255, 218, 120)
SUN_GLOW = (255, 236, 190)
HAZE = (104, 146, 116)  # Dãy đồi xa phủ cây (xanh ngả sương).
# Dãy núi xa: 2 lớp đỉnh cao, nhọn, mảnh cho hùng vĩ, cùng tông xanh với đồi phía trước
# (lớp xa hơn nhạt hơn vì sương). Chừa khoảng trời quanh mặt trời (x ~ 320–390) để không che.
# Mỗi đỉnh (x, y, dốc): dốc càng lớn thì núi càng mảnh. Xếp gần đối xứng quanh quán (x = 216):
# 2 đỉnh cao nhất kẹp hai bên tên game, thấp dần ra ngoài; phía phải hạ thấp chỗ mặt trời.
RANGE_LAYERS = [
    {  # lớp xa, cao nhất
        "peaks": [(18, 16, 2.6), (60, 28, 2.6), (98, 14, 2.8), (142, 4, 3.0), (180, 22, 2.6),
                  (252, 22, 2.6), (290, 4, 3.0), (334, 48, 2.8), (372, 44, 2.8), (414, 16, 2.6)],
        "lit": (134, 170, 140), "shade": (112, 150, 128), "mid": (122, 160, 134), "ridge": (100, 138, 118),
        "cap": (176, 200, 172),
    },
    {  # lớp gần, thấp hơn, xanh đậm hơn
        "peaks": [(30, 46, 2.4), (74, 40, 2.4), (118, 34, 2.4), (164, 46, 2.4),
                  (268, 46, 2.4), (314, 34, 2.4), (358, 50, 2.4), (402, 42, 2.4)],
        "lit": (110, 154, 112), "shade": (90, 132, 100), "mid": (100, 144, 106), "ridge": (80, 120, 92),
        "cap": (140, 178, 132),
    },
]
RANGE_ROUND = 2.5  # Bo đỉnh rất ít để đỉnh nhọn (điểm ảnh).
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
DOOR_LIGHT = (255, 238, 176)  # Ánh sáng trong quán sau cánh cửa (không phủ sương, lộ ra khi cửa mở).
DOOR_BOX = (37, 27, 46, 35)  # Ô cửa trong ảnh quán (x0, y0, x1, y1), mỗi cánh rộng 5 điểm ảnh.
# Trên phong cảnh, cánh trái ở (211, 54), cánh phải ở (216, 54): khớp DOOR_LEFT_LEAF trong main_menu.gd.

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


def range_curve(peaks, x: float) -> float:
    """Đường đỉnh một lớp núi: y = min theo từng đỉnh của peak_y(x) + gợn 0.8 * sin(x / 2.3)."""
    return min(peak_y(p, x) for p in peaks) + 0.8 * math.sin(x / 2.3)


def peak_y(peak: tuple, x: float) -> float:
    """Một đỉnh: y = đỉnh_y + dốc * (sqrt((x - đỉnh_x)^2 + R^2) - R); gần đỉnh hơi bo, xa ra thành sườn thẳng dốc."""
    px, py, slope = peak
    return py + slope * (math.hypot(x - px, RANGE_ROUND) - RANGE_ROUND)


def nearest_peak(peaks, x: float) -> tuple:
    """Đỉnh tạo nên đường núi tại cột x (đỉnh cho y nhỏ nhất) - để biết x nằm sườn trái hay sườn phải."""
    return min(peaks, key=lambda p: peak_y(p, x))


def draw_mountain_range(d: ImageDraw.ImageDraw, rng: random.Random) -> None:
    """Hai lớp núi xa (xa trước, gần sau): sườn trái sáng, sườn phải tối, đỉnh sáng nhạt,
    khe núi chéo xuống từ đỉnh, chấm lưới thưa cho sườn đỡ phẳng."""
    for layer in RANGE_LAYERS:
        peaks = layer["peaks"]
        for x in range(W):
            top = round(range_curve(peaks, x))
            px, py, _ = nearest_peak(peaks, x)
            d.line((x, top, x, MEADOW_TOP), fill=layer["lit"] if x < px else layer["shade"])
            if top - py < 7:  # chóp núi sáng nhạt
                d.line((x, top, x, top + 1), fill=layer["cap"])
            for y in range(top + 5, MEADOW_TOP, 3):
                if x % 3 == (y // 3) % 3:
                    d.point((x, y), fill=layer["mid"])
        for px, py, slope in peaks:  # khe núi: vệt chéo từ gần đỉnh đi xuống theo sườn
            for side in (-1, 1):
                x, y = px + side * 1.5, py + 3
                for _ in range(rng.randint(14, 24)):
                    d.point((round(x), y), fill=layer["ridge"])
                    x += side * rng.uniform(0.2, 0.5)
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


# Cụm mây (tâm x theo tỉ lệ bề ngang, bán kính theo tỉ lệ chiều cao), vẽ từ sau ra trước:
# cụm giữa to nhất nhô cao, hai bên thấp dần, hai cụm nhỏ sát đáy cho chân mây tròn.
CLOUD_PUFFS = [(0.17, 0.27), (0.40, 0.49), (0.66, 0.40), (0.85, 0.25), (0.28, 0.24), (0.55, 0.26), (0.76, 0.22)]


def make_cloud(width: int, seed: int) -> Image.Image:
    """Mây tích phồng: các cụm tròn chồng nhau, đáy phẳng. Mép trên mỗi cụm sáng nắng,
    rãnh giữa hai cụm có vệt bóng, nửa dưới chuyển dần sang bóng tím (ô cờ), đáy đậm."""
    rng = random.Random(seed)
    height = round(width * 0.5)
    base = height - 1
    owner = [[-1] * width for _ in range(height)]  # cụm nào vẽ sau cùng phủ điểm này
    centers = []
    for i, (fx, fr) in enumerate(CLOUD_PUFFS):
        r = fr * height + rng.uniform(-0.6, 0.6)
        cx = fx * width + rng.uniform(-0.8, 0.8)
        cy = base - r * (0.95 if i < 4 else 0.35)  # 4 cụm đầu nhô cao, mấy cụm sau làm chân mây
        centers.append((cx, cy, r))
        for y in range(height):
            for x in range(width):
                if y <= base and math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= r:
                    owner[y][x] = i
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    px = img.load()
    for y in range(height):
        for x in range(width):
            i = owner[y][x]
            if i < 0:
                continue
            cx, cy, r = centers[i]
            up = y == 0 or owner[y - 1][x] < 0
            dy = (y + 0.5 - cy) / r  # -1 đỉnh cụm, +1 đáy cụm
            dx = (x + 0.5 - cx) / r
            seam = y > 0 and owner[y - 1][x] >= 0 and owner[y - 1][x] != i  # cụm trước nằm trên: rãnh bóng
            if up or (dy < -0.6 and dx < -0.1):
                c = CLOUD_LIGHT
            elif y >= base:
                c = CLOUD_DEEP
            elif seam or (dx > 0.5 and dy > 0.0):
                c = CLOUD_SHADE
            elif y >= base - 2 or (y >= base - 4 and (x + y) % 2 == 0):
                c = CLOUD_SHADE
            else:
                c = CLOUD
            px[x, y] = c + (255,)
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


def make_door_leaf() -> Image.Image:
    """Một cánh cửa gỗ 5x9: khung tối, ô vuông chìm, núm cửa vàng ở mép trong (mép phải). Cánh phải = lật ngang."""
    w = (DOOR_BOX[2] - DOOR_BOX[0] + 1) // 2
    h = DOOR_BOX[3] - DOOR_BOX[1] + 1
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w - 1, h - 1), fill=WOOD, outline=WOOD_DARK)
    d.rectangle((1, 2, w - 2, 4), outline=WOOD_DARK)
    d.point((w - 2, h // 2 + 1), fill=GOLD)
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
    """Đồng cỏ phía trước: mép trên gợn sóng, vệt cỏ sáng nằm ngang, nét cỏ đậm."""
    for x in range(W):
        top = MEADOW_TOP + round(2 * math.sin(x / 23))
        d.line((x, top, x, H), fill=MEADOW)
        d.point((x, top), fill=MEADOW_LIGHT)
    for _ in range(14):  # (bỏ mảng bóng tối dẹt: trông như vết bẩn) - vẫn rút số ngẫu nhiên để cỏ còn lại giữ nguyên
        rng.randrange(W), rng.randrange(MEADOW_TOP + 10, H), rng.randint(10, 26)
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
    x0, y0, x1, y1 = DOOR_BOX  # ô cửa sáng rực (bị 2 cánh cửa trong Godot che tới khi mở)
    d.rectangle((rx + x0, ry + y0, rx + x1, ry + y1), fill=DOOR_LIGHT)
    draw_near_hill(d, left_hill_curve, rng)
    draw_trees(d, left_hill_curve, [x + SIDE for x in (-44, -36, 118, 126)], rng)
    draw_grass_tufts(d, rng)
    draw_near_hill(d, right_hill_curve, rng)
    draw_trees(d, right_hill_curve, [x + SIDE for x in (236, 244, 350, 360)], rng)
    draw_meadow(d, rng)
    return img


# --- Mèo nhảy góc trái menu ---------------------------------------------------------------------
# Mèo nhảy (góc trái menu): mèo đứng 2 chân, mỗi ảnh là dải 8 khung 24x28 một điệu nhảy lặp lại.
# Mỗi khung: (nhún xuống, bật lên, nghiêng, tay trái, tay phải); tay = điểm bàn tay so với vai (dx, dy).
DANCE_W, DANCE_H = 24, 28
DANCE_POSES = [
    (0, 0, 0, (-6, -6), (6, -6)),   # giơ 2 tay lên
    (2, 0, 0, (-5, 1), (5, 1)),     # nhún, dang tay
    (0, 0, -1, (-6, -6), (4, 3)),   # nghiêng trái, tay trái giơ
    (2, 0, 0, (-4, 3), (4, 3)),     # nhún
    (0, 0, 1, (-4, 3), (6, -6)),    # nghiêng phải, tay phải giơ
    (2, 0, 0, (-5, 1), (5, 1)),     # nhún, dang tay
    (0, 3, 0, (-7, -5), (7, -5)),   # bật nhảy
    (1, 0, 0, (-4, 3), (4, 3)),     # tiếp đất
]
DANCE_CATS = {
    "orange": {"O": (74, 40, 22), "B": (232, 142, 58), "L": (252, 218, 166), "S": (196, 104, 40), "E": (36, 28, 24)},
    "black": {"O": (20, 16, 24), "B": (60, 56, 70), "L": (236, 232, 240), "S": (40, 36, 48), "E": (250, 214, 80)},
    "grey": {"O": (40, 40, 52), "B": (150, 152, 168), "L": (240, 240, 246), "S": (110, 112, 130), "E": (36, 28, 24)},
}
CAT_PINK = (240, 128, 140)
CAT_EYE = (36, 28, 24)


SUN_RIM = (255, 240, 196)  # Nắng chiều ấm hắt lên mép phải / đỉnh (mặt trời ở góc trên bên phải menu).


def shade_volume(layer: Image.Image) -> None:
    """Đổ sáng tối cho khối màu (trước khi viền): mặt trời ở trên bên phải nên mép phải + đỉnh phía phải
    sáng lên pha màu nắng, 2 điểm ảnh sát mép trái tối đi như mặt khuất nắng."""
    w, h = layer.size
    src = layer.copy().load()
    px = layer.load()

    def empty(x, y):
        return not (0 <= x < w and 0 <= y < h) or src[x, y][3] == 0

    def mix(c, t, a):
        return tuple(round(ci * (1 - a) + ti * a) for ci, ti in zip(c[:3], t)) + (c[3],)

    for y in range(h):
        for x in range(w):
            c = src[x, y]
            if c[3] == 0:
                continue
            if empty(x + 1, y) or (empty(x, y - 1) and not empty(x - 1, y) and empty(x + 1, y - 1)):
                px[x, y] = mix(c, SUN_RIM, 0.38)  # mép đón nắng
            elif empty(x - 1, y):
                px[x, y] = mix(c, (0, 0, 0), 0.30)  # mép khuất nắng
            elif empty(x - 2, y):
                px[x, y] = mix(c, (0, 0, 0), 0.15)


def draw_dance_frame(img: Image.Image, ox: int, pose: tuple, pal: dict) -> None:
    """Vẽ 1 khung mèo nhảy tại cột ox: tô thân bằng màu lông rồi tự viền 1 điểm ảnh quanh hình, sau đó vẽ mặt + bụng."""
    squat, jump, lean, hand_l, hand_r = pose
    body = Image.new("RGBA", (DANCE_W, DANCE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    feet = DANCE_H - 2 - jump
    cx = DANCE_W // 2 + lean
    hip = feet - 4 + squat
    # chân (nhún thì chân ngắn lại, hai bàn chân dạng ra)
    spread = 2 + squat
    d.rectangle((cx - spread - 1, hip, cx - spread + 1, feet), fill=pal["B"])
    d.rectangle((cx + spread - 1, hip, cx + spread + 1, feet), fill=pal["B"])
    # đuôi vẫy theo hướng nghiêng
    tail = -1 if lean > 0 else 1
    d.line((cx + 3 * tail, hip - 1, cx + 6 * tail, hip - 4, cx + 6 * tail, hip - 7), fill=pal["B"], width=2)
    # thân
    top = hip - 7
    d.ellipse((cx - 4, top, cx + 4, hip + 1), fill=pal["B"])
    # tay từ vai ra bàn tay
    shoulder_y = top + 2
    for side, (hx, hy) in ((-1, hand_l), (1, hand_r)):
        sx = cx + 3 * side
        d.line((sx, shoulder_y, sx + hx, shoulder_y + hy), fill=pal["B"], width=2)
    # đầu + tai
    head_top = top - 8
    d.ellipse((cx - 5, head_top, cx + 5, top + 1), fill=pal["B"])
    d.polygon([(cx - 5, head_top + 3), (cx - 4, head_top - 2), (cx - 1, head_top + 1)], fill=pal["B"])
    d.polygon([(cx + 5, head_top + 3), (cx + 4, head_top - 2), (cx + 1, head_top + 1)], fill=pal["B"])
    shade_volume(body)
    # viền: điểm trong suốt kề điểm có màu
    src = body.load()
    out = body.copy()
    o = out.load()
    for y in range(DANCE_H):
        for x in range(DANCE_W):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < DANCE_W and 0 <= ny < DANCE_H and src[nx, ny][3]:
                    o[x, y] = pal["O"] + (255,)
                    break
    d = ImageDraw.Draw(out)
    d.ellipse((cx - 2, top + 2, cx + 2, hip), fill=pal["L"])  # bụng
    for ex in (cx - 3, cx + 3):  # mắt 1x2
        d.line((ex, head_top + 3, ex, head_top + 4), fill=pal["E"])
    d.point((cx, top - 3), fill=CAT_PINK)  # mũi
    d.point((cx - 4, head_top), fill=CAT_PINK)  # lòng tai
    d.point((cx + 4, head_top), fill=CAT_PINK)
    d.point((cx - 1, top - 2), fill=pal["O"])  # miệng chữ w
    d.point((cx + 1, top - 2), fill=pal["O"])
    img.alpha_composite(out, (ox, 0))


# Trâu Thần Tài nhảy (đứng sau 3 mèo): người tròn mập bụng phệ, áo đỏ viền vàng thắt đai vàng, má hồng cười tươi,
# mũ đỏ đai vàng có 2 cánh chuồn vàng, tay phải cầm thỏi vàng; nhảy cùng DANCE_POSES.
BUF_W, BUF_H = 50, 54
BUF_SKIN = (84, 88, 104)
BUF_SKIN_LIGHT = (120, 124, 140)
BUF_MUZZLE = (186, 176, 178)
BUF_HORN = (236, 224, 192)
BUF_HOOF = (40, 34, 38)
BUF_RED = (204, 36, 36)
BUF_RED_LIGHT = (238, 84, 72)
BUF_RED_DARK = (150, 24, 30)
BUF_GOLD = (250, 196, 60)
BUF_GOLD_LIGHT = (255, 236, 150)
BUF_CHEEK = (236, 120, 130)
BUF_OUTLINE = (30, 24, 30)


def outline_layer(layer: Image.Image, color) -> Image.Image:
    """Viền 1 điểm ảnh quanh mọi điểm có màu của layer (điểm trong suốt kề điểm có màu thành màu viền)."""
    w, h = layer.size
    src = layer.load()
    out = layer.copy()
    o = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3]:
                    o[x, y] = color + (255,)
                    break
    return out


def draw_buffalo_frame(img: Image.Image, ox: int, pose: tuple) -> None:
    """Một khung trâu Thần Tài nhảy, cùng tư thế với mèo nhưng to và tròn hơn."""
    squat, jump, lean, hand_l, hand_r = pose
    layer = Image.new("RGBA", (BUF_W, BUF_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    feet = BUF_H - 2 - round(jump * 1.4)
    cx = BUF_W // 2 + lean
    hip = feet - 4 + squat
    spread = 4 + squat
    for side in (-1, 1):  # chân ngắn mập + móng
        x = cx + spread * side
        d.rectangle((x - 2, hip, x + 2, feet), fill=BUF_SKIN)
        d.rectangle((x - 2, feet - 1, x + 2, feet), fill=BUF_HOOF)
    top = hip - 17
    d.ellipse((cx - 11, top, cx + 11, hip + 3), fill=BUF_RED)  # thân tròn bụng phệ trong áo đỏ
    shoulder_y = top + 5
    ingot = None
    for side, (hx, hy) in ((-1, hand_l), (1, hand_r)):
        sx = cx + 8 * side
        ex, ey = sx + round(hx * 1.5), shoulder_y + round(hy * 1.5)
        mx, my = (sx * 2 + ex) // 3, (shoulder_y * 2 + ey) // 3
        d.line((sx, shoulder_y, mx, my), fill=BUF_RED, width=5)  # ống tay áo rộng
        d.line((mx, my, ex, ey), fill=BUF_SKIN, width=3)
        d.rectangle((ex - 1, ey - 1, ex + 1, ey + 1), fill=BUF_HOOF)
        if side == 1:
            ingot = (ex, ey)
    head_top = top - 14
    for side in (-1, 1):  # sừng cong ra ngoài rồi vểnh lên
        hx = cx + 7 * side
        d.line((hx, head_top + 6, hx + 4 * side, head_top + 5, hx + 6 * side, head_top + 2), fill=BUF_HORN, width=2)
    d.ellipse((cx - 8, head_top, cx + 8, top + 3), fill=BUF_SKIN)  # đầu tròn
    d.ellipse((cx - 6, top - 5, cx + 6, top + 3), fill=BUF_MUZZLE)  # mõm
    d.ellipse((cx - 6, head_top - 5, cx + 6, head_top + 4), fill=BUF_RED)  # mũ tròn
    d.rectangle((cx - 7, head_top + 1, cx + 7, head_top + 3), fill=BUF_RED)
    for side in (-1, 1):  # 2 cánh chuồn
        d.rectangle((cx + 8 * side - (2 if side > 0 else 0), head_top - 1, cx + 8 * side + (0 if side > 0 else 2), head_top + 1), fill=BUF_GOLD)
        d.rectangle((cx + 11 * side - 1, head_top - 2, cx + 11 * side + 1, head_top + 2), fill=BUF_GOLD)
    if ingot:  # thỏi vàng hình thuyền trên tay phải
        ix, iy = ingot
        d.polygon([(ix - 4, iy - 4), (ix + 4, iy - 4), (ix + 3, iy - 1), (ix - 3, iy - 1)], fill=BUF_GOLD)
        d.rectangle((ix - 1, iy - 6, ix + 1, iy - 4), fill=BUF_GOLD)
    shade_volume(layer)
    out = outline_layer(layer, BUF_OUTLINE)
    d = ImageDraw.Draw(out)
    # áo: viền vàng ở gấu, vạt giữa, đai vàng ngang bụng, bóng tối bên phải
    d.arc((cx - 11, top, cx + 11, hip + 3), 20, 160, fill=BUF_GOLD)
    d.line((cx, top + 2, cx, hip + 1), fill=BUF_GOLD)
    d.rectangle((cx - 10, top + 9, cx + 10, top + 10), fill=BUF_GOLD)
    d.rectangle((cx - 2, top + 8, cx + 2, top + 11), fill=BUF_GOLD_LIGHT)  # khoá đai
    d.arc((cx - 11, top, cx + 11, hip + 3), 190, 240, fill=BUF_RED_DARK)
    d.line((cx + 5, top + 2, cx + 7, top + 3), fill=BUF_RED_LIGHT)
    # mũ: đai vàng, chấm ngọc, ánh sáng
    d.line((cx - 7, head_top + 2, cx + 7, head_top + 2), fill=BUF_GOLD)
    d.point((cx, head_top - 2), fill=BUF_GOLD_LIGHT)
    d.line((cx + 1, head_top - 4, cx + 3, head_top - 3), fill=BUF_RED_LIGHT)
    # mặt: mắt cười cong, má hồng, lỗ mũi, miệng cười
    for ex in (cx - 4, cx + 4):
        d.point((ex - 1, head_top + 7), fill=BUF_OUTLINE)
        d.point((ex, head_top + 6), fill=BUF_OUTLINE)
        d.point((ex + 1, head_top + 7), fill=BUF_OUTLINE)
    for chx in (cx - 6, cx + 5):
        d.rectangle((chx, head_top + 9, chx + 1, head_top + 9), fill=BUF_CHEEK)
    d.point((cx - 2, top - 2), fill=BUF_OUTLINE)
    d.point((cx + 2, top - 2), fill=BUF_OUTLINE)
    d.line((cx - 3, top, cx - 1, top + 1, cx + 1, top + 1, cx + 3, top), fill=(120, 80, 90))
    if ingot:
        ix, iy = ingot
        d.line((ix - 3, iy - 4, ix + 3, iy - 4), fill=BUF_GOLD_LIGHT)
    img.alpha_composite(out, (ox, 0))


def make_buffalo_dance_sheet() -> Image.Image:
    img = Image.new("RGBA", (BUF_W * len(DANCE_POSES), BUF_H), (0, 0, 0, 0))
    for i, pose in enumerate(DANCE_POSES):
        draw_buffalo_frame(img, i * BUF_W, pose)
    return img


GAME_SHADOW = (0, 0, 0, 71)  # Bóng chung của mọi nhân vật trong game (đen mờ, xem ảnh characters/, monsters/).


def make_pixel_shadow(width: int) -> Image.Image:
    """Bóng dưới chân đúng kiểu chung của game: 2 hàng rộng width, 1 hàng ngắn bằng 1/3 ở giữa phía dưới."""
    img = Image.new("RGBA", (width, 3), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, width - 1, 1), fill=GAME_SHADOW)
    short = max(2, width // 3)
    d.line(((width - short) // 2, 2, (width + short) // 2 - 1, 2), fill=GAME_SHADOW)
    return img


def make_dance_sheet(pal: dict) -> Image.Image:
    img = Image.new("RGBA", (DANCE_W * len(DANCE_POSES), DANCE_H), (0, 0, 0, 0))
    for i, pose in enumerate(DANCE_POSES):
        draw_dance_frame(img, i * DANCE_W, pose, pal)
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
    hazed(make_door_leaf(), HAZE_AMOUNT).save(SCENERY_DIR + "door_leaf.png")
    assert (MOUNTAIN_CENTER - RESTAURANT_SIZE[0] // 2 + DOOR_BOX[0], PLATEAU_Y - RESTAURANT_SIZE[1] + 1 + DOOR_BOX[1]) == (211, 54), \
        "đổi vị trí quán thì sửa cả DOOR_LEFT_LEAF trong main_menu.gd"
    landscape.save(SCENERY_DIR + "landscape.png")
    make_kitchen_clutter().save(SCENERY_DIR + "kitchen_clutter.png")
    for name, pal in DANCE_CATS.items():
        make_dance_sheet(pal).save(SCENERY_DIR + "cat_dance_%s.png" % name)
    make_buffalo_dance_sheet().save(SCENERY_DIR + "buffalo_dance.png")
    make_pixel_shadow(14).save(SCENERY_DIR + "shadow_cat.png")
    make_pixel_shadow(28).save(SCENERY_DIR + "shadow_buffalo.png")
    make_sky().save(SCENERY_DIR + "sky.png")
    make_sun().save(SCENERY_DIR + "sun.png")
    make_sun_glow().save(SCENERY_DIR + "sun_glow.png")
    make_cloud(44, 1).save(SCENERY_DIR + "cloud_big.png")
    make_cloud(28, 2).save(SCENERY_DIR + "cloud_small.png")
    for name in BUTTON_STYLES:
        button = make_button(name)
        assert button.getpixel((0, 0))[3] == 0, "góc nút phải trong suốt (vát góc)"
        button.save(UI_DIR + "button_red_%s.png" % name)
    print("Đã ghi ảnh vào", SCENERY_DIR, "và", UI_DIR)
