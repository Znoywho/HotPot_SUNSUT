class_name MenuBoard
extends Control
## Bảng phấn "THỰC ĐƠN" kiểu chữ A đứng cạnh quầy lễ tân. Vẽ một nồi lẩu nhỏ + vạch phấn cho mỗi món
## đang bán hôm nay. Chạm vào bảng để mở bảng Thực đơn đầy đủ (thẻ Thực đơn của bảng Kho).
## Toạ độ theo sân khấu 1280x720 của màn bán.

const FEET := Vector2(404, 344) ## Giữa chân bảng trên sàn.
const BOARD := Vector2(112, 104) ## Cỡ mặt bảng (cả khung gỗ).
const LEG := 18.0 ## Chân bảng lộ ra dưới mặt bảng.
const MAX_LINES := 3
const POT_ICON := "res://assets/sprites/ui/broth_pot.png"
const WOOD := Color("8d5a34")
const WOOD_DARK := Color("5a3820")
const SLATE := Color("2f3b35")
const CHALK := Color("f4f1e6")
const CHALK_SOFT := Color(0.96, 0.94, 0.88, 0.55)

var _lines := 0
var _pot: Texture2D


func _ready() -> void:
	size = Vector2(BOARD.x + 12, BOARD.y + LEG)
	position = Vector2(FEET.x - size.x / 2.0, FEET.y - size.y)
	pivot_offset = Vector2(size.x / 2.0, size.y)
	mouse_filter = MOUSE_FILTER_STOP
	_pot = load(POT_ICON) if ResourceLoader.exists(POT_ICON) else null
	_lines = mini(Database.broths_for_day(GameState.day).size(), MAX_LINES)
	var title := HuntUI.label("THỰC ĐƠN", 18, CHALK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(6, 8)
	title.size = Vector2(BOARD.x, 24)
	title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(title)
	# Nồi nhỏ trước mỗi vạch phấn (vẽ bằng hình để giống nồi ở ô cửa bếp).
	for i in _lines:
		if _pot != null:
			var ic := HuntUI.texture_rect(_pot, 20)
			ic.position = Vector2(16, 40 + i * 20)
			ic.mouse_filter = MOUSE_FILTER_IGNORE
			ic.modulate = Color(1, 1, 1, 0.9)
			add_child(ic)


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
	if not tapped:
		return
	accept_event()
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.06, 0.94), 0.06)
	t.tween_property(self, "scale", Vector2.ONE, 0.1)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	for child in hud.get_children():
		if child is StoragePopup:
			return # Đang mở rồi.
	var popup := StoragePopup.new()
	popup.start_tab = 1
	hud.add_child(popup)


func _draw() -> void:
	var w := BOARD.x
	var h := BOARD.y
	var x0 := 6.0
	# Bóng dưới chân + hai chân chữ A.
	draw_rect(Rect2(x0 + 4, h + LEG - 4, w - 8, 6), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(x0 + 6, h - 4, 6, LEG + 2), WOOD_DARK)
	draw_rect(Rect2(x0 + w - 12, h - 4, 6, LEG + 2), WOOD_DARK)
	draw_rect(Rect2(x0 + 8, h - 4, 3, LEG), WOOD)
	draw_rect(Rect2(x0 + w - 10, h - 4, 3, LEG), WOOD)
	# Khung gỗ + mặt bảng phấn.
	draw_rect(Rect2(x0 - 2, 0, w + 4, h), WOOD_DARK)
	draw_rect(Rect2(x0, 2, w, h - 4), WOOD)
	draw_rect(Rect2(x0 + 6, 6, w - 12, h - 12), SLATE)
	draw_rect(Rect2(x0 + 6, 6, w - 12, 3), SLATE.lightened(0.12))
	# Gạch chân tiêu đề.
	draw_rect(Rect2(x0 + 18, 32, w - 36, 2), CHALK_SOFT)
	# Vạch phấn cho từng món (dài ngắn khác nhau như chữ viết tay) + chấm giá ở cuối.
	for i in _lines:
		var y := 50.0 + i * 20.0
		var dash: float = [56.0, 44.0, 50.0][i % 3]
		draw_rect(Rect2(x0 + 34, y, dash, 2), CHALK_SOFT)
		draw_rect(Rect2(x0 + 34 + dash + 4, y - 1, 4, 4), Color("f2c14e"))
	if _lines == 0:
		draw_rect(Rect2(x0 + 20, 54, w - 40, 2), CHALK_SOFT)
	# Phấn trên gờ dưới.
	draw_rect(Rect2(x0 + 14, h - 8, 10, 3), CHALK)
	draw_rect(Rect2(x0 + 28, h - 8, 6, 3), Color("ffab91"))
