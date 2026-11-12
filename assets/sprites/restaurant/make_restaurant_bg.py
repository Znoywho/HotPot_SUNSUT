#!/usr/bin/env python3
"""Ghép nền nhà hàng 320x180 (pixel, 1 điểm ảnh = 4 px màn hình) từ chính bộ gạch của nền bếp,
để màn bán hàng cùng phong cách với màn bếp: tường gạch + cửa sổ trên, ốp gạch men chân tường,
nẹp chân tường tối, sàn gạch nung bên dưới (tường và sàn tách bạch rõ ràng).

Chạy từ thư mục gốc project: python assets/sprites/restaurant/make_restaurant_bg.py
Kết quả (assets/sprites/restaurant/):
- restaurant_bg.png        nền chính 320x180
- restaurant_bg_side.png   tường + sàn nối hai bên cho màn rộng hơn 16:9 (160x180)
- restaurant_pass_front.png  mép quầy ô cửa bếp, vẽ đè lên đầu bếp (320x180, trong suốt)
- restaurant_window_sky.png / restaurant_window_land.png  lớp trời / cảnh trong cửa sổ để đổi màu theo giờ
"""
from PIL import Image, ImageDraw

KIT = "assets/sprites/kitchen/"
OUT = "assets/sprites/restaurant/"
W, H = 320, 180

# --- Mốc hàng (điểm ảnh nền) -------------------------------------------------------
WALL_END = 57  # Hết tường gạch.
WAINSCOT_END = 74  # Hết ốp gạch men.
FLOOR_TOP = 79  # Sàn bắt đầu (sau nẹp chân tường 75..78).

# Cửa sổ lấy từ nền bếp: khung (112..154, 15..49), có đèn treo đè lên mép trên -> vá lại.
KITCHEN_WINDOWS = [
    {"box": (112, 15, 155, 50), "lamp": (124, 143), "ref": 120, "mullion": (133, 134)},
    {"box": (202, 15, 245, 50), "lamp": (214, 233), "ref": 210, "mullion": (223, 224)},
]
WINDOW_TOP = 22
WINDOW_X = [46, 112]

DOOR = (6, 26, 31, 79)  # trái, trên, phải, dưới (dưới = sàn)
PASS = (190, 22, 315, 57)  # Ô cửa bếp (khung ngoài).
LEDGE_TOP = 50

FRAME_DARK = (62, 36, 22)
WOOD = (122, 79, 40)
WOOD_LIGHT = (176, 122, 69)
WOOD_SHADOW = (90, 56, 32)
GOLD = (242, 193, 78)
RED = (196, 52, 43)
RED_DARK = (140, 32, 28)
CREAM = (241, 227, 196)


def side_row_map():
    """Hàng đích -> hàng nguồn trong kitchen_bg_side: tường cao hơn, ốp men thấp hơn, sàn dài hơn."""
    rows = []
    rows += list(range(0, 53))  # Dầm trần + 44 hàng gạch.
    rows += list(range(13, 18))  # Thêm 1 hàng gạch (cùng lệch với hàng trên).
    rows += list(range(53, 63))  # Nẹp trên + viền lấm tấm của ốp men.
    rows += list(range(77, 84))  # Một hàng gạch men.
    rows += list(range(90, 94))  # Nẹp chân tường.
    src = 94
    while len(rows) < H:
        rows.append(src if src < 180 else src - 24)  # Sàn lặp mỗi 24 hàng.
        src += 1
    return rows


def compose_base(width):
    side = Image.open(KIT + "kitchen_bg_side.png").convert("RGBA")
    rows = side_row_map()
    img = Image.new("RGBA", (width, H))
    for x0 in range(0, width, side.width):
        for y, sy in enumerate(rows):
            img.paste(side.crop((0, sy, side.width, sy + 1)), (x0, y))
    return img


def patch_lamp(src, win):
    """Che đèn treo trong ảnh cửa sổ bếp: chép cột tham chiếu (không có đèn) sang các cột bị đèn che."""
    left, top, _, _ = win["box"]
    a, b = win["lamp"]
    ref = win["ref"]
    for x in range(a, b + 1):
        for y in range(top, top + 6):
            if win["mullion"][0] <= x <= win["mullion"][1] and y >= top + 3:
                src.putpixel((x - left, y - top), src.getpixel((win["mullion"][0] - left, top + 8)))
            else:
                src.putpixel((x - left, y - top), src.getpixel((ref - left, y - top)))


def window_piece(path, win):
    img = Image.open(path).convert("RGBA").crop(win["box"])
    patch_lamp(img, win)
    return img


def draw_door(d):
    l, t, r, b = DOOR
    d.rectangle((l - 1, t - 1, r + 1, b - 1), fill=FRAME_DARK)
    d.rectangle((l + 1, t + 1, r - 1, b - 1), fill=WOOD)
    # Ô kính trên cánh cửa + 2 ô ván dưới.
    d.rectangle((l + 4, t + 4, r - 4, t + 16), fill=FRAME_DARK)
    d.rectangle((l + 5, t + 5, r - 5, t + 15), fill=(166, 205, 224))
    d.line((l + 5, t + 5, l + 9, t + 5), fill=(220, 236, 240))
    d.rectangle((l + 4, t + 20, r - 4, t + 33), outline=WOOD_LIGHT)
    d.rectangle((l + 4, t + 37, r - 4, b - 4), outline=WOOD_LIGHT)
    d.rectangle((r - 6, t + 26, r - 4, t + 28), fill=GOLD)
    d.line((l, t, r, t), fill=WOOD_LIGHT)
    # Bảng treo trước cửa (màu đỏ, không chữ).
    d.rectangle((l + 6, t + 18, r - 6, t + 19), fill=RED)


def draw_pass(img, d):
    l, t, r, b = PASS
    # Bên trong: bếp phía sau, tối hơn (gạch men bếp tối đi).
    side = Image.open(KIT + "kitchen_bg_side.png").convert("RGBA")
    inner = Image.new("RGBA", (r - l - 5, b - t - 5))
    for y in range(inner.height):
        sy = 57 + (y % 33)
        for x in range(inner.width):
            c = side.getpixel((x % side.width, sy))
            inner.putpixel((x, y), (int(c[0] * 0.45), int(c[1] * 0.42), int(c[2] * 0.4), 255))
    img.paste(inner, (l + 3, t + 3))
    d.rectangle((l, t, r, b), outline=FRAME_DARK)
    d.rectangle((l + 1, t + 1, r - 1, b - 1), outline=WOOD)
    d.rectangle((l + 2, t + 2, r - 2, b - 2), outline=WOOD)
    # Mái che sọc đỏ - kem, mép dưới lượn sóng.
    for x in range(l - 3, r + 4):
        stripe = RED if ((x - l) // 6) % 2 == 0 else CREAM
        for y in range(t - 4, t + 4):
            img.putpixel((x, y), stripe + (255,))
        if (x - l) % 6 in (1, 2, 3, 4):
            img.putpixel((x, t + 4), stripe + (255,))
    d.line((l - 3, t - 5, r + 3, t - 5), fill=FRAME_DARK)


def draw_pass_front():
    """Mép quầy ô cửa bếp: nằm trên đầu bếp (che chân), dưới các nồi lẩu bày trên quầy."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    l, _, r, b = PASS
    d.rectangle((l - 4, LEDGE_TOP, r + 4, LEDGE_TOP + 2), fill=WOOD_LIGHT)
    d.rectangle((l - 4, LEDGE_TOP + 3, r + 4, b + 1), fill=WOOD)
    d.line((l - 4, b + 2, r + 4, b + 2), fill=WOOD_SHADOW)
    d.line((l - 4, LEDGE_TOP, r + 4, LEDGE_TOP), fill=(214, 160, 100))
    for x in range(l, r, 16):
        d.line((x, LEDGE_TOP + 4, x, b), fill=WOOD_SHADOW)
    return img


def build():
    bg = compose_base(W)
    d = ImageDraw.Draw(bg)
    sky = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    land = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for win, x in zip(KITCHEN_WINDOWS, WINDOW_X):
        piece = window_piece(KIT + "kitchen_bg.png", win)
        bg.alpha_composite(piece, (x, WINDOW_TOP))
        sky.alpha_composite(window_piece(KIT + "kitchen_window_sky.png", win), (x, WINDOW_TOP))
        land.alpha_composite(window_piece(KIT + "kitchen_window_land.png", win), (x, WINDOW_TOP))
    draw_door(d)
    draw_pass(bg, d)
    # Đèn (bóng trần / đèn lồng) đổi theo cấp Nội thất nên vẽ bằng code (scenes/sell/room_decor.gd), không vẽ vào nền.
    bg.save(OUT + "restaurant_bg.png")
    compose_base(160).save(OUT + "restaurant_bg_side.png")
    draw_pass_front().save(OUT + "restaurant_pass_front.png")
    sky.save(OUT + "restaurant_window_sky.png")
    land.save(OUT + "restaurant_window_land.png")
    print("OK: restaurant_bg*.png")


if __name__ == "__main__":
    build()
