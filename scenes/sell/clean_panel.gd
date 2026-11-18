class_name CleanPanel
extends Control
## Bảng dọn dẹp (cùng kiểu bảng sơ chế ở bếp): đè lên quán, giờ vẫn chạy. Chơi lần lượt từng bước:
## - "table" (bàn khách vừa ăn): Dọn bát đũa (chạm từng bát) -> Lau bàn (cầm khăn chà các vết bẩn).
## - "trash" (rác dưới sàn): Quét rác (kéo từng mẩu rác vào hốt rác bằng chổi).
## - "puddle" (vũng nước dưới sàn): Lau vũng nước (cầm cây lau nhà lau qua lại).
## Mỗi bước bị trừ điểm khi chạm trượt / làm rơi rác ra ngoài. Cuối lượt chấm Hoàn hảo / Ổn / Hỏng
## -> `finished(grade)` (0 hỏng, 1 ổn, 2 hoàn hảo). Chạm ra khoảng tối ngoài khung -> `closed` (để dọn sau).

signal finished(grade: int)
signal closed

const PANEL_SIZE := Vector2(900, 520)
const HUD_SHIFT := 46.0
const BAR_HEIGHT := 28.0
const PENALTY := 25 ## Điểm trừ mỗi lỗi (điểm bước = 100 - PENALTY × số lỗi).
const GRADE_TEXT := ["HỎNG!", "ỔN", "HOÀN HẢO!"]
const GRADE_COLOR := [Color("ff8a80"), Color("fff59d"), Color("ffd54f")]
const STEPS := {
	"table": [
		{"game": "bowls", "title": "Dọn bát đũa", "hint": "Chạm từng bát đũa dơ để xếp lên khay."},
		{"game": "wipe", "title": "Lau bàn", "hint": "Cầm khăn chà qua lại lên các vết bẩn cho sạch."},
	],
	"trash": [
		{"game": "sweep", "title": "Quét rác", "hint": "Kéo từng mẩu rác vào hốt rác bằng chổi."},
	],
	"puddle": [
		{"game": "mop", "title": "Lau vũng nước", "hint": "Cầm cây lau nhà lau qua lại cho khô."},
	],
}

var kind := "table"
var _steps: Array = []
var _step_i := 0
var _scores: Array[int] = []
var _host: Control
var _game: CleanGame = null
var _title: Label
var _hint: Label
var _bar: ProgressBar
var _status: Label
var _done := false


func open(mess_kind: String, title: String) -> void:
	kind = mess_kind
	_steps = STEPS.get(kind, STEPS["trash"])
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close_panel())

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_panel", 8, Vector2(22, 16)))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -PANEL_SIZE.x / 2.0
	panel.offset_right = PANEL_SIZE.x / 2.0
	panel.offset_top = -PANEL_SIZE.y / 2.0 + HUD_SHIFT
	panel.offset_bottom = PANEL_SIZE.y / 2.0 + HUD_SHIFT
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)
	var head_label := HuntUI.label("DỌN DẸP: " + title.to_upper(), 26, HuntUI.RUST)
	head_label.size_flags_vertical = SIZE_SHRINK_CENTER
	head_label.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(head_label)
	var later := _flat_button("Để sau", Color("e6d3a8"), Color("8a5a3c"))
	later.pressed.connect(close_panel)
	head.add_child(later)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_card", 8, Vector2(16, 10)))
	card.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(card)
	var gbox := VBoxContainer.new()
	gbox.add_theme_constant_override("separation", 4)
	card.add_child(gbox)
	var banner := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("5a3820")
	bs.border_color = Color("2b1a14")
	bs.set_border_width_all(3)
	bs.set_corner_radius_all(4)
	bs.content_margin_left = 12
	bs.content_margin_right = 12
	bs.content_margin_top = 4
	bs.content_margin_bottom = 4
	banner.add_theme_stylebox_override("panel", bs)
	gbox.add_child(banner)
	_title = HuntUI.outlined_label("", 24, Color("ffd36b"))
	banner.add_child(_title)
	_hint = HuntUI.label("", 18, HuntUI.INK)
	_hint.clip_text = true
	gbox.add_child(_hint)
	_host = Control.new()
	_host.custom_minimum_size = CleanGame.AREA
	_host.size_flags_horizontal = SIZE_SHRINK_CENTER
	gbox.add_child(_host)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("1e2a33")
	bar_bg.border_color = Color("2b1a14")
	bar_bg.set_border_width_all(3)
	bar_bg.set_corner_radius_all(4)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("3d9be9")
	bar_fill.border_color = Color("a6d8ff")
	bar_fill.border_width_top = 3
	bar_fill.set_corner_radius_all(3)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		bar_fill.set_expand_margin(side, -3)
	_bar.add_theme_stylebox_override("background", bar_bg)
	_bar.add_theme_stylebox_override("fill", bar_fill)
	_bar.max_value = 1.0
	_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	gbox.add_child(_bar)
	_status = HuntUI.outlined_label("", 18, Color("fbe9d0"))
	_status.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bar.add_child(_status)

	HuntUI.book_open(panel)
	_start_step()


func close_panel() -> void:
	if _done:
		return
	_done = true
	closed.emit()
	queue_free()


func _start_step() -> void:
	var st: Dictionary = _steps[_step_i]
	_title.text = "Bước %d/%d: %s" % [_step_i + 1, _steps.size(), st["title"]] if _steps.size() > 1 else str(st["title"])
	_hint.text = st["hint"]
	if _game != null:
		_game.queue_free()
	_game = CleanGame.new(str(st["game"]))
	_host.add_child(_game)
	_game.step_finished.connect(_on_step_finished)


func _process(_delta: float) -> void:
	if _game != null and is_instance_valid(_game) and not _done:
		var total := float(_steps.size())
		_bar.value = (_step_i + _game.progress()) / total
		_status.text = "Lỗi: %d" % _game.mistakes if _game.mistakes > 0 else "Bước %d/%d" % [_step_i + 1, _steps.size()]


func _on_step_finished(score: int) -> void:
	_scores.append(score)
	_step_i += 1
	if _step_i < _steps.size():
		get_tree().create_timer(0.3).timeout.connect(_start_step)
		return
	var avg := 0.0
	for s in _scores:
		avg += s
	avg /= maxf(_scores.size(), 1)
	var grade := 2 if avg >= 85.0 else (1 if avg >= 50.0 else 0)
	_show_result(grade)


func _show_result(grade: int) -> void:
	_bar.value = 1.0
	_status.text = "Xong!"
	var l := HuntUI.outlined_label(GRADE_TEXT[grade], 48, GRADE_COLOR[grade])
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = CleanGame.AREA
	l.pivot_offset = CleanGame.AREA / 2.0
	l.mouse_filter = MOUSE_FILTER_IGNORE
	_host.add_child(l)
	l.scale = Vector2(0.4, 0.4)
	l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		if _done:
			return
		_done = true
		finished.emit(grade)
		queue_free())


func _flat_button(text: String, bg: Color, border: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 20)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var st := StyleBoxFlat.new()
		st.bg_color = bg.darkened(0.15 if state.ends_with("pressed") else 0.0)
		st.border_color = border
		st.set_border_width_all(3)
		st.set_corner_radius_all(6)
		st.content_margin_left = 18
		st.content_margin_right = 18
		b.add_theme_stylebox_override(state, st)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, HuntUI.INK)
	return b
