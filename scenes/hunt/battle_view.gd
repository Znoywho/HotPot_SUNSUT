class_name BattleView
extends Control
## Màn hình trận đánh (S11): sprite, thanh máu, chọn mục tiêu bằng chạm, thứ tự lượt,
## chiêu đầu bếp, số sát thương bay lên, Tự đánh và tốc độ x2.
## Dùng: add_child(view); view.start(session, encounter); chờ signal closed(result).

signal closed(result: BattleController.Result)
signal _action_chosen(choice: Dictionary)

const ORDER_PREVIEW := 7
const ORDER_SLOT := 56 ## Kích thước 1 ô trên thanh lượt.
const ORDER_BIG := 68 ## Ô của người đang đánh (to hơn).
const ORDER_GAP := 6
const ORDER_ARROW := 28 ## Chỗ cho dấu » sau ô đang đánh.
const ORDER_SLIDE := 0.28 ## Thời gian trượt 1 ô (giây).
const SFX_DIR := "res://assets/audio/sfx/"

var session: HuntSession
var encounter: Encounter
var controller: BattleController
var views := {} ## Combatant -> CombatantView
var selected_target: Combatant
var auto_mode := false
var fast_mode := false
var _waiting_input := false
var _timed_out := false
var _log_index := 0

var _allies_box: HBoxContainer
var _enemies_box: HBoxContainer
var _order_box: Control ## Thanh lượt: các ô đặt tay để trượt mượt.
var _order_slots: Array[Dictionary] = [] ## {c: Combatant, node: PanelContainer}
var _order_arrow: Label
var _order_current: Combatant ## Người đang/vừa đánh, giữ ở ô đầu tới lượt sau.
var _log: RichTextLabel
var _turn_label: Label
var _skill_buttons: Array[Button] = []
var _flee_button: Button
var _auto_button: Button
var _fast_button: Button
var _float_layer: Control
var _arena: Control
var timer_label: Label


func start(p_session: HuntSession, p_encounter: Encounter) -> void:
	session = p_session
	encounter = p_encounter
	controller = BattleController.new(session.allies(), encounter.create_enemies(), session.player, session.config)
	_build()
	for c in controller.battle.allies:
		_add_view(c)
	for c in controller.battle.enemies:
		_add_view(c)
	selected_target = controller.default_target()
	controller.battle.add_log("Trận bắt đầu! Thanh \"Lượt tiếp\" cho biết ai sẽ hành động trước.")
	_refresh_all()
	_flush_log()
	_run()


func _process(_delta: float) -> void:
	if timer_label != null:
		timer_label.visible = DayManager.timer_running and get_tree().get_first_node_in_group("hud") == null
		timer_label.text = "Còn lại " + DayManager.time_left_text()


## Gọi khi hết giờ săn giữa trận.
func time_out() -> void:
	_timed_out = true
	if _waiting_input:
		_action_chosen.emit({"timeout": true})


# --- Vòng lặp lượt ----------------------------------------------------------

func _run() -> void:
	while not controller.is_finished() and not _timed_out:
		var before := controller.snapshot()
		var actor := controller.begin_turn()
		if actor == null:
			break
		await _show_changes(before)
		if not controller.can_act(actor) or _timed_out:
			continue
		_set_acting(actor)
		_update_order(actor)
		if controller.is_player(actor) and not auto_mode:
			var choice: Dictionary = await _wait_player()
			if choice.has("timeout"):
				break
			if choice.has("flee"):
				controller.flee()
				break
			before = controller.snapshot()
			if choice.has("auto"):
				controller.ai_action(actor)
			else:
				_bump(actor)
				_play_skill_sfx(choice.skill)
				controller.player_action(choice.skill, selected_target)
		else:
			await _wait(session.config.action_delay)
			if _timed_out:
				break
			before = controller.snapshot()
			_bump(actor)
			controller.ai_action(actor)
		await _show_changes(before)
		await _wait(session.config.action_delay * 0.5)
	if _timed_out and controller.result == BattleController.Result.NONE:
		controller.time_out()
	_set_acting(null)
	_flush_log()
	_set_actions_enabled(false)
	_finish()


func _wait_player() -> Dictionary:
	_turn_label.text = "Lượt của bạn: chạm vào quái để chọn mục tiêu, rồi chọn chiêu"
	_ensure_target()
	_set_actions_enabled(true)
	_waiting_input = true
	var choice: Dictionary = await _action_chosen
	_waiting_input = false
	_set_actions_enabled(false)
	_turn_label.text = ""
	return choice


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds / (2.0 if fast_mode else 1.0)).timeout


# --- Hiệu ứng ---------------------------------------------------------------

## So trạng thái trước/sau để hiện số sát thương, hồi máu, giáp, chết.
func _show_changes(before: Dictionary) -> void:
	var shake := false
	var hurt := false
	var crit_hit := false
	var died := false
	var new_lines := controller.battle.log_lines.slice(_log_index)
	var all_text := "\n".join(new_lines)
	for c in controller.battle.all_combatants():
		if not views.has(c):
			_add_view(c) # Đơn vị mới sinh (nấm con).
			_float_text(c, "Xuất hiện!", Color("ffe0b2"))
			_fx(c, "smoke", 1.2)
			continue
		var prev: Dictionary = before.get(c, {})
		if prev.is_empty():
			continue
		var view: CombatantView = views[c]
		var dhp: int = c.hp - int(prev.hp)
		var darmor: int = c.armor - int(prev.armor)
		if dhp < 0:
			view.play_hurt(c in controller.crits)
			hurt = true
			_fx_for_damage(c, new_lines, all_text)
			if c in controller.crits:
				crit_hit = true
				_float_text(c, "CHÍ MẠNG -%d" % -dhp, Color("ffd54f"), 34)
			else:
				_float_text(c, "-%d" % -dhp, Color("ff6b6b"))
		elif dhp > 0:
			_float_text(c, "+%d" % dhp, Color("8cff8c"))
			_fx(c, "heal")
		if darmor > 0:
			_float_text(c, "+%d giáp" % darmor, Color("81d4fa"), 22, 30)
			_fx(c, "shield")
		if prev.alive and not c.is_alive():
			died = true
			if c.data != null and c.data.id == "mad_bull":
				shake = true
				_fx(c, "explosion_big")
			elif c.data != null and c.data.is_boss:
				_fx(c, "explosion_fire", 3.0)
			else:
				_fx(c, "smoke")
	for line in controller.battle.log_lines.slice(_log_index):
		if "né" in line:
			for c in controller.battle.all_combatants():
				if line.begins_with(c.display_name + " nhảy né"):
					_float_text(c, "Né!", Color("e1f5fe"))
	if shake:
		_shake()
		_sfx("explosion")
	elif died:
		_sfx("defeat")
	elif crit_hit:
		_sfx("crit")
	elif hurt:
		_sfx("hit")
	_flush_log()
	_refresh_all()
	await _wait(0.25)


## Chọn hiệu ứng theo nguyên nhân mất máu (đọc từ nhật ký trận của bước vừa rồi).
func _fx_for_damage(c: Combatant, lines: Array, all_text: String) -> void:
	var name := c.display_name
	for line in lines:
		var l: String = line
		if l.begins_with(name + " bị đốt"):
			_fx(c, "flame")
			return
		if l.begins_with(name + " trúng độc"):
			_fx(c, "poison")
			return
		if l.strip_edges().begins_with(name + " bị bỏng"):
			_fx(c, "splash_broth")
			return
	if not c.is_ally and "hất nồi lẩu" in all_text:
		_fx(c, "splash_broth")
	elif "phát nổ" in all_text and not (c.data != null and c.data.id == "mad_bull"):
		_fx(c, "burst", 2.0)
	elif c in controller.crits:
		_fx(c, "burst")
	else:
		_fx(c, "slash")


func _fx(c: Combatant, fx_name: String, scale := -1.0, tint := Color.WHITE) -> void:
	var view: CombatantView = views.get(c)
	if view == null:
		return
	var rect := view.sprite.get_global_rect()
	HuntFX.play(_float_layer, fx_name, rect.get_center(), scale, tint, 2.0 if fast_mode else 1.0)


func _float_text(c: Combatant, text: String, color: Color, size := 28, offset := 0.0) -> void:
	var view: CombatantView = views.get(c)
	if view == null:
		return
	var l := HuntUI.outlined_label(text, size, color)
	l.add_theme_constant_override("outline_size", 6)
	_float_layer.add_child(l)
	var rect := view.sprite.get_global_rect()
	l.global_position = Vector2(rect.position.x + rect.size.x / 2.0 - 40 + randf_range(-12, 12), rect.position.y + rect.size.y * 0.3 + offset)
	var tween := l.create_tween()
	tween.set_parallel(true)
	tween.tween_property(l, "position:y", l.position.y - 60, 0.9 / (2.0 if fast_mode else 1.0))
	tween.tween_property(l, "modulate:a", 0.0, 0.9 / (2.0 if fast_mode else 1.0)).set_delay(0.3)
	tween.chain().tween_callback(l.queue_free)


func _shake() -> void:
	var tween := create_tween()
	for i in 6:
		tween.tween_property(_arena, "position:x", 10.0 * (1 if i % 2 == 0 else -1), 0.04)
	tween.tween_property(_arena, "position:x", 0.0, 0.04)


func _sfx(sound: String) -> void:
	var path := SFX_DIR + sound + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.pitch_scale = randf_range(0.92, 1.08)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _play_skill_sfx(skill: ChefSkill) -> void:
	if skill is HotSplashSkill:
		_sfx("splash")
	elif skill is SliceSkill:
		_sfx("slice")


func _bump(actor: Combatant) -> void:
	var view: CombatantView = views.get(actor)
	if view != null:
		view.play_attack(1.0 if actor.is_ally else -1.0)


# --- Chọn mục tiêu / hành động ---------------------------------------------

func _on_view_tapped(view: CombatantView) -> void:
	if view.combatant.is_ally or not view.combatant.is_alive():
		return
	selected_target = view.combatant
	_refresh_selection()


func _ensure_target() -> void:
	if selected_target == null or not selected_target.is_alive():
		selected_target = controller.default_target()
	_refresh_selection()


func _on_skill_pressed(index: int) -> void:
	if _waiting_input:
		_action_chosen.emit({"skill": controller.skills[index]})


func _on_flee_pressed() -> void:
	if _waiting_input:
		_action_chosen.emit({"flee": true})


func _on_auto_toggled(on: bool) -> void:
	auto_mode = on
	_auto_button.text = "Tự đánh: Bật" if on else "Tự đánh: Tắt"
	if on and _waiting_input:
		_action_chosen.emit({"auto": true})


func _on_fast_toggled(on: bool) -> void:
	fast_mode = on
	_fast_button.text = "Tốc độ x2" if on else "Tốc độ x1"


func _set_actions_enabled(enabled: bool) -> void:
	for i in _skill_buttons.size():
		var skill := controller.skills[i]
		var b := _skill_buttons[i]
		b.disabled = not enabled or not skill.is_ready()
		if skill.is_ready():
			b.text = "%s\n%s" % [skill.display_name, skill.description]
		else:
			b.text = "%s\n(chờ %d lượt)" % [skill.display_name, skill.cooldown_left]
	_flee_button.disabled = not enabled


# --- Kết thúc ---------------------------------------------------------------

func _finish() -> void:
	var drops := session.finish_battle(controller, encounter)
	var result := controller.result
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_panel", 8, Vector2(28, 22)))
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	HuntUI.book_open(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	var title := ""
	var color := Color.WHITE
	match result:
		BattleController.Result.WIN:
			title = "Thắng!"
			color = HuntUI.GOOD
		BattleController.Result.LOSE:
			title = "Đầu bếp gục ngã..."
			color = HuntUI.BAD
		BattleController.Result.FLED:
			title = "Đã bỏ chạy"
			color = HuntUI.WARN
		BattleController.Result.TIMEOUT:
			title = "Hết giờ săn!"
			color = HuntUI.RUST
	var t := HuntUI.label(title, 40, color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	if result == BattleController.Result.WIN:
		_sfx("loot")
		box.add_child(HuntUI.label("Nhận được:", HuntUI.FONT))
		var row := HuntUI.items_row(drops, 48)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(row)
		var names := HuntUI.label(HuntUI.describe_items(drops), HuntUI.FONT_SMALL, HuntUI.INK_SOFT)
		names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		names.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(names)
		if session.streak >= 2:
			var s := HuntUI.label("Chuỗi thắng %d trận: +%d%% tỷ lệ rơi" % [session.streak, roundi(minf(session.config.streak_bonus_per_win * session.streak, session.config.streak_bonus_max) * 100)], HuntUI.FONT_SMALL, HuntUI.GOLDEN_INK)
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(s)
	elif result == BattleController.Result.LOSE:
		var l := HuntUI.label("Không còn sức săn tiếp. Hãy về bếp nấu lẩu.", HuntUI.FONT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	elif result == BattleController.Result.FLED:
		box.add_child(HuntUI.label("Không có đồ rơi, mất chuỗi thắng.", HuntUI.FONT))
	var next := HuntUI.button("Về bếp nấu lẩu »" if result == BattleController.Result.TIMEOUT else "Tiếp tục »", 280)
	next.pressed.connect(func(): closed.emit(result))
	box.add_child(next)


# --- Dựng UI ----------------------------------------------------------------

func _build() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(HuntUI.background())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# Thanh trên: tên trận, đồng hồ, Tự đánh, x2.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var title := HuntUI.outlined_label(("BOSS: " if encounter.is_boss else "Gặp: ") + encounter.names(), 26, HuntUI.GOLD)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(title)
	timer_label = HuntUI.outlined_label("", 24, HuntUI.GOLD)
	top.add_child(timer_label)
	_auto_button = HuntUI.button("Tự đánh: Tắt", 190)
	_auto_button.toggle_mode = true
	_auto_button.toggled.connect(_on_auto_toggled)
	top.add_child(_auto_button)
	_fast_button = HuntUI.button("Tốc độ x1", 160)
	_fast_button.toggle_mode = true
	_fast_button.toggled.connect(_on_fast_toggled)
	top.add_child(_fast_button)

	# Đấu trường: phe ta bên trái, quái bên phải.
	_arena = Control.new()
	_arena.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(_arena)
	var arena_row := HBoxContainer.new()
	arena_row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	arena_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_arena.add_child(arena_row)
	_allies_box = HBoxContainer.new()
	_allies_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_allies_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_allies_box.add_theme_constant_override("separation", 8)
	arena_row.add_child(_allies_box)
	var vs := HuntUI.outlined_label("VS", 36, Color(1, 1, 1, 0.7))
	vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arena_row.add_child(vs)
	_enemies_box = HBoxContainer.new()
	_enemies_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemies_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_enemies_box.add_theme_constant_override("separation", 8)
	arena_row.add_child(_enemies_box)

	# Thứ tự lượt.
	var order_panel := PanelContainer.new()
	order_panel.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_panel", 8, Vector2(18, 10)))
	root.add_child(order_panel)
	HuntUI.pop_in(order_panel, 0.1)
	var order_row := HBoxContainer.new()
	order_row.add_theme_constant_override("separation", 8)
	order_panel.add_child(order_row)
	order_row.add_child(HuntUI.label("Lượt tiếp:", HuntUI.FONT_SMALL))
	_order_box = Control.new()
	_order_box.custom_minimum_size = Vector2(ORDER_BIG + ORDER_ARROW + (ORDER_PREVIEW - 1) * (ORDER_SLOT + ORDER_GAP), ORDER_BIG)
	order_row.add_child(_order_box)
	_order_arrow = HuntUI.label("»", 24)
	_order_arrow.position = Vector2(ORDER_BIG + 3, (ORDER_BIG - 34) / 2.0)
	_order_box.add_child(_order_arrow)
	_turn_label = HuntUI.label("", HuntUI.FONT_SMALL, HuntUI.RUST)
	_turn_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	order_row.add_child(_turn_label)

	# Nhật ký + hành động.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	var log_panel := PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_panel", 8, Vector2(20, 14)))
	log_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	log_panel.custom_minimum_size = Vector2(0, 150)
	bottom.add_child(log_panel)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.add_theme_color_override("default_color", HuntUI.INK)
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", HuntUI.FONT_SMALL)
	log_panel.add_child(_log)

	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	bottom.add_child(actions)
	HuntUI.pop_in(log_panel, 0.15)
	HuntUI.pop_in(actions, 0.2)
	for i in controller.skills.size():
		var b := HuntUI.button(controller.skills[i].display_name, 230)
		b.custom_minimum_size.y = 70
		b.add_theme_font_size_override("font_size", HuntUI.FONT_SMALL)
		b.pressed.connect(_on_skill_pressed.bind(i))
		actions.add_child(b)
		_skill_buttons.append(b)
	_flee_button = HuntUI.button("Bỏ chạy\n(mất đồ rơi)", 230)
	_flee_button.custom_minimum_size.y = 70
	_flee_button.add_theme_font_size_override("font_size", HuntUI.FONT_SMALL)
	_flee_button.pressed.connect(_on_flee_pressed)
	actions.add_child(_flee_button)
	_set_actions_enabled(false)

	_float_layer = Control.new()
	_float_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_float_layer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_float_layer)


func _add_view(c: Combatant) -> void:
	var view := CombatantView.new()
	view.size_flags_vertical = SIZE_SHRINK_CENTER
	if c.is_ally:
		_allies_box.add_child(view)
	else:
		_enemies_box.add_child(view)
	view.setup(c)
	view.tapped.connect(_on_view_tapped)
	views[c] = view
	HuntUI.pop_in(view, 0.05 * views.size())


func _refresh_all() -> void:
	for c in views:
		views[c].refresh()
	_refresh_selection()
	# Thanh lượt chỉ trượt khi sang lượt mới; ở đây chỉ dựng lần đầu hoặc khi có ai bị hạ.
	var someone_down := false
	for slot in _order_slots:
		if not (slot["c"] as Combatant).is_alive():
			someone_down = true
	if _order_slots.is_empty() or someone_down:
		_update_order(_order_current)


func _refresh_selection() -> void:
	if selected_target != null and not selected_target.is_alive():
		selected_target = controller.default_target()
	for c in views:
		views[c].set_selected(c == selected_target)


func _set_acting(actor: Combatant) -> void:
	for c in views:
		views[c].set_acting(c == actor)


## Thanh thứ tự lượt: người đang hành động (viền trắng) rồi các lượt dự đoán.
## Qua lượt mới thì các ô trượt sang trái từng ô, ô vừa đánh trượt ra và mờ đi, lượt mới hiện dần ở cuối.
func _update_order(current: Combatant = null) -> void:
	_order_current = current
	var order: Array[Combatant] = []
	if current != null and current.is_alive():
		order.append(current)
	order.append_array(controller.predict_order(ORDER_PREVIEW - order.size()))
	var has_current := current != null and not order.is_empty() and order[0] == current
	_order_arrow.visible = has_current
	var duration := ORDER_SLIDE / (2.0 if fast_mode else 1.0)

	# Ghép ô cũ với lượt mới theo đúng thứ tự trái -> phải (không ô nào trượt chéo qua ô khác).
	var used: Array[bool] = []
	used.resize(_order_slots.size())
	used.fill(false)
	var new_slots: Array[Dictionary] = []
	var cursor := 0
	for i in order.size():
		var c := order[i]
		var pick := -1
		for j in range(cursor, _order_slots.size()):
			if _order_slots[j]["c"] == c:
				pick = j
				break
		if pick >= 0:
			cursor = pick + 1
		var slot: Dictionary
		if pick >= 0:
			used[pick] = true
			slot = _order_slots[pick]
		else:
			slot = _make_order_slot(c)
			var node: Control = slot["node"]
			node.modulate.a = 0.0
			if cursor >= _order_slots.size() or i == order.size() - 1:
				# Lượt mới ở cuối hàng: hiện dần, trượt nhẹ từ bên phải vào.
				node.position = _order_slot_rect(i + 1, has_current).position
			else:
				# Chen vào giữa hàng (vd được đẩy lượt lên): rơi từ trên xuống đúng chỗ, các ô khác dạt ra.
				node.position = _order_slot_rect(i, has_current).position + Vector2(0, -ORDER_SLOT * 0.8)
			_order_box.add_child(node)
		new_slots.append(slot)
		var is_current := i == 0 and has_current
		_style_order_slot(slot, is_current)
		var rect := _order_slot_rect(i, has_current)
		var n: Control = slot["node"]
		var t := n.create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(n, "position", rect.position, duration)
		t.tween_property(n, "size", rect.size, duration)
		t.tween_property(n, "modulate:a", 1.0, duration)
		var icon: Control = slot["icon"]
		t.tween_property(icon, "custom_minimum_size", Vector2.ONE * (52.0 if is_current else 40.0), duration)
	# Ô không còn trong hàng. Người vừa đánh: lóe trắng rồi trượt ra trái; ô khác: mờ dần tại chỗ.
	for j in _order_slots.size():
		if used[j]:
			continue
		var gone: Control = _order_slots[j]["node"]
		var t := gone.create_tween()
		if j == 0:
			t.tween_property(gone, "modulate", Color(2.0, 2.0, 2.0, 1.0), duration * 0.3)
			t.set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.chain().tween_property(gone, "position", gone.position + Vector2(-ORDER_SLOT * 0.6, -10), duration)
			t.tween_property(gone, "modulate", Color(2.0, 2.0, 2.0, 0.0), duration)
		else:
			t.tween_property(gone, "modulate:a", 0.0, duration)
		t.chain().tween_callback(gone.queue_free)
	_order_slots = new_slots


## Vị trí + kích thước ô thứ index. Ô đầu (người đang đánh) to hơn, sau nó là dấu ».
func _order_slot_rect(index: int, has_current: bool) -> Rect2:
	var small_y := (ORDER_BIG - ORDER_SLOT) / 2.0
	if not has_current:
		return Rect2(index * (ORDER_SLOT + ORDER_GAP), small_y, ORDER_SLOT, ORDER_SLOT)
	if index == 0:
		return Rect2(0, 0, ORDER_BIG, ORDER_BIG)
	var x := ORDER_BIG + ORDER_ARROW + (index - 1) * (ORDER_SLOT + ORDER_GAP)
	return Rect2(x, small_y, ORDER_SLOT, ORDER_SLOT)


func _make_order_slot(c: Combatant) -> Dictionary:
	var holder := PanelContainer.new()
	holder.size = Vector2(ORDER_SLOT, ORDER_SLOT)
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.mouse_filter = MOUSE_FILTER_IGNORE
	var icon := HuntUI.texture_rect(HuntUI.combatant_texture(c.data), 40)
	center.add_child(icon)
	holder.add_child(center)
	return {"c": c, "node": holder, "icon": icon}


func _style_order_slot(slot: Dictionary, is_current: bool) -> void:
	var c: Combatant = slot["c"]
	var border := Color(0, 0, 0, 0)
	if is_current:
		border = Color.WHITE
	elif c == controller.player:
		border = HuntUI.GOLD
	var style := HuntUI.panel_style(Color(0.2, 0.35, 0.2, 0.9) if c.is_ally else Color(0.4, 0.15, 0.12, 0.9), border, 6, 3 if is_current else 2)
	style.set_content_margin_all(0)
	var node: PanelContainer = slot["node"]
	node.add_theme_stylebox_override("panel", style)


func _flush_log() -> void:
	var lines := controller.battle.log_lines
	for i in range(_log_index, lines.size()):
		var line: String = lines[i]
		if "CHÍ MẠNG" in line:
			line = "[color=#a3461a]%s[/color]" % line
		elif "bị hạ" in line:
			line = "[color=#c62828]%s[/color]" % line
		_log.append_text(line + "\n")
	_log_index = lines.size()
