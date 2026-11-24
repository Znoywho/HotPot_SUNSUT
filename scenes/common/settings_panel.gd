class_name SettingsPanel
extends CanvasLayer
## Bảng Cài đặt dùng chung (menu chính + menu tạm dừng): âm lượng chung, chỉnh bằng nút – / + (mỗi lần 10%)
## và thanh PixelBar, vì thanh trượt mặc định có nút kéo quá nhỏ để chạm trên điện thoại.
## Mở: get_tree().root.add_child(SettingsPanel.new()). Đóng bằng nút XONG, chạm ra ngoài hoặc ESC.
## Cài đặt lưu riêng ở user://settings.cfg (không lẫn vào save game); menu chính gọi load_and_apply() khi mở game.
## shortcut: chỉ có âm lượng chung (bus Master), khi có nhạc nền thì thêm bus Music / SFX và 2 dòng riêng.

const SETTINGS_PATH := "user://settings.cfg"
const MAX_STEP := 10 ## Âm lượng chia 10 nấc, mỗi nấc 10%.
const DEFAULT_STEP := 8
const LAYER := 120 ## Trên menu tạm dừng (PauseMenu.LAYER = 110).
const BOARD_COLOR := Color("4a2e20") ## Trùng PauseMenu.PANEL_BG.
const BOARD_BORDER := Color("a8764a") ## Trùng PauseMenu.PANEL_BORDER.
const BOARD_WIDTH := 760
const LABEL_WIDTH := 190
const TEXT_LIGHT := Color("fbecd2")
const ACCENT := Color("f2a33a")

var _step := DEFAULT_STEP
var _bar: PixelBar
var _value_label: Label
var _fullscreen_button: PixelButton


## Âm lượng đã lưu (0..MAX_STEP); chưa có file thì dùng mặc định.
static func saved_volume_step() -> int:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return DEFAULT_STEP
	return clampi(int(config.get_value("audio", "volume_step", DEFAULT_STEP)), 0, MAX_STEP)


## Đặt âm lượng bus Master: volume_db = linear_to_db(step / MAX_STEP); nấc 0 thì tắt tiếng hẳn.
static func apply_volume_step(step: int) -> void:
	AudioServer.set_bus_mute(0, step <= 0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(step, 1) / float(MAX_STEP)))


## Đọc cài đặt đã lưu và áp dụng (gọi một lần khi mở game).
static func load_and_apply() -> void:
	apply_volume_step(saved_volume_step())


## Ghi âm lượng ra file cài đặt.
static func save_volume_step(step: int) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH) # chưa có file cũng không sao, giữ các mục khác nếu có
	config.set_value("audio", "volume_step", step)
	config.save(SETTINGS_PATH)


## Dựng lớp tối phủ màn, bảng giữa có tiêu đề, dòng âm lượng và nút XONG.
func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS # vẫn bấm được khi menu tạm dừng đang dừng game
	_step = saved_volume_step()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)

	var board := PanelContainer.new()
	board.custom_minimum_size = Vector2(BOARD_WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = BOARD_COLOR # cùng màu khung với menu tạm dừng để hai bảng nhìn như một bộ
	style.border_color = BOARD_BORDER
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(28)
	board.add_theme_stylebox_override("panel", style)
	center.add_child(board)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	board.add_child(column)

	column.add_child(_make_label("CÀI ĐẶT", 40, ACCENT))
	column.add_child(_divider())
	column.add_child(_setting_row("Âm lượng", _volume_control()))
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		column.add_child(_setting_row("Toàn màn hình", _fullscreen_control())) # điện thoại luôn tràn màn hình rồi
	column.add_child(_divider())
	var done := PixelButton.new("XONG", 26)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(queue_free)
	column.add_child(done)
	_show_step()


## ESC / nút Back: chỉ đóng bảng này, không để menu tạm dừng phía dưới bắt phím.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode in [KEY_ESCAPE, KEY_BACK]:
		get_viewport().set_input_as_handled()
		queue_free()


## Chạm vào vùng tối bên ngoài bảng thì đóng.
func _on_dim_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed:
		queue_free()


## Một dòng cài đặt: tên ở cột trái (rộng cố định để các dòng thẳng hàng), điều khiển chiếm phần còn lại bên phải.
func _setting_row(title: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var name_label := _make_label(title, 24, TEXT_LIGHT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	row.add_child(name_label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


## Đường kẻ mảnh ngăn các vùng trong bảng.
func _divider() -> Control:
	var line := ColorRect.new()
	line.color = BOARD_BORDER
	line.custom_minimum_size = Vector2(0, 3)
	return line


## Nút bật / tắt toàn màn hình; chữ trên nút cho biết trạng thái hiện tại.
func _fullscreen_control() -> Control:
	_fullscreen_button = PixelButton.new("", 24)
	PixelTitle.style(_fullscreen_button, 24) # chữ BẬT / TẮT gán sau: font pixel chung
	_fullscreen_button.custom_minimum_size = Vector2(180, 64)
	_fullscreen_button.pressed.connect(_toggle_fullscreen)
	_show_fullscreen()
	var holder := HBoxContainer.new() # _setting_row kéo dãn điều khiển; bọc lại để nút giữ cỡ cũ, nằm sát phải
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.add_child(_fullscreen_button)
	return holder


## Đảo chế độ toàn màn hình (không lưu: mỗi lần mở game là cửa sổ thường).
func _toggle_fullscreen() -> void:
	var is_full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_show_fullscreen()


## Chữ trên nút: BẬT khi đang toàn màn hình, TẮT khi không.
func _show_fullscreen() -> void:
	_fullscreen_button.text = "BẬT" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "TẮT"


## Điều khiển âm lượng: [–] thanh PixelBar + số % [+].
func _volume_control() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(_step_button("–", -1))
	_bar = PixelBar.new(PixelBar.GOLD)
	_bar.custom_minimum_size = Vector2(0, 32)
	_bar.max_value = MAX_STEP
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_bar)
	_value_label = _make_label("", 24, TEXT_LIGHT)
	_value_label.custom_minimum_size.x = 76
	row.add_child(_value_label)
	row.add_child(_step_button("+", 1))
	return row


## Nút vuông – / + đổi âm lượng một nấc.
func _step_button(text: String, delta: int) -> PixelButton:
	var button := PixelButton.new(text, 32)
	button.custom_minimum_size = Vector2(72, 64)
	button.pressed.connect(_change_step.bind(delta))
	return button


## Đổi âm lượng một nấc, áp dụng và lưu ngay.
func _change_step(delta: int) -> void:
	_step = clampi(_step + delta, 0, MAX_STEP)
	apply_volume_step(_step)
	save_volume_step(_step)
	_show_step()


## Cập nhật thanh và số %; nấc 0 ghi "Tắt".
func _show_step() -> void:
	_bar.value = _step
	_value_label.text = "Tắt" if _step == 0 else "%d%%" % (_step * 100 / MAX_STEP)


## Label căn giữa, chữ đậm có viền tối.
func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("1a0f0b"))
	label.add_theme_constant_override("outline_size", PixelButton.outline_for(font_size))
	PixelTitle.style_if_supported(label, text, font_size) # chữ in hoa (CÀI ĐẶT): font pixel chung
	return label
