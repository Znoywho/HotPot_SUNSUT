class_name CleanTools
extends RefCounted
## Dụng cụ dọn dẹp của màn bán (vẽ pixel, không cần ảnh):
## - "broom": chổi + hốt rác, quét rác dưới sàn.
## - "mop": cây lau nhà, lau vũng nước dưới sàn.
## - "cloth": khăn lau bàn, dọn bàn khách vừa ăn xong.
## Dùng trong các trò của bảng Dọn dẹp (CleanGame): dụng cụ đi theo ngón tay.

const NAMES := {"broom": "Chổi + hốt rác", "mop": "Cây lau nhà", "cloth": "Khăn lau bàn"}
const ICON_PX := 4.0 ## 1 điểm ảnh dụng cụ = 4 px (khung 16x16 điểm ảnh = 64 px).

const WOOD := Color("9a6a3c")
const WOOD_DARK := Color("6b4423")
const STRAW := Color("e8c56a")
const STRAW_DARK := Color("b8913a")
const BAND := Color("c4342b")
const PAN := Color("3f7fc4")
const PAN_LIGHT := Color("7fb3e8")
const PAN_DARK := Color("2a5a8f")
const MOP := Color("e6e6e0")
const MOP_DARK := Color("a8a8a0")
const CLOTH := Color("4fa3e0")
const CLOTH_LIGHT := Color("9ccff2")
const CLOTH_DARK := Color("2f6f9e")


static func tool_name(tool: String) -> String:
	return NAMES.get(tool, tool)


## Ô pixel (x, y theo điểm ảnh dụng cụ, gốc ở `origin`).
static func _p(ci: CanvasItem, origin: Vector2, px: float, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(origin.x + x * px, origin.y + y * px, w * px, h * px), c)


## Đường pixel (cán chổi, cán lau nhà).
static func _line(ci: CanvasItem, origin: Vector2, px: float, a: Vector2, b: Vector2, c: Color) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for s in steps + 1:
		var q := a.lerp(b, float(s) / maxf(steps, 1)).round()
		_p(ci, origin, px, q.x, q.y, 1, 1, c)


## Vẽ dụng cụ, tâm ở `center`. part: "all" / "broom_only" / "pan_only" (để Fx cho chổi chuyển động riêng).
static func draw_tool(ci: CanvasItem, tool: String, center: Vector2, px := ICON_PX, part := "all") -> void:
	match tool:
		"broom":
			if part != "pan_only":
				_draw_broom(ci, center + Vector2(-2, 0) * px, px)
			if part != "broom_only":
				_draw_pan(ci, center + Vector2(4, 0) * px, px)
		"mop":
			_draw_mop(ci, center, px)
		_:
			_draw_cloth(ci, center, px)


static func _draw_broom(ci: CanvasItem, o: Vector2, px: float) -> void:
	_line(ci, o, px, Vector2(4, -8), Vector2(-1, 1), WOOD)
	_line(ci, o, px, Vector2(5, -8), Vector2(0, 1), WOOD_DARK)
	_p(ci, o, px, -2, 1, 4, 1, BAND)
	# Đầu chổi rơm loe ra.
	_p(ci, o, px, -3, 2, 5, 2, STRAW)
	_p(ci, o, px, -4, 4, 7, 2, STRAW)
	_p(ci, o, px, -5, 6, 8, 2, STRAW)
	for k in 4:
		_p(ci, o, px, -4 + k * 2, 5, 1, 3, STRAW_DARK)


static func _draw_pan(ci: CanvasItem, o: Vector2, px: float) -> void:
	_p(ci, o, px, 0, -4, 1, 7, WOOD_DARK)
	_p(ci, o, px, -3, 3, 6, 1, PAN_DARK)
	_p(ci, o, px, -3, 4, 6, 3, PAN)
	_p(ci, o, px, -3, 4, 6, 1, PAN_LIGHT)
	_p(ci, o, px, -4, 7, 8, 1, PAN_DARK)


static func _draw_mop(ci: CanvasItem, o: Vector2, px: float) -> void:
	_p(ci, o, px, 0, -8, 1, 11, WOOD)
	_p(ci, o, px, 1, -8, 1, 11, WOOD_DARK)
	_p(ci, o, px, -4, 3, 10, 2, MOP_DARK)
	for k in 5:
		var c := MOP if k % 2 == 0 else MOP_DARK
		_p(ci, o, px, -4 + k * 2, 5, 2, 2 + (k % 2), c)
	_p(ci, o, px, -3, 4, 8, 1, Color.WHITE)


static func _draw_cloth(ci: CanvasItem, o: Vector2, px: float) -> void:
	# Khăn gấp đôi + vài giọt nước.
	_p(ci, o, px, -5, -3, 10, 7, CLOTH)
	_p(ci, o, px, -5, -3, 10, 1, CLOTH_LIGHT)
	_p(ci, o, px, -5, 1, 10, 1, CLOTH_DARK)
	_p(ci, o, px, -5, 4, 10, 1, CLOTH_DARK)
	_p(ci, o, px, 3, -3, 1, 8, CLOTH_DARK)
	_p(ci, o, px, -3, -6, 1, 1, CLOTH_LIGHT)
	_p(ci, o, px, 1, -7, 1, 1, CLOTH_LIGHT)
	_p(ci, o, px, -1, -5, 1, 1, CLOTH_LIGHT)
