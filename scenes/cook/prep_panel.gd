class_name PrepPanel
extends Control
## Bảng sơ chế nguyên liệu (đè lên khu bếp, giờ vẫn chạy):
## trái = danh sách nguyên liệu cần cho các món hôm nay (thô / đã sơ chế), phải = trò sơ chế đang chơi.
## Mỗi phần xong: GameState.prep_items() chuyển 1 phần từ kho thô sang kho đã sơ chế.

signal closed
signal prepped(id: String) ## Vừa sơ chế xong 1 phần (đầu bếp làm động tác thái).

const GAMES := {
	"chop": preload("res://scenes/cook/prep_chop.gd"),
	"wash": preload("res://scenes/cook/prep_wash.gd"),
	"sort": preload("res://scenes/cook/prep_sort.gd"),
	"peel": preload("res://scenes/cook/prep_peel.gd"),
}

var cfg: KitchenConfig
var _needs: Dictionary = {} ## id -> số phần cần cho 1 mẻ (lấy món cần nhiều nhất).
var _ids: Array[String] = []
var _list: VBoxContainer
var _buttons: Dictionary = {} ## id -> Button
var _host: Control
var _game: PrepGame = null
var _selected := ""
var _title: Label
var _hint: Label
var _status: Label
var _bar: ProgressBar
var _message: Label


func open(config: KitchenConfig, needs: Dictionary) -> void:
	cfg = config
	_needs = needs
	for id in needs:
		_ids.append(str(id))
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_panel", 8, Vector2(22, 16)))
	panel.position = Vector2(20, 94)
	panel.size = Vector2(1240, 560)
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	root.add_child(head)
	head.add_child(HuntUI.label("SƠ CHẾ NGUYÊN LIỆU LẨU", 26, HuntUI.RUST))
	var sub := HuntUI.label("Chạm, vuốt, kéo hoặc giữ để chuẩn bị nguyên liệu. Chỉ nấu được bằng đồ đã sơ chế.", 18, HuntUI.INK_SOFT)
	sub.size_flags_horizontal = SIZE_EXPAND_FILL
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(sub)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	var game_card := PanelContainer.new()
	game_card.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_card", 8, Vector2(14, 10)))
	game_card.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(game_card)
	var gbox := VBoxContainer.new()
	gbox.add_theme_constant_override("separation", 4)
	game_card.add_child(gbox)
	_title = HuntUI.label("", 22, HuntUI.RUST)
	gbox.add_child(_title)
	_hint = HuntUI.label("", 18, HuntUI.INK)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gbox.add_child(_hint)
	_host = Control.new()
	_host.custom_minimum_size = PrepGame.AREA
	gbox.add_child(_host)
	_message = HuntUI.label("", 20, HuntUI.INK_SOFT)
	_message.position = Vector2(40, 120)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(700, 0)
	_host.add_child(_message)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 12)
	gbox.add_child(prow)
	_bar = HuntUI.hp_bar(true)
	_bar.max_value = 1.0
	_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	_bar.custom_minimum_size = Vector2(0, 24)
	prow.add_child(_bar)
	_status = HuntUI.label("", 18, HuntUI.INK)
	_status.custom_minimum_size = Vector2(300, 0)
	prow.add_child(_status)

	var foot := HBoxContainer.new()
	root.add_child(foot)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	foot.add_child(spacer)
	var close := HuntUI.button("Xong, chuyển sang nấu lẩu »", 360)
	close.pressed.connect(close_panel)
	foot.add_child(close)

	_ids.sort_custom(func(a: String, b: String) -> bool: return _shortage(a) > _shortage(b))
	_rebuild_list()
	HuntUI.book_open(panel)
	var first := _best_next("")
	_select(first if first != "" else (_ids[0] if not _ids.is_empty() else ""))


## Chọn sẵn 1 nguyên liệu (vd bấm thẻ món đang thiếu đồ sơ chế).
func select(id: String) -> void:
	if _buttons.has(id):
		_select(id)


func close_panel() -> void:
	if _game != null:
		_game.stop()
	closed.emit()
	queue_free()


func _process(_delta: float) -> void:
	if _game != null:
		_bar.value = _game.progress()
		_status.text = _game.status_text()


func _shortage(id: String) -> int:
	return int(_needs.get(id, 0)) * cfg.staff_target_batches - GameState.get_prepped_count(id)


func _rebuild_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	_buttons.clear()
	for id in _ids:
		var b := HuntUI.card_button()
		b.custom_minimum_size = Vector2(316, 70)
		b.pressed.connect(_select.bind(id))
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(PRESET_FULL_RECT, PRESET_MODE_MINSIZE, 8)
		row.add_theme_constant_override("separation", 8)
		b.add_child(row)
		row.add_child(HuntUI.texture_rect(HuntUI.ingredient_texture(id), 44))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(HuntUI.label(GameState.item_display_name(id), 18, HuntUI.INK))
		var counts := HuntUI.label("", 16, HuntUI.INK_SOFT)
		counts.name = "Counts"
		col.add_child(counts)
		var badge := HuntUI.label("", 15, HuntUI.BAD)
		badge.name = "Badge"
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
		(b.find_child("Counts", true, false) as Label).text = "Thô x%d · Đã sơ chế x%d" % [raw, prepped]
		var badge := b.find_child("Badge", true, false) as Label
		var short := _shortage(id)
		badge.text = "Cần" if short > 0 and raw > 0 else ("Hết" if raw == 0 else "Đủ")
		badge.add_theme_color_override("font_color", HuntUI.BAD if (short > 0 and raw > 0) else (HuntUI.INK_SOFT if raw == 0 else HuntUI.GOOD))
		b.modulate = Color(1, 1, 1) if id == _selected else Color(0.86, 0.84, 0.8)


## Nguyên liệu nên làm tiếp: đang thiếu và còn đồ thô (ưu tiên giữ nguyên món đang làm).
func _best_next(current: String) -> String:
	if current != "" and GameState.get_item_count(current) > 0 and _shortage(current) > 0:
		return current
	var best := ""
	var best_short := 0
	for id in _ids:
		var short := _shortage(id)
		if GameState.get_item_count(id) > 0 and short > best_short:
			best = id
			best_short = short
	return best


func _select(id: String) -> void:
	if _game != null:
		_game.stop()
		_game.queue_free()
		_game = null
	_selected = id
	_refresh_buttons()
	_bar.value = 0.0
	if id == "":
		_show_message("Hôm nay chưa có món nào cần sơ chế.")
		return
	var raw := GameState.get_item_count(id)
	if raw <= 0:
		_title.text = GameState.item_display_name(id).to_upper()
		_hint.text = ""
		_status.text = ""
		_show_message("Hết %s thô trong kho. Đi săn thêm vào sáng mai, hoặc chọn nguyên liệu khác." % GameState.item_display_name(id).to_lower())
		return
	_show_message("")
	var game_class: GDScript = GAMES.get(cfg.method_for(id), GAMES["chop"])
	_game = game_class.new()
	_host.add_child(_game)
	_game.begin(id, mini(raw, cfg.prep_session_max), cfg)
	_game.unit_done.connect(_on_unit_done)
	_game.all_done.connect(_on_all_done)
	_title.text = _game.title()
	_hint.text = _game.hint()


func _show_message(text: String) -> void:
	_message.text = text
	_message.visible = text != ""


func _on_unit_done() -> void:
	if GameState.prep_items(_selected, 1) > 0:
		prepped.emit(_selected)
	else:
		# Kho thô đã hết (vd phụ bếp vừa dùng): dừng lượt này.
		if _game != null:
			_game.stop()
		_status.text = "Hết %s thô!" % GameState.item_display_name(_selected).to_lower()
	_refresh_buttons()


func _on_all_done() -> void:
	var finished_id := _selected
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree() or _selected != finished_id:
		return
	var next := _best_next(finished_id)
	if next == "" and GameState.get_item_count(finished_id) > 0:
		next = finished_id
	if next != "":
		_select(next)
	else:
		if _game != null:
			_game.queue_free()
			_game = null
		_title.text = "ĐÃ SƠ CHẾ XONG"
		_hint.text = ""
		_show_message("Đã sơ chế hết nguyên liệu thô cần cho món hôm nay. Bấm \"Xong\" để nấu lẩu!")
