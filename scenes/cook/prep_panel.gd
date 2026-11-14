class_name PrepPanel
extends Control
## Bảng sơ chế nguyên liệu (đè lên khu bếp, giờ vẫn chạy).
## Trái: nguyên liệu trong kho (thô / đã sơ chế). Phải: quy trình của nguyên liệu đang chọn (data/prep/<id>.tres):
## xem các bước -> "Bắt đầu" -> chơi lần lượt từng bước (5 kiểu thao tác chung trong scenes/cook/prep_actions/).
## Mỗi bước chấm Hoàn hảo / Ổn / Hỏng; cuối lượt ra chất lượng Thượng hạng / Thường / Kém (hỏng nặng thì mất đồ).
## "Sơ chế nhanh tất cả": sơ chế cả kho thô trong vài giây với chất lượng thấp (PrepConfig.quick_quality).

signal closed
signal prepped(id: String) ## Vừa sơ chế xong 1 lượt (đầu bếp làm động tác thái).
signal step_done ## Xong 1 bước (đầu bếp làm động tác).

const ACTIONS := {
	"hold_wash": preload("res://scenes/cook/prep_actions/hold_wash.gd"),
	"tap_targets": preload("res://scenes/cook/prep_actions/tap_targets.gd"),
	"drag_pull": preload("res://scenes/cook/prep_actions/drag_pull.gd"),
	"swipe_cut": preload("res://scenes/cook/prep_actions/swipe_cut.gd"),
	"timed_stage": preload("res://scenes/cook/prep_actions/timed_stage.gd"),
	"scrub": preload("res://scenes/cook/prep_actions/scrub.gd"),
	"roll_ball": preload("res://scenes/cook/prep_actions/roll_ball.gd"),
	"skewer": preload("res://scenes/cook/prep_actions/skewer.gd"),
}
const PANEL_SIZE := Vector2(1200, 540)
const BAR_HEIGHT := 28.0 ## Đủ cao để chữ 18px nằm trong thanh tiến độ.
const HUD_SHIFT := 46.0 ## Dời khung xuống dưới thanh HUD.
const LIST_W := 330.0
const GRADE_TEXT := ["HỎNG!", "ỔN", "HOÀN HẢO!"]
const GRADE_COLOR := [Color("ff8a80"), Color("fff59d"), Color("ffd54f")]

var cfg: PrepConfig
var _needs: Dictionary = {} ## id -> số phần cần cho 1 mẻ món hôm nay.
var _ids: Array[String] = []
var _list: VBoxContainer
var _buttons: Dictionary = {} ## id -> Button
var _host: Control
var _view: Control = null ## Màn giới thiệu / kết quả / sơ chế nhanh (trong khung phải).
var _action: PrepAction = null
var _selected := ""
var _title: Label
var _hint: Label
var _status: Label
var _bar: ProgressBar
var _quick: Button
var _busy := false ## Đang sơ chế nhanh.
# Lượt sơ chế đang chơi.
var _recipe: PrepRecipeData = null
var _step_i := 0
var _carry: Texture2D ## Hình nguyên liệu sau bước vừa xong, truyền sang bước sau và màn kết quả.
var _grades: Array[int] = []
var _units := 0


func open(needs: Dictionary) -> void:
	cfg = Database.prep_config
	_needs = needs
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	# Bấm ra khoảng tối ngoài khung thì đóng bảng, về bếp (giống ESC).
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close_panel())

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_panel", 8, Vector2(22, 16)))
	# Khung vừa tầm mắt: giữa màn, chừa chỗ cho thanh HUD phía trên.
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
	var title := HuntUI.label("SƠ CHẾ NGUYÊN LIỆU", 26, HuntUI.RUST)
	title.size_flags_vertical = SIZE_SHRINK_CENTER
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	_quick = _flat_button("Sơ chế nhanh tất cả", Color("e6d3a8"), Color("8a5a3c"))
	_quick.pressed.connect(_quick_all)
	head.add_child(_quick)
	var close := _flat_button("Xong, chuyển sang nấu lẩu  »", Color("f2a33a"), Color("8a5a3c"))
	close.pressed.connect(close_panel)
	head.add_child(close)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(LIST_W, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	var game_card := PanelContainer.new()
	game_card.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_card", 8, Vector2(16, 10)))
	game_card.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(game_card)
	var gbox := VBoxContainer.new()
	gbox.add_theme_constant_override("separation", 4)
	game_card.add_child(gbox)
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
	_title.clip_text = true
	banner.add_child(_title)
	_hint = HuntUI.label("", 18, HuntUI.INK)
	_hint.clip_text = true
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	gbox.add_child(_hint)
	_host = Control.new()
	_host.custom_minimum_size = PrepAction.AREA
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
	gbox.add_child(_bar) # Thanh chạy hết bề ngang thẻ, số Hoàn hảo/Ổn/Hỏng nằm gọn trong thanh.
	_status = HuntUI.outlined_label("", 18, Color("fbe9d0"))
	_status.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bar.add_child(_status)

	_collect_ids()
	_rebuild_list()
	HuntUI.book_open(panel)
	var first := _best_next()
	_select(first if first != "" else (_ids[0] if not _ids.is_empty() else ""))


## Chọn sẵn 1 nguyên liệu.
func select(id: String) -> void:
	if _buttons.has(id) and not _busy:
		_select(id)


func close_panel() -> void:
	_abort_session()
	closed.emit()
	queue_free()


func _flat_button(text: String, bg: Color, border: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 20)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var st := StyleBoxFlat.new()
		st.bg_color = bg.darkened(0.15 if state.ends_with("pressed") else (0.35 if state == "disabled" else 0.0))
		st.border_color = border
		st.set_border_width_all(3)
		st.set_corner_radius_all(6)
		st.content_margin_left = 18
		st.content_margin_right = 18
		b.add_theme_stylebox_override(state, st)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(state, HuntUI.INK)
	return b


# --- Danh sách nguyên liệu -----------------------------------------------------

## Mọi nguyên liệu có quy trình sơ chế đang có trong kho (thô / đã sơ chế) hoặc cần cho món hôm nay.
func _collect_ids() -> void:
	var seen := {}
	var candidates: Array[String] = []
	for id in _needs:
		candidates.append(str(id))
	for store in [GameState.item_batches, GameState.prepped_batches]:
		for id in store:
			candidates.append(str(id))
	for id in candidates:
		if seen.has(id) or Database.prep_recipe_for(id) == null:
			continue
		seen[id] = true
		_ids.append(id)
	_ids.sort_custom(func(a: String, b: String) -> bool:
		var ka := _sort_key(a)
		var kb := _sort_key(b)
		return ka > kb if ka != kb else GameState.item_display_name(a) < GameState.item_display_name(b))


func _sort_key(id: String) -> int:
	var k := 0
	if _shortage(id) > 0:
		k += 4
	if _needs.has(id):
		k += 2
	if GameState.get_item_count(id) > 0:
		k += 1
	return k


func _shortage(id: String) -> int:
	return int(_needs.get(id, 0)) - GameState.get_prepped_count(id)


func _rebuild_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	_buttons.clear()
	for id in _ids:
		var b := HuntUI.card_button()
		b.custom_minimum_size = Vector2(0, 80)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.pressed.connect(func():
			if not _busy:
				_select(id))
		var row := HBoxContainer.new()
		# Chừa viền khung thẻ (có chấm trang trí ở góc) để chữ không bị đè.
		row.set_anchors_preset(PRESET_FULL_RECT)
		row.offset_left = 14
		row.offset_top = 10
		row.offset_right = -20
		row.offset_bottom = -10
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		b.add_child(row)
		row.add_child(HuntUI.texture_rect(HuntUI.ingredient_texture(id), 44))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(col)
		var name_label := HuntUI.label(GameState.item_display_name(id), 18, HuntUI.GOLDEN_INK if id.begins_with(GameState.GOLDEN_PREFIX) else HuntUI.INK)
		name_label.clip_text = true
		col.add_child(name_label)
		var counts := HuntUI.label("", 15, HuntUI.INK_SOFT)
		counts.name = "Counts"
		col.add_child(counts)
		var badge := HuntUI.label("", 16, HuntUI.BAD)
		badge.name = "Badge"
		badge.custom_minimum_size = Vector2(48, 0)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(badge)
		HuntUI.ignore_mouse_recursive(b)
		_list.add_child(b)
		_buttons[id] = b
	_refresh_buttons()


func _refresh_buttons() -> void:
	for id in _buttons:
		var b: Button = _buttons[id]
		var raw := GameState.get_item_count(id)
		var prepped := GameState.get_prepped_count(id)
		(b.find_child("Counts", true, false) as Label).text = "Thô %d · Sơ chế %d" % [raw, prepped]
		var badge := b.find_child("Badge", true, false) as Label
		var text := ""
		var color := HuntUI.INK_SOFT
		if _needs.has(id):
			if _shortage(id) > 0 and raw > 0:
				text = "Cần"
				color = HuntUI.BAD
			elif raw == 0 and prepped == 0:
				text = "Hết"
			else:
				text = "Đủ"
				color = HuntUI.GOOD
		elif raw > 0:
			text = "Nhúng"
		badge.text = text
		badge.add_theme_color_override("font_color", color)
		b.modulate = Color(1, 1, 1) if id == _selected else Color(0.86, 0.84, 0.8)
	var any_raw := false
	for id in _ids:
		any_raw = any_raw or GameState.get_item_count(id) > 0
	_quick.disabled = _busy or not any_raw


## Nguyên liệu nên làm tiếp: đang thiếu cho món hôm nay và còn đồ thô; không có thì món nào còn đồ thô.
func _best_next() -> String:
	var fallback := ""
	for id in _ids:
		if GameState.get_item_count(id) <= 0:
			continue
		if _shortage(id) > 0:
			return id
		if fallback == "":
			fallback = id
	return fallback


# --- Màn trong khung phải -----------------------------------------------------

func _clear_view() -> void:
	if _view != null:
		_view.queue_free()
		_view = null


func _new_view() -> VBoxContainer:
	_clear_view()
	var v := VBoxContainer.new()
	v.position = Vector2(12, 8)
	v.size = PrepAction.AREA - Vector2(24, 16)
	v.add_theme_constant_override("separation", 10)
	_host.add_child(v)
	_view = v
	return v


func _select(id: String) -> void:
	_abort_session()
	_selected = id
	_refresh_buttons()
	_bar.value = 0.0
	_status.text = ""
	if id == "":
		_title.text = "SƠ CHẾ NGUYÊN LIỆU"
		_hint.text = ""
		_message("Kho chưa có nguyên liệu nào cần sơ chế. Đi săn thêm vào sáng mai nhé!")
		return
	_show_intro(id)


func _message(text: String) -> void:
	var v := _new_view()
	var l := HuntUI.label(text, 20, HuntUI.INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)


## Giới thiệu quy trình: các bước, số phần làm lượt này, chất lượng đang có trong kho.
func _show_intro(id: String) -> void:
	var recipe := Database.prep_recipe_for(id)
	var raw := GameState.get_item_count(id)
	_title.text = "%s · %d BƯỚC" % [GameState.item_display_name(id).to_upper(), recipe.steps.size()]
	_hint.text = "Làm khéo được Thượng hạng: nấu nhanh hơn, đồ nhúng bán giá cao hơn."
	var v := _new_view()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	top.add_child(HuntUI.texture_rect(HuntUI.ingredient_texture(id), 112))
	# Thành phẩm sau khi sơ chế (thô » đĩa đồ nhúng).
	var arrow := HuntUI.label("»", 40, HuntUI.INK_SOFT)
	arrow.size_flags_vertical = SIZE_SHRINK_CENTER
	top.add_child(arrow)
	top.add_child(HuntUI.texture_rect(HuntUI.prepped_texture(id), 112))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	top.add_child(info)
	var q := GameState.prepped_quality_counts(id)
	info.add_child(HuntUI.label("Thô %d · Đã sơ chế %d" % [raw, GameState.get_prepped_count(id)], 20, HuntUI.INK))
	info.add_child(HuntUI.label("Thượng hạng %d · Thường %d · Kém %d" % [q[2], q[1], q[0]], 18, HuntUI.INK_SOFT))
	var steps: Array[String] = []
	for i in recipe.steps.size():
		var s: PrepStepData = recipe.steps[i]
		steps.append("%d. %s%s" % [i + 1, s.title, " (tùy chọn)" if s.optional else ""])
	var flow := HuntUI.label("  ›  ".join(steps), 18, HuntUI.INK)
	flow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flow.custom_minimum_size = Vector2(PrepAction.AREA.x - 40, 0)
	v.add_child(flow)
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(spacer)
	if raw <= 0:
		var l := HuntUI.label("Hết %s thô trong kho. Đi săn thêm, hoặc chọn nguyên liệu khác." % GameState.item_display_name(id).to_lower(), 18, HuntUI.BAD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		return
	var n := mini(raw, cfg.session_max)
	var go := _flat_button("Bắt đầu sơ chế %d phần  »" % n, Color("f2a33a"), Color("8a5a3c"))
	go.size_flags_horizontal = SIZE_SHRINK_END
	go.pressed.connect(_start_session.bind(id))
	v.add_child(go)


# --- Lượt sơ chế ----------------------------------------------------------------

func _start_session(id: String) -> void:
	_recipe = Database.prep_recipe_for(id)
	_units = mini(GameState.get_item_count(id), cfg.session_max)
	if _recipe == null or _units <= 0:
		return
	_selected = id
	_refresh_buttons()
	_grades.clear()
	_step_i = 0
	_carry = null
	_clear_view()
	_next_step()


func _next_step() -> void:
	if _recipe == null:
		return
	if _step_i >= _recipe.steps.size():
		_finish_session()
		return
	var s: PrepStepData = _recipe.steps[_step_i]
	_title.text = "BƯỚC %d/%d · %s" % [_step_i + 1, _recipe.steps.size(), s.title.to_upper()]
	_hint.text = s.hint
	var script: GDScript = ACTIONS.get(s.kind, ACTIONS["swipe_cut"])
	_action = script.new()
	_action.carry = _carry # Tiếp tục từ hình sau bước trước (đã gỡ lá, đã thái...).
	_host.add_child(_action)
	_action.begin(s, cfg, _selected, _units, _difficulty(s))
	_action.finished.connect(_on_step_finished)
	_update_progress()


## Độ khó thật: bước dùng dao được nâng cấp Dao bén làm dễ hơn.
func _difficulty(s: PrepStepData) -> float:
	var d := s.difficulty
	if s.cut:
		d *= 1.0 - minf(cfg.knife_ease_max, cfg.knife_ease_per_level * GameState.get_upgrade_level("knife"))
	return d


func _update_progress() -> void:
	if _recipe == null:
		return
	_bar.value = float(_grades.size()) / float(_recipe.steps.size())
	_status.text = "Hoàn hảo %d · Ổn %d · Hỏng %d" % [_grades.count(2), _grades.count(1), _grades.count(0)]


func _on_step_finished(score: int) -> void:
	var grade := cfg.optional_skip_grade if score < 0 else cfg.grade_of(score)
	_grades.append(grade)
	_update_progress()
	step_done.emit()
	var flash := HuntUI.outlined_label("BỎ QUA" if score < 0 else str(GRADE_TEXT[grade]), 44, GRADE_COLOR[grade])
	flash.position = Vector2(PrepAction.AREA.x / 2.0 - 110, 90)
	flash.z_index = 5
	_host.add_child(flash)
	flash.pivot_offset = Vector2(110, 26)
	flash.scale = Vector2(0.5, 0.5)
	var t := flash.create_tween()
	t.tween_property(flash, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.45)
	t.tween_callback(flash.queue_free)
	var act := _action
	get_tree().create_timer(0.65).timeout.connect(func():
		if not is_inside_tree() or _action != act:
			return
		_carry = act.result_texture()
		act.queue_free()
		_action = null
		_step_i += 1
		_next_step())


func _finish_session() -> void:
	var id := _selected
	var units := mini(_units, GameState.get_item_count(id)) # Phụ bếp có thể đã dùng bớt đồ thô.
	var total := 0
	for g in _grades:
		total += g
	var avg := float(total) / maxf(1.0, _grades.size())
	var fails := _grades.count(0)
	var v := _new_view()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	if fails >= cfg.ruin_fails:
		var lost := GameState.ruin_items(id, units)
		_title.text = "HỎNG NẶNG!"
		_hint.text = "Hỏng %d bước: mất %d phần %s." % [fails, lost, GameState.item_display_name(id).to_lower()]
		v.add_child(_center_label("Hỏng nặng, mất %d phần" % lost, 34, HuntUI.BAD))
	else:
		var q := cfg.quality_of(avg)
		var n := GameState.prep_items(id, units, q)
		_title.text = "SƠ CHẾ XONG: %s" % str(GameState.QUALITY_NAMES[q]).to_upper()
		_hint.text = _effect_text(q) # Số Hoàn hảo/Ổn/Hỏng đã hiện trong thanh tiến độ.
		var pic := HuntUI.texture_rect(HuntUI.prepped_texture(id), 96)
		pic.size_flags_horizontal = SIZE_SHRINK_CENTER
		v.add_child(pic) # Icon đồ đã sơ chế (bày trên đĩa).
		v.add_child(_center_label("+%d %s" % [n, GameState.item_display_name(id).to_lower()], 26, HuntUI.INK))
		v.add_child(_center_label(str(GameState.QUALITY_NAMES[q]), 40, [HuntUI.BAD, HuntUI.INK, HuntUI.GOLDEN_INK][q]))
		prepped.emit(id)
	_recipe = null
	_bar.value = 1.0
	_status.text = "Hoàn hảo %d · Ổn %d · Hỏng %d" % [_grades.count(2), _grades.count(1), fails]
	_refresh_buttons()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	if GameState.get_item_count(id) > 0:
		var again := _flat_button("Sơ chế tiếp %s" % GameState.item_display_name(id).to_lower(), Color("f2a33a"), Color("8a5a3c"))
		again.pressed.connect(_start_session.bind(id))
		row.add_child(again)
	var next := _best_next()
	if next != "" and next != id:
		var go := _flat_button("Làm %s  »" % GameState.item_display_name(next).to_lower(), Color("e6d3a8"), Color("8a5a3c"))
		go.pressed.connect(_select.bind(next))
		row.add_child(go)


func _effect_text(q: int) -> String:
	var cook := roundi((1.0 - cfg.cook_time_mult(q)) * 100.0)
	var price := roundi((cfg.dipping_price_mult(q) - 1.0) * 100.0)
	var cook_text := "bình thường"
	if cook > 0:
		cook_text = "nhanh hơn %d%%" % cook
	elif cook < 0:
		cook_text = "chậm hơn %d%%" % -cook
	var price_text := "bình thường"
	if price > 0:
		price_text = "+%d%%" % price
	elif price < 0:
		price_text = "%d%%" % price
	return "Nấu nước cốt %s · Giá đồ nhúng %s" % [cook_text, price_text]


func _center_label(text: String, size_px: int, color: Color) -> Label:
	var l := HuntUI.label(text, size_px, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Bỏ lượt đang chơi dở (chưa trừ kho gì).
func _abort_session() -> void:
	_recipe = null
	if _action != null:
		_action.queue_free()
		_action = null
	_clear_view()


# --- Sơ chế nhanh -----------------------------------------------------------------

func _quick_all() -> void:
	if _busy:
		return
	_abort_session()
	var total := 0
	for id in _ids:
		total += GameState.get_item_count(id)
	if total <= 0:
		return
	_busy = true
	_refresh_buttons()
	var secs := minf(cfg.quick_max_seconds, total * cfg.quick_seconds_per_unit)
	var quality_name := str(GameState.QUALITY_NAMES[cfg.quick_quality])
	_title.text = "SƠ CHẾ NHANH TẤT CẢ"
	_hint.text = "Làm vội cả kho %d phần, chất lượng %s." % [total, quality_name.to_lower()]
	_status.text = ""
	var v := _new_view()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_center_label("Đang sơ chế nhanh %d phần..." % total, 26, HuntUI.INK))
	_bar.value = 0.0
	var t := create_tween()
	t.tween_property(_bar, "value", 1.0, secs)
	t.tween_callback(_quick_done.bind(quality_name))


func _quick_done(quality_name: String) -> void:
	var done := 0
	for id in _ids:
		done += GameState.prep_items(id, GameState.get_item_count(id), cfg.quick_quality)
	_busy = false
	_title.text = "SƠ CHẾ NHANH XONG"
	_hint.text = _effect_text(cfg.quick_quality)
	var v := _new_view()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_center_label("Đã sơ chế nhanh %d phần" % done, 28, HuntUI.INK))
	v.add_child(_center_label("Chất lượng: %s" % quality_name, 24, HuntUI.INK_SOFT))
	v.add_child(_center_label("Muốn Thượng hạng thì chọn từng nguyên liệu và tự làm.", 18, HuntUI.INK_SOFT))
	prepped.emit("")
	_refresh_buttons()
