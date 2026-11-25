"""Tạo 4 tiếng chuyển cảnh (jingle 8-bit ~1 giây) phát lúc hiện thẻ tên buổi (scenes/common/phase_transition.gd).

Dùng chung bộ tổng hợp của assets/audio/make_audio.py (cùng chất âm với nhạc nền và SFX), không sửa file đó.
Chạy:  python tools/make_transition_sfx.py        (cần: pip install numpy soundfile)
Ghi ra assets/audio/sfx/transition_<buổi>.ogg; mở Godot hoặc chạy `godot --headless --path . --import` để nhập.
"""
import os
import sys

sys.dont_write_bytecode = True  # import make_audio không để lại __pycache__ trong assets/
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio"))
from make_audio import arp, at, mix, noise, note_hz, perc, save, tone, SR  # noqa: E402


def morning():
	"""Buổi sáng đi săn: arpeggio Đô trưởng đi lên sáng sủa + tiếng chim hót ở cuối."""
	rise = arp(["C5", "E5", "G5", "C6"], 0.08, "square", duty=0.25, tau=0.07)
	chord = tone(note_hz("E6"), 0.45, "tri", tau=0.25)
	chirp = mix(tone(2600, 0.06, "sine", 3400, tau=0.03), at(tone(2800, 0.07, "sine", 3800, tau=0.04), 0.09))
	return mix(rise, at(chord, 0.32), at(chirp * 0.35, 0.5))


def noon():
	"""Buổi trưa nấu lẩu: nồi xèo xèo nhỏ dần + chuông bếp "ting ting"."""
	sizzle = noise(0.7, 0.35) * perc(int(SR * 0.7), tau=0.25) * 0.35
	bell = mix(tone(note_hz("G5"), 0.4, "tri", tau=0.15), at(tone(note_hz("D6"), 0.5, "tri", tau=0.25), 0.14))
	return mix(sizzle, at(bell, 0.12))


def evening():
	"""Chiều tối mở quán: chuông cửa hai nốt trầm ấm + arpeggio La trưởng đi lên như đèn quán bật lần lượt."""
	door = mix(tone(note_hz("E6"), 0.6, "sine", tau=0.25), at(tone(note_hz("C#6"), 0.7, "sine", tau=0.3), 0.15))
	lamps = arp(["A4", "C#5", "E5", "A5"], 0.09, "square", duty=0.125, tau=0.08, vol=0.6)
	return mix(door, at(lamps, 0.35))


def shop():
	"""Cửa hàng nâng cấp (rạng sáng hôm sau): tiếng đồng xu + hợp âm Mi thứ -> Sol trưởng nhẹ nhàng."""
	coin = mix(tone(note_hz("B5"), 0.06, "square", duty=0.25, tau=0.04), at(tone(note_hz("E6"), 0.3, "square", duty=0.25, tau=0.12), 0.06))
	chime = arp(["E5", "G5", "B5", "D6"], 0.1, "tri", tau=0.18)
	return mix(coin * 0.6, at(chime, 0.25))


if __name__ == "__main__":
	for name, make in (("morning", morning), ("noon", noon), ("evening", evening), ("shop", shop)):
		save("transition_" + name, make(), peak=0.7)
		print("transition_" + name + ".ogg")
