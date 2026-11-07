extends Control
## Trưa – nấu nước cốt lẩu.

const BASE_POT_COUNT := 1

var _cooking: Array[Dictionary] = []
var _pots_container: GridContainer
var _recipes_container: VBoxContainer
var _info_label: Label


func _ready() -> void:
	DayManager.phase_time_up.connect(_on_phase_time_up)
	_build_ui()
	_rebuild()


func _process(delta: float) -> void:
	for i in range(_cooking.size() - 1, -1, -1):
		var pot := _cooking[i]
		pot["remaining"] = float(pot["remaining"]) - delta
		var ui: Dictionary = pot["ui"]
		if ui.is_empty() or not ui.has("bar"):
			continue
		var total := float(pot["total"])
		var progress := 100.0 * (1.0 - float(pot["remaining"]) / total) if total > 0.0 else 100.0
		(ui["bar"] as ProgressBar).value = clampf(progress, 0.0, 100.0)
		(ui["time"] as Label).text = "%.0fs" % maxf(float(pot["remaining"]), 0.0)
		if float(pot["remaining"]) <= 0.0:
			_cooking.remove_at(i)
			_add_cooked(pot)
			log_line("Đã nấu xong 1 nồi %s." % str(pot["display_name"]))
			(ui["card"] as Control).queue_free()
			_rebuild()
	_update_info()


func _build_ui() -> void:
	add_child(HuntUI.background())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := HuntUI.outlined_label("Trưa · Nấu nước cốt lẩu", 26, HuntUI.GOLD)
	root.add_child(title)

	_info_label = HuntUI.label("Số nồi đang nấu: 0 / 0", 18, HuntUI.INK)
	root.add_child(_info_label)

	var stove_label := HuntUI.label("Khu vực bếp lò", 22, HuntUI.RUST)
	root.add_child(stove_label)

	_pots_container = GridContainer.new()
	_pots_container.columns = 3
	_pots_container.add_theme_constant_override("h_separation", 12)
	_pots_container.add_theme_constant_override("v_separation", 12)
	root.add_child(_pots_container)

	var recipe_label := HuntUI.label("Chọn món nấu", 22, HuntUI.RUST)
	root.add_child(recipe_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_recipes_container = VBoxContainer.new()
	_recipes_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_recipes_container)

	var next_btn := HuntUI.button("Mở quán bán hàng »")
	next_btn.pressed.connect(DayManager.next_phase)
	root.add_child(next_btn)


func _rebuild() -> void:
	_update_pots()
	_rebuild_recipes()
	_update_info()


func _update_info() -> void:
	var max_pots := BASE_POT_COUNT + GameState.get_upgrade_level("stove")
	_info_label.text = "Số nồi đang nấu: %d / %d nồi tối đa (Cấp bếp: %d)" % [_cooking.size(), max_pots, GameState.get_upgrade_level("stove")]


func _update_pots() -> void:
	for child in _pots_container.get_children():
		child.queue_free()
	var max_pots := BASE_POT_COUNT + GameState.get_upgrade_level("stove")
	for i in max_pots:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(220, 120)
		card.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_card"))
		var vbox := VBoxContainer.new()
		card.add_child(vbox)
		var pot_data := _pot_at_index(i)
		if pot_data.is_empty():
			var lbl := HuntUI.label("Bếp lò trống", 18, HuntUI.INK_SOFT)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(lbl)
		else:
			var name_lbl := HuntUI.label(str(pot_data["display_name"]), 18, HuntUI.INK)
			vbox.add_child(name_lbl)
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(0, 24)
			var total := float(pot_data["total"])
			var progress := 100.0 * (1.0 - float(pot_data["remaining"]) / total) if total > 0.0 else 100.0
			bar.value = clampf(progress, 0.0, 100.0)
			vbox.add_child(bar)
			var time_lbl := HuntUI.label("%.0fs" % maxf(float(pot_data["remaining"]), 0.0), 16, HuntUI.INK)
			vbox.add_child(time_lbl)
			pot_data["ui"] = {"card": card, "bar": bar, "time": time_lbl}
		_pots_container.add_child(card)


func _pot_at_index(index: int) -> Dictionary:
	if index < _cooking.size():
		return _cooking[index]
	return {}


func _rebuild_recipes() -> void:
	for child in _recipes_container.get_children():
		child.queue_free()
	var max_pots := BASE_POT_COUNT + GameState.get_upgrade_level("stove")
	for broth in Database.broths_for_day(GameState.day):
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_card"))
		var vbox := VBoxContainer.new()
		card.add_child(vbox)
		var name_lbl := HuntUI.label("%s - %s" % [broth.display_name, GameState.format_money(broth.price)], 18, HuntUI.INK)
		vbox.add_child(name_lbl)
		var time_lbl := HuntUI.label("Thời gian nấu: %.0fs" % (broth.cook_time * Database.upgrade_value("stove")), 16, HuntUI.INK_SOFT)
		vbox.add_child(time_lbl)
		vbox.add_child(HuntUI.items_row(broth.ingredients, 32))
		var btn := HuntUI.button("Bắt đầu nấu")
		btn.disabled = not GameState.has_items(broth.ingredients) or _cooking.size() >= max_pots
		btn.pressed.connect(_cook.bind(broth))
		vbox.add_child(btn)
		_recipes_container.add_child(card)


func _cook(broth: BrothData) -> void:
	var max_pots := BASE_POT_COUNT + GameState.get_upgrade_level("stove")
	if _cooking.size() >= max_pots:
		return
	if not GameState.has_items(broth.ingredients):
		return
	var used := GameState.consume_items_info(broth.ingredients)
	if not used["ok"]:
		return
	var cook_time := broth.cook_time * Database.upgrade_value("stove")
	_cooking.append({
		"broth_id": broth.id,
		"display_name": broth.display_name,
		"remaining": cook_time,
		"total": cook_time,
		"from_day": used["oldest_day"],
		"expired": used["expired"],
		"ui": {},
	})
	if used["expired"]:
		print("[color=orange]Nồi này nấu từ nguyên liệu hết hạn, bán ra có thể bị khách phát hiện![/color]")
	_rebuild()


func _add_cooked(pot: Dictionary) -> void:
	GameState.add_broth(str(pot["broth_id"]), 1, int(pot.get("from_day", -1)), bool(pot.get("expired", false)))


func _on_phase_time_up() -> void:
	for pot in _cooking:
		_add_cooked(pot)
	_cooking.clear()
	DayManager.next_phase()


func log_line(text: String) -> void:
	print(text)