"""Tạo SFX + nhạc nền 8-bit cho Sôi Sùng Sục bằng code (tự tổng hợp, CC0, không dùng mẫu âm của ai).

Chạy:  python assets/audio/make_audio.py          (cần: pip install numpy soundfile)
Ghi ra assets/audio/sfx/<tên>.ogg và assets/audio/music/<tên>.ogg (mono 22050 Hz, Vorbis).
Không ghi đè các SFX gốc từ Kenney (hit, crit, defeat, explosion, loot, slice, splash).
Sửa âm: chỉnh hàm tương ứng bên dưới rồi chạy lại, mở Godot để nhập lại.
"""
import os
import random
import numpy as np
import soundfile as sf

SR = 22050
ROOT = os.path.dirname(os.path.abspath(__file__))
SFX_DIR = os.path.join(ROOT, "sfx")
MUSIC_DIR = os.path.join(ROOT, "music")
KEEP = {"hit", "crit", "defeat", "explosion", "loot", "slice", "splash"}
_rand = random.Random(1508)
_noise_seed = [0]


def _white(n):
	"""Nhiễu trắng -1..1 bằng hàm băm sin (không dùng numpy.random: máy nhóm có chính sách chặn DLL của nó)."""
	_noise_seed[0] += 1
	i = np.arange(n, dtype=np.float64) + _noise_seed[0] * 7919.0
	v = np.sin(i * 12.9898 + _noise_seed[0] * 78.233) * 43758.5453
	return (v - np.floor(v)) * 2.0 - 1.0


# --- Bộ tổng hợp -------------------------------------------------------------

def t_axis(dur):
	return np.arange(int(SR * dur)) / SR


def freq_curve(f0, f1, dur, curve=1.0):
	"""Tần số trượt từ f0 tới f1 (curve > 1: trượt chậm lúc đầu)."""
	k = np.linspace(0.0, 1.0, int(SR * dur)) ** curve
	return f0 + (f1 - f0) * k


def phase_of(freq):
	return np.cumsum(freq) / SR


def osc(kind, freq, duty=0.5):
	ph = phase_of(freq) % 1.0
	if kind == "square":
		return np.where(ph < duty, 1.0, -1.0)
	if kind == "tri":
		return 4.0 * np.abs(ph - 0.5) - 1.0
	if kind == "saw":
		return 2.0 * ph - 1.0
	return np.sin(2 * np.pi * ph)


def noise(dur, color=0.0):
	"""Nhiễu trắng; color 0..0.98 = lọc thông thấp một cực (càng lớn càng trầm)."""
	n = _white(int(SR * dur))
	return lowpass(n, color) if color > 0 else n


def lowpass(x, a):
	y = np.empty_like(x)
	acc = 0.0
	for i, v in enumerate(x):
		acc = a * acc + (1 - a) * v
		y[i] = acc
	return y / (np.max(np.abs(y)) + 1e-9)


def env(n, attack=0.005, decay=0.1, sustain=0.0, release=0.05, hold=0.0):
	"""ADSR theo số mẫu n (giây cho các tham số)."""
	a, d, h, r = (int(SR * v) for v in (attack, decay, hold, release))
	e = np.zeros(n)
	pos = 0
	for seg in (np.linspace(0, 1, a, endpoint=False), np.linspace(1, sustain, d, endpoint=False),
				np.full(h, sustain), np.linspace(sustain, 0, r)):
		take = min(len(seg), n - pos)
		e[pos:pos + take] = seg[:take]
		pos += take
		if pos >= n:
			break
	return e


def perc(n, attack=0.002, tau=0.08):
	"""Đường bao gõ: lên nhanh, tắt dần theo hàm mũ."""
	t = np.arange(n) / SR
	e = np.exp(-t / tau)
	a = max(1, int(SR * attack))
	e[:a] *= np.linspace(0, 1, a)
	return e


def tone(f0, dur, kind="square", f1=None, duty=0.5, tau=None, vib=0.0, vib_rate=6.0, curve=1.0):
	f = freq_curve(f0, f1 if f1 else f0, dur, curve)
	if vib:
		f = f * (1 + vib * np.sin(2 * np.pi * vib_rate * t_axis(dur)))
	x = osc(kind, f, duty)
	return x * (perc(len(x), tau=tau) if tau else env(len(x), decay=dur * 0.6, sustain=0.3, release=dur * 0.3))


def cat(*parts, gap=0.0):
	out = []
	for p in parts:
		out.append(p)
		if gap:
			out.append(np.zeros(int(SR * gap)))
	return np.concatenate(out)


def mix(*layers):
	n = max(len(l) for l in layers)
	out = np.zeros(n)
	for l in layers:
		out[:len(l)] += l
	return out


def at(x, delay):
	return np.concatenate([np.zeros(int(SR * delay)), x])


def note_hz(name):
	"""'C4', 'F#5', 'Bb3' -> Hz."""
	names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	k = names[name[0]]
	i = 1
	if name[i] == "#":
		k += 1
		i += 1
	elif name[i] == "b":
		k -= 1
		i += 1
	octave = int(name[i:])
	return 440.0 * 2 ** ((k + 12 * (octave + 1) - 69) / 12)


def arp(notes, step, kind="square", tau=0.08, duty=0.5, vol=1.0):
	return cat(*[tone(note_hz(n), step, kind, duty=duty, tau=tau) * vol for n in notes])


def save(name, x, folder=SFX_DIR, peak=0.85):
	if folder == SFX_DIR and name in KEEP:
		return
	x = np.asarray(x, dtype=np.float64)
	x = x / (np.max(np.abs(x)) + 1e-9) * peak
	fade = min(len(x), int(SR * 0.01))
	x[-fade:] *= np.linspace(1, 0, fade)
	os.makedirs(folder, exist_ok=True)
	sf.write(os.path.join(folder, name + ".ogg"), x.astype(np.float32), SR, format="OGG", subtype="VORBIS")


# --- SFX ---------------------------------------------------------------------

def make_sfx():
	n = lambda d, c=0.0: noise(d, c)
	# Chung
	save("click", tone(900, 0.05, "square", 600, duty=0.25, tau=0.02))
	save("good", cat(tone(988, 0.07, "square", duty=0.25, tau=0.05), tone(1319, 0.12, "square", duty=0.25, tau=0.08)))
	save("wrong", tone(160, 0.22, "square", 110, duty=0.4) * 0.8)
	save("pop", tone(400, 0.09, "sine", 1100, tau=0.04))
	# Săn / đánh
	save("bush", mix(*[at(n(0.09, 0.6) * perc(int(SR * 0.09), tau=0.03), k * 0.07) for k in range(4)]))
	save("battle_start", cat(arp(["C4", "E4", "G4", "C5"], 0.07, tau=0.06), tone(note_hz("G5"), 0.3, "square", duty=0.25, tau=0.15)))
	save("swing", n(0.14, 0.3) * env(int(SR * 0.14), attack=0.03, decay=0.08, release=0.03) * 0.7)
	save("dodge", mix(n(0.18, 0.5) * env(int(SR * 0.18), attack=0.02, decay=0.1), tone(500, 0.18, "sine", 1400, tau=0.1) * 0.4))
	save("heal", arp(["C5", "E5", "G5", "C6", "E6"], 0.06, "tri", tau=0.12))
	save("shield", mix(tone(1400, 0.35, "square", duty=0.125, tau=0.12) * 0.5, tone(2100, 0.35, "tri", tau=0.18) * 0.5))
	save("poison", cat(*[tone(f, 0.07, "square", f * 0.7, duty=0.3, tau=0.05) for f in (300, 240, 330, 200)]))
	save("burn", mix(n(0.45, 0.2) * perc(int(SR * 0.45), tau=0.2) * 0.6,
		*[at(n(0.02) * 0.9, _rand.uniform(0, 0.35)) for _ in range(9)]))
	save("spawn", cat(tone(300, 0.06, "square", 700, tau=0.05), tone(900, 0.1, "square", 1200, duty=0.25, tau=0.06)))
	save("boss", mix(tone(70, 0.9, "saw", 55, vib=0.08, vib_rate=9) * env(int(SR * 0.9), attack=0.05, decay=0.5, sustain=0.6, release=0.3),
		n(0.9, 0.85) * 0.5 * env(int(SR * 0.9), attack=0.1, decay=0.6, release=0.2)))
	save("victory", cat(arp(["C5", "C5", "C5"], 0.09, tau=0.07), tone(note_hz("C5"), 0.18, tau=0.1),
		tone(note_hz("Ab4"), 0.18, tau=0.1), tone(note_hz("Bb4"), 0.18, tau=0.1),
		tone(note_hz("C5"), 0.12, tau=0.08), tone(note_hz("Bb4"), 0.09, tau=0.06), tone(note_hz("C5"), 0.5, tau=0.3)))
	save("lose", cat(*[tone(note_hz(x), 0.22, "tri", tau=0.18) for x in ("G4", "F#4", "F4")], tone(note_hz("E4"), 0.7, "tri", vib=0.02, tau=0.5)))
	save("flee", cat(*[n(0.05, 0.4) * perc(int(SR * 0.05), tau=0.02) for _ in range(5)], gap=0.06))
	save("coin", cat(tone(1319, 0.06, "square", duty=0.25, tau=0.04), tone(1976, 0.25, "square", duty=0.25, tau=0.12)))
	# Bếp
	save("water", n(0.7, 0.55) * env(int(SR * 0.7), attack=0.05, decay=0.3, sustain=0.6, release=0.2) * 0.7)
	save("chop", mix(n(0.05, 0.1) * perc(int(SR * 0.05), tau=0.015), tone(220, 0.06, "sine", 120, tau=0.03)))
	save("stove", mix(n(0.5, 0.75) * env(int(SR * 0.5), attack=0.15, decay=0.2, sustain=0.5, release=0.15),
		tone(90, 0.5, "tri", 140, tau=0.3) * 0.4))
	save("bubble", cat(*[tone(f, 0.05, "sine", f * 1.8, tau=0.03) for f in (300, 380, 260, 420)], gap=0.04))
	save("ding", mix(tone(1568, 0.8, "sine", tau=0.35), tone(3136, 0.8, "sine", tau=0.2) * 0.3))
	save("fridge", mix(tone(120, 0.25, "square", 90, duty=0.3, tau=0.1) * 0.5, n(0.25, 0.8) * perc(int(SR * 0.25), tau=0.08)))
	# Quán
	save("door_bell", mix(tone(1319, 0.9, "sine", tau=0.3), at(tone(1047, 0.9, "sine", tau=0.4), 0.16)))
	save("seat", mix(tone(140, 0.12, "sine", 80, tau=0.05), n(0.06, 0.7) * perc(int(SR * 0.06), tau=0.02) * 0.5))
	save("serve", mix(tone(2093, 0.3, "tri", tau=0.08) * 0.6, tone(150, 0.1, "sine", 90, tau=0.04)))
	save("cash", cat(tone(2637, 0.05, "square", duty=0.25, tau=0.03), mix(tone(3136, 0.4, "square", duty=0.25, tau=0.15) * 0.7,
		at(n(0.2, 0.3) * perc(int(SR * 0.2), tau=0.05) * 0.5, 0.02))))
	save("angry", cat(tone(220, 0.18, "saw", 160, tau=0.12), tone(180, 0.3, "saw", 110, vib=0.05, tau=0.2)) * 0.7)
	save("sweep", cat(*[n(0.16, 0.25) * env(int(SR * 0.16), attack=0.05, decay=0.08, release=0.03) for _ in range(2)], gap=0.05) * 0.8)
	save("mop", cat(*[n(0.22, 0.65) * env(int(SR * 0.22), attack=0.06, decay=0.1, sustain=0.4, release=0.06) for _ in range(2)], gap=0.03))
	save("wipe", mix(n(0.2, 0.4) * env(int(SR * 0.2), attack=0.03, decay=0.12, release=0.05) * 0.6, tone(1800, 0.2, "tri", 2400, tau=0.08) * 0.25))
	save("bowl", mix(tone(1760, 0.35, "tri", tau=0.1), tone(2640, 0.35, "sine", tau=0.06) * 0.4))
	save("trash_in", cat(tone(500, 0.05, "square", 300, duty=0.3, tau=0.03), n(0.12, 0.5) * perc(int(SR * 0.12), tau=0.04)))
	save("critic", cat(arp(["E5", "G5", "B5"], 0.1, "square", duty=0.25, tau=0.08), tone(note_hz("E6"), 0.4, "square", duty=0.25, vib=0.02, tau=0.25)))
	save("whistle", cat(tone(2300, 0.15, "sine", 2600, vib=0.03, vib_rate=20) * env(int(SR * 0.15), attack=0.01, decay=0.1, sustain=0.8, release=0.03),
		tone(2600, 0.35, "sine", vib=0.04, vib_rate=25) * env(int(SR * 0.35), attack=0.01, decay=0.2, sustain=0.7, release=0.1), gap=0.05))
	save("star_up", arp(["G5", "C6", "E6"], 0.07, "square", duty=0.25, tau=0.08))
	save("star_down", arp(["E5", "C5", "G4"], 0.1, "tri", tau=0.1))


# --- Nhạc nền ----------------------------------------------------------------

def kick(n):
	d = n / SR
	return tone(160, d, "sine", 45, tau=0.08, curve=0.4)


def hat(n, open_=False):
	d = n / SR
	return noise(d) * perc(n, tau=0.05 if open_ else 0.015) * 0.35


def snare(n):
	d = n / SR
	return noise(d, 0.2) * perc(n, tau=0.06) * 0.6 + tone(200, d, "tri", 150, tau=0.04) * 0.3


def song(bpm, bars, chords, melody, bass_pattern, drum, lead="square", lead_duty=0.25, bass_kind="tri", vol_lead=0.32):
	"""chords: list hợp âm (mỗi ô nhịp 1 hợp âm, tên nốt gốc + 'm'?) ; melody: chuỗi nốt theo 1/8, '-' = nghỉ, '=' = ngân."""
	step = 60.0 / bpm / 2.0  # nốt móc đơn
	steps_per_bar = 8
	total = int(SR * step * steps_per_bar * bars)
	out = np.zeros(total + SR)
	ns = int(SR * step)
	# Melody
	i = 0
	tokens = melody.split()
	while i < len(tokens):
		tok = tokens[i]
		length = 1
		while i + length < len(tokens) and tokens[i + length] == "=":
			length += 1
		if tok not in ("-", "="):
			x = tone(note_hz(tok), step * length * 0.95, lead, duty=lead_duty, tau=step * length * 0.7, vib=0.004)
			pos = i * ns
			if pos >= total:
				break
			x = x[:len(out) - pos]
			out[pos:pos + len(x)] += x * vol_lead
		i += length
	# Bass + hợp âm rải nhẹ + trống
	for b in range(bars):
		root = chords[b % len(chords)]
		minor = root.endswith("m")
		base = note_hz(root.rstrip("m") + "2")
		third = base * (2 ** ((3 if minor else 4) / 12))
		fifth = base * (2 ** (7 / 12))
		for s in range(steps_per_bar):
			pos = (b * steps_per_bar + s) * ns
			bp = bass_pattern[s]
			if bp != "-":
				f = {"1": base, "5": fifth, "8": base * 2, "3": third}[bp]
				x = tone(f, step * 0.9, bass_kind, tau=step * 0.6) * 0.5
				out[pos:pos + len(x)] += x
			# Hợp âm rải (tam giác, quãng 8 trên) cho đầy tiếng.
			chord_f = [base * 4, third * 4, fifth * 4][s % 3]
			x = tone(chord_f, step * 0.8, "tri", tau=step * 0.3) * 0.09
			out[pos:pos + len(x)] += x
			d = drum[s]
			if "k" in d:
				x = kick(ns * 2) * 0.55
				out[pos:pos + len(x)] += x
			if "s" in d:
				x = snare(ns)
				out[pos:pos + len(x)] += x
			if "h" in d:
				x = hat(ns)
				out[pos:pos + len(x)] += x
	out = out[:total]
	# Đuôi vòng lặp: cộng phần ngân dư vào đầu để nối liền mạch.
	return out


def make_music():
	# Menu / cửa hàng: vui, nhẹ (C trưởng, 112 bpm).
	save("menu", song(112, 8, ["C", "Am", "F", "G"],
		"E5 = G5 E5 D5 = C5 - | E5 = G5 A5 G5 = - - | A5 = G5 E5 F5 = E5 D5 | D5 = E5 D5 C5 = - - | "
		"E5 = G5 E5 D5 = C5 - | E5 = G5 A5 C6 = - - | A5 = G5 E5 F5 E5 D5 = | C5 = = = - - - -".replace("| ", ""),
		["1", "-", "5", "-", "8", "-", "5", "-"], ["kh", "h", "sh", "h", "kh", "h", "sh", "h"]), MUSIC_DIR, 0.7)
	# Đi săn: phiêu lưu, nảy (G trưởng, 132 bpm).
	save("hunt", song(132, 8, ["G", "Em", "C", "D"],
		"G4 B4 D5 = B4 D5 G5 = E5 = D5 B4 G4 = - - C5 E5 G5 = E5 = D5 C5 D5 = F#5 = A5 = - - "
		"G4 B4 D5 = B4 D5 G5 = E5 = G5 E5 D5 = B4 - C5 = E5 C5 D5 = A4 = G4 = = = - - - -",
		["1", "-", "8", "1", "5", "-", "8", "5"], ["kh", "h", "sh", "kh", "kh", "h", "sh", "h"]), MUSIC_DIR, 0.7)
	# Đánh nhau: dồn dập, thứ (A thứ, 150 bpm).
	save("battle", song(150, 8, ["Am", "F", "G", "Em"],
		"A4 = C5 E5 A5 = G5 E5 F5 = A5 F5 C5 = - - G5 = B5 G5 D5 = B4 D5 E5 = G5 E5 B4 = - - "
		"A4 = C5 E5 A5 = C6 A5 F5 = A5 C6 F5 = E5 F5 G5 = F5 E5 D5 = B4 D5 E5 = = = - - E5 -",
		["1", "1", "8", "1", "1", "1", "8", "5"], ["kh", "h", "skh", "h", "kh", "kh", "sh", "h"],
		lead="square", lead_duty=0.5, bass_kind="saw", vol_lead=0.26), MUSIC_DIR, 0.7)
	# Bếp: đều tay, nhẹ nhàng (F trưởng, 104 bpm).
	save("cook", song(104, 8, ["F", "Dm", "Bb", "C"],
		"C5 - A4 C5 F5 = E5 C5 D5 - F5 = A5 = G5 F5 D5 = Bb4 D5 F5 = E5 D5 C5 = E5 = G5 = - - "
		"C5 - A4 C5 F5 = A5 C6 Bb5 = A5 G5 F5 = D5 - D5 = F5 D5 C5 = Bb4 = A4 = = = - - - -",
		["1", "-", "5", "-", "1", "3", "5", "-"], ["k", "h", "s", "h", "k", "h", "s", "hh"], lead_duty=0.125), MUSIC_DIR, 0.7)
	# Quán đông khách: rộn ràng (D trưởng, 124 bpm).
	save("sell", song(124, 8, ["D", "Bm", "G", "A"],
		"F#5 = A5 F#5 E5 D5 E5 F#5 D5 = F#5 B5 A5 = F#5 - G5 = B5 G5 D5 = G5 B5 A5 = C#6 A5 E5 = - - "
		"F#5 = A5 F#5 E5 D5 E5 F#5 B5 = A5 F#5 D5 = B4 D5 G5 = F#5 E5 D5 = B4 G4 A4 = C#5 E5 D5 = = -",
		["1", "-", "5", "8", "1", "-", "5", "8"], ["kh", "h", "sh", "h", "kh", "kh", "sh", "h"]), MUSIC_DIR, 0.7)


if __name__ == "__main__":
	make_sfx()
	make_music()
	for folder in (SFX_DIR, MUSIC_DIR):
		files = sorted(f for f in os.listdir(folder) if f.endswith(".ogg"))
		size = sum(os.path.getsize(os.path.join(folder, f)) for f in files)
		print(f"{os.path.basename(folder)}: {len(files)} file, {size // 1024} KB")
