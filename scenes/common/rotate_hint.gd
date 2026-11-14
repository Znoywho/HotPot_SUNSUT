class_name RotateHint
extends ColorRect
## Lớp phủ nhắc xoay ngang điện thoại, dùng chung cho mọi màn tự dựng UI.
## Tự hiện khi cửa sổ đang dọc và chặn luôn thao tác bên dưới. Dùng: thêm vào CUỐI màn bằng add_child(RotateHint.new()).

const TEXT_COLOR := Color("f2a33a")


## Dựng nền tối phủ kín + chữ nhắc ở giữa, ẩn sẵn.
func _init() -> void:
	color = Color("1a0f0b")
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var label := Label.new()
	label.text = "Xoay ngang điện thoại\nđể chơi nhé!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(label)


## Hiện khi cửa sổ cao hơn rộng (điện thoại cầm dọc).
func _process(_delta: float) -> void:
	var window_size := DisplayServer.window_get_size()
	visible = window_size.y > window_size.x
