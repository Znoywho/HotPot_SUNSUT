"""Vẽ icon pixel 16x16 cho cửa hàng: 5 vũ khí, vài nâng cấp chưa có hình, icon tab.

Mỗi icon là một lưới 16 dòng x 16 ký tự; mỗi ký tự là một màu trong PALETTE ('.' = trong suốt).
Sửa hình: đổi ký tự trong lưới rồi chạy lại.

Chạy:  python3 tools/make_shop_icons.py   ->  assets/sprites/ui/shop/*.png
"""
from pathlib import Path

from PIL import Image

OUT_DIR = Path("assets/sprites/ui/shop")
PALETTE = {
    "k": "#2b1a14",  # viền tối
    "w": "#8a5a2c",  # gỗ
    "W": "#b8823f",  # gỗ sáng
    "s": "#9aa7b0",  # thép
    "S": "#dde4e8",  # thép sáng (lưỡi sáng)
    "d": "#5d6a73",  # thép tối
    "g": "#d99a1e",  # vàng
    "G": "#ffe08a",  # vàng sáng
    "o": "#a8650f",  # vàng tối
    "b": "#34343c",  # gang
    "B": "#5f5f6b",  # gang sáng
    "r": "#b8322a",  # đỏ
    "R": "#e8604c",  # đỏ sáng
    "m": "#8b3a1e",  # thịt nướng
    "M": "#c0603a",  # thịt sáng
    "v": "#4f9a3a",  # ớt xanh
    "e": "#f5f1e6",  # lòng trắng mắt
    "p": "#2e6fb5",  # tròng mắt
    "y": "#ffd54a",  # tia sét
    "c": "#f1e3c4",  # khăn bàn kem
    "P": "#f08aa0",  # não hồng
    "q": "#c8566e",  # nếp não hồng đậm
}

ICONS = {
    # --- Vũ khí ---
    "ladle": [
        "................",
        "............kk..",
        "...........kWk..",
        "..........kWk...",
        ".........kWk....",
        "........kWk.....",
        ".......kWk......",
        "......kWk.......",
        ".....kWk........",
        "..kkkWk.........",
        ".kSSSsk.........",
        "kSSSssdk........",
        "ksSsssdk........",
        "ksssddk.........",
        ".kdddk..........",
        "..kkk...........",
    ],
    "cleaver": [
        "................",
        "................",
        "................",
        ".kkkkkkkkk......",
        ".kSSSSSSSdk.....",
        ".kSSSSSSSdk.....",
        ".kSsssssssk.....",
        ".ksssssssskkkkk.",
        ".ksssssssskwWWk.",
        ".ksssssssskwwWk.",
        ".kdddddddskkkkk.",
        ".kkkkkkkkkk.....",
        "................",
        "................",
        "................",
        "................",
    ],
    "skewer": [
        "...............k",
        "..............kS",
        ".............kSk",
        "...........kkk..",
        "..........kMMk..",
        ".........kmMmk..",
        "........kkmmk...",
        ".......kvvkk....",
        "......kvvvk.....",
        ".....kkvkk......",
        "....kMMk........",
        "...kmMmk........",
        "..kkmmk.........",
        "..kWkk..........",
        ".kWk............",
        "kkk.............",
    ],
    "cast_pan": [
        "................",
        "................",
        "................",
        "...kkkkkk.......",
        "..kbbbbbbk......",
        ".kbBBBBBBbk.....",
        ".kbBbbbbBbkkkkk.",
        ".kbBbbbbBbkwWWk.",
        ".kbBbbbbBbkwwWk.",
        ".kbBBBBBBbkkkkk.",
        "..kbbbbbbk......",
        "...kkkkkk.......",
        "................",
        "................",
        "................",
        "................",
    ],
    "golden_cleaver": [
        "................",
        "................",
        "................",
        ".kkkkkkkkk......",
        ".kGGGGGGGok.....",
        ".kGGGGGGGok.....",
        ".kGgggggggk.....",
        ".kggggggggkkkkk.",
        ".kggggggggkrRRk.",
        ".kggggggggkrrRk.",
        ".kooooooogkkkkk.",
        ".kkkkkkkkkk.....",
        "................",
        "................",
        "................",
        "................",
    ],
    # --- Nâng cấp chưa có hình ---
    "dragon_blade": [
        "..............kk",
        ".............kSk",
        "............kSdk",
        "...........kSdk.",
        "..........kSdk..",
        ".........kSdk...",
        "........kSdk....",
        ".......kSdk.....",
        "......kSdk......",
        "...kkkSdk.......",
        "..kGgkdk........",
        "...kgokk........",
        "..krkGk.........",
        ".krRkkk.........",
        "krRk............",
        ".kk.............",
    ],
    "battle_robe": [
        "................",
        "....kkk..kkk....",
        "...krRRkkRRrk...",
        "..krRRRGGRRRrk..",
        ".krrRRRgGRRRrrk.",
        ".krrkRRgGRRkrrk.",
        "..kk.kRgGRk.kk..",
        ".....krgGrk.....",
        ".....krgGrk.....",
        ".....krgGrk.....",
        "....krrgGrrk....",
        "....krrgGrrk....",
        "....kGGGGGGk....",
        "....kkkkkkkk....",
        "................",
        "................",
    ],
    "armor": [
        "................",
        "...kkk....kkk...",
        "..kSSdk..kdSSk..",
        ".kSSssdkkdssSSk.",
        ".ksSssssssssSsk.",
        ".kkssSSSSSSsskk.",
        "..kssSkkkkSssk..",
        "..ksssSSSSsssk..",
        "..kssskkkksssk..",
        "..ksssSSSSsssk..",
        "..kddssssssddk..",
        "..kggggggggggk..",
        "...kdssssssdk...",
        "....kkkkkkkk....",
        "................",
        "................",
    ],
    "hawk": [
        "k..............k",
        "kk............kk",
        "kWk..........kWk",
        "kwWk...kk...kWwk",
        ".kwWk.keek.kWwk.",
        ".kwwWkkeekkWwwk.",
        "..kwwWkyykWwwk..",
        "...kwwwkkwwwk...",
        "....kwwwwwwk....",
        ".....kwWWwk.....",
        "......kwwk......",
        ".....kwWWwk.....",
        "....kwWwwWwk....",
        "....kkkkkkkk....",
        "................",
        "................",
    ],
    "sharp_mind": [
        "................",
        ".y....kkkk....y.",
        "y.y.kkPPPPkk.y.y",
        ".y.kPPqPPqPPk.y.",
        "..kPqPPPqPPqPk..",
        "yykPPPqPPPqPPkyy",
        "..kPqPPqPPPqPk..",
        "..kPPPPqPqPPPk..",
        ".y.kPqPPPPqPk.y.",
        "y.y.kkPPPPkk.y.y",
        ".y....kPPk....y.",
        "......kqqk......",
        "......kkkk......",
        "................",
        "................",
        "................",
    ],
    "table": [
        "................",
        "................",
        "................",
        "....kkkkkkkk....",
        "..kkcccccccckk..",
        ".kccrrrrrrrrcck.",
        ".kcrrRRRRRRrrck.",
        ".kccrrrrrrrrcck.",
        "..kkcccccccckk..",
        "....kkkkkkkk....",
        "......kwwk......",
        "......kwwk......",
        "......kwwk......",
        "....kkwwwwkk....",
        "...kwwwwwwwwk...",
        "...kkkkkkkkkk...",
    ],
    "lantern": [
        "................",
        ".......kk.......",
        ".......kk.......",
        ".....kkkkkk.....",
        ".....kggggk.....",
        "...kkrrrrrrkk...",
        "..krRRrrrrRRrk..",
        "..krRrrrrrrRrk..",
        "..krRrrrrrrRrk..",
        "..krRRrrrrRRrk..",
        "...kkrrrrrrkk...",
        ".....kggggk.....",
        ".....kkkkkk.....",
        "......kyyk......",
        "......kyyk......",
        ".......kk.......",
    ],
    "swords": [
        "kk............kk",
        "kSk..........kSk",
        ".kSk........kSk.",
        "..kSk......kSk..",
        "...kSk....kSk...",
        "....kSk..kSk....",
        ".....kSkkSk.....",
        "......kSSk......",
        "......kSSk......",
        ".....kSkkSk.....",
        "...kkSk..kSkk...",
        "..kgkk....kkgk..",
        "...kgk....kgk...",
        "..kwkgk..kgkwk..",
        ".kwk.kk..kk.kwk.",
        ".kk..........kk.",
    ],
}


def draw_icon(rows: list[str]) -> Image.Image:
    """Lưới ký tự 16x16 -> ảnh RGBA: mỗi ô là 1 điểm ảnh màu PALETTE[ký tự], '.' trong suốt."""
    assert len(rows) == 16 and all(len(r) == 16 for r in rows), [len(r) for r in rows]
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x, y), Image.new("RGB", (1, 1), PALETTE[ch]).getpixel((0, 0)) + (255,))
    return img


if __name__ == "__main__":
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, rows in ICONS.items():
        draw_icon(rows).save(OUT_DIR / f"{name}.png")
    print("Đã vẽ", len(ICONS), "icon vào", OUT_DIR)
