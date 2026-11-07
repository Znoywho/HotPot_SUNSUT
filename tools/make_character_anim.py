#!/usr/bin/env python3
"""Tạo sheet animation từ hình nhân vật cũ (32x32): chân chạy, chém trên không kiểu ninja, chiêu của đầu bếp.

Chạy từ thư mục gốc project: python3 tools/make_character_anim.py [thư_mục_xem_trước]
Kết quả: assets/sprites/characters/<tên>_anim.png, mỗi hàng là một chuyển động, mỗi khung FRAME x FRAME.
Thứ tự hàng và số khung phải khớp với ANIMATIONS trong scenes/common/sprite_frame_layer.gd.
"""
import math
import sys
from PIL import Image, ImageDraw

CHAR_DIR = "assets/sprites/characters/"
SRC_SIZE = 32
PAD = 12  # Chừa chỗ quanh hình gốc cho muôi và vệt chém.
FRAME = SRC_SIZE + 2 * PAD
HEM_Y = 27  # Hàng gấu áo, chân bắt đầu từ đây.
FOOT_Y = 28  # Hàng cuối của bàn chân khi đứng.
ARM_X = 21  # Từ cột này sang phải là tay và đồ cầm.
ARM_TOP = 16  # Tay và đồ cầm của nhân viên nằm từ hàng này xuống (trên đó là mũ, tóc).
STAFF_SMEAR_RADIUS = 11  # Đồ cầm của nhân viên ngắn hơn muôi nên vệt chém sát hơn.
SHOULDER = (22, 21)  # Trục quay của tay đầu bếp.
HANDLE_LENGTH = 13
BEHIND_BODY_ANGLE = 90  # Muôi vung ra sau lưng (góc lớn hơn) thì vẽ dưới thân để không che mặt.
OUTLINE = (36, 26, 26, 255)
SKIN = (242, 194, 155, 255)
HANDLE = (141, 110, 99, 255)
STEEL, STEEL_SHADE, STEEL_LIGHT = (176, 190, 197, 255), (120, 144, 156, 255), (236, 239, 241, 255)
BROTH, BROTH_DARK = (239, 83, 80, 255), (198, 40, 40, 255)
SMEAR = (255, 255, 255, 130)

# (góc muôi so với phương ngang, độ dịch thân, độ mở chân, vẽ vệt chém, nước lẩu trong muôi, văng nước)
RUN_FRAMES = [(50, 0, 2), (72, -1, 0), (92, 0, -2), (72, -1, 0)]  # (góc, bob thân, độ mở chân)
CHEF_NINJA_ANGLES = [110, -20, 90, -35, 70, -10]  # Góc muôi mỗi nhát chém trên không.
STAFF_NINJA_ANGLES = [60, -40, 45, -50, 30, -30]  # Góc xoay đồ cầm so với tư thế gốc.
ATTACK_FRAMES = [
    (130, -1, 1, False, False, False), (165, -2, 1, False, False, False), (95, 2, 2, True, False, False),
    (20, 3, 3, True, False, False), (-15, 3, 3, False, False, False), (35, 1, 1, False, False, False),
]
SLICE_FRAMES = [
    (140, -1, 1, False, False, False), (45, 2, 2, True, False, False), (-25, 3, 3, True, False, False),
    (150, 0, 1, False, False, False), (50, 2, 2, True, False, False), (-25, 3, 3, True, False, False),
    (40, 1, 1, False, False, False),
]
SPLASH_FRAMES = [
    (-35, -1, 1, False, True, False), (-15, 0, 1, False, True, False), (60, 1, 2, False, True, False),
    (110, 1, 2, False, False, True), (85, 1, 1, False, False, True), (70, 0, 1, False, False, False),
    (62, 0, 0, False, False, False),
]


def is_outline(pixel):
    """Pixel viền là pixel đặc và rất tối."""
    return pixel[3] > 200 and sum(pixel[:3]) < 110


def find_leg_columns(source):
    """Tìm hai cột trái của hai chân và màu chân từ hàng bàn chân (mỗi chân rộng 3 ô, giữa hai lớp viền)."""
    xs = [x for x in range(SRC_SIZE) if source.getpixel((x, FOOT_Y))[3] > 200]
    runs, start = [], xs[0]
    for previous, current in zip(xs, xs[1:] + [None]):
        if current != previous + 1:
            runs.append((start, previous))
            start = current
    if len(runs) == 1:  # Hai chân dính viền nhau (vd Lan): chia đôi.
        left, right = runs[0]
        middle = (left + right) // 2
        runs = [(left, middle), (middle, right)]
    legs = [run[0] + 1 for run in runs[:2]]
    return legs, source.getpixel((legs[0] + 1, FOOT_Y))


def split_character(source):
    """Tách hình gốc thành thân (không chân, không tay) và phần tay + đồ cầm."""
    body = source.copy()
    arm = Image.new("RGBA", source.size, (0, 0, 0, 0))
    for y in range(SRC_SIZE):
        for x in range(SRC_SIZE):
            pixel = source.getpixel((x, y))
            if y >= HEM_Y:
                body.putpixel((x, y), (0, 0, 0, 0))
            elif x >= ARM_X + 1 and y >= ARM_TOP:
                arm.putpixel((x, y), pixel)
                body.putpixel((x, y), (0, 0, 0, 0))
    return body, arm


def paste_shadow(canvas, source):
    """Giữ bóng dưới chân cố định trên mặt đất."""
    for y in range(FOOT_Y + 1, SRC_SIZE):
        for x in range(SRC_SIZE):
            pixel = source.getpixel((x, y))
            if pixel[3] > 0 and not is_outline(pixel):
                canvas.putpixel((x + PAD, y + PAD), pixel)
            elif pixel[3] > 0:
                canvas.putpixel((x + PAD, y + PAD), (0, 0, 0, 71))


def draw_leg(canvas, column, hem_y, foot_y, color):
    """Vẽ một chân rộng 3 ô từ gấu áo xuống bàn chân, viền tối hai bên và đáy."""
    for y in range(hem_y, foot_y + 1):
        canvas.putpixel((column - 1 + PAD, y + PAD), OUTLINE)
        canvas.putpixel((column + 3 + PAD, y + PAD), OUTLINE)
        for x in range(column, column + 3):
            canvas.putpixel((x + PAD, y + PAD), color)
    for x in range(column - 1, column + 4):
        canvas.putpixel((x + PAD, foot_y + 1 + PAD), OUTLINE)


def draw_legs(canvas, legs, color, stride, body_y):
    """Hai chân ngược pha: chân trái lùi khi chân phải tiến; stride = 0 thì chân sau nhấc lên 1 ô."""
    hem_y = HEM_Y + body_y
    far, near = legs[1], legs[0]
    draw_leg(canvas, far + stride, hem_y, FOOT_Y, color)
    near_foot = FOOT_Y - 1 if stride == 0 else FOOT_Y
    draw_leg(canvas, near - stride, hem_y, near_foot, color)


def compose_body(canvas, body, offset_x, offset_y):
    """Dán thân lên khung tại vị trí đã dịch."""
    canvas.alpha_composite(body, (PAD + offset_x, PAD + offset_y))


def bowl_position(angle_deg, shoulder_x, shoulder_y):
    """Đầu muôi: x = sx + L cos(a), y = sy - L sin(a)."""
    angle = math.radians(angle_deg)
    return shoulder_x + HANDLE_LENGTH * math.cos(angle), shoulder_y - HANDLE_LENGTH * math.sin(angle)


def draw_smear(canvas, shoulder_x, shoulder_y, from_deg, to_deg, reach=HANDLE_LENGTH):
    """Vệt chém mờ quét theo đường đi của đầu đồ cầm; reach là khoảng cách từ vai tới đầu đồ cầm."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    radius = reach + 3
    start, end = sorted((-from_deg, -to_deg))
    box = [shoulder_x - radius, shoulder_y - radius, shoulder_x + radius, shoulder_y + radius]
    draw.pieslice(box, start, end, fill=SMEAR)
    inner = reach - 5
    draw.ellipse([shoulder_x - inner, shoulder_y - inner, shoulder_x + inner, shoulder_y + inner], fill=(0, 0, 0, 0))
    canvas.alpha_composite(layer)


def draw_ladle_arm(canvas, angle_deg, offset_x, offset_y, has_broth=False):
    """Vẽ bàn tay, cán và đầu muôi bằng đúng bảng màu của hình cũ."""
    sx, sy = SHOULDER[0] + PAD + offset_x, SHOULDER[1] + PAD + offset_y
    ex, ey = bowl_position(angle_deg, sx, sy)
    draw = ImageDraw.Draw(canvas)
    draw.line([(sx, sy), (ex, ey)], fill=OUTLINE, width=3)
    draw.line([(sx, sy), (ex, ey)], fill=HANDLE, width=1)
    draw.ellipse([ex - 3, ey - 3, ex + 3, ey + 3], fill=OUTLINE)
    draw.ellipse([ex - 2, ey - 2, ex + 2, ey + 2], fill=BROTH if has_broth else STEEL)
    canvas.putpixel((round(ex) + 1, round(ey) + 1), BROTH_DARK if has_broth else STEEL_SHADE)
    canvas.putpixel((round(ex) - 1, round(ey) - 1), BROTH if has_broth else STEEL_LIGHT)
    draw_hand(canvas, offset_x, offset_y)


def draw_hand(canvas, offset_x, offset_y):
    """Bàn tay ở vai, luôn nằm trên thân."""
    sx, sy = SHOULDER[0] + PAD + offset_x, SHOULDER[1] + PAD + offset_y
    draw = ImageDraw.Draw(canvas)
    draw.rectangle([sx - 2, sy - 2, sx + 1, sy + 2], fill=OUTLINE)
    draw.rectangle([sx - 1, sy - 1, sx, sy + 1], fill=SKIN)


def draw_splash_drops(canvas, angle_deg, offset_x, offset_y):
    """Giọt nước lẩu văng ra phía trước đầu muôi."""
    sx, sy = SHOULDER[0] + PAD + offset_x, SHOULDER[1] + PAD + offset_y
    ex, ey = bowl_position(angle_deg, sx, sy)
    for dx, dy in [(5, -2), (9, 0), (7, 3), (12, 3), (11, -3), (15, 1)]:
        x, y = min(FRAME - 2, round(ex + dx)), round(ey + dy)
        canvas.putpixel((x, y), OUTLINE)
        canvas.putpixel((x, y - 1), BROTH)
        canvas.putpixel((x + 1, y - 1), BROTH_DARK)


def build_chef_frame(source, body, legs, color, spec, previous_angle):
    """Một khung đầu bếp có muôi: chân, thân, vệt chém, tay."""
    angle, lean, stride, smear, has_broth, drops = spec
    canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    paste_shadow(canvas, source)
    draw_legs(canvas, legs, color, stride, 0)
    if smear:
        draw_smear(canvas, SHOULDER[0] + PAD + lean, SHOULDER[1] + PAD, previous_angle, angle)
    behind_body = angle > BEHIND_BODY_ANGLE
    if behind_body:
        draw_ladle_arm(canvas, angle, lean, 0, has_broth)
    compose_body(canvas, body, lean, 0)
    if behind_body:
        draw_hand(canvas, lean, 0)
    else:
        draw_ladle_arm(canvas, angle, lean, 0, has_broth)
    if drops:
        draw_splash_drops(canvas, angle, lean, 0)
    return canvas


def draw_tucked_legs(canvas, legs, color, kick):
    """Chân co lên khi đang bay: bàn chân nhấc cao 1 ô, đá ngược nhau theo nhịp chém."""
    draw_leg(canvas, legs[1] + kick, HEM_Y, FOOT_Y - 1, color)
    draw_leg(canvas, legs[0] - kick, HEM_Y, FOOT_Y - 1, color)


def build_chef_ninja(body, legs, color):
    """Các khung chém trên không của đầu bếp: không có bóng đất, muôi quét liên tục kèm vệt chém."""
    frames, previous = [], CHEF_NINJA_ANGLES[-1]
    for index, angle in enumerate(CHEF_NINJA_ANGLES):
        canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        draw_tucked_legs(canvas, legs, color, 1 if index % 2 == 0 else -1)
        draw_smear(canvas, SHOULDER[0] + PAD, SHOULDER[1] + PAD, previous, angle)
        if angle > BEHIND_BODY_ANGLE:
            draw_ladle_arm(canvas, angle, 0, 0)
            compose_body(canvas, body, 0, 0)
            draw_hand(canvas, 0, 0)
        else:
            compose_body(canvas, body, 0, 0)
            draw_ladle_arm(canvas, angle, 0, 0)
        frames.append(canvas)
        previous = angle
    return frames


def build_staff_ninja(body, arm, legs, color):
    """Các khung chém trên không của nhân viên: xoay tay và đồ cầm quanh vai, kèm vệt chém."""
    pivot = (SHOULDER[0] + PAD, SHOULDER[1] + PAD)
    arm_canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    arm_canvas.alpha_composite(arm, (PAD, PAD))
    frames, previous = [], STAFF_NINJA_ANGLES[-1]
    for index, angle in enumerate(STAFF_NINJA_ANGLES):
        canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        draw_tucked_legs(canvas, legs, color, 1 if index % 2 == 0 else -1)
        draw_smear(canvas, pivot[0], pivot[1], previous, angle, STAFF_SMEAR_RADIUS)
        compose_body(canvas, body, 0, 0)
        canvas.alpha_composite(arm_canvas.rotate(angle, Image.NEAREST, center=pivot))
        frames.append(canvas)
        previous = angle
    return frames


def build_chef_run(source, body, legs, color):
    """Bốn khung chạy của đầu bếp: chân bước, thân nhún, muôi đưa theo nhịp chân."""
    frames = []
    for angle, bob, stride in RUN_FRAMES:
        canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        paste_shadow(canvas, source)
        draw_legs(canvas, legs, color, stride, bob)
        compose_body(canvas, body, 0, bob)
        draw_ladle_arm(canvas, angle, 0, bob)
        frames.append(canvas)
    return frames


def build_staff_run(source, body, arm, legs, color):
    """Bốn khung chạy của nhân viên: chân bước, thân nhún, tay và đồ cầm nhấp nhô ngược nhịp."""
    frames = []
    for stride, bob, arm_y in [(2, 0, 1), (0, -1, 0), (-2, 0, -1), (0, -1, 0)]:
        canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        paste_shadow(canvas, source)
        draw_legs(canvas, legs, color, stride, bob)
        compose_body(canvas, body, 0, bob)
        canvas.alpha_composite(arm, (PAD, PAD + bob + arm_y))
        frames.append(canvas)
    return frames


def build_chef_skill(source, body, legs, color, specs):
    """Tạo các khung của một chiêu; vệt chém nối từ góc khung trước sang góc khung này."""
    frames, previous = [], specs[0][0]
    for spec in specs:
        frames.append(build_chef_frame(source, body, legs, color, spec, previous))
        previous = spec[0]
    return frames


def clear_chef_arm_from_body(body):
    """Bỏ tay trên thân đầu bếp và khép lại viền áo bên phải (tay được vẽ lại theo từng khung)."""
    for y in range(HEM_Y):
        for x in range(ARM_X, SRC_SIZE):
            if y >= 19 or x >= ARM_X + 3:  # Hàng trên 19 chỉ còn cán và đầu muôi nằm ngoài đầu nhân vật.
                body.putpixel((x, y), (0, 0, 0, 0))
    for y in range(19, HEM_Y):
        body.putpixel((ARM_X, y), OUTLINE)


def save_sheet(name, rows):
    """Ghép các hàng khung thành một sheet và lưu vào thư mục nhân vật."""
    columns = max(len(frames) for frames in rows)
    sheet = Image.new("RGBA", (columns * FRAME, len(rows) * FRAME), (0, 0, 0, 0))
    for row, frames in enumerate(rows):
        for column, frame in enumerate(frames):
            sheet.alpha_composite(frame, (column * FRAME, row * FRAME))
    sheet.save(f"{CHAR_DIR}{name}_anim.png")
    return sheet


def save_preview_gif(path, rows, scale=5, frame_ms=70):
    """GIF xem nhanh: các chuyển động chạy cạnh nhau trên nền xám (chỉ để xem, không vào game)."""
    longest = max(len(frames) for frames in rows) * 2
    images = []
    for tick in range(longest):
        canvas = Image.new("RGBA", (FRAME * len(rows), FRAME), (92, 112, 130, 255))
        for index, frames in enumerate(rows):
            canvas.alpha_composite(frames[tick % len(frames)], (index * FRAME, 0))
        images.append(canvas.resize((canvas.width * scale, canvas.height * scale), Image.NEAREST).convert("P", palette=Image.ADAPTIVE))
    images[0].save(path, save_all=True, append_images=images[1:], duration=frame_ms, loop=0)


def make_chef(preview_dir):
    """Sheet đầu bếp: chạy, đánh thường, thái lát, hất lẩu."""
    source = Image.open(f"{CHAR_DIR}player.png").convert("RGBA")
    body, _ = split_character(source)
    clear_chef_arm_from_body(body)
    legs, color = find_leg_columns(source)
    rows = [
        build_chef_run(source, body, legs, color),
        build_chef_ninja(body, legs, color),
        build_chef_skill(source, body, legs, color, ATTACK_FRAMES),
        build_chef_skill(source, body, legs, color, SLICE_FRAMES),
        build_chef_skill(source, body, legs, color, SPLASH_FRAMES),
    ]
    save_sheet("player", rows)
    if preview_dir:
        save_preview_gif(f"{preview_dir}/chef_old_style.gif", rows)


def make_staff(name):
    """Sheet nhân viên: chạy và chém trên không."""
    source = Image.open(f"{CHAR_DIR}{name}.png").convert("RGBA")
    body, arm = split_character(source)
    legs, color = find_leg_columns(source)
    save_sheet(name, [build_staff_run(source, body, arm, legs, color), build_staff_ninja(body, arm, legs, color)])


if __name__ == "__main__":
    preview = sys.argv[1] if len(sys.argv) > 1 else ""
    make_chef(preview)
    for staff_name in ["staff_lan", "staff_tung", "staff_minh"]:
        make_staff(staff_name)
    print("Đã tạo sheet animation.")
