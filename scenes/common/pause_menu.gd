class_name PauseMenu
extends CanvasLayer
## Menu tạm dừng: ESC (hoặc nút "II" trên HUD, nút Back trên Android) để mở/đóng.
## Chơi tiếp / Cách chơi / Cài đặt / Chơi mới / Thoát ra menu chính. Chơi mới và Thoát phải xác nhận lần nữa.
## HUD tạo sẵn menu này; chỉ mở được khi HUD đang hiện (tức là đang trong ngày chơi).

const LAYER := 110 ## Trên cả sổ tổng kết ngày (DayManager.DAY_END_LAYER = 100).
const DIM := Color(0, 0, 0, 0.6)
const PANEL_BG := Color("4a2e20") ## Màu thân bảng gỗ; bảng của các màn khác lấy theo.
const PANEL_BORDER := Color("a8764a") ## Màu vạch kẻ dưới tiêu đề; bảng của các màn khác lấy theo.
## Bảng gỗ pixel 9 ô (tools/make_menu_art.py): ảnh 96 px, lề góc 32 px, ô giữa là 1 tấm ván lặp lại.
const BOARD := preload("res://assets/sprites/ui/board_wood.png")
const BOARD_MARGIN := 32.0
const TITLE_COLOR := Color("f3e2c0")
const TEXT_COLOR := Color("fbecd2") ## = PixelButton.TEXT_COLOR
const WARNING_COLOR := Color("f2a33a") ## Dòng hậu quả ("... sẽ bị xoá"): cam ấm, nổi trên nền gỗ.
const MESSAGE_SIZE := 24 ## Bội của lưới 12 px của font Ark Pixel -> nét pixel đều.
const BUTTON_SIZE := Vector2(300, 68) ## Chạm được: cao >= 56 px.
const POP_TIME := 0.28 ## Bảng bật ra (nảy nhẹ quá 1 rồi về đúng cỡ).
const POP_START_SCALE := 0.85

var _was_paused := false ## Sổ tổng kết ngày cũng dừng game; đóng menu thì trả lại đúng trạng thái cũ.
var _box: VBoxContainer
var _dim: ColorRect
var _panel: PanelContainer
var _pop_tween: Tween
var _confirm_only := false ## Chỉ là hộp xác nhận (tạo bằng confirm()): "Quay lại" đóng và xoá hộp.


## Hộp xác nhận đứng riêng, cùng kiểu với menu tạm dừng (vd menu chính hỏi trước khi Chơi mới).
static func confirm(parent: Node, message: String, confirm_text: String, action: Callable) -> void:
	var menu := PauseMenu.new()
	menu._confirm_only = true
	parent.add_child(menu)
	menu.visible = true
	menu._show_confirm(message, confirm_text, func():
		menu.close()
		action.call())
	menu._pop_in(true)


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_dim = ColorRect.new()
	_dim.color = DIM
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP # Chặn chạm xuống màn chơi phía dưới.
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.add_child(center)
	_panel = PanelContainer.new()
	var style := StyleBoxTexture.new()
	style.texture = BOARD
	style.set_texture_margin_all(BOARD_MARGIN)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE # ván lặp lại, không bị kéo dãn méo
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.set_content_margin_all(44)
	style.content_margin_top = 36
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 16)
	_panel.add_child(_box)


func _input(event: InputEvent) -> void:
	var hud := get_parent() as CanvasLayer
	if hud != null and not hud.visible and not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE or key.keycode == KEY_BACK:
		get_viewport().set_input_as_handled()
		# ESC = "quay lại": đang mở bảng gì (sơ chế, chọn món, Kho...) thì đóng bảng đó trước,
		# không mở gì mới hiện menu tạm dừng. Nút "II" trên HUD thì luôn mở menu.
		if visible:
			close()
		elif not _close_top_overlay():
			open()


## Đóng bảng đang mở trên cùng: bảng Kho/Thực đơn của HUD, rồi tới bảng của màn hiện tại
## (màn nào có `handle_back() -> bool` thì tự quyết đóng gì). Trả về true nếu đã đóng được.
func _close_top_overlay() -> bool:
	var hud := get_parent()
	if hud != null:
		for child in hud.get_children():
			if child is StoragePopup and not child.is_queued_for_deletion():
				child.queue_free()
				return true
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("handle_back"):
		return bool(scene.call("handle_back"))
	return false


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
	_pop_in(true)


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused
	if _confirm_only:
		queue_free()


# --- Các trang của menu -----------------------------------------------------

func _show_main() -> void:
	_clear()
	_add_title("TẠM DỪNG")
	_add_button(_box, "CHƠI TIẾP", close, "red")
	if HowToPlay.has_page(DayManager.current_phase):
		_add_button(_box, "CÁCH CHƠI", _show_how_to_play)
	_add_button(_box, "CÀI ĐẶT", func(): get_tree().root.add_child(SettingsPanel.new()))
	_add_button(_box, "CHƠI MỚI", _go_to_page.bind(_show_confirm.bind(
			"Bắt đầu lại từ Ngày 1?\nTiến độ hiện tại sẽ mất.", "Bắt đầu lại", _new_game)))
	_add_button(_box, "THOÁT", _go_to_page.bind(_show_confirm.bind(
			"Thoát ra menu chính?\nGame tự lưu khi vào Cửa hàng,\nphần chơi hôm nay chưa được lưu.", "Thoát", _quit_to_menu)))


## Hộp xác nhận: dòng đầu của message là câu hỏi (chữ kem), các dòng sau là hậu quả (chữ cam cảnh báo).
## Hai nút nằm ngang: QUAY LẠI (gỗ, an toàn) bên trái, hành động (đỏ, ghi đúng tên việc sẽ làm) bên phải.
func _show_confirm(message: String, confirm_text: String, action: Callable) -> void:
	_clear()
	_add_title("XÁC NHẬN")
	var lines := message.split("\n", true, 1)
	_add_message(lines[0], TEXT_COLOR)
	if lines.size() > 1:
		_add_message(lines[1], WARNING_COLOR)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	_box.add_child(row)
	_add_button(row, "QUAY LẠI", close if _confirm_only else _go_to_page.bind(_show_main))
	_add_button(row, confirm_text.to_upper(), action, "red")


## Đổi trang trong menu (chính <-> xác nhận) rồi cho bảng nảy nhẹ, không làm tối lại nền.
func _go_to_page(show_page: Callable) -> void:
	show_page.call()
	_pop_in(false)


## Bảng bật ra: phóng từ POP_START_SCALE lên 1, nảy quá đà một chút (TRANS_BACK); nền tối mờ dần vào nếu fade_dim.
## Chạy cả khi game đang tạm dừng: CanvasLayer này PROCESS_MODE_ALWAYS nên tween của nó cũng chạy.
func _pop_in(fade_dim: bool) -> void:
	if _pop_tween != null:
		_pop_tween.kill()
	_panel.modulate.a = 0.0 # ẩn tới khi bố cục xong, tránh nháy một khung ở cỡ cũ
	if fade_dim:
		_dim.modulate.a = 0.0
	await get_tree().process_frame # đợi CenterContainer tính xong cỡ bảng để lấy tâm phóng
	if not is_inside_tree():
		return
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2.ONE * POP_START_SCALE
	_pop_tween = create_tween().set_parallel(true)
	_pop_tween.tween_property(_panel, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(_panel, "modulate:a", 1.0, POP_TIME * 0.5)
	_pop_tween.tween_property(_dim, "modulate:a", 1.0, POP_TIME * 0.6)


## Đóng menu rồi mở bảng "Cách chơi" của buổi đang chơi (bảng tự tạm dừng game).
func _show_how_to_play() -> void:
	close()
	get_tree().root.add_child(HowToPlay.new(DayManager.current_phase))


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


## Tiêu đề font pixel chung (TẠM DỪNG / XÁC NHẬN) và một vạch kẻ pixel ngăn với nội dung.
func _add_title(text: String) -> void:
	var t := Label.new()
	t.text = text
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", TITLE_COLOR)
	PixelTitle.style(t, 34)
	_box.add_child(t)
	var divider := ColorRect.new()
	divider.color = PANEL_BORDER
	divider.custom_minimum_size = Vector2(0, 4) # = 1 điểm ảnh của khung (phóng 4 lần)
	_box.add_child(divider)


## Một dòng chữ căn giữa (câu hỏi / hậu quả) trong hộp xác nhận.
func _add_message(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", MESSAGE_SIZE)
	label.add_theme_color_override("font_color", color)
	_box.add_child(label)


## Nút pixel dùng chung: "wood" cho hành động an toàn / phụ, "red" cho hành động chính hoặc không quay lại được.
func _add_button(parent: Container, text: String, action: Callable, color := "wood") -> PixelButton:
	var b := PixelButton.new(text, 26, color)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = BUTTON_SIZE
	b.pressed.connect(action)
	parent.add_child(b)
	return b
