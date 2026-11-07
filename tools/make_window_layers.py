#!/usr/bin/env python3
"""Tách cửa sổ trong nền bếp thành 2 lớp để đổi màu theo giờ: bầu trời và cảnh (mây, đồi).

Chạy từ thư mục gốc project: python3 tools/make_window_layers.py
Kết quả: assets/sprites/kitchen/kitchen_window_sky.png, kitchen_window_land.png (cùng cỡ nền 320x180).
"""
from PIL import Image

KITCHEN_DIR = "assets/sprites/kitchen/"
WINDOW_BOXES = [(113, 13, 153, 47), (203, 13, 243, 47)]  # (trái, trên, phải, dưới) của 2 cửa sổ.
DAY_SKY = (194, 220, 220)  # Màu trời sáng nhất: lớp trời nhân với màu này ra đúng hình gốc.
SKY_COLORS = {(143, 191, 220), (166, 205, 224), (194, 220, 220)}
LAND_COLORS = {(244, 244, 238), (223, 230, 204), (134, 174, 150), (106, 150, 112), (47, 90, 60), (95, 150, 64)}


def sky_pixel(rgb):
    """Lớp trời: pixel = gốc / màu trời ngày, để khi nhân lại màu ngày thì khớp hình gốc."""
    return tuple(min(255, round(rgb[i] * 255 / DAY_SKY[i])) for i in range(3)) + (255,)


def split_window_layers():
    """Duyệt 2 khung cửa sổ, chia pixel vào lớp trời hoặc lớp cảnh theo màu."""
    background = Image.open(KITCHEN_DIR + "kitchen_bg.png").convert("RGB")
    sky = Image.new("RGBA", background.size, (0, 0, 0, 0))
    land = Image.new("RGBA", background.size, (0, 0, 0, 0))
    for left, top, right, bottom in WINDOW_BOXES:
        for y in range(top, bottom):
            for x in range(left, right):
                rgb = background.getpixel((x, y))
                if rgb in SKY_COLORS:
                    sky.putpixel((x, y), sky_pixel(rgb))
                elif rgb in LAND_COLORS:
                    land.putpixel((x, y), rgb + (255,))
    return sky, land


if __name__ == "__main__":
    sky_layer, land_layer = split_window_layers()
    sky_layer.save(KITCHEN_DIR + "kitchen_window_sky.png")
    land_layer.save(KITCHEN_DIR + "kitchen_window_land.png")
    print("Đã tạo lớp cửa sổ.")
