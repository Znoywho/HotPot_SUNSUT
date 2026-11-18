class_name FloorMess
extends Control
## Một chỗ bẩn dưới sàn quán, vẽ pixel 4 px:
## - "trash": rác (khăn giấy vo, vỏ chai, xương, giấy gói đũa) -> quét vào hốt rác.
## - "puddle": vũng nước đổ -> lau bằng cây lau nhà.
## Vùng chạm >= 56 px (dễ bấm trên điện thoại). Chạm -> `tapped` (màn bán mở bảng Dọn dẹp), xong thì `finish()` biến mất.

signal tapped(mess: FloorMess)

const PX := 4.0
const TRASH_KINDS := ["napkin", "bottle", "bone", "wrapper"]

var kind := "trash"
var look := "napkin"
var cleaning := false
var _gone := false


func _init(mess_kind := "trash") -> void:
	kind = mess_kind
	look = TRASH_KINDS[randi() % TRASH_KINDS.size()] if kind == "trash" else "water"
	size = hit_size(kind)
	custom_minimum_size = size
	pivot_offset = size / 2.0
	mouse_filter = MOUSE_FILTER_STOP
	if kind == "trash":
		rotation = randf_range(-0.4, 0.4)


static func hit_size(mess_kind: String) -> Vector2:
	return Vector2(80, 56) if mess_kind == "puddle" else Vector2(56, 56)


func label() -> String:
	return "Vũng nước" if kind == "puddle" else "Rác"


func _ready() -> void:
	scale = Vector2(0.3, 0.3)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if _gone or cleaning:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		tapped.emit(self)


func finish() -> void:
	if _gone:
		return
	_gone = true
	mouse_filter = MOUSE_FILTER_IGNORE
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector2(0.2, 0.2), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.chain().tween_callback(queue_free)


func is_gone() -> bool:
	return _gone


## Ô pixel (x, y theo điểm ảnh gốc, gốc là tâm vùng chạm).
func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(size.x / 2.0 + x * PX, size.y / 2.0 + y * PX, w * PX, h * PX), c)


func _draw() -> void:
	if kind == "puddle":
		# Vũng nước loang, có viền đậm và vệt sáng phản chiếu.
		_px(-7, -2, 14, 5, Color(0.25, 0.5, 0.75, 0.55))
		_px(-8, -1, 16, 3, Color(0.25, 0.5, 0.75, 0.55))
		_px(-5, -3, 9, 1, Color(0.25, 0.5, 0.75, 0.55))
		_px(-6, -1, 12, 3, Color(0.45, 0.72, 0.92, 0.6))
		_px(-4, -1, 3, 1, Color(0.9, 0.97, 1.0, 0.8))
		_px(2, 1, 2, 1, Color(0.9, 0.97, 1.0, 0.7))
		_px(9, 0, 1, 1, Color(0.45, 0.72, 0.92, 0.6))
		_px(-10, 1, 1, 1, Color(0.45, 0.72, 0.92, 0.6))
		return
	FloorMess.draw_trash(self, look, size / 2.0, PX)


## Vẽ 1 mẩu rác pixel, tâm ở `c` (dùng chung với trò quét rác trong bảng Dọn dẹp).
static func draw_trash(ci: CanvasItem, look_id: String, c: Vector2, px: float) -> void:
	var b := func(x: float, y: float, w: float, h: float, col: Color) -> void:
		ci.draw_rect(Rect2(c.x + x * px, c.y + y * px, w * px, h * px), col)
	b.call(-4, 2, 8, 1, Color(0, 0, 0, 0.25))
	match look_id:
		"napkin":
			b.call(-3, -2, 6, 4, Color("e8e2d4"))
			b.call(-2, -3, 4, 1, Color("f7f3ea"))
			b.call(-3, 0, 2, 1, Color("bdb5a4"))
			b.call(1, -1, 2, 1, Color("bdb5a4"))
			b.call(-1, 1, 3, 1, Color("cfc7b6"))
		"bottle":
			b.call(-4, -1, 6, 3, Color("3f8f4a"))
			b.call(-4, -1, 6, 1, Color("6cc27a"))
			b.call(2, 0, 2, 1, Color("3f8f4a"))
			b.call(4, 0, 1, 1, Color("d9a441"))
		"bone":
			b.call(-3, -1, 6, 2, Color("efe3c2"))
			b.call(-4, -2, 2, 2, Color("efe3c2"))
			b.call(-4, 0, 2, 2, Color("efe3c2"))
			b.call(2, -2, 2, 2, Color("efe3c2"))
			b.call(2, 0, 2, 2, Color("efe3c2"))
			b.call(-2, 0, 4, 1, Color("c9b98f"))
		_:
			b.call(-4, -1, 8, 2, Color("c0392b"))
			b.call(-4, -1, 8, 1, Color("e06b5d"))
			b.call(-1, -2, 2, 4, Color("f2c14e"))
