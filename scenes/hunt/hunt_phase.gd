extends Control
## Sáng – đi săn nguyên liệu (S12–S14).
## Khu săn: chọn 1 trong các thẻ trận (thấy trước quái, đồ rơi, độ khó), boss mở sau vài trận thắng.
## Máu đầu bếp giữ nguyên giữa các trận trong buổi sáng. Hết giờ -> về bếp.

const BATTLE_SCENE := preload("res://scenes/hunt/battle_view.tscn")

var session: HuntSession
var _battle: BattleView
var _map: Control
var _cards_box: HBoxContainer
var _boss_holder: Control
var _status_box: VBoxContainer
var _timer_label: Label
var _reroll_button: Button
var _rerolling := false
var _rotate_hint: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	session = HuntSession.new(GameState.day)
	DayManager.phase_time_up.connect(_on_time_up)
	add_child(HuntUI.background())
	_build_map()
	_build_rotate_hint()
	_refresh()


func _process(_delta: float) -> void:
	var window_size := DisplayServer.window_get_size()
	_rotate_hint.visible = window_size.y > window_size.x
	_timer_label.visible = DayManager.timer_running
	_timer_label.text = "Còn lại " + DayManager.time_left_text()


# --- Luồng ------------------------------------------------------------------

func _start_fight(index: int) -> void:
	var enc := session.boss_encounter() if index < 0 else session.encounters[index]
	if enc.monsters.is_empty() or not session.can_fight():
		return
	_map.visible = false
	_battle = BATTLE_SCENE.instantiate()
	add_child(_battle)
	move_child(_rotate_hint, -1)
	_battle.closed.connect(_on_battle_closed.bind(index))
	_battle.start(session, enc)


func _on_battle_closed(result: BattleController.Result, index: int) -> void:
	_battle.queue_free()
	_battle = null
	if result == BattleController.Result.TIMEOUT:
		DayManager.next_phase()
		return
	if index >= 0:
		session.replace_encounter(index)
	_map.visible = true
	_refresh()


## Đổi bụi cỏ: miễn phí vài lần mỗi ngày, sau đó tốn tiền.
func _on_reroll() -> void:
	if _rerolling or not session.reroll_encounters():
		return
	_rerolling = true
	_reroll_button.disabled = true
	# Lật úp các thẻ cũ, đổi nội dung, rồi lật ngửa thẻ mới.
	var last: Tween
	for card in _cards_box.get_children():
		last = HuntUI.flip_out(card)
	if last != null:
		await last.finished
	_refresh_status()
	_refresh_cards(true)
	_refresh_reroll_button()
	_rerolling = false


func _refresh_reroll_button() -> void:
	var cost := session.reroll_cost()
	if cost == 0:
		_reroll_button.text = "Đổi bụi cỏ (miễn phí, còn %d lần)" % session.free_rerolls_left()
	else:
		_reroll_button.text = "Đổi bụi cỏ (%s)" % GameState.format_money(cost)
	_reroll_button.disabled = not session.can_fight() or not GameState.can_afford(cost)


func _on_time_up() -> void:
	if _battle != null:
		_battle.time_out() # Trận tự kết thúc, người chơi bấm "Về bếp".
	else:
		DayManager.next_phase()


# --- Dựng UI ----------------------------------------------------------------

func _build_map() -> void:
	_map = MarginContainer.new()
	_map.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_map.add_theme_constant_override(side, 24)
	add_child(_map)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	_map.add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	var title := HuntUI.outlined_label("Ngày %d · Sáng: Đi săn nguyên liệu" % GameState.day, 30, HuntUI.GOLD)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(title)
	_timer_label = HuntUI.outlined_label("", 28, HuntUI.GOLD)
	top.add_child(_timer_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)

	# Cột trái: đầu bếp, thú cưỡi, thu hoạch, gợi ý công thức.
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_panel", 8, Vector2(22, 18)))
	left.custom_minimum_size = Vector2(390, 0)
	body.add_child(left)
	HuntUI.pop_in(left)
	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(left_scroll)
	_status_box = VBoxContainer.new()
	_status_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_status_box.add_theme_constant_override("separation", 8)
	left_scroll.add_child(_status_box)

	# Cột phải: thẻ trận + boss + về bếp.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	right.add_child(head)
	var pick := HuntUI.outlined_label("Chọn bụi cỏ để săn:", 24)
	pick.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(pick)
	_reroll_button = HuntUI.button("", 330)
	_reroll_button.custom_minimum_size.y = 56
	_reroll_button.add_theme_font_size_override("font_size", HuntUI.FONT_SMALL)
	_reroll_button.pressed.connect(_on_reroll)
	head.add_child(_reroll_button)
	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 12)
	_cards_box.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(_cards_box)
	_boss_holder = VBoxContainer.new()
	right.add_child(_boss_holder)
	var back := HuntUI.button("Về bếp nấu lẩu »", 320)
	back.size_flags_horizontal = SIZE_SHRINK_END
	back.pressed.connect(DayManager.next_phase)
	right.add_child(back)


func _refresh() -> void:
	_refresh_status()
	_refresh_cards()
	_refresh_reroll_button()


func _refresh_status() -> void:
	for child in _status_box.get_children():
		child.queue_free()
	var p := session.player
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_status_box.add_child(head)
	head.add_child(HuntUI.texture_rect(HuntUI.combatant_texture(p.data), 80))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(info)
	info.add_child(HuntUI.label(p.display_name, 22, HuntUI.RUST))
	var bar := HuntUI.hp_bar(true)
	bar.max_value = p.max_hp
	bar.value = p.hp
	info.add_child(bar)
	info.add_child(HuntUI.label("Máu %d/%d" % [p.hp, p.max_hp], HuntUI.FONT_SMALL))
	_status_box.add_child(HuntUI.label("Dame %d · Tốc %d · Chí mạng %d%% (x%.2f)" % [
		p.damage, p.speed, roundi(p.crit_chance * 100), p.crit_multiplier], HuntUI.FONT_SMALL))
	if session.mount != null:
		var m := session.mount
		_status_box.add_child(HuntUI.label("Thú cưỡi: %s %d/%d máu" % [m.display_name, m.hp, m.max_hp], HuntUI.FONT_SMALL, HuntUI.TEAL))
	_status_box.add_child(HuntUI.label("Thắng %d trận · Chuỗi thắng %d" % [session.wins, session.streak], HuntUI.FONT_SMALL))
	_status_box.add_child(HuntUI.label("Tỷ lệ rơi đồ: %d%%" % roundi(session.current_drop_chance() * 100), HuntUI.FONT_SMALL))
	_status_box.add_child(HuntUI.label("Tiền: %s" % GameState.format_money(GameState.money), HuntUI.FONT_SMALL, HuntUI.RUST))
	_status_box.add_child(HSeparator.new())
	_status_box.add_child(HuntUI.label("Thu hoạch sáng nay:", HuntUI.FONT_SMALL, HuntUI.RUST))
	_status_box.add_child(_wrap_items(session.harvest))
	_status_box.add_child(HuntUI.label("Công thức hôm nay cần:", HuntUI.FONT_SMALL, HuntUI.RUST))
	for hint in session.recipe_hints():
		var l := HuntUI.label(hint, HuntUI.FONT_SMALL)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(340, 0)
		_status_box.add_child(l)
	if not session.can_fight():
		var l := HuntUI.label("Đầu bếp đã kiệt sức, hãy về bếp.", HuntUI.FONT, HuntUI.BAD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_status_box.add_child(l)


func _wrap_items(items: Dictionary) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	if items.is_empty():
		flow.add_child(HuntUI.label("(chưa có)", HuntUI.FONT_SMALL, HuntUI.INK_SOFT))
	for id in items:
		flow.add_child(HuntUI.items_row({id: items[id]}, 32))
	return flow


## flip = true: thẻ mới lật ngửa (sau khi đổi bụi cỏ); mặc định thẻ bật lên lần lượt.
func _refresh_cards(flip := false) -> void:
	for child in _cards_box.get_children():
		_cards_box.remove_child(child)
		child.queue_free()
	for child in _boss_holder.get_children():
		_boss_holder.remove_child(child)
		child.queue_free()
	for i in session.encounters.size():
		var card := _make_card(session.encounters[i], i)
		_cards_box.add_child(card)
		if flip:
			HuntUI.flip_in(card, 0.07 * i)
		else:
			HuntUI.pop_in(card, 0.08 * i)
	var boss := _make_boss_card()
	_boss_holder.add_child(boss)
	if not flip:
		HuntUI.pop_in(boss, 0.28)


func _make_card(enc: Encounter, index: int) -> Button:
	var card := HuntUI.card_button()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.size_flags_vertical = SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 260)
	card.disabled = not session.can_fight() or enc.monsters.is_empty()
	card.pressed.connect(_start_fight.bind(index))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT, PRESET_MODE_MINSIZE, 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	var sprites := HBoxContainer.new()
	sprites.alignment = BoxContainer.ALIGNMENT_CENTER
	sprites.add_theme_constant_override("separation", -10)
	box.add_child(sprites)
	var size := 128.0 if enc.monsters.size() == 1 else (96.0 if enc.monsters.size() == 2 else 72.0)
	for m in enc.monsters:
		sprites.add_child(HuntUI.texture_rect(HuntUI.combatant_texture(m), size))
	var names := HuntUI.label(enc.names(), HuntUI.FONT_SMALL)
	names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.custom_minimum_size = Vector2(180, 0)
	box.add_child(names)
	var diff := enc.difficulty(session.player)
	var diff_color: Color = [HuntUI.GOOD, HuntUI.WARN, HuntUI.BAD][diff]
	var d := HuntUI.label("Độ khó: " + Encounter.difficulty_name(diff), HuntUI.FONT_SMALL, diff_color)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(d)
	var drops := HuntUI.items_row(enc.expected_drops(session.drop_amount_multiplier()), 30)
	drops.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(drops)
	HuntUI.ignore_mouse_recursive(card)
	return card


func _make_boss_card() -> Button:
	var card := HuntUI.card_button()
	card.custom_minimum_size = Vector2(0, 92)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT, PRESET_MODE_MINSIZE, 8)
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var boss_data: CombatantData = session.boss_pool[0] if not session.boss_pool.is_empty() else null
	row.add_child(HuntUI.texture_rect(HuntUI.combatant_texture(boss_data), 76))
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(text)
	var state := ""
	if session.boss_pool.is_empty():
		state = "Chưa có boss"
	elif session.boss_defeated:
		state = "Đã hạ boss hôm nay"
	elif session.boss_unlocked():
		state = "Sẵn sàng! Boss luôn rơi nguyên liệu hoàng kim (giá x3)"
	else:
		state = "Thắng thêm %d trận để mở" % (session.config.boss_unlock_wins - session.wins)
	text.add_child(HuntUI.label("BOSS", 24, HuntUI.BAD))
	var s := HuntUI.label(state, HuntUI.FONT_SMALL)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(s)
	card.disabled = not session.boss_unlocked() or not session.can_fight()
	card.pressed.connect(_start_fight.bind(-1))
	HuntUI.ignore_mouse_recursive(card)
	return card


## Lớp phủ nhắc xoay ngang khi cầm điện thoại dọc.
func _build_rotate_hint() -> void:
	_rotate_hint = ColorRect.new()
	(_rotate_hint as ColorRect).color = Color("1a0f0b")
	_rotate_hint.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_rotate_hint.mouse_filter = MOUSE_FILTER_STOP
	_rotate_hint.visible = false
	add_child(_rotate_hint)
	var label := HuntUI.outlined_label("Xoay ngang điện thoại\nđể chơi nhé!", 56, HuntUI.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_rotate_hint.add_child(label)
