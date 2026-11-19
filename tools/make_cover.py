"""Tạo ảnh bìa itch.io 630x500 từ chính hình pixel trong game.

Cách làm: ghép mọi thứ ở tỉ lệ 1 (1 điểm ảnh gốc) trên khung 210x167, rồi phóng x3 bằng NEAREST
để điểm ảnh vuông sắc, không nhòe. 210 x 3 = 630, 167 x 3 = 501 (cắt bớt 1 hàng) -> 630x500.

Chạy:  python3 tools/make_cover.py   ->  docs/screenshots/cover_630x500.png
Muốn đổi bố cục: sửa toạ độ trong CAST (toạ độ tính theo điểm ảnh gốc, chưa nhân 3).
"""
from PIL import Image

ART = "assets/sprites/"
OUT = "docs/screenshots/cover_630x500.png"
SCALE = 3  # 1 điểm ảnh gốc = 3 px trên ảnh bìa
CANVAS = (210, 167)  # 630x500 chia 3 (làm tròn lên)
COVER_SIZE = (630, 500)
DOOR_X = 216  # Giữa cửa quán trên phong cảnh 432x180: căn khung quanh quán
DOOR_LEFT_LEAF = (211, 54)  # Góc trái trên cánh cửa trái (giống main_menu.gd)
# (ảnh, x, y, phóng thêm) — vẽ theo thứ tự: xa trước, gần sau.
CAST = [
    ("characters/mount_buffalo.png", 4, 128, 1),
    ("characters/player.png", 28, 100, 2),
    ("monsters/angry_chili.png", 104, 132, 1),
    ("monsters/tomato_warrior.png", 126, 128, 1),
    ("monsters/boss_hotpot_golem.png", 148, 96, 2),
]


def load(path: str) -> Image.Image:
    """Mở một ảnh trong assets/sprites dạng RGBA để ghép có nền trong suốt."""
    return Image.open(ART + path).convert("RGBA")


def scale_nearest(img: Image.Image, factor: int) -> Image.Image:
    """Phóng ảnh pixel nguyên lần: kích thước mới = kích thước cũ x factor, không làm mượt."""
    return img.resize((img.width * factor, img.height * factor), Image.NEAREST)


def draw_background(canvas: Image.Image) -> int:
    """Trời + phong cảnh cắt quanh quán lẩu; đóng 2 cánh cửa quán. Trả về x bắt đầu cắt (x0 = cửa - rộng/2)."""
    x0 = DOOR_X - canvas.width // 2
    for layer in ("scenery/sky.png", "scenery/landscape.png"):
        canvas.alpha_composite(load(layer).crop((x0, 0, x0 + canvas.width, canvas.height)))
    leaf = load("scenery/door_leaf.png")
    left = (DOOR_LEFT_LEAF[0] - x0, DOOR_LEFT_LEAF[1])
    canvas.alpha_composite(leaf, left)
    canvas.alpha_composite(leaf.transpose(Image.FLIP_LEFT_RIGHT), (left[0] + leaf.width, left[1]))
    return x0


def draw_cast(canvas: Image.Image) -> None:
    """Đầu bếp, trâu, quái và boss đứng trên cỏ phía dưới."""
    for path, x, y, factor in CAST:
        canvas.alpha_composite(scale_nearest(load(path), factor), (x, y))


def draw_logo(canvas: Image.Image) -> None:
    """Logo pixel "Sôi Sùng Sục" căn giữa sát mép trên."""
    logo = load("scenery/title_pixel.png")
    canvas.alpha_composite(logo, ((canvas.width - logo.width) // 2, 4))


def make_cover() -> Image.Image:
    """Ghép các lớp ở tỉ lệ 1 rồi phóng x3 và cắt đúng 630x500."""
    canvas = Image.new("RGBA", CANVAS)
    draw_background(canvas)
    draw_cast(canvas)
    draw_logo(canvas)
    return scale_nearest(canvas, SCALE).crop((0, 0, *COVER_SIZE)).convert("RGB")


if __name__ == "__main__":
    cover = make_cover()
    assert cover.size == COVER_SIZE, cover.size
    cover.save(OUT)
    print("Đã lưu", OUT, cover.size)
