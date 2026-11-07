extends ScreenBase
## Trưa – nấu nước cốt lẩu.

const BASE_POT_COUNT := 1

var _cooking: Array[Dictionary] = []


func _get_title() -> String:
	return "Trưa – Nấu nước cốt lẩu"


func _ready() -> void:
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	for i in range(_cooking.size() - 1, -1, -1):
		var pot := _cooking[i]
		pot["remaining"] = float(pot["remaining"]) - delta
		if float(pot["remaining"]) <= 0.0:
			_cooking.remove_at(i)
			GameState.add_broth(str(pot["broth_id"]))
			log_line("Đã nấu xong 1 nồi %s." % str(pot["display_name"]))
			_rebuild()
	_update_pot_labels()


func _setup() -> void:
	_rebuild()
	log_line("Chọn nước cốt để nấu. Mỗi nồi tốn nguyên liệu theo công thức.")


func _rebuild() -> void:
	clear_actions()
	var max_pots := BASE_POT_COUNT + GameState.get_upgrade_level("stove")
	var info := Label.new()
	info.text = "Số nồi đang nấu: %d / %d nồi tối đa (Cấp bếp: %d)" % [_cooking.size(), max_pots, GameState.get_upgrade_level("stove")]
	info.add_theme_font_size_override("font_size", 18)
	actions.add_child(info)
	for pot in _cooking:
		var row := Label.new()
		row.text = "%s - %s - %.0fs" % [str(pot["display_name"]), "Đang nấu", maxf(float(pot["remaining"]), 0.0)]
		row.add_theme_font_size_override("font_size", 18)
		actions.add_child(row)
		pot["ui_label"] = row
	for broth in Database.broths_for_day(GameState.day):
		var cook_time := broth.cook_time * Database.upgrade_value("stove")
		var button := add_action(
			"Nấu %s (cần %s, %.0fs)" % [broth.display_name, GameState.describe_items(broth.ingredients), cook_time],
			_cook.bind(broth))
		button.disabled = not GameState.has_items(broth.ingredients) or _cooking.size() >= max_pots
	if _cooking.size() >= max_pots:
		log_line("Bếp đã đầy nồi (tối đa %d nồi), hãy đợi nấu xong!" % max_pots)
	add_action("Mở quán bán hàng »", DayManager.next_phase)


func _update_pot_labels() -> void:
	for pot in _cooking:
		if pot.has("ui_label"):
			var label: Label = pot["ui_label"]
			label.text = "%s - %s - %.0fs" % [str(pot["display_name"]), "Đang nấu", maxf(float(pot["remaining"]), 0.0)]


func _cook(broth: BrothData) -> void:
	var max_pots := BASE_POT_COUNT + GameState.get_upgrade_level("stove")
	if _cooking.size() >= max_pots:
		log_line("Bếp đã đầy nồi (tối đa %d nồi), hãy đợi nấu xong!" % max_pots)
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
	})
	log_line("Bắt đầu nấu 1 nồi %s (%.0fs)." % [broth.display_name, cook_time])
	_rebuild()
