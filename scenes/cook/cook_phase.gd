extends Control
## Trưa – nấu nước cốt lẩu.

const BASE_POT_COUNT := 1

var _cooking: Array[Dictionary] = []
var _pots_container: GridContainer
var _recipes_container: VBoxContainer
var _info_label: Label


func _ready() -> void:
	_build_ui()
	_rebuild()


func _process(delta: float) -> void:
	for i in range(_cooking.size() - 1, -1, -1):
		var pot := _cooking[i]
		pot["remaining"] = float(pot["remaining"]) - delta
		var ui: Dictionary = pot["ui"]
		var total := float(pot["total"])
		var progress := 100.0 * (1.0 - float(pot["remaining"]) / total) if total > 0.0 else 100.0
		(ui["bar"] as ProgressBar).value = clampf(progress, 0.0, 100.0)
		(ui["time"] as Label).text = "%.0fs" % maxf(float(pot["remaining"]), 0.0)
		if float(pot["remaining"]) <= 0.0:
			_cooking.remove_at(i)
			GameState.add_broth(str(pot["broth_id"]))
			log_msg("Đã nấu xong 1 nồi %s." % str(pot["display_name"]))
			(ui["card"] as Control).queue_free()
			_rebuild()
	_update_info()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var title := Label.new()
	title.text = "Trưa – Nấu nước cốt lẩu"
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 18)
	root.add_child(_info_label)

	var stove_label := Label.new()
	stove_label.text = "Khu vực bếp lò"
	stove_label.add_theme_font_size_override("font_size", 22)
	root.add_child(stove_label)

	_pots_container = GridContainer.new()
	_pots_container.columns = 3
	_pots_container.add_theme_constant_override("h_separation", 12)
	_pots_container.add_theme_constant_override("v_separation", 12)
	root.add_child(_pots_container)

	var recipe_label := Label.new()
	recipe_label.text = "Chọn món nấu"
	recipe_label.add_theme_font_size_override("font_size", 22)
	root.add_child(recipe_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_recipes_container = VBoxContainer.new()
	_recipes_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_recipes_container)

	var next_btn := Button.new()
	next_btn.text = "Mở quán bán hàng »"
	next_btn.custom_minimum_size = Vector2(0, 56)
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
		var vbox := VBoxContainer.new()
		card.add_child(vbox)
		var pot_data := _pot_at_index(i)
		if pot_data == null:
			var lbl := Label.new()
			lbl.text = "Bếp lò trống"
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(lbl)
		else:
			var name_lbl := Label.new()
			name_lbl.text = str(pot_data["display_name"])
			vbox.add_child(name_lbl)
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(0, 24)
			var total := float(pot_data["total"])
			var progress := 100.0 * (1.0 - float(pot_data["remaining"]) / total) if total > 0.0 else 100.0
			bar.value = clampf(progress, 0.0, 100.0)
			vbox.add_child(bar)
			var time_lbl := Label.new()
			time_lbl.text = "%.0fs" % maxf(float(pot_data["remaining"]), 0.0)
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
		var vbox := VBoxContainer.new()
		card.add_child(vbox)
		var name_lbl := Label.new()
		name_lbl.text = "%s - %s" % [broth.display_name, GameState.format_money(broth.price)]
		name_lbl.add_theme_font_size_override("font_size", 18)
		vbox.add_child(name_lbl)
		var time_lbl := Label.new()
		var cook_time := broth.cook_time * Database.upgrade_value("stove")
		time_lbl.text = "Thời gian nấu: %.0fs" % cook_time
		vbox.add_child(time_lbl)
		var ing_box := HBoxContainer.new()
		for id in broth.ingredients:
			var ing_lbl := Label.new()
			ing_lbl.text = "%s x%d/%d" % [id, GameState.get_item_count(id), int(broth.ingredients[id])]
			ing_lbl.add_theme_font_size_override("font_size", 16)
			ing_box.add_child(ing_lbl)
		vbox.add_child(ing_box)
		var btn := Button.new()
		btn.text = "Bắt đầu nấu"
		btn.custom_minimum_size = Vector2(0, 56)
		btn.disabled = not GameState.has_items(broth.ingredients) or _cooking.size() >= max_pots
		btn.pressed.connect(_cook.bind(broth))
		vbox.add_child(btn)
		_recipes_container.add_child(card)


func _cook(broth: BrothData) -> void:
	var max_pots := BASE_POT_COUNT + GameState.get_upgrade_level("stove")
	if _cooking.size() >= max_pots:
		log_msg("Bếp đã đầy nồi (tối đa %d nồi), hãy đợi nấu xong!" % max_pots)
		return
	if not GameState.has_items(broth.ingredients):
		return
	if not GameState.consume_items(broth.ingredients):
		return
	var cook_time := broth.cook_time * Database.upgrade_value("stove")
	_cooking.append({
		"broth_id": broth.id,
		"display_name": broth.display_name,
		"remaining": cook_time,
		"total": cook_time,
		"ui": {},
	})
	log_msg("Bắt đầu nấu 1 nồi %s (%.0fs)." % [broth.display_name, cook_time])
	_rebuild()


func log_msg(text: String) -> void:
	print(text)