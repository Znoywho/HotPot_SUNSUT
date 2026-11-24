"""Font pixel mập cho MỌI chữ in hoa của game: chữ IN HOA tiếng Việt (đủ dấu) + số + vài dấu câu + "đ" (tiền).

Chạy:  py assets/fonts/pixel_title/make_pixel_title_font.py [--preview]

Hai bộ chữ cùng độ dày nét (2 px): bộ LỚN (chữ hoa cao 12) cho tiêu đề, bộ NHỎ (chữ hoa cao 8, file small_*)
cho nhãn / nút cỡ 20-30 px. Bảng màu có sẵn (morning, noon...) cho tiêu đề; "white" (có viền) và "plain"
(không viền) là chữ trắng để Godot nhuộm theo màu chữ của từng màn. Cách chọn bộ + độ phóng: PixelTitle.style().

Cùng kiểu logo menu "SÔI SÙNG SỤC" (tools/make_title_logo.py): nét dày 2 px, viền tối 1 px quanh chữ,
bóng đổ lệch xuống 1 px, thân chữ tô theo dải màu từ sáng (trên) xuống tối (dưới), không khử răng cưa.
Mỗi bảng màu ra 1 font BMFont (<variant>.fnt + <variant>.png) để Godot import; khi hiện phải phóng
NGUYÊN lần (cỡ chữ = NATIVE_SIZE x 2, 3, 4...) để điểm ảnh không méo.

Dấu tiếng Việt ghép tự động: tách NFD thành chữ gốc + dấu (unicodedata), mỗi dấu một mặt nạ riêng.
Dấu thanh đi với dấu mũ (Ấ Ầ Ẩ) đặt lệch bên phải dấu mũ như chữ Việt in; dấu ngã + mũ (Ẫ) và dấu thanh
+ trăng (Ắ Ằ Ẳ Ẵ) thì chồng lên trên. Ơ Ư có móc ở góc trên phải. Đ = D + gạch ngang thân trái.
Tự vẽ hoàn toàn bằng code, không lấy từ font của ai (repo công khai).
--preview ghi thêm _tmp_test/pixel_title_preview.png (thư mục đã gitignore) để xem trước.
"""
import sys
import unicodedata
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]

GAP = 1  # px trống giữa 2 chữ, ngoài viền
ATLAS_W = 512

# --- Mặt nạ thân chữ: '#' = nét, cao CAP hàng (dấu phẩy thòng thêm 1 hàng) --------------------------------
GLYPHS = {
    'A': [".######.", "########", "##....##", "##....##", "##....##", "##....##", "########", "########", "##....##", "##....##", "##....##", "##....##"],
    'B': ["#######.", "########", "##....##", "##....##", "##...##.", "#######.", "########", "##....##", "##....##", "##....##", "########", "#######."],
    'C': [".######.", "########", "##....##", "##......", "##......", "##......", "##......", "##......", "##......", "##....##", "########", ".######."],
    'D': ["#######.", "########", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "########", "#######."],
    'E': ["#######", "#######", "##.....", "##.....", "##.....", "######.", "######.", "##.....", "##.....", "##.....", "#######", "#######"],
    'F': ["#######", "#######", "##.....", "##.....", "##.....", "######.", "######.", "##.....", "##.....", "##.....", "##.....", "##....."],
    'G': [".######.", "########", "##....##", "##......", "##......", "##..####", "##..####", "##....##", "##....##", "##....##", "########", ".######."],
    'H': ["##....##", "##....##", "##....##", "##....##", "##....##", "########", "########", "##....##", "##....##", "##....##", "##....##", "##....##"],
    'I': ["######", "######", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "######", "######"],
    'J': ["...#####", "...#####", "......##", "......##", "......##", "......##", "......##", "......##", "##....##", "##....##", "########", ".######."],
    'K': ["##....##", "##...###", "##..###.", "##.###..", "#####...", "####....", "####....", "#####...", "##.###..", "##..###.", "##...###", "##....##"],
    'L': ["##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "#######", "#######"],
    'M': ["##......##", "###....###", "####..####", "##.####.##", "##..##..##", "##......##", "##......##", "##......##", "##......##", "##......##", "##......##", "##......##"],
    'N': ["##....##", "###...##", "####..##", "####..##", "##.##.##", "##.##.##", "##..####", "##..####", "##...###", "##....##", "##....##", "##....##"],
    'O': [".######.", "########", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "########", ".######."],
    'P': ["#######.", "########", "##....##", "##....##", "##....##", "########", "#######.", "##......", "##......", "##......", "##......", "##......"],
    'Q': [".######.", "########", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##.##.##", "##..####", "#######.", ".#######"],
    'R': ["#######.", "########", "##....##", "##....##", "##....##", "########", "#######.", "##.###..", "##..###.", "##...###", "##....##", "##....##"],
    'S': [".######.", "########", "##....##", "##......", "##......", "#######.", ".#######", "......##", "......##", "##....##", "########", ".######."],
    'T': ["########", "########", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...", "...##..."],
    'U': ["##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "########", ".######."],
    'V': ["##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "###..###", ".##..##.", ".######.", "..####..", "..####..", "...##..."],
    'W': ["##......##", "##......##", "##......##", "##......##", "##......##", "##..##..##", "##..##..##", "##.####.##", "##########", "####..####", "###....###", "##......##"],
    'X': ["##....##", "##....##", "###..###", ".######.", "..####..", "...##...", "...##...", "..####..", ".######.", "###..###", "##....##", "##....##"],
    'Y': ["##....##", "##....##", "##....##", "###..###", ".######.", "..####..", "...##...", "...##...", "...##...", "...##...", "...##...", "...##..."],
    'Z': ["########", "########", ".....###", "....###.", "....###.", "...###..", "..###...", ".###....", ".###....", "###.....", "########", "########"],
    'Đ': [".#######.", ".########", ".##....##", ".##....##", ".##....##", "#####..##", "#####..##", ".##....##", ".##....##", ".##....##", ".########", ".#######."],
    '0': [".#####.", "#######", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "#######", ".#####."],
    '1': ["..##..", ".###..", "####..", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "######", "######"],
    '2': [".######.", "########", "##....##", "......##", "......##", ".#######", "#######.", "##......", "##......", "##......", "########", "########"],
    '3': [".######.", "########", "##....##", "......##", "......##", "..#####.", "..######", "......##", "......##", "##....##", "########", ".######."],
    '4': ["....###.", "...####.", "..##.##.", ".##..##.", "##...##.", "########", "########", ".....##.", ".....##.", ".....##.", ".....##.", ".....##."],
    '5': ["########", "########", "##......", "##......", "#######.", "########", "......##", "......##", "......##", "##....##", "########", ".######."],
    '6': [".######.", "########", "##....##", "##......", "##......", "#######.", "########", "##....##", "##....##", "##....##", "########", ".######."],
    '7': ["########", "########", "......##", ".....###", "....###.", "...###..", "..###...", "..##....", "..##....", "..##....", "..##....", "..##...."],
    '8': [".######.", "########", "##....##", "##....##", "##....##", ".######.", "########", "##....##", "##....##", "##....##", "########", ".######."],
    '9': [".######.", "########", "##....##", "##....##", "##....##", "########", ".#######", "......##", "......##", "##....##", "########", ".######."],
    '!': ["##", "##", "##", "##", "##", "##", "##", "##", "..", "..", "##", "##"],
    '?': [".######.", "########", "##....##", "......##", ".....###", "...####.", "...###..", "...##...", "...##...", "........", "...##...", "...##..."],
    '.': ["..", "..", "..", "..", "..", "..", "..", "..", "..", "..", "##", "##"],
    ',': ["..", "..", "..", "..", "..", "..", "..", "..", "..", "..", "##", "##", "#."],
    ':': ["..", "..", "..", "##", "##", "..", "..", "..", "..", "..", "##", "##"],
    '·': ["..", "..", "..", "..", "..", "##", "##", "..", "..", "..", "..", ".."],
    '-': ["......", "......", "......", "......", "......", "######", "######", "......", "......", "......", "......", "......"],
    '+': ["......", "......", "......", "..##..", "..##..", "######", "######", "..##..", "..##..", "......", "......", "......"],
    '%': ["##....##", "##...###", ".....##.", "....###.", "....##..", "...###..", "..###...", "..##....", ".###....", ".##.....", "###...##", "##....##"],
    '/': ["....##", "....##", "...###", "...##.", "..###.", "..##..", "..##..", ".###..", ".##...", "###...", "##....", "##...."],
    '(': ["..##", ".###", "###.", "##..", "##..", "##..", "##..", "##..", "##..", "###.", ".###", "..##"],
    ')': ["##..", "###.", ".###", "..##", "..##", "..##", "..##", "..##", "..##", ".###", "###.", "##.."],
}

# Ký tự thêm cho chữ giao diện: "đ" thường (tiền: 1.200đ), mũi tên » › « ‹ (font không có ▶), gạch – .
GLYPHS.update({
    'đ': ["......##", "...#####", "...#####", "......##", ".#######", "########", "##....##", "##....##", "##....##", "##....##", "########", ".#######"],
    '»': ["........", "........", "........", "##..##..", ".##..##.", "..##..##", "..##..##", ".##..##.", "##..##..", "........", "........", "........"],
    '«': ["........", "........", "........", "..##..##", ".##..##.", "##..##..", "##..##..", ".##..##.", "..##..##", "........", "........", "........"],
    '›': ["....", "....", "....", "##..", ".##.", "..##", "..##", ".##.", "##..", "....", "....", "...."],
    '‹': ["....", "....", "....", "..##", ".##.", "##..", "##..", ".##.", "..##", "....", "....", "...."],
    '–': ["........", "........", "........", "........", "........", "########", "########", "........", "........", "........", "........", "........"],
})

# --- Bộ chữ NHỎ: chữ hoa cao 8, nét dọc 2 px (cùng độ dày nét với bộ lớn), cho nhãn / nút cỡ 20-30 px ----------
SMALL_GLYPHS = {
    'A': [".####.", "######", "##..##", "##..##", "######", "######", "##..##", "##..##"],
    'B': ["#####.", "######", "##..##", "#####.", "######", "##..##", "######", "#####."],
    'C': [".####.", "######", "##..##", "##....", "##....", "##..##", "######", ".####."],
    'D': ["#####.", "######", "##..##", "##..##", "##..##", "##..##", "######", "#####."],
    'E': ["#####", "#####", "##...", "####.", "####.", "##...", "#####", "#####"],
    'F': ["#####", "#####", "##...", "####.", "####.", "##...", "##...", "##..."],
    'G': [".####.", "######", "##....", "##.###", "##.###", "##..##", "######", ".####."],
    'H': ["##..##", "##..##", "##..##", "######", "######", "##..##", "##..##", "##..##"],
    'I': ["####", "####", ".##.", ".##.", ".##.", ".##.", "####", "####"],
    'J': ["..####", "..####", "....##", "....##", "....##", "##..##", "######", ".####."],
    'K': ["##..##", "##.###", "#####.", "####..", "####..", "#####.", "##.###", "##..##"],
    'L': ["##...", "##...", "##...", "##...", "##...", "##...", "#####", "#####"],
    'M': ["##....##", "###..###", "########", "##.##.##", "##....##", "##....##", "##....##", "##....##"],
    'N': ["##..##", "###.##", "######", "######", "##.###", "##..##", "##..##", "##..##"],
    'O': [".####.", "######", "##..##", "##..##", "##..##", "##..##", "######", ".####."],
    'P': ["#####.", "######", "##..##", "##..##", "######", "#####.", "##....", "##...."],
    'Q': [".####.", "######", "##..##", "##..##", "##..##", "##.###", "#####.", ".#####"],
    'R': ["#####.", "######", "##..##", "##..##", "#####.", "####..", "##.##.", "##..##"],
    'S': [".####.", "######", "##....", "#####.", ".#####", "....##", "######", ".####."],
    'T': ["######", "######", "..##..", "..##..", "..##..", "..##..", "..##..", "..##.."],
    'U': ["##..##", "##..##", "##..##", "##..##", "##..##", "##..##", "######", ".####."],
    'V': ["##..##", "##..##", "##..##", "##..##", "######", ".####.", ".####.", "..##.."],
    'W': ["##....##", "##....##", "##....##", "##.##.##", "##.##.##", "########", "###..###", "##....##"],
    'X': ["##..##", "##..##", "######", ".####.", ".####.", "######", "##..##", "##..##"],
    'Y': ["##..##", "##..##", "######", ".####.", "..##..", "..##..", "..##..", "..##.."],
    'Z': ["######", "######", "...###", "..###.", ".###..", "###...", "######", "######"],
    'Đ': [".#####.", ".######", ".##..##", "####.##", "####.##", ".##..##", ".######", ".#####."],
    'đ': ["....##", "..####", "....##", ".#####", "##..##", "##..##", "######", ".#####"],
    '0': [".###.", "#####", "##.##", "##.##", "##.##", "##.##", "#####", ".###."],
    '1': [".##.", "###.", ".##.", ".##.", ".##.", ".##.", "####", "####"],
    '2': [".####.", "######", "##..##", "...###", ".###..", "###...", "######", "######"],
    '3': [".####.", "######", "....##", "..###.", "..####", "....##", "######", ".####."],
    '4': ["...##.", "..###.", ".####.", "##.##.", "######", "######", "...##.", "...##."],
    '5': ["######", "######", "##....", "#####.", "######", "....##", "######", "#####."],
    '6': [".####.", "######", "##....", "#####.", "######", "##..##", "######", ".####."],
    '7': ["######", "######", "...###", "..###.", ".###..", ".##...", ".##...", ".##..."],
    '8': [".####.", "######", "##..##", ".####.", "######", "##..##", "######", ".####."],
    '9': [".####.", "######", "##..##", "######", ".#####", "....##", "######", ".####."],
    '!': ["##", "##", "##", "##", "##", "..", "##", "##"],
    '?': [".####.", "######", "##..##", "..###.", "..##..", "......", "..##..", "..##.."],
    '.': ["..", "..", "..", "..", "..", "..", "##", "##"],
    ',': ["..", "..", "..", "..", "..", "..", "##", "##", "#."],
    ':': ["..", "##", "##", "..", "..", "##", "##", ".."],
    '·': ["..", "..", "..", "##", "##", "..", "..", ".."],
    '-': ["....", "....", "....", "####", "####", "....", "....", "...."],
    '–': ["......", "......", "......", "######", "######", "......", "......", "......"],
    '+': ["......", "..##..", "..##..", "######", "######", "..##..", "..##..", "......"],
    '%': ["##..##", "##.###", "...##.", "..###.", ".###..", ".##...", "###.##", "##..##"],
    '/': ["..##", "..##", ".###", ".##.", ".##.", "###.", "##..", "##.."],
    '(': [".##", "##.", "##.", "##.", "##.", "##.", "##.", ".##"],
    ')': ["##.", ".##", ".##", ".##", ".##", ".##", ".##", "##."],
    '»': [".......", "##.##..", ".##.##.", "..##.##", ".##.##.", "##.##..", ".......", "......."],
    '«': [".......", "..##.##", ".##.##.", "##.##..", ".##.##.", "..##.##", ".......", "......."],
    '›': ["....", "##..", ".##.", "..##", ".##.", "##..", "....", "...."],
    '‹': ["....", "..##", ".##.", "##..", ".##.", "..##", "....", "...."],
}

# --- Dấu ---------------------------------------------------------------------------------------------------------
# Bộ lớn: nét 2 px theo bậc thang.
ACUTE = ["..##", ".##.", "##.."]
GRAVE = ["##..", ".##.", "..##"]
HOOK = ["###.", "..##", ".##."]  # dấu hỏi: móc nhỏ như dấu ? không chấm
TILDE = [".###...#", "#...###."]  # dấu ngã: sóng 2 hàng, đỉnh và đáy rộng 3 px cho rõ hình "~"
CIRCUMFLEX = ["..##..", ".####.", "##..##"]
CIRCUMFLEX_LOW = [".####.", "##..##"]  # mũ thấp 2 hàng khi có dấu ngã chồng lên trên (Ẫ Ễ Ỗ)
BREVE = ["##..##", ".####."]
DOT = ["##", "##"]
HORN = [".##", "###"]  # móc của Ơ Ư, gắn vào góc trên phải
# Bộ nhỏ: dấu 2 hàng (dấu hỏi 3 hàng cho ra hình móc).
S_ACUTE = [".##", "##."]
S_GRAVE = ["##.", ".##"]
S_HOOK = ["##.", "..#", ".#."]
S_TILDE = [".##.#", "#.##."]
S_CIRCUMFLEX = ["..##..", "##..##"]
S_BREVE = ["##..##", ".####."]
S_DOT = ["##", "##"]
S_HORN = [".#", "##"]

ACUTE_M, GRAVE_M, HOOK_M, TILDE_M, DOT_M = "́", "̀", "̉", "̃", "̣"
CIRC_M, BREVE_M, HORN_M = "̂", "̆", "̛"
VOWELS = "AĂÂEÊIOÔƠUƯY"
TONES = ["", GRAVE_M, ACUTE_M, HOOK_M, TILDE_M, DOT_M]  # ngang, huyền, sắc, hỏi, ngã, nặng


def put(cells, mask, x0, y0):
    for r, row in enumerate(mask):
        for c, p in enumerate(row):
            if p == '#':
                cells[(x0 + c, y0 + r)] = True


def split(ch):
    """Chữ gốc, dấu nguyên âm (mũ / trăng), dấu thanh (trên), có móc, có dấu nặng."""
    nfd = unicodedata.normalize("NFD", ch)
    marks = nfd[1:]
    vowel = CIRC_M if CIRC_M in marks else BREVE_M if BREVE_M in marks else None
    tone = next((m for m in marks if m in (ACUTE_M, GRAVE_M, HOOK_M, TILDE_M)), None)
    return nfd[0], vowel, tone, HORN_M in marks, DOT_M in marks


def compose_big(ch):
    """Lưới ô nét {(x, y)} của 1 ký tự bộ lớn; y = 0 là mép trên thân chữ."""
    cells = {}
    if ch in GLYPHS:
        put(cells, GLYPHS[ch], 0, 0)
        return cells
    base, vowel, tone_m, horn, dot = split(ch)
    tone = {ACUTE_M: ACUTE, GRAVE_M: GRAVE, HOOK_M: HOOK, TILDE_M: TILDE}.get(tone_m)
    w = len(GLYPHS[base][0])
    put(cells, GLYPHS[base], 0, 0)
    if horn:  # móc Ơ Ư: chạm góc trên phải thân chữ
        put(cells, HORN, w - 1, -2)
    if vowel == CIRC_M:
        cx = (w - 6) // 2
        if tone is TILDE:
            put(cells, CIRCUMFLEX_LOW, cx, -3)
            put(cells, TILDE, (w - len(TILDE[0])) // 2, -7)  # ngã chồng trên mũ, cách 1 hàng
        elif tone is not None:
            put(cells, CIRCUMFLEX, cx - 1, -4)
            put(cells, tone, cx + 4, -7)  # sắc / huyền / hỏi ở góc trên phải dấu mũ, không chạm mũ
        else:
            put(cells, CIRCUMFLEX, cx, -4)
    elif vowel == BREVE_M:
        put(cells, BREVE, (w - 6) // 2, -3)
        if tone is not None:
            put(cells, tone, (w - len(tone[0])) // 2, -7)  # dấu thanh chồng trên dấu trăng
    elif tone is TILDE:
        put(cells, TILDE, (w - len(TILDE[0])) // 2, -4)  # ngã chỉ 2 hàng: nhích lên cho sóng không dính sát chữ
    elif tone is not None:
        put(cells, tone, (w - len(tone[0])) // 2, -len(tone) - 1)
    if dot:
        put(cells, DOT, (w - 2) // 2, 12 + 1)
    return cells


def compose_small(ch):
    """Như compose_big cho bộ nhỏ (chữ hoa cao 8): dấu đơn ở 2 hàng ngay trên chữ, dấu chồng cách 1 hàng."""
    cells = {}
    if ch in SMALL_GLYPHS:
        put(cells, SMALL_GLYPHS[ch], 0, 0)
        return cells
    base, vowel, tone_m, horn, dot = split(ch)
    tone = {ACUTE_M: S_ACUTE, GRAVE_M: S_GRAVE, HOOK_M: S_HOOK, TILDE_M: S_TILDE}.get(tone_m)
    w = len(SMALL_GLYPHS[base][0])
    put(cells, SMALL_GLYPHS[base], 0, 0)
    if horn:
        put(cells, S_HORN, w - 1, -2)
    if vowel == CIRC_M:
        cx = (w - 6) // 2
        if tone is S_TILDE:
            put(cells, S_CIRCUMFLEX, cx, -3)
            put(cells, S_TILDE, (w - len(S_TILDE[0])) // 2, -6)
        elif tone is not None:
            put(cells, S_CIRCUMFLEX, cx - 1, -3)
            put(cells, tone, cx + 4, -3 - len(tone))  # góc trên phải dấu mũ
        else:
            put(cells, S_CIRCUMFLEX, cx, -3)
    elif vowel == BREVE_M:
        put(cells, S_BREVE, (w - 6) // 2, -3)
        if tone is not None:
            put(cells, tone, (w - len(tone[0])) // 2, -4 - len(tone))
    elif tone is not None:
        put(cells, tone, (w - len(tone[0])) // 2, -1 - len(tone))
    if dot:
        put(cells, S_DOT, (w - 2) // 2, 8 + 1)
    return cells


# Bộ chữ: chiều cao chữ hoa, hàng trên / dưới cùng của ô (gồm viền + bóng), hàm ghép, tiền tố tên file.
SETS = {
    "big": {"cap": 12, "top": -8, "bottom": 16, "compose": compose_big, "prefix": "", "space": 6},
    "small": {"cap": 8, "top": -8, "bottom": 12, "compose": compose_small, "prefix": "small_", "space": 5},
}
for _gs in SETS.values():
    _gs["line_h"] = _gs["bottom"] - _gs["top"] + 1  # big 25, small 21 (= "size" trong .fnt)
    _gs["base"] = _gs["cap"] - _gs["top"]  # từ mép trên ô tới chân chữ hoa


def charset():
    chars = [chr(c) for c in range(ord('A'), ord('Z') + 1)] + ['Đ', 'đ']
    for v in VOWELS:
        for t in TONES:
            c = unicodedata.normalize("NFC", v + t)
            if len(c) == 1 and c not in chars:
                chars.append(c)
    chars += list("0123456789!?.,:·-–+%/()»«›‹")
    return chars


# --- Bảng màu: [sáng nhất (hàng trên cùng), dải 1..4 từ sáng tới tối], viền, bóng ---------------------------
# Quy tắc (skill pixel-art-studio): đổi sắc >= 30 độ dọc dải, viền tối hơn màu tối nhất, nắng chiếu từ trên.
# "white" / "plain" là chữ trắng để Godot nhuộm theo màu chữ của từng màn (font_color / modulate):
# white có viền + bóng tối vẽ sẵn (nhuộm vẫn giữ viền tối), plain không viền (chữ trên nền giấy sáng).
VARIANTS = {
    "morning": (["#fff6d8", "#ffe79a", "#ffc96b", "#ffa155", "#f07a48"], "#3a1a10", "#8a3a1c"),  # bình minh: kem bơ -> đào -> cam
    "noon": (["#fffbe8", "#fff1a0", "#ffd36b", "#f6b443", "#e07a2a"], "#3a1810", "#8c2a1a"),  # nắng trưa: trắng vàng -> vàng -> hổ phách
    "evening": (["#ffe6c8", "#ffbf8a", "#ff8f6a", "#e8627a", "#b8457e"], "#2a1030", "#5c1a46"),  # hoàng hôn: hồng cam -> san hô -> mận
    "shop": (["#eafff4", "#b8f2d6", "#7ed9c0", "#4fb8ac", "#3a8896"], "#10282a", "#1c4a4c"),  # rạng đông: bạc hà -> ngọc -> lam
    "game_over": (["#ffc4a8", "#ff9270", "#e8583f", "#c03a30", "#8a2430"], "#1a0a08", "#3a1210"),  # biển hiệu tắt: đỏ cam -> đỏ -> đỏ rượu (cũng là số sát thương)
    "heal": (["#eaffd8", "#c6f59a", "#8fe06a", "#52c25a", "#2e9a5a"], "#0e2a14", "#1e4a24"),  # số hồi máu: xanh nõn -> xanh lá
    "armor": (["#e8f6ff", "#b6e2ff", "#7cc4f6", "#4c96e6", "#4a52c8"], "#0c1838", "#1c2e5c"),  # số giáp: xanh trời -> chàm
    "white": (["#ffffff", "#ffffff", "#f2f2f2", "#e4e4e4", "#d2d2d2"], "#1a1014", "#3a2a2e"),  # chữ trắng có viền: nhuộm theo màu chữ (nhãn, nút, chữ báo)
    "plain": (["#ffffff"] * 5, None, None),  # chữ trắng trơn: nhuộm theo màu chữ, không viền (chữ trên nền giấy)
}
SMALL_VARIANTS = ["white", "plain"]


def hex_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def row_color(fills, y, cap):
    """Màu nét theo hàng: hàng 0 sáng nhất, rồi 4 dải đều nhau xuống chân chữ; dấu trên lấy dải 1, dấu dưới dải 3."""
    if y < 0:
        return fills[1]
    if y == 0:
        return fills[0]
    if y >= cap:
        return fills[3]
    band = max(1, -(-(cap - 1) // 4))  # big: 3 hàng / dải, small: 2
    return fills[min(4, 1 + (y - 1) // band)]


def render_glyph(ch, variant, gs):
    """Ảnh RGBA cao line_h của 1 ký tự: nét tô dải màu (+ viền 8 hướng + bóng lệch xuống 1 px nếu bảng màu có)."""
    fills_hex, outline_hex, shadow_hex = VARIANTS[variant]
    fills = [hex_rgb(h) for h in fills_hex]
    cells = gs["compose"](ch)
    xs = [x for x, _ in cells]
    min_x, max_x = min(xs), max(xs)
    outline = set()
    if outline_hex is not None:
        for (x, y) in cells:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (x + dx, y + dy)
                    if n not in cells:
                        outline.add(n)
    solid = set(cells) | outline
    shadow = {(x, y + 1) for (x, y) in solid if (x, y + 1) not in solid} if shadow_hex is not None else set()
    width = max_x - min_x + 3  # chừa 1 px mỗi bên cho viền (plain cũng giữ để 2 bản thẳng hàng)
    img = Image.new("RGBA", (width, gs["line_h"]), (0, 0, 0, 0))

    def px(p, color):
        x, y = p[0] - min_x + 1, p[1] - gs["top"]
        assert 0 <= y < gs["line_h"], f"{ch!r}: hàng {p[1]} ra ngoài ô chữ"
        img.putpixel((x, y), color + (255,))

    for p in shadow:
        px(p, hex_rgb(shadow_hex))
    for p in outline:
        px(p, hex_rgb(outline_hex))
    for (x, y) in cells:
        px((x, y), row_color(fills, y, gs["cap"]))
    return img


def build_font(variant, chars, gs):
    glyphs = {ch: render_glyph(ch, variant, gs) for ch in chars}
    line_h = gs["line_h"]
    # Xếp ảnh vào atlas theo hàng, cách nhau 1 px trong suốt.
    placements = {}
    x = y = 0
    for ch, g in glyphs.items():
        if x + g.width > ATLAS_W:
            x, y = 0, y + line_h + 1
        placements[ch] = (x, y)
        x += g.width + 1
    height = y + line_h
    atlas_h = 1
    while atlas_h < height:
        atlas_h *= 2
    atlas = Image.new("RGBA", (ATLAS_W, atlas_h), (0, 0, 0, 0))
    for ch, g in glyphs.items():
        atlas.paste(g, placements[ch])
    name = gs["prefix"] + variant
    atlas.save(HERE / f"{name}.png")
    lines = [
        f'info face="PixelTitle {name}" size={line_h} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0',
        f"common lineHeight={line_h} base={gs['base']} scaleW={ATLAS_W} scaleH={atlas_h} pages=1 packed=0 alphaChnl=0 redChnl=0 greenChnl=0 blueChnl=0",
        f'page id=0 file="{name}.png"',
        f"chars count={len(glyphs) + 1}",
        f"char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance={gs['space']} page=0 chnl=15",
    ]
    for ch, g in glyphs.items():
        gx, gy = placements[ch]
        lines.append(f"char id={ord(ch)} x={gx} y={gy} width={g.width} height={line_h} xoffset=0 yoffset=0 xadvance={g.width + GAP} page=0 chnl=15")
    (HERE / f"{name}.fnt").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")  # LF: chạy lại trên Windows không đổi file
    return glyphs


def text_image(glyphs, text, scale, gs):
    width = sum(gs["space"] if c == ' ' else glyphs[c].width + GAP for c in text)
    img = Image.new("RGBA", (max(1, width), gs["line_h"]), (0, 0, 0, 0))
    x = 0
    for c in text:
        if c == ' ':
            x += gs["space"]
            continue
        g = glyphs[c]
        img.alpha_composite(g, (x, 0))
        x += g.width + GAP
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


def tint(img, color_hex):
    """Nhuộm ảnh chữ trắng như Godot nhân font_color (để xem trước bản white / plain)."""
    r, g, b = hex_rgb(color_hex)
    px = img.load()
    out = img.copy()
    po = out.load()
    for y in range(img.height):
        for x in range(img.width):
            pr, pg, pb, pa = px[x, y]
            po[x, y] = (pr * r // 255, pg * g // 255, pb * b // 255, pa)
    return out


def preview(fonts):
    big, small = SETS["big"], SETS["small"]
    rows = [
        (fonts["big"]["morning"], "NGÀY 12 · SÁNG", "#7ec8f0", 4, big, None),
        (fonts["big"]["evening"], "CHIỀU TỐI", "#6a4a7a", 4, big, None),
        (fonts["big"]["game_over"], "QUÁN ĐÓNG CỬA", "#3a2418", 3, big, None),
        (fonts["big"]["noon"], "ẤẦẨẪẬ ẮẰẲẴẶ ỐỒỔỖỘ ỚỜỞỠỢ", "#8fd4f4", 2, big, None),
        (fonts["big"]["white"], "TẠM DỪNG · CÀI ĐẶT · BẮT ĐẦU NGÀY 5 »", "#5a2a20", 2, big, "#fbecd2"),
        (fonts["small"]["white"], "TIỀN · NGÀY · KPI · ĐÁNH GIÁ · KHO", "#3a2418", 2, small, "#f3e2c0"),
        (fonts["small"]["white"], "MUA · 1.200đ  THIẾU TIỀN · 45.000đ  ĐÃ TỐI ĐA", "#7a2a1e", 2, small, "#fbecd2"),
        (fonts["small"]["plain"], "SƠ CHẾ NGUYÊN LIỆU · DỌN DẸP: BÀN 3", "#f1e2c0", 2, small, "#8a4a2a"),
        (fonts["small"]["white"], "ẤẦẨẪẬ ẮẰẲẴẶ ỐỒỔỖỘ ỚỜỞỠỢ ỨỪỬỮỰ ĐĨỸ 0123456789", "#5a3a5a", 2, small, "#ffd36b"),
        (fonts["small"]["white"], "ABCDEFGHIJKLMNOPQRSTUVWXYZ ! ? % ( ) / + – « ‹ › »", "#2a4060", 2, small, "#ffffff"),
    ]
    images = []
    for glyphs, text, bg, scale, gs, color in rows:
        img = text_image(glyphs, text, scale, gs)
        images.append((tint(img, color) if color else img, bg))
    pad = 14
    w = max(i.width for i, _ in images) + pad * 2
    h = sum(i.height + pad for i, _ in images) + pad
    sheet = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    y = pad // 2
    for img, bg in images:
        band = Image.new("RGBA", (w, img.height + pad), hex_rgb(bg) + (255,))
        band.alpha_composite(img, (pad, pad // 2))
        sheet.alpha_composite(band, (0, y))
        y += img.height + pad
    out = ROOT / "_tmp_test" / "pixel_title_preview.png"
    out.parent.mkdir(exist_ok=True)
    sheet.save(out)
    return out


if __name__ == "__main__":
    chars = charset()
    fonts = {"big": {v: build_font(v, chars, SETS["big"]) for v in VARIANTS},
             "small": {v: build_font(v, chars, SETS["small"]) for v in SMALL_VARIANTS}}
    print(f"Wrote {len(VARIANTS)} big + {len(SMALL_VARIANTS)} small fonts x {len(chars)} glyphs to {HERE.relative_to(ROOT)}")
    if "--preview" in sys.argv:
        print("Preview:", preview(fonts).relative_to(ROOT))
