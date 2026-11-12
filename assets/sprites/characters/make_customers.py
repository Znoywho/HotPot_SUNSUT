#!/usr/bin/env python3
"""Vẽ nhân vật khách nhà hàng (pixel 32x32, cùng khung đầu-thân-chân, viền và bóng với nhân viên bếp)
kèm sheet chạy bộ <tên>_anim.png (1 hàng "run" 4 khung 56x56, khớp SpriteFrameLayer).

Chạy từ thư mục gốc project: python assets/sprites/characters/make_customers.py
Kết quả: assets/sprites/characters/customer_1..6.png (khách thường), customer_critic.png, customer_michelin.png
"""
from PIL import Image

OUT = "assets/sprites/characters/"
S = 32
FRAME = 56
PAD = (FRAME - S) // 2
OUTLINE = (36, 26, 26, 255)
SHADOW = (0, 0, 0, 71)
WHITE = (255, 255, 255, 255)
PUPIL = (26, 16, 16, 255)

SKINS = [
    ((224, 172, 126), (191, 138, 94), (141, 78, 58)),
    ((241, 194, 155), (214, 158, 118), (168, 84, 70)),
    ((198, 134, 90), (160, 102, 64), (110, 56, 40)),
]


def rgba(c):
    return tuple(c) + (255,) if len(c) == 3 else c


def shade(c, k=0.75):
    return tuple(int(v * k) for v in c[:3])


class Sprite:
    def __init__(self):
        self.img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    def px(self, x, y, c):
        if 0 <= x < S and 0 <= y < S:
            self.img.putpixel((x, y), rgba(c))

    def hline(self, x0, x1, y, c):
        for x in range(x0, x1 + 1):
            self.px(x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            self.hline(x0, x1, y, c)

    def outline_pass(self):
        """Thêm viền 1 điểm ảnh quanh mọi điểm đặc chưa có viền (giống nhân viên)."""
        src = self.img.copy()
        for y in range(S):
            for x in range(S):
                if src.getpixel((x, y))[3] != 0:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < S and 0 <= ny < S:
                        p = src.getpixel((nx, ny))
                        if p[3] == 255 and p != OUTLINE:
                            self.img.putpixel((x, y), OUTLINE)
                            break


# Khung đầu (giống staff_tung): (hàng, x trái, x phải) phần trong viền.
SKULL = [(4, 11, 16), (5, 9, 18), (6, 8, 19)] + [(r, 8, 19) for r in range(7, 12)]
FACE = [(r, 9, 19) for r in range(12, 19)]


def draw_body(sp, shirt, pants, skin, collar=None, buttons=None):
    main, light = shirt, tuple(min(255, int(v * 1.12)) for v in shirt)
    dark = shade(shirt, 0.72)
    sp.rect(8, 19, 20, 26, main)
    sp.rect(8, 19, 9, 26, light)  # Vai trái sáng.
    sp.rect(18, 19, 20, 26, dark)  # Tay phải tối.
    sp.hline(8, 20, 26, dark)
    if collar:
        sp.rect(13, 19, 15, 20, collar)
        sp.px(14, 21, collar)
    if buttons:
        for y in (21, 23, 25):
            sp.px(14, y, buttons)
    # Bàn tay buông hai bên.
    sp.rect(7, 24, 7, 25, skin[0])
    sp.rect(21, 24, 21, 25, skin[1])
    # Chân.
    sp.rect(10, 27, 12, 28, pants)
    sp.rect(16, 27, 18, 28, pants)


def draw_head(sp, skin, eye_dir=1):
    base, mid, mouth = skin
    for r, a, b in SKULL:
        sp.hline(a, b, r, base)
    for r, a, b in FACE:
        sp.hline(a, b, r, base)
    sp.px(8, 14, mid)  # Tai.
    sp.px(8, 15, mid)
    sp.hline(9, 19, 17, mid)
    sp.hline(9, 19, 18, mid)
    sp.hline(15, 17, 17, mouth)
    # Mắt nhìn sang phải giống nhân viên.
    for ex in (13, 17):
        sp.rect(ex, 14, ex, 15, WHITE)
        sp.rect(ex + 1, 14, ex + 1, 15, PUPIL)


def fill_hair(sp, color, rows, left_only_from=None):
    """Tô tóc trong khung đầu ở các hàng `rows`."""
    for r, a, b in SKULL + FACE:
        if r in rows:
            sp.hline(a, b, r, color)


# --- Kiểu tóc / mũ -----------------------------------------------------------------

def hair_short(sp, c):
    fill_hair(sp, c, range(4, 11))
    hl = tuple(min(255, int(v * 1.35)) for v in c)
    sp.hline(11, 14, 5, hl)
    sp.hline(16, 19, 10, sp.img.getpixel((10, 12))[:3])  # mái ngắn lộ trán
    sp.rect(8, 11, 10, 13, c)  # tóc mai phía sau
    sp.rect(15, 10, 19, 10, c)


def hair_long(sp, c):
    hair_short(sp, c)
    dark = shade(c, 0.8)
    sp.rect(5, 9, 7, 22, c)  # tóc dài xõa sau lưng
    sp.rect(5, 18, 7, 22, dark)
    sp.rect(8, 12, 9, 18, c)


def hair_buns(sp, c):
    hair_short(sp, c)
    for cx in (9, 18):
        sp.rect(cx - 2, 1, cx + 1, 4, c)
    sp.hline(9, 18, 4, c)


def hair_bob(sp, c):
    hair_short(sp, c)
    sp.rect(7, 9, 9, 17, c)
    sp.rect(19, 10, 20, 13, c)
    sp.hline(12, 19, 10, c)


def hair_spiky(sp, c):
    hair_short(sp, c)
    for x in (9, 12, 15, 18):
        sp.px(x, 2, c)
        sp.rect(x - 1, 3, x + 1, 3, c)


def hair_old(sp, c):
    fill_hair(sp, (224, 172, 126), [])
    sp.rect(8, 8, 10, 13, c)  # hói đỉnh, tóc bạc hai bên
    sp.rect(18, 8, 19, 11, c)
    sp.hline(12, 19, 12, c)  # lông mày bạc


def glasses(sp):
    for x0 in (12, 16):
        sp.hline(x0, x0 + 3, 13, OUTLINE)
        sp.px(x0, 14, OUTLINE)
        sp.px(x0, 15, OUTLINE)
    sp.hline(15, 16, 14, OUTLINE)


def beret(sp, c):
    hair_short(sp, (40, 30, 30))
    sp.rect(7, 3, 19, 6, c)
    sp.rect(9, 2, 17, 2, c)
    sp.px(13, 1, c)
    sp.hline(7, 19, 6, shade(c, 0.7))


def fedora(sp, c):
    hair_short(sp, (90, 90, 96))
    sp.rect(9, 2, 18, 7, c)
    sp.hline(9, 18, 6, (120, 30, 30))  # dải mũ
    sp.hline(5, 22, 8, c)
    sp.hline(6, 21, 9, shade(c, 0.7))


CUSTOMERS = {
    "customer_1": dict(skin=0, hair=(hair_short, (40, 32, 30)), shirt=(66, 133, 214), pants=(52, 58, 82), collar=None),
    "customer_2": dict(skin=1, hair=(hair_long, (110, 62, 38)), shirt=(236, 120, 150), pants=(110, 60, 80), collar=(250, 236, 220)),
    "customer_3": dict(skin=0, hair=(hair_old, (220, 220, 226)), shirt=(150, 98, 62), pants=(70, 60, 54), collar=(240, 240, 240), extra=glasses, buttons=(240, 210, 120)),
    "customer_4": dict(skin=1, hair=(hair_buns, (34, 28, 28)), shirt=(246, 196, 64), pants=(70, 100, 160), collar=None),
    "customer_5": dict(skin=2, hair=(hair_spiky, (214, 110, 40)), shirt=(92, 170, 96), pants=(60, 60, 70), collar=None),
    "customer_6": dict(skin=0, hair=(hair_bob, (122, 70, 140)), shirt=(200, 64, 56), pants=(40, 40, 48), collar=(250, 236, 220)),
    "customer_critic": dict(skin=1, hair=(beret, (126, 60, 160)), shirt=(44, 40, 52), pants=(30, 30, 36), collar=(44, 40, 52), extra=glasses, back_hair=(40, 30, 30)),
    "customer_michelin": dict(skin=0, hair=(fedora, (70, 70, 80)), shirt=(70, 70, 80), pants=(40, 40, 46), collar=(245, 245, 245), buttons=(230, 190, 80), back_hair=(90, 90, 96)),
}


def make(spec):
    sp = Sprite()
    skin = SKINS[spec["skin"]]
    draw_body(sp, spec["shirt"], spec["pants"], skin, spec.get("collar"), spec.get("buttons"))
    draw_head(sp, skin)
    style, color = spec["hair"]
    style(sp, color)
    if spec.get("extra"):
        spec["extra"](sp)
    sp.outline_pass()
    # Bóng dưới chân (giống nhân viên).
    for x in range(7, 25):
        if sp.img.getpixel((x, 29))[3] == 0:
            sp.px(x, 29, SHADOW)
        sp.px(x, 30, SHADOW)
    for x in range(13, 19):
        sp.px(x, 31, SHADOW)
    return sp.img


def make_back(spec):
    """Hình sau lưng (khách ngồi phía trước bàn, quay lưng về người chơi): không mặt, tóc/mũ phủ sau đầu."""
    sp = Sprite()
    skin = SKINS[spec["skin"]]
    draw_body(sp, spec["shirt"], spec["pants"], skin)
    for r, a, b in SKULL + FACE:
        sp.hline(a, b, r, skin[0])
    sp.hline(9, 19, 17, skin[1])
    sp.hline(9, 19, 18, skin[1])
    style, color = spec["hair"]
    style(sp, color)
    back = spec.get("back_hair", color)
    if style is hair_old:
        # Hói đỉnh, vòng tóc bạc phía sau.
        sp.rect(8, 11, 19, 15, back)
    else:
        sp.rect(9, 9, 19, 16, back)
        sp.rect(8, 11, 8, 15, back)
        sp.hline(10, 18, 8, back)
    sp.px(8, 14, skin[1])  # tai
    sp.px(19, 14, skin[1])
    if style is hair_long:
        sp.rect(9, 16, 19, 23, back)
    sp.outline_pass()
    for x in range(7, 25):
        if sp.img.getpixel((x, 29))[3] == 0:
            sp.px(x, 29, SHADOW)
        sp.px(x, 30, SHADOW)
    for x in range(13, 19):
        sp.px(x, 31, SHADOW)
    return sp.img


def run_sheet(still):
    """4 khung chạy: chân bước so le, thân nhún nhẹ."""
    sheet = Image.new("RGBA", (FRAME * 4, FRAME), (0, 0, 0, 0))
    body = still.crop((0, 0, S, 27))
    legs_l = still.crop((9, 27, 14, 29))
    legs_r = still.crop((15, 27, 20, 29))
    shadow = still.crop((0, 29, S, S))
    for i, (bob, step) in enumerate([(0, 1), (-1, 0), (0, -1), (-1, 0)]):
        f = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        f.alpha_composite(shadow, (PAD, PAD + 29))
        f.alpha_composite(legs_l, (PAD + 9 - step, PAD + 27 + (1 if step < 0 else 0)))
        f.alpha_composite(legs_r, (PAD + 15 + step, PAD + 27 + (1 if step > 0 else 0)))
        f.alpha_composite(body, (PAD, PAD + bob))
        sheet.alpha_composite(f, (i * FRAME, 0))
    return sheet


if __name__ == "__main__":
    for name, spec in CUSTOMERS.items():
        img = make(spec)
        img.save(OUT + name + ".png")
        run_sheet(img).save(OUT + name + "_anim.png")
        make_back(spec).save(OUT + name + "_back.png")
    print("OK: %d customers" % len(CUSTOMERS))
