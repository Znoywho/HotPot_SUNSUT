"""Hiệu ứng chiến đấu pixel tự vẽ (sheet xếp khung theo hàng ngang, đọc bởi scenes/hunt/ui/hunt_fx.gd).

Chạy:  py assets/sprites/fx/make_combat_fx.py [--preview]

- impact_star (32x32, 5 khung): tia chạm lúc đòn trúng: lõi trắng nổ ra, tia vàng tách khỏi tâm rồi tắt.
- slash_arc   (48x48, 5 khung): vệt smear lưỡi dao (kiểu smear frame): cung trăng lưỡi liềm dày giữa, nhọn 2 đầu.
- bonk_star   (16x16, 4 khung): ngôi sao lấp lánh xoay quanh đầu khi bị muôi "bonk".
- shockwave   (64x64, 6 khung): vòng xung kích nở ra khi chí mạng / boss gục.
- dust        (24x16, 5 khung): bụi tung dưới chân lúc bật người lao tới.
- broth_blob  (12x12, 2 khung): giọt nước lẩu bay (chiêu Hất lẩu).

Quy tắc (skill pixel-art-studio): không khử răng cưa, 4-6 khung mỗi hiệu ứng, vật thể có viền tối hơn màu tối nhất,
hiệu ứng ánh sáng (tia, vệt chém, vòng) không viền. Tự vẽ bằng code, không dùng file của ai (repo công khai).
--preview ghi _tmp_test/combat_fx_preview.png (thư mục đã gitignore) để xem trước.
"""
import math
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def rgb(h, a=255):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


WHITE = rgb("#ffffff")
PALE = rgb("#fff4b0")
YELLOW = rgb("#ffd23a")
ORANGE = rgb("#ff8a2a")
EMBER = rgb("#e0582a")


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def outline(img, color):
    """Viền 8 hướng quanh mọi điểm có màu (cho vật thể: sao, bụi, giọt lẩu)."""
    src = img.copy()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src.getpixel((x, y))[3] != 0:
                continue
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src.getpixel((nx, ny))[3] != 0:
                        img.putpixel((x, y), color)
                        break
                else:
                    continue
                break


def sheet(frames):
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


# --- impact_star ------------------------------------------------------------------------------------
def impact_star():
    frames = []
    core = [2, 3, 2, 1, 0]
    reach = [5, 10, 13, 14, 15]  # đầu tia
    start = [0, 2, 5, 9, 12]  # chân tia tách dần khỏi tâm
    for f in range(5):
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        c = 16
        if core[f] > 0:  # lõi hình thoi trắng đặc, tâm ở giữa 4 ô (15..16)
            for y in range(32):
                for x in range(32):
                    if abs(x + 0.5 - c) + abs(y + 0.5 - c) <= core[f] + 0.5:
                        put(img, x, y, WHITE)
        hot = WHITE if f < 2 else PALE
        cold = YELLOW if f < 3 else ORANGE
        for d in range(start[f], reach[f]):
            col = hot if d < (start[f] + reach[f]) / 2 else cold
            if f == 4 and d < reach[f] - 2:
                continue  # khung cuối: chỉ còn đốm đầu tia
            for w in (-1, 0):  # tia chính dày 2 px
                put(img, c + d, c + w, col)
                put(img, c - 1 - d, c + w, col)
                put(img, c + w, c + d, col)
                put(img, c + w, c - 1 - d, col)
            k = int(d * 0.7)  # tia chéo mảnh 1 px, ngắn hơn
            if d % 2 == 0 and k >= start[f] * 0.7:
                put(img, c + k, c + k, col)
                put(img, c - 1 - k, c + k, col)
                put(img, c + k, c - 1 - k, col)
                put(img, c - 1 - k, c - 1 - k, col)
        frames.append(img)
    return sheet(frames)


# --- slash_arc --------------------------------------------------------------------------------------
def slash_arc():
    frames = []
    spans = [(200, 250), (165, 320), (140, 375), (150, 380), (165, 385)]
    thick = [2.0, 4.0, 5.0, 3.2, 2.2]
    core_c = [WHITE, WHITE, WHITE, rgb("#dffbff"), rgb("#bff6ff")]
    mid_c = [rgb("#bff6ff"), rgb("#bff6ff"), rgb("#9fefff"), rgb("#8fe0ff"), rgb("#6ac8f0")]
    edge_c = [rgb("#5ad0ff"), rgb("#5ad0ff"), rgb("#4ab8f0"), rgb("#4aa8e0"), rgb("#3a88c8")]
    R = 17.0
    for f in range(5):
        img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        a0, a1 = spans[f]
        for y in range(48):
            for x in range(48):
                dx, dy = x + 0.5 - 24, y + 0.5 - 24
                r = math.hypot(dx, dy)
                ang = math.degrees(math.atan2(dy, dx)) % 360
                if ang < a0 - 360 + 360 and ang < a0:
                    ang += 360  # cho cung vượt qua 360 độ
                if not (a0 <= ang <= a1):
                    continue
                u = (ang - a0) / (a1 - a0)
                t = thick[f] * math.sin(math.pi * u) ** 0.6
                dist = abs(r - R)
                if t <= 0.5 or dist > t:
                    continue
                if f == 4 and int(ang / 14) % 2 == 1:
                    continue  # khung cuối vỡ thành vệt đứt
                col = core_c[f] if dist < t * 0.4 else mid_c[f] if dist < t * 0.75 else edge_c[f]
                img.putpixel((x, y), col)
        frames.append(img)
    return sheet(frames)


# --- bonk_star --------------------------------------------------------------------------------------
def bonk_star():
    arms = [1, 3, 4, 3]
    diag = [0, 1, 2, 1]
    frames = []
    for f in range(4):
        img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        c = 8
        for dy in (-1, 0):
            for dx in (-1, 0):
                put(img, c + dx, c + dy, WHITE)
        for d in range(1, arms[f] + 1):
            col = YELLOW if d > 1 or f == 0 else PALE
            put(img, c + d - 1 + 1, c - 1, col)
            put(img, c + d - 1 + 1, c, col)
            put(img, c - 1 - d, c - 1, col)
            put(img, c - 1 - d, c, col)
            put(img, c - 1, c + d, col)
            put(img, c, c + d, col)
            put(img, c - 1, c - 1 - d, col)
            put(img, c, c - 1 - d, col)
        for d in range(1, diag[f] + 1):
            for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
                put(img, c - 1 + (d if sx > 0 else -d + 1) + (0 if sx > 0 else -1), c - 1 + (d if sy > 0 else -d + 1) + (0 if sy > 0 else -1), YELLOW)
        outline(img, rgb("#6a3a0a"))
        frames.append(img)
    return sheet(frames)


# --- shockwave --------------------------------------------------------------------------------------
def shockwave():
    radius = [5, 10, 15, 20, 25, 29]
    width = [3.0, 3.0, 2.4, 2.0, 1.4, 1.2]
    cols = [WHITE, WHITE, PALE, PALE, rgb("#ffe08a"), rgb("#ffd27a")]
    frames = []
    for f in range(6):
        img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        for y in range(64):
            for x in range(64):
                dx, dy = x + 0.5 - 32, y + 0.5 - 32
                d = abs(math.hypot(dx, dy) - radius[f])
                if d > width[f] / 2:
                    continue
                if f >= 4 and int((math.degrees(math.atan2(dy, dx)) % 360) / 20) % 3 == 2:
                    continue  # vòng cuối đứt đoạn rồi tan
                img.putpixel((x, y), cols[f])
        frames.append(img)
    return sheet(frames)


# --- dust -------------------------------------------------------------------------------------------
def disk(img, cx, cy, r, fill, shade):
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                put(img, x, y, shade if y + 0.5 > cy + r * 0.35 else fill)


def dust():
    puffs = [
        [(12, 12, 2.2)],
        [(9, 11, 3.0), (14.5, 12, 2.4)],
        [(7.5, 10, 3.6), (15, 10.5, 3.2), (11.5, 7.5, 2.2)],
        [(6, 9, 3.4), (16.5, 9, 3.0), (11, 6, 1.8)],
        [(5, 7, 1.8), (18, 7, 1.6), (11.5, 4, 1.2)],
    ]
    fills = [rgb("#f4ead6"), rgb("#efe3cc"), rgb("#efe3cc"), rgb("#e6dac4"), rgb("#ddd0ba")]
    shades = [rgb("#c8b48f"), rgb("#c8b48f"), rgb("#c2ae8a"), rgb("#b8a684"), rgb("#ad9c7c")]
    frames = []
    for f in range(5):
        img = Image.new("RGBA", (24, 16), (0, 0, 0, 0))
        for (x, y, r) in puffs[f]:
            disk(img, x, y, r, fills[f], shades[f])
        outline(img, rgb("#7a6650"))
        frames.append(img)
    return sheet(frames)


# --- broth_blob -------------------------------------------------------------------------------------
def broth_blob():
    frames = []
    for f, (rx, ry) in enumerate([(3.6, 3.6), (4.4, 3.0)]):
        img = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
        for y in range(12):
            for x in range(12):
                dx, dy = (x + 0.5 - 6) / rx, (y + 0.5 - 6.2) / ry
                if dx * dx + dy * dy <= 1.0:
                    col = rgb("#d0501e") if dx + dy > 0.55 else rgb("#ff8a3a")
                    img.putpixel((x, y), col)
        for p in [(4, 4), (5, 4), (4, 5)] if f == 0 else [(3, 5), (4, 4), (5, 4)]:
            put(img, p[0], p[1], rgb("#ffe0b0"))
        outline(img, rgb("#5a1a0a"))
        frames.append(img)
    return sheet(frames)


BUILDERS = {
    "impact_star": impact_star,
    "slash_arc": slash_arc,
    "bonk_star": bonk_star,
    "shockwave": shockwave,
    "dust": dust,
    "broth_blob": broth_blob,
}


def preview(sheets):
    scale = 4
    pad = 12
    rows = [s.resize((s.width * scale, s.height * scale), Image.NEAREST) for s in sheets.values()]
    w = max(r.width for r in rows) + pad * 2
    h = sum(r.height + pad for r in rows) + pad
    out = Image.new("RGBA", (w, h), rgb("#4a7a3a"))
    half = Image.new("RGBA", (w // 2, h), rgb("#2a1c18"))
    out.paste(half, (0, 0))
    y = pad
    for r in rows:
        out.alpha_composite(r, (pad, y))
        y += r.height + pad
    path = ROOT / "_tmp_test" / "combat_fx_preview.png"
    path.parent.mkdir(exist_ok=True)
    out.save(path)
    return path


if __name__ == "__main__":
    sheets = {}
    for name, build in BUILDERS.items():
        s = build()
        s.save(HERE / f"{name}.png")
        sheets[name] = s
    print("Wrote", ", ".join(f"{n}.png" for n in sheets))
    if "--preview" in sys.argv:
        print("Preview:", preview(sheets).relative_to(ROOT))
