class_name HowToPlay
extends CanvasLayer
## Bảng "Cách chơi" của từng buổi, dạng thẻ: mỗi thẻ là một ảnh chụp game thật + khung vàng nhấp nháy quanh chỗ cần chạm
## + mũi tên nhún (TutorialPointer) + một câu ngắn. Đi thẻ bằng ‹ Trước / Tiếp », chạm ảnh, hoặc phím ← →; thẻ cuối có "Đã hiểu".
## DayManager tự mở lần đầu người chơi vào mỗi buổi (và luôn mở trong Ngày 0); menu tạm dừng có nút "Cách chơi" để xem lại.
## Mở thì game tạm dừng (đồng hồ buổi đứng yên), đóng thì trả lại đúng trạng thái cũ.
## Đã xem buổi nào thì ghi vào user://settings.cfg (cùng file cài đặt, không lẫn vào save game).
## Ảnh ở assets/sprites/ui/tutorial/, chụp lại bằng tools/capture_tutorial_shots.gd (script đó in ra số cho FOCUS).

const LAYER := 115 ## Trên menu tạm dừng (110) vì mở được từ đó, dưới bảng cài đặt (120).
const SECTION := "how_to_play"
const IMAGE_DIR := "res://assets/sprites/ui/tutorial/"
const IMAGE_SIZE := Vector2(640, 360)
const PANEL_WIDTH := 860.0
const DIM := Color(0, 0, 0, 0.6)
const PANEL_BG := Color("4a2e20")
const PANEL_BORDER := Color("a8764a")
const TITLE_COLOR := Color("ffd36b")
const TEXT_COLOR := Color("f5f1e6")
const OUTLINE := Color("1a0f0a")
const BUTTON_BG := Color("7a2a1e")
const DOT_ON := Color("ffd36b")
const DOT_OFF := Color("7a5a44")
const FOCUS_PAD := 6.0 ## Khung chỉ nới rộng ra mỗi bên (px trên ảnh) cho dễ thấy.
const SLIDE_DISTANCE := 40.0 ## Thẻ mới trượt vào từ bên phải bao nhiêu px.

## Khung chỉ trên từng ảnh, tỉ lệ 0..1 (x, y, rộng, cao). Do tools/capture_tutorial_shots.gd in ra, dán lại khi chụp lại.
const FOCUS := {
	"hunt_bush": Rect2(0.335, 0.326, 0.209, 0.390),
	"hunt_recipe": Rect2(0.036, 0.681, 0.270, 0.165),
	"hunt_back": Rect2(0.731, 0.878, 0.250, 0.089),
	"hunt_target": Rect2(0.691, 0.365, 0.119, 0.354),
	"hunt_skills": Rect2(0.127, 0.869, 0.558, 0.097),
	"cook_prep": Rect2(0.146, 0.250, 0.146, 0.078),
	"cook_stove": Rect2(0.554, 0.279, 0.085, 0.240),
	"cook_fridge": Rect2(0.013, 0.206, 0.112, 0.311),
	"cook_open": Rect2(0.013, 0.919, 0.975, 0.078),
	"cook_steps": Rect2(0.318, 0.447, 0.609, 0.469),
	"sell_queue": Rect2(0.922, 0.497, 0.066, 0.158),
	"sell_table": Rect2(0.013, 0.593, 0.212, 0.242),
	"sell_serve": Rect2(0.013, 0.593, 0.212, 0.242),
	"sell_mess": Rect2(0.415, 0.741, 0.044, 0.078),
	"sell_stars": Rect2(0.570, 0.056, 0.147, 0.050),
	"shop_kpi": Rect2(0.384, 0.017, 0.116, 0.090),
	"shop_tabs": Rect2(0.069, 0.181, 0.478, 0.083),
	"shop_buy": Rect2(0.081, 0.690, 0.397, 0.078),
	"shop_start": Rect2(0.666, 0.850, 0.266, 0.094),
}
## Nội dung theo DayManager.Phase: mỗi thẻ = tên ảnh (khoá của FOCUS) + một câu. Font không có glyph ▶ → nên dùng » ›.
const PAGES := {
	DayManager.Phase.SHOP: {
		"title": "Cách chơi: Một ngày ở quán",
		"cards": [
			["shop_kpi", "Mỗi ngày: Sáng đi săn » Trưa nấu lẩu » Tối bán hàng. Cuối ngày doanh thu phải đạt KPI ở ô này, không thì quán đóng cửa."],
			["shop_tabs", "Đạt KPI thì vào cửa hàng: nhóm Quán lẩu nâng bếp, quán, trang trí; nhóm Đi săn nâng vũ khí, thú cưỡi."],
			["shop_buy", "Chạm Mua để nâng cấp. KPI ngày sau cao hơn doanh thu hôm nay, nên nâng cấp đều tay."],
			["shop_start", "Sẵn sàng thì bấm \"Bắt đầu ngày\" để đi săn."],
		],
	},
	DayManager.Phase.HUNT: {
		"title": "Cách chơi: Buổi sáng đi săn",
		"cards": [
			["hunt_bush", "Chạm một bụi cỏ để đánh quái. Thắng thì nhận nguyên liệu như hình trên thẻ."],
			["hunt_target", "Trong trận: chạm vào quái để chọn mục tiêu."],
			["hunt_skills", "Rồi chọn chiêu để đánh. Bật \"Tự đánh\" nếu muốn nhanh. Bỏ chạy thì mất đồ rơi."],
			["hunt_recipe", "Săn đúng thứ món hôm nay cần. Thắng đủ trận sẽ mở Boss, rơi nguyên liệu hoàng kim giá gấp 3."],
			["hunt_back", "Hết giờ hoặc bấm \"Về bếp nấu lẩu\" để sang buổi trưa."],
		],
	},
	DayManager.Phase.COOK: {
		"title": "Cách chơi: Buổi trưa nấu lẩu",
		"cards": [
			["cook_prep", "Nguyên liệu phải sơ chế trước khi nấu: chạm \"Sơ chế nguyên liệu\"."],
			["cook_steps", "Mỗi bước là một trò nhỏ: vàng Hoàn hảo, cam Ổn, đỏ Hỏng. Gần như toàn vàng thì được Thượng hạng, bán đắt hơn."],
			["cook_stove", "Chạm một bếp trống rồi chọn món để nấu. Nâng cấp Nồi để mỗi mẻ ra nhiều phần hơn."],
			["cook_fridge", "Chạm tủ lạnh để xem kho. Nguyên liệu và nồi lẩu để lâu sẽ hết hạn."],
			["cook_open", "Nấu đủ thì bấm \"Mở quán bán hàng\". Lẩu nấu xong được mang ra quầy bếp ở màn bán."],
		],
	},
	DayManager.Phase.SELL: {
		"title": "Cách chơi: Buổi chiều tối bán hàng",
		"cards": [
			["sell_queue", "Khách đang chờ hiện ở cột này: số người mỗi nhóm và thanh kiên nhẫn."],
			["sell_table", "Chạm một bàn trống đủ ghế để mời nhóm khách vào ngồi."],
			["sell_serve", "Bàn gọi món xong thì chạm bàn đó để bưng lẩu ra. Bưng nhanh được cộng sao."],
			["sell_mess", "Khách về để lại rác, vũng nước, bàn bẩn: chạm vào để dọn. Sàn bẩn làm khách sốt ruột."],
			["sell_stars", "Khách chờ lâu sẽ bỏ về và quán bị trừ sao. Hết lẩu thì quán tạm ngừng đón khách."],
		],
	},
}

var _phase: int
var _was_paused := false
var _index := 0
var _card_box: Control ## Khung ảnh (trượt vào mỗi lần đổi thẻ).
var _picture: TextureRect
var _focus: Panel
var _pointer: TutorialPointer
var _text: Label
var _dots: Array[ColorRect] = []
var _prev: Button
var _next: Button


## Bảng hướng dẫn của buổi `phase` (một trong các khóa của PAGES).
func _init(phase: int) -> void:
	_phase = phase


## Buổi này có bảng hướng dẫn không.
static func has_page(phase: int) -> bool:
	return PAGES.has(phase)


## Buổi này có bảng hướng dẫn mà người chơi chưa xem trên máy này.
static func should_show(phase: int) -> bool:
	if not has_page(phase):
		return false
	var config := ConfigFile.new()
	config.load(SettingsPanel.SETTINGS_PATH) # chưa có file = chưa xem gì
	return not bool(config.get_value(SECTION, str(phase), false))


## Ghi nhớ đã xem bảng của buổi này (giữ nguyên các mục cài đặt khác trong file).
static func mark_seen(phase: int) -> void:
	var config := ConfigFile.new()
	config.load(SettingsPanel.SETTINGS_PATH)
	config.set_value(SECTION, str(phase), true)
	config.save(SettingsPanel.SETTINGS_PATH)


## Đã chơi xong Ngày 0 hướng dẫn trên máy này chưa.
static func tutorial_done() -> bool:
	var config := ConfigFile.new()
	config.load(SettingsPanel.SETTINGS_PATH)
	return bool(config.get_value(SECTION, "tutorial_done", false))


## Ghi nhớ đã xong Ngày 0 (giữ nguyên các mục khác trong file).
static func mark_tutorial_done() -> void:
	var config := ConfigFile.new()
	config.load(SettingsPanel.SETTINGS_PATH)
	config.set_value(SECTION, "tutorial_done", true)
	config.save(SettingsPanel.SETTINGS_PATH)


## Dựng bảng: nền tối chặn chạm, khung giữa màn có tiêu đề, ảnh + khung chỉ, câu hướng dẫn, chấm trang và hai nút.
func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	var page: Dictionary = PAGES[_phase]

	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box_style(PANEL_BG, 4, 6, 24))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = PANEL_WIDTH
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := _label(page["title"], 30, TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_build_picture())

	_text = _label("", 20, TEXT_COLOR)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.custom_minimum_size = Vector2(PANEL_WIDTH, 56) # 2 dòng: đổi thẻ không làm bảng co giãn
	box.add_child(_text)

	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 10)
	box.add_child(dots)
	for i in (page["cards"] as Array).size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dots.add_child(dot)
		_dots.append(dot)

	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	_prev = _button("‹ Trước")
	_prev.pressed.connect(_go.bind(-1))
	buttons.add_child(_prev)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	_next = _button("Tiếp »")
	_next.pressed.connect(_go.bind(1))
	buttons.add_child(_next)

	_show_card(0)


## Khung ảnh 640x360 (giữ chỗ cố định) chứa ảnh chụp và khung chỉ; chạm vào ảnh = sang thẻ sau.
func _build_picture() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = IMAGE_SIZE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_box = Control.new()
	_card_box.size = IMAGE_SIZE
	holder.add_child(_card_box)
	var frame := Panel.new() # viền gỗ quanh ảnh
	frame.add_theme_stylebox_override("panel", _box_style(Color.TRANSPARENT, 3, 2, 0))
	frame.position = Vector2(-3, -3)
	frame.size = IMAGE_SIZE + Vector2(6, 6)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.add_child(frame)
	_picture = TextureRect.new()
	_picture.size = IMAGE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.mouse_filter = Control.MOUSE_FILTER_STOP
	_picture.gui_input.connect(_on_picture_input)
	_card_box.add_child(_picture)
	_focus = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = TITLE_COLOR
	style.set_border_width_all(5)
	style.set_corner_radius_all(4)
	_focus.add_theme_stylebox_override("panel", style)
	_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.add_child(_focus)
	var ring := Panel.new() # vòng viền tối ngay ngoài khung vàng: khung nổi trên cả nền sáng lẫn tối
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color.TRANSPARENT
	ring_style.border_color = OUTLINE
	ring_style.set_border_width_all(3)
	ring_style.set_corner_radius_all(6)
	ring.add_theme_stylebox_override("panel", ring_style)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.set_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		ring.set_offset(side, -3.0)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		ring.set_offset(side, 3.0)
	_focus.add_child(ring)
	# Khung "thở": phóng to nhẹ và nhạt đi một chút rồi trở lại, lặp mãi.
	var pulse := _focus.create_tween().set_loops().set_parallel()
	pulse.tween_property(_focus, "scale", Vector2.ONE * 1.06, 0.45).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_focus, "modulate:a", 0.65, 0.45).set_trans(Tween.TRANS_SINE)
	pulse.chain().tween_property(_focus, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_focus, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	return holder


## Hiện thẻ thứ `i`: đổi ảnh, khung chỉ, mũi tên, câu chữ, chấm trang, nút; ảnh trượt vào từ bên phải.
func _show_card(i: int) -> void:
	var cards: Array = PAGES[_phase]["cards"]
	_index = clampi(i, 0, cards.size() - 1)
	var card: Array = cards[_index]
	var image_name: String = card[0]
	_text.text = card[1]
	var path := IMAGE_DIR + image_name + ".webp"
	_picture.texture = load(path) if ResourceLoader.exists(path) else null
	_card_box.visible = _picture.texture != null # thiếu ảnh thì chỉ còn chữ
	var f: Rect2 = FOCUS.get(image_name, Rect2())
	_focus.visible = _card_box.visible and f.size != Vector2.ZERO
	_focus.position = f.position * IMAGE_SIZE - Vector2.ONE * FOCUS_PAD
	_focus.size = f.size * IMAGE_SIZE + Vector2.ONE * FOCUS_PAD * 2.0
	_focus.pivot_offset = _focus.size / 2.0
	if is_instance_valid(_pointer):
		_pointer.queue_free()
	if _focus.visible:
		_pointer = TutorialPointer.point_at(_focus, "", false, _picture)
	for d in _dots.size():
		_dots[d].color = DOT_ON if d == _index else DOT_OFF
	_prev.modulate.a = 0.0 if _index == 0 else 1.0
	_prev.disabled = _index == 0
	_next.text = "Đã hiểu" if _index == cards.size() - 1 else "Tiếp »"
	_card_box.position.x = SLIDE_DISTANCE
	_card_box.modulate.a = 0.0
	var slide := _card_box.create_tween().set_parallel()
	slide.tween_property(_card_box, "position:x", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_property(_card_box, "modulate:a", 1.0, 0.2)


## Lùi / tiến một thẻ; tiến ở thẻ cuối = đóng bảng.
func _go(step: int) -> void:
	var last: int = (PAGES[_phase]["cards"] as Array).size() - 1
	if step > 0 and _index >= last:
		close()
	elif _index + step >= 0:
		_show_card(_index + step)


## Chạm vào ảnh thì sang thẻ sau.
func _on_picture_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		_go(1)


## Đóng bảng, ghi đã xem, trả game về trạng thái tạm dừng như trước khi mở.
func close() -> void:
	mark_seen(_phase)
	get_tree().paused = _was_paused
	queue_free()


## ESC / nút Back đóng bảng (để không mở menu tạm dừng chồng lên); ← → đổi thẻ.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE, KEY_BACK:
			get_viewport().set_input_as_handled()
			close()
		KEY_LEFT:
			get_viewport().set_input_as_handled()
			_go(-1)
		KEY_RIGHT:
			get_viewport().set_input_as_handled()
			_go(1)


## Nút gỗ đỏ cao 60 px (đủ to cho ngón tay).
func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(220, 60)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color", TEXT_COLOR)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := _box_style(BUTTON_BG.lightened(0.15) if state == "pressed" else BUTTON_BG, 3, 4, 0)
		button.add_theme_stylebox_override(state, s)
	return button


## Khung nền + viền gỗ dùng chung cho bảng, khung ảnh và nút.
func _box_style(bg: Color, border: int, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = PANEL_BORDER
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


## Một dòng chữ có viền tối.
func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 4)
	return label
