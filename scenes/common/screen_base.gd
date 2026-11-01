class_name ScreenBase
extends Control
## Khung UI TẠM cho mọi màn hình: tiêu đề, đồng hồ, thanh trạng thái, cột nút và ô log.
## Mục đích: chơi thử trọn vòng lặp ngày ngay từ tuần 1.
## Khi làm UI thật cho màn nào, cho màn đó extends Control/Node2D và bỏ class này.
##
## QUY TẮC UI CẢM ỨNG (game chơi được trên điện thoại qua web):
## - Nút cao tối thiểu ~56px, chữ >= 18px.
## - Không dựa vào hover/tooltip, chuột phải hay bàn phím.
## - Kéo thả phải dùng được bằng ngón tay.

const BUTTON_HEIGHT := 56
const BUTTON_FONT_SIZE := 20
const BODY_FONT_SIZE := 18

var title_label: Label
var timer_label: Label
var info_label: Label
var actions: VBoxContainer
var log_box: RichTextLabel
var _rotate_hint: Control


func _ready() -> void:
	_build_layout()
	GameState.money_changed.connect(_on_state_changed)
	GameState.inventory_changed.connect(_on_state_changed)
	GameState.stars_changed.connect(_on_state_changed)
	DayManager.phase_time_up.connect(_on_phase_time_up)
	title_label.text = _get_title()
	_setup()
	refresh_info()


func _process(_delta: float) -> void:
	var window_size := DisplayServer.window_get_size()
	_rotate_hint.visible = window_size.y > window_size.x
	timer_label.visible = DayManager.timer_running
	if DayManager.timer_running:
		timer_label.text = "Còn lại " + DayManager.time_left_text()


# --- Hook cho màn con override ----------------------------------------------

func _get_title() -> String:
	return ""


func _setup() -> void:
	pass


func _show_status() -> bool:
	return true


## Mặc định hết giờ thì sang giai đoạn kế tiếp.
func _on_phase_time_up() -> void:
	log_line("[color=orange]Hết giờ![/color]")
	DayManager.next_phase()


# --- Tiện ích ---------------------------------------------------------------

func add_action(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.pressed.connect(callback)
	actions.add_child(button)
	return button


func clear_actions() -> void:
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()


func log_line(text: String) -> void:
	log_box.append_text(text + "\n")


func refresh_info() -> void:
	if not _show_status():
		info_label.text = ""
		return
	var broth_counts := {}
	for id in GameState.broths:
		var broth := Database.get_broth(id)
		broth_counts[broth.display_name if broth else id] = GameState.broths[id]
	var broth_text := "(trống)"
	if not broth_counts.is_empty():
		var parts: Array[String] = []
		for name in broth_counts:
			parts.append("%s x%d" % [name, broth_counts[name]])
		broth_text = ", ".join(parts)
	info_label.text = "Ngày %d   |   Tiền: %s   |   Doanh thu hôm nay: %s / KPI %s   |   Sao: %.1f\nKho: %s\nNước cốt: %s" % [
		GameState.day,
		GameState.format_money(GameState.money),
		GameState.format_money(GameState.today_revenue),
		GameState.format_money(GameState.kpi_target),
		GameState.stars,
		GameState.describe_items(GameState.inventory),
		broth_text,
	]


func _on_state_changed(_value: Variant = null) -> void:
	refresh_info()


func _build_layout() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color("2b1a14")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 32)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title_label)
	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 26)
	timer_label.add_theme_color_override("font_color", Color("f2a33a"))
	header.add_child(timer_label)

	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	root.add_child(info_label)
	root.add_child(HSeparator.new())

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	root.add_child(columns)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	actions = VBoxContainer.new()
	actions.size_flags_horizontal = SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 8)
	scroll.add_child(actions)

	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.size_flags_horizontal = SIZE_EXPAND_FILL
	log_box.size_flags_vertical = SIZE_EXPAND_FILL
	for font_name in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		log_box.add_theme_font_size_override(font_name, BODY_FONT_SIZE)
	columns.add_child(log_box)

	_build_rotate_hint()


## Lớp phủ nhắc xoay ngang khi cầm điện thoại dọc (chặn luôn thao tác bên dưới).
func _build_rotate_hint() -> void:
	_rotate_hint = ColorRect.new()
	(_rotate_hint as ColorRect).color = Color("1a0f0b")
	_rotate_hint.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_rotate_hint.mouse_filter = MOUSE_FILTER_STOP
	_rotate_hint.visible = false
	add_child(_rotate_hint)

	var label := Label.new()
	label.text = "Xoay ngang điện thoại\nđể chơi nhé!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", Color("f2a33a"))
	label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_rotate_hint.add_child(label)
