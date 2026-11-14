class_name PauseMenu
extends CanvasLayer
## Menu tạm dừng: ESC (hoặc nút "II" trên HUD, nút Back trên Android) để mở/đóng.
## Chơi tiếp / Chơi mới / Thoát ra menu chính. Chơi mới và Thoát phải xác nhận lần nữa.
## HUD tạo sẵn menu này; chỉ mở được khi HUD đang hiện (tức là đang trong ngày chơi).

const LAYER := 110 ## Trên cả sổ tổng kết ngày (DayManager.DAY_END_LAYER = 100).
const DIM := Color(0, 0, 0, 0.6)
const PANEL_BG := Color("4a2e20")
const PANEL_BORDER := Color("a8764a")
const TITLE_COLOR := Color("f3e2c0")
const TEXT_COLOR := Color("f5f1e6")
const OUTLINE := Color("1a0f0a")
const BUTTON_BG := Color("2b1a14")
const BUTTON_DANGER := Color("7a2a1e")
const BUTTON_HEIGHT := 64
const BUTTON_WIDTH := 320

var _was_paused := false ## Sổ tổng kết ngày cũng dừng game; đóng menu thì trả lại đúng trạng thái cũ.
var _box: VBoxContainer


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP # Chặn chạm xuống màn chơi phía dưới.
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	panel.add_child(_box)


func _input(event: InputEvent) -> void:
	var hud := get_parent() as CanvasLayer
	if hud != null and not hud.visible and not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE or key.keycode == KEY_BACK:
		get_viewport().set_input_as_handled()
		toggle()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_show_main()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused


# --- Các trang của menu -----------------------------------------------------

func _show_main() -> void:
	_clear()
	_add_title("TẠM DỪNG")
	_add_button("Chơi tiếp", close)
	_add_button("Chơi mới", _show_confirm.bind(
			"Bắt đầu lại từ Ngày 1?\nTiến độ hiện tại sẽ mất.", "Bắt đầu lại", _new_game))
	_add_button("Thoát", _show_confirm.bind(
			"Thoát ra menu chính?\nGame tự lưu khi vào Cửa hàng,\nphần chơi hôm nay chưa được lưu.", "Thoát", _quit_to_menu))


func _show_confirm(message: String, confirm_text: String, action: Callable) -> void:
	_clear()
	_add_title("XÁC NHẬN")
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	_box.add_child(label)
	_add_button(confirm_text, action, BUTTON_DANGER)
	_add_button("Quay lại", _show_main)


func _new_game() -> void:
	visible = false
	DayManager.start_new_game() # go_to() tự bỏ tạm dừng.


func _quit_to_menu() -> void:
	visible = false
	get_tree().paused = false # go_to_main_menu() không tự bỏ tạm dừng.
	DayManager.go_to_main_menu()


# --- Dựng giao diện ---------------------------------------------------------

func _clear() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()


func _add_title(text: String) -> void:
	var t := Label.new()
	t.text = text
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", TITLE_COLOR)
	t.add_theme_color_override("font_outline_color", OUTLINE)
	t.add_theme_constant_override("outline_size", 6)
	_box.add_child(t)


func _add_button(text: String, action: Callable, color := BUTTON_BG) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", TEXT_COLOR)
	b.add_theme_color_override("font_hover_color", TEXT_COLOR)
	b.add_theme_color_override("font_pressed_color", TITLE_COLOR)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = color.lightened(0.12) if state == "hover" else (color.lightened(0.25) if state == "pressed" else color)
		s.border_color = PANEL_BORDER
		s.set_border_width_all(3)
		s.set_corner_radius_all(4)
		b.add_theme_stylebox_override(state, s)
	b.pressed.connect(action)
	_box.add_child(b)
	return b
