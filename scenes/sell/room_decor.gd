class_name RoomDecor
extends Control
## Đồ trang trí nhà hàng đổi theo cấp Nội thất (RestaurantDecor): đèn treo, rèm cửa sổ, chậu cây, thảm lối đi.
## Vẽ theo lưới điểm ảnh của nền (1 điểm ảnh nền = 4 px), toạ độ theo sân khấu 1280x720 của màn bán.
## Nằm trên nền, dưới bàn và nhân vật. Dây đèn trang trí (cấp cao) nằm ở lớp FairyLights riêng phía trên ánh sáng.

const PX := 4.0
const LAMP_X := [38, 100, 172] ## Cột (điểm ảnh nền) của các đèn treo, giữa cửa/cửa sổ/ô cửa bếp.
const WINDOWS := [Rect2i(46, 22, 43, 35), Rect2i(112, 22, 43, 35)] ## Khung 2 cửa sổ (điểm ảnh nền).
const PLANTS := [Vector2i(176, 81), Vector2i(311, 81)] ## Gốc chậu cây (giữa đáy chậu) trên sàn, sát chân tường.
const CARPET_ROWS := Vector2i(82, 88) ## Thảm lối đi từ cửa vào (hàng điểm ảnh nền).
const CORD := Color("2e1a10")
const RED := Color("c4342b")
const RED_DARK := Color("8c201c")
const RED_LIGHT := Color("e86048")
const GOLD := Color("f2c14e")
const GOLD_DARK := Color("b8862a")

var _fur: Dictionary


func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = MOUSE_FILTER_IGNORE
	_fur = RestaurantDecor.furniture()


## Tâm (px màn hình) các đèn, để lớp ánh sáng thêm vầng sáng đúng chỗ.
static func lamp_centers() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var low: bool = RestaurantDecor.furniture()["lamp"] == "bulb"
	for x in LAMP_X:
		result.append(Vector2(x + 0.5, 27 if low else 31) * PX)
	return result


func _p(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x * PX, y * PX, w * PX, h * PX), c)


func _draw() -> void:
	var carpet: Color = _fur["carpet"]
	if carpet.a > 0.0:
		_draw_carpet(carpet)
	var curtain: Color = _fur["curtain"]
	if curtain.a > 0.0:
		for w in WINDOWS:
			_draw_curtain(w, curtain)
	for x in LAMP_X:
		match str(_fur["lamp"]):
			"bulb":
				_draw_bulb(x)
			"gold":
				_draw_lantern(x, GOLD, GOLD_DARK, Color("fff1b0"), RED)
			_:
				_draw_lantern(x, RED, RED_DARK, RED_LIGHT, GOLD)
	if _fur["plants"]:
		for p in PLANTS:
			_draw_plant(p)


func _draw_bulb(x: int) -> void:
	_p(x, 9, 1, 15, CORD)
	_p(x - 1, 24, 3, 1, Color("5a4a3a"))
	_p(x - 1, 25, 3, 2, Color("fff3c4"))
	_p(x, 27, 1, 1, Color("ffe08a"))


func _draw_lantern(x: int, body: Color, dark: Color, light: Color, cap: Color) -> void:
	_p(x, 9, 1, 15, CORD)
	_p(x - 3, 24, 7, 2, cap)
	_p(x - 4, 26, 9, 10, body)
	_p(x - 5, 27, 11, 8, body)
	_p(x - 2, 26, 1, 10, dark)
	_p(x + 2, 26, 1, 10, dark)
	_p(x - 4, 28, 1, 5, light)
	_p(x - 3, 36, 7, 2, cap)
	_p(x, 38, 1, 5, body if body != GOLD else RED)
	_p(x - 1, 42, 3, 1, dark)


func _draw_curtain(w: Rect2i, c: Color) -> void:
	var dark := c.darkened(0.3)
	var trim: Color = _fur["trim"]
	# Diềm trên + 2 tấm rèm buộc hai bên.
	_p(w.position.x - 3, w.position.y - 2, w.size.x + 6, 4, c)
	for i in int((w.size.x + 6) / 4.0):
		_p(w.position.x - 3 + i * 4, w.position.y + 2, 2, 1, dark)
	for side in [w.position.x - 3, w.end.x - 3]:
		_p(side, w.position.y + 2, 6, w.size.y - 2, c)
		_p(side + 2, w.position.y + 2, 1, w.size.y - 2, dark)
		_p(side + 4, w.position.y + 2, 1, w.size.y - 2, dark)
		_p(side - 1, w.position.y + 18, 8, 2, trim if trim.a > 0.0 else dark)
	if trim.a > 0.0:
		_p(w.position.x - 3, w.position.y + 1, w.size.x + 6, 1, trim)


func _draw_plant(base: Vector2i) -> void:
	var leaf := Color("3f8a3a")
	var leaf_dark := Color("2c6128")
	var leaf_light := Color("6cb24a")
	_p(base.x - 4, base.y - 6, 8, 6, Color("b5562c"))
	_p(base.x - 5, base.y - 7, 10, 2, Color("d0703c"))
	_p(base.x - 3, base.y - 1, 6, 1, Color("7a3518"))
	_p(base.x - 5, base.y - 16, 10, 9, leaf)
	_p(base.x - 3, base.y - 20, 6, 4, leaf)
	_p(base.x - 7, base.y - 13, 3, 4, leaf_dark)
	_p(base.x + 4, base.y - 14, 3, 5, leaf_dark)
	_p(base.x - 2, base.y - 18, 2, 3, leaf_light)
	_p(base.x + 1, base.y - 12, 2, 2, leaf_light)


func _draw_carpet(c: Color) -> void:
	var trim: Color = _fur["trim"]
	var edge := trim if trim.a > 0.0 else c.darkened(0.3)
	var y0 := CARPET_ROWS.x
	var h := CARPET_ROWS.y - CARPET_ROWS.x
	_p(8, y0, 320, h, c)
	_p(8, y0, 320, 1, edge)
	_p(8, y0 + h - 1, 320, 1, edge)
	for i in 40:
		_p(12 + i * 8, y0 + 3, 2, 1, c.lightened(0.15))


## Dây đèn trang trí chạy ngang tường (cấp Nội thất cao), lấp lánh và luôn sáng (nằm trên lớp ánh sáng).
class FairyLights extends Control:
	var _time := 0.0

	func _init() -> void:
		size = Vector2(1280, 720)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var px := RoomDecor.PX
		# Hai đoạn võng: cửa ra vào -> giữa, giữa -> ô cửa bếp.
		for seg in [Vector2(2, 96), Vector2(96, 188)]:
			var prev := Vector2.ZERO
			for i in 23:
				var t := i / 22.0
				var x := lerpf(seg.x, seg.y, t)
				var y := 23.0 + sin(t * PI) * 4.0
				var p := Vector2(x, y) * px
				if i > 0:
					draw_line(prev, p, Color("2e1a10"), 2.0)
				prev = p
				if i % 2 == 0:
					var tw := 0.6 + 0.4 * sin(_time * 3.0 + i * 1.7 + seg.x)
					var col := [Color("ffd54f"), Color("ff8a65"), Color("fff59d")][(i / 2) % 3] as Color
					draw_rect(Rect2(p + Vector2(-4, 2), Vector2(8, 8)), Color(col, 0.25 * tw))
					draw_rect(Rect2(p + Vector2(-2, 4), Vector2(4, 4)), Color(col, tw))
