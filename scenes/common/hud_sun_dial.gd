class_name HudSunDial
extends Control
## Đồng hồ mặt trời: mặt trời mọc lúc đi săn, lên đỉnh lúc nấu, lặn khi bán xong.
## Mặt trời lặn bên phải thì trăng mọc dần từ bên trái theo cùng đường cung.
## progress: 0 = bình minh, 0.5 = trưa, 1 = hoàng hôn, 1.5 = trăng lên đỉnh, 2 = trăng lặn.

const PX := 3.0 ## Kích thước 1 "điểm ảnh" khi vẽ, cho hợp phong cách pixel.

const SKY_DAWN := Color("f2a65e")
const SKY_DAY := Color("7cc6e6")
const SKY_GOLD := Color("f7c06a")
const SKY_DUSK := Color("d9664f")
const SKY_NIGHT := Color("1d2547")
const HILL_FAR := Color("4f7a55")
const HILL_NEAR := Color("355c3d")
const SUN := Color("ffd44a")
const SUN_LOW := Color("ff8a3a")
const SUN_CORE := Color("fff3b8")
const MOON := Color("eef0d8")
const FRAME := Color("12191d")

var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()

var _time := 0.0


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(204, 66)
	clip_contents = true


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), _sky_color())
	_draw_stars(_night_amount())
	var horizon := h - 4 * PX
	var center := Vector2(w / 2.0, horizon)
	var rx := w / 2.0 - 7 * PX
	var ry := horizon - 7 * PX
	_draw_arc_path(center, rx, ry)
	# Mặt trời chìm hẳn xuống sau đồi một chút sau hoàng hôn.
	if progress < 1.15:
		var t := clampf(progress, 0.0, 1.15)
		_draw_sun(_arc_pos(center, rx, ry, t), sin(PI * clampf(t, 0.0, 1.0)))
	# Trăng nhô lên từ bên trái ngay lúc mặt trời sắp lặn.
	var m := progress - 0.95
	if m > -0.1:
		_draw_moon(_arc_pos(center, rx, ry, clampf(m, -0.1, 1.0)))
	_draw_hills(horizon)
	draw_rect(Rect2(Vector2.ZERO, size), FRAME, false, 2.0)


## Vị trí trên cung: 0 = chân trời trái, 0.5 = đỉnh, 1 = chân trời phải (ngoài 0..1 thì chìm dưới đồi).
func _arc_pos(center: Vector2, rx: float, ry: float, t: float) -> Vector2:
	return center + Vector2(-cos(PI * t) * rx, -sin(PI * t) * ry)


## 0 = ngày, 1 = đêm hẳn. Gần 6h sáng trời hửng dần.
func _night_amount() -> float:
	var dusk := clampf((progress - 1.0) / 0.25, 0.0, 1.0)
	var dawn := clampf((progress - 1.8) / 0.2, 0.0, 1.0)
	return dusk * (1.0 - dawn * 0.7)


func _sky_color() -> Color:
	if progress >= 1.8:
		return SKY_DAWN.lerp(SKY_NIGHT, _night_amount())
	if progress >= 1.0:
		return SKY_DUSK.lerp(SKY_NIGHT, _night_amount())
	var t := clampf(progress, 0.0, 1.0)
	if t < 0.2:
		return SKY_DAWN.lerp(SKY_DAY, t / 0.2)
	if t > 0.88:
		return SKY_GOLD.lerp(SKY_DUSK, (t - 0.88) / 0.12)
	if t > 0.7:
		return SKY_DAY.lerp(SKY_GOLD, (t - 0.7) / 0.18)
	return SKY_DAY


## Đường chấm mờ vẽ quỹ đạo mặt trời.
func _draw_arc_path(center: Vector2, rx: float, ry: float) -> void:
	var c := Color(1, 1, 1, 0.28)
	for i in 13:
		var a := PI * i / 12.0
		var p := center + Vector2(-cos(a) * rx, -sin(a) * ry)
		_pixel(p, c)


func _draw_sun(pos: Vector2, height: float) -> void:
	var col := SUN_LOW.lerp(SUN, clampf(height * 1.6, 0.0, 1.0))
	# Tia nắng xoay chậm.
	for k in 8:
		var a := _time * 0.8 + k * TAU / 8.0
		_pixel(pos + Vector2(cos(a), sin(a)) * 6.5 * PX, col)
	_disc(pos, 4.2, col)
	_disc(pos + Vector2(-PX, -PX), 2.0, SUN_CORE)


func _draw_moon(pos: Vector2) -> void:
	var r := 4.2
	var cut := Vector2(2, -1)
	var n := int(ceil(r))
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var v := Vector2(x, y)
			if v.length() <= r and (v - cut).length() > 3.6:
				_pixel(pos + v * PX, MOON)


func _draw_stars(amount: float) -> void:
	if amount <= 0.0:
		return
	var spots := [Vector2(0.12, 0.25), Vector2(0.3, 0.15), Vector2(0.45, 0.4), Vector2(0.58, 0.2), Vector2(0.88, 0.3), Vector2(0.22, 0.55), Vector2(0.75, 0.12)]
	for i in spots.size():
		var s: Vector2 = spots[i]
		var blink := 0.5 + 0.5 * sin(_time * 2.0 + i * 1.7)
		_pixel(Vector2(s.x * size.x, s.y * size.y), Color(1, 1, 0.85, (0.35 + 0.65 * blink) * amount))


## Đồi phía trước che phần dưới chân trời.
func _draw_hills(horizon: float) -> void:
	var w := size.x
	var dark := _night_amount() * 0.5
	var far := HILL_FAR.darkened(dark)
	var near := HILL_NEAR.darkened(dark)
	var cols := int(ceil(w / PX))
	for i in cols:
		var x := i * PX
		var hf := 2.0 + 1.5 * sin(i * 0.22) + 1.0 * sin(i * 0.53 + 1.0)
		var hn := 1.0 + 1.2 * sin(i * 0.31 + 2.0)
		var top_far := horizon - roundf(hf) * PX
		var top_near := horizon + 2 * PX - roundf(hn) * PX
		draw_rect(Rect2(x, top_far, PX, size.y - top_far), far)
		draw_rect(Rect2(x, top_near, PX, size.y - top_near), near)


func _pixel(p: Vector2, c: Color) -> void:
	draw_rect(Rect2(p.snapped(Vector2(PX, PX)), Vector2(PX, PX)), c)


## Hình tròn vẽ theo ô pixel (bán kính tính bằng số ô).
func _disc(center: Vector2, r: float, c: Color) -> void:
	var n := int(ceil(r))
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			if Vector2(x, y).length() <= r:
				_pixel(center + Vector2(x, y) * PX, c)
