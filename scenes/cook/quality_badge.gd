class_name QualityBadge
extends Control
## Huy hiệu pixel cho chất lượng đồ sơ chế, vẽ bằng code trên lưới 18×20 ô (mỗi ô = `px` điểm ảnh, không cần file ảnh):
## - Thượng hạng (2): huy chương vàng, dây đỏ / xanh, ngôi sao giữa, tia lấp lánh nhấp nháy xung quanh.
## - Thường (1): huy chương đồng cam, dây xanh, vòng tròn giữa.
## - Kém (0): đĩa xám bị nứt, không dây, vệt mùi xanh lượn bốc lên.

const GRID := Vector2i(18, 20)
const DISC_CENTER := Vector2(9.5, 13.5) ## Tâm đĩa (đơn vị ô); lệch nửa ô để đĩa 11 ô đối xứng quanh cột 9.
const DISC_RADIUS := 5.5
const PALETTES := [
	{"outline": Color("3f3a33"), "main": Color("9b9184"), "light": Color("c4bcb0"), "shade": Color("6f665b")},
	{"outline": Color("6b3d17"), "main": Color("e7a35a"), "light": Color("f9d3a2"), "shade": Color("b06f2e")},
	{"outline": Color("7a4a10"), "main": Color("f5c542"), "light": Color("fff1a8"), "shade": Color("c98a1b")},
]
const RIBBON_LEFT := [[5, 6], [5, 6], [6, 7], [7, 8], [8, 9]] ## Cột của dây trái, từ hàng 3 xuống hàng 7.
const RIBBON_COLORS := [[], [Color("3d6fb0"), Color("3d6fb0")], [Color("c62828"), Color("1e5fa8")]]
const STAR := ["..x..", ".xxx.", "xxxxx", ".xxx.", ".x.x."] ## Ngôi sao 5×5 giữa huy chương vàng.
const CRACK := [Vector2i(8, 9), Vector2i(9, 10), Vector2i(9, 11), Vector2i(10, 12), Vector2i(9, 13), Vector2i(10, 14), Vector2i(11, 15)]
const SPARKLES := [Vector2i(2, 8), Vector2i(15, 5), Vector2i(16, 15), Vector2i(1, 17)]
const SPARKLE_COLOR := Color("fff6c0")
const STINK_COLOR := Color("8bab4f")

var grade := 1
var px := 4.0
var _time := 0.0


## `quality_grade`: 0 Kém, 1 Thường, 2 Thượng hạng; `pixel`: cỡ một ô (4 -> huy hiệu 72×80).
func _init(quality_grade: int, pixel := 4.0) -> void:
	grade = clampi(quality_grade, 0, 2)
	px = pixel
	custom_minimum_size = Vector2(GRID) * px
	mouse_filter = MOUSE_FILTER_IGNORE


## Godot tự bật _process khi node vào cây nếu script có _process, nên phải tắt ở đây chứ không phải trong _init.
func _ready() -> void:
	set_process(grade != 1)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pal: Dictionary = PALETTES[grade]
	if grade >= 1:
		_draw_ribbon(RIBBON_COLORS[grade])
	_draw_disc(pal)
	match grade:
		2:
			_draw_pattern(STAR, Vector2i(7, 11), pal["light"])
			_draw_sparkles()
		1:
			_draw_inner_ring(pal["shade"])
		0:
			for cell in CRACK:
				_cell(cell.x, cell.y, pal["outline"])
			_draw_stink()


## Tô một ô của lưới.
func _cell(x: int, y: int, color: Color) -> void:
	draw_rect(Rect2(Vector2(x, y) * px, Vector2(px, px)), color)


## Hai dây đeo hình chữ V phía trên đĩa (dây phải là ảnh gương của dây trái qua cột 9,5).
func _draw_ribbon(colors: Array) -> void:
	for i in RIBBON_LEFT.size():
		for x in RIBBON_LEFT[i]:
			_cell(x, 3 + i, colors[0])
			_cell(GRID.x + 1 - x, 3 + i, colors[1])


## Đĩa tròn: ô có tâm cách tâm đĩa d <= R. Viền khi d > R − 1; sáng ở góc trên-trái, tối ở góc dưới-phải.
func _draw_disc(pal: Dictionary) -> void:
	for y in GRID.y:
		for x in GRID.x:
			var off := Vector2(x + 0.5, y + 0.5) - DISC_CENTER
			var d := off.length()
			if d > DISC_RADIUS:
				continue
			var color: Color = pal["main"]
			if d > DISC_RADIUS - 1.0:
				color = pal["outline"]
			elif off.x + off.y < -3.0:
				color = pal["light"]
			elif off.x + off.y > 3.0:
				color = pal["shade"]
			_cell(x, y, color)


## Vòng tròn nhỏ giữa huy chương Thường: ô có 1,6 < d < 2,6.
func _draw_inner_ring(color: Color) -> void:
	for y in GRID.y:
		for x in GRID.x:
			var d := (Vector2(x + 0.5, y + 0.5) - DISC_CENTER).length()
			if d > 1.6 and d < 2.6:
				_cell(x, y, color)


## Vẽ hình theo lưới chữ ('x' là ô tô màu) bắt đầu từ ô `origin`.
func _draw_pattern(rows: Array, origin: Vector2i, color: Color) -> void:
	for r in rows.size():
		var row: String = rows[r]
		for c in row.length():
			if row[c] == "x":
				_cell(origin.x + c, origin.y + r, color)


## Tia lấp lánh hình dấu cộng; mỗi tia nhấp nháy lệch pha nhau: hiện khi sin > 0, tỏa 4 cánh khi sin > 0,6.
func _draw_sparkles() -> void:
	for i in SPARKLES.size():
		var s := sin(_time * 4.0 + i * 1.7)
		if s <= 0.0:
			continue
		var p: Vector2i = SPARKLES[i]
		_cell(p.x, p.y, SPARKLE_COLOR)
		if s > 0.6:
			for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				_cell(p.x + dir.x, p.y + dir.y, SPARKLE_COLOR)


## Hai vệt mùi lượn sóng bốc lên trên đĩa Kém: x = gốc + round(sin((y + t×6) × 0,9)).
func _draw_stink() -> void:
	for base: int in [7, 12]:
		for y in range(1, 7):
			var x := base + roundi(sin((y + _time * 6.0 + base) * 0.9))
			_cell(x, y, Color(STINK_COLOR, 0.35 + 0.1 * y))
