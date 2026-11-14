extends Control
## Trưa – sơ chế nguyên liệu và nấu nước cốt lẩu (khu bếp pixel, cùng phong cách màn săn).
## - Sơ chế: bấm "Sơ chế nguyên liệu" (hoặc chạm bàn sơ chế) -> bảng PrepPanel (quy trình từng nguyên liệu, data/prep/).
## - Nấu ưu tiên đồ đã sơ chế (chất lượng càng cao nấu càng nhanh); thiếu thì dùng đồ thô:
##   nấu chậm hơn và có nguy cơ khách chê, mất sao (data/prep/prep_config.tres).
## - Lúc đầu chỉ có đầu bếp và 1 bếp. Mỗi cấp "Bếp xịn" mở thêm 1 bếp; "Nhân viên bếp" thêm phụ bếp
##   tự sơ chế (cấp 1–2) và bếp phó tự nấu khi có bếp trống (cấp 3).
## - Mỗi lần nấu ra nhiều phần lẩu (giá trị nâng cấp "Nồi"), thời gian = cook_time × hệ số "Bếp xịn".
## - Chạm tủ kho lạnh để xem kho (hạn sử dụng). Ánh sáng đổi theo giờ trong game (DayLight).
## Số liệu cân bằng: data/broths/kitchen_config.tres, data/broths/*.tres, data/upgrades/*.tres.

const CONFIG := preload("res://data/broths/kitchen_config.tres")
const KIT := "res://assets/sprites/kitchen/"
const CHAR_DIR := "res://assets/sprites/characters/"
const STAGE := Vector2(1280, 720)
const PX := 4.0 ## 1 điểm ảnh nền = 4 px màn hình.
const SIDE_WALL_PX := 160.0 ## Bề rộng ảnh tường nối (điểm ảnh nền), đủ lấp màn rất rộng.
const FEET_Y := 452.0
const STOVE_X0 := 388.0
const STOVE_SCALE := 0.8 ## Thu nhỏ hàng bếp cho gọn, dồn vào giữa.
const STOVE_W := StoveSlot.WIDTH * STOVE_SCALE
const STOVE_STEP := STOVE_W + 10.0
const STOVE_AREA := 870.0 ## Bề rộng khu bếp nấu (từ STOVE_X0 tới mép kệ phải).
const STOVE_FLOOR := 374.0 ## Đáy bếp chạm sàn.
const STOVE_TOP := STOVE_FLOOR - StoveSlot.HEIGHT * STOVE_SCALE
const CHEF_HOME := 232.0
const MENU_Y := 362.0 ## Bảng chọn món (chỉ hiện khi chạm vào bếp).
const STRIP_Y := 604.0 ## Dải thông tin luôn hiện phía trên nút mở quán.
const STAFF := [
	{"tex": "staff_lan", "name": "Lan", "x": 336.0, "right": false},
	{"tex": "staff_tung", "name": "Tùng", "x": 92.0, "right": true},
	{"tex": "staff_minh", "name": "Minh", "x": 676.0, "right": true},
]

var cfg: KitchenConfig = CONFIG
var _stage: Control
var _stoves: Array[StoveSlot] = []
var _chef: KitchenActor
var _prep_staff: Array[KitchenActor] = []
var _staff_timers: Array[float] = []
var _sous: KitchenActor = null
var _sous_wait := 0.0
var _fridge: TextureRect
var _cards: Dictionary = {} ## broth id -> {button: Button, chips: Dictionary(id -> Label), sub: Label}
var _info: Label
var _menu: PanelContainer
var _leave_layer: Control ## Hộp hỏi "Còn nồi chưa chín" đang mở (ESC đóng được).
var _menu_title: Label
var _menu_slot: StoveSlot = null
var _timer_label: Label
var _prep_panel: PrepPanel = null
var _storage_open := false
var _leaving := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	set_meta("reserves_hud", true) # Đã chừa sẵn chỗ cho thanh HUD phía trên.
	DayManager.phase_time_up.connect(_on_time_up)
	_build_stage()
	_build_ui()
	GameState.inventory_changed.connect(_refresh_cards)
	resized.connect(_center_stage)
	_center_stage()
	_refresh_cards()


func _process(delta: float) -> void:
	for slot in _stoves:
		if slot.tick(delta):
			_finish_stove(slot)
	_staff_tick(delta)
	_sous_tick(delta)
	_update_info()


# --- Số liệu từ nâng cấp ---------------------------------------------------

func stove_count() -> int:
	return clampi(1 + GameState.get_upgrade_level("stove"), 1, cfg.max_stoves)


func servings() -> int:
	var v := int(Database.upgrade_value("pot"))
	return v if v > 0 else 4


func staff_level() -> int:
	return int(Database.upgrade_value("staff"))


## Nguyên liệu cần cho 1 mẻ của các món hôm nay (mỗi loại lấy món cần nhiều nhất).
func needs() -> Dictionary:
	var result := {}
	for broth in Database.broths_for_day(GameState.day):
		for id in broth.ingredients:
			result[id] = maxi(int(result.get(id, 0)), int(broth.ingredients[id]))
	return result


# --- Dựng khu bếp ------------------------------------------------------------

func _build_stage() -> void:
	var back := ColorRect.new()
	back.color = Color("2b1a14")
	back.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	back.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(back)
	_stage = Control.new()
	_stage.size = STAGE
	_stage.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_stage)
	_kit_sprite("kitchen_bg", Vector2(320, 180), Vector2.ZERO)
	_build_side_walls()

	_fridge = _kit_sprite("fridge_closed", Vector2(36, 56), Vector2(16, 148))
	_fridge.mouse_filter = MOUSE_FILTER_STOP
	_fridge.gui_input.connect(_on_fridge_input)
	var counter := _kit_sprite("prep_counter", Vector2(54, 32), Vector2(172, 248))
	counter.mouse_filter = MOUSE_FILTER_STOP
	counter.gui_input.connect(_on_counter_input)

	for i in stove_count():
		var slot := StoveSlot.new()
		_stage.add_child(slot)
		slot.setup(i, i >= cfg.gas_stove_from)
		slot.scale = Vector2(STOVE_SCALE, STOVE_SCALE)
		slot.position = Vector2(_stove_x(i), STOVE_TOP)
		slot.tapped.connect(_on_stove_tapped)
		_stoves.append(slot)
	if stove_count() < cfg.max_stoves:
		_build_locked_slot(stove_count())

	_chef = _add_actor("player", CHEF_HOME, "Đầu bếp", true)
	var level := staff_level()
	for i in mini(level, cfg.prep_staff_max):
		var info: Dictionary = STAFF[i]
		var a := _add_actor(str(info["tex"]), float(info["x"]), str(info["name"]), bool(info["right"]))
		a.appear(0.15 * i)
		_prep_staff.append(a)
		_staff_timers.append(cfg.staff_prep_interval * (0.35 + 0.3 * i))
	if level >= cfg.sous_chef_level:
		var info: Dictionary = STAFF[2]
		_sous = _add_actor(str(info["tex"]), float(info["x"]), str(info["name"]), true)
		_sous.appear(0.3)

	var light := DayLight.new()
	_stage.add_child(light)
	light.add_lamp(Vector2(534, 100), 230.0, 1.0, 1.25)
	light.add_lamp(Vector2(894, 100), 230.0, 1.0, 1.25)
	var windows := WindowSky.new()
	_stage.add_child(windows)
	windows.setup(light)
	# Thẻ trạng thái bếp nằm trên nhân vật để không bị che.
	var chips := Control.new()
	chips.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.add_child(chips)
	for slot in _stoves:
		slot.detach_chip(chips)


## Nối tường và sàn sang hai bên nền bếp để màn rộng hơn 16:9 không bị dải trống.
func _build_side_walls() -> void:
	var side_size := Vector2(SIDE_WALL_PX, 180)
	_kit_sprite("kitchen_bg_side", side_size, Vector2(-SIDE_WALL_PX * PX, 0))
	_kit_sprite("kitchen_bg_side", side_size, Vector2(STAGE.x, 0))


## Dàn các bếp (kể cả ô "nâng cấp") ra giữa khu bếp nấu cho cân đối.
func _stove_x(i: int) -> float:
	var slots := stove_count() + (1 if stove_count() < cfg.max_stoves else 0)
	var used := STOVE_W + (slots - 1) * STOVE_STEP
	return STOVE_X0 + floorf((STOVE_AREA - used) / 2.0) + i * STOVE_STEP


func _build_locked_slot(i: int) -> void:
	var box := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.06, 0.04, 0.25)
	st.border_color = Color(1, 1, 1, 0.45)
	st.set_border_width_all(3)
	st.set_corner_radius_all(8)
	box.add_theme_stylebox_override("panel", st)
	box.position = Vector2(_stove_x(i) + 3, STOVE_TOP + StoveSlot.STOVE_Y * STOVE_SCALE + 6)
	box.size = Vector2(STOVE_W - 6, 140 * STOVE_SCALE)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	var l := HuntUI.outlined_label("Bếp %d\nNâng cấp\nBếp xịn" % (i + 1), 18, Color(1, 1, 1, 0.85))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(l)
	_stage.add_child(box)


func _add_actor(tex_name: String, x: float, display: String, right: bool) -> KitchenActor:
	var a := KitchenActor.new()
	_stage.add_child(a)
	a.setup(load(CHAR_DIR + tex_name + ".png"), x, FEET_Y, display, right)
	return a


func _kit_sprite(name: String, px_size: Vector2, pos: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(KIT + name + ".png")
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = px_size * PX
	r.position = pos
	r.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.add_child(r)
	return r


func _center_stage() -> void:
	_stage.position = ((size - STAGE) / 2.0).floor()


# --- Giao diện ---------------------------------------------------------------

func _build_ui() -> void:
	_timer_label = HuntUI.outlined_label("", 24, HuntUI.GOLD)
	_timer_label.position = Vector2(1120, 96)
	_stage.add_child(_timer_label)

	var prep := Button.new()
	prep.text = "Sơ chế nguyên liệu"
	prep.focus_mode = Control.FOCUS_NONE
	prep.add_theme_font_size_override("font_size", 18)
	_style_button(prep, Color("b8432a"), Color("5a1f12"), Color("fbe9d0"), 14)
	prep.custom_minimum_size = Vector2(0, 56)
	prep.pressed.connect(_open_prep.bind(""))
	_stage.add_child(prep)
	# Nút vừa khít chữ, đặt giữa bàn sơ chế.
	prep.size = prep.get_combined_minimum_size()
	prep.position = Vector2(280.0 - prep.size.x / 2.0, 180)

	# Dải thông tin: gợi ý + số bếp/nhân viên.
	var strip := PanelContainer.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.17, 0.1, 0.07, 0.82)
	ss.border_color = Color("8a5a3c")
	ss.set_border_width_all(3)
	ss.set_corner_radius_all(6)
	ss.content_margin_left = 16
	ss.content_margin_right = 16
	ss.content_margin_top = 6
	ss.content_margin_bottom = 6
	strip.add_theme_stylebox_override("panel", ss)
	strip.position = Vector2(16, STRIP_Y)
	strip.size = Vector2(1248, 50)
	strip.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.add_child(strip)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 16)
	strip.add_child(srow)
	srow.add_child(HuntUI.outlined_label("Chạm vào bếp để chọn món nấu", 18, HuntUI.GOLD))
	_info = HuntUI.outlined_label("", 18, Color("f3e2c0"))
	_info.size_flags_horizontal = SIZE_EXPAND_FILL
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.clip_text = true
	srow.add_child(_info)

	# Bảng chọn món: ẩn, chạm bếp mới hiện.
	_menu = PanelContainer.new()
	_menu.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_panel", 8, Vector2(18, 10)))
	_menu.position = Vector2(16, MENU_Y)
	_menu.size = Vector2(1248, 236)
	_menu.visible = false
	_stage.add_child(_menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_menu.add_child(box)
	_menu_title = HuntUI.label("Chọn món nấu", 20, HuntUI.RUST)
	box.add_child(_menu_title)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	box.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 186) # Thẻ 156 + chỗ cho thanh cuộn ngang.
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	scroll.add_child(row)
	for broth in Database.broths_for_day(GameState.day):
		row.add_child(_make_card(broth))
	var close := HuntUI.button("Đóng", 0)
	close.custom_minimum_size = Vector2(110, 158)
	close.size_flags_vertical = SIZE_SHRINK_BEGIN
	close.pressed.connect(_close_menu)
	body.add_child(close)

	var leave := Button.new()
	leave.text = "Mở quán bán hàng  »"
	leave.focus_mode = Control.FOCUS_NONE
	leave.position = Vector2(16, 662)
	leave.size = Vector2(1248, 56)
	leave.add_theme_font_size_override("font_size", 22)
	_style_button(leave, Color("f2a33a"), Color("8a5a3c"), HuntUI.INK)
	leave.pressed.connect(_on_leave_pressed)
	_stage.add_child(leave)


func _style_button(b: Button, bg: Color, border: Color, font: Color, pad := 0) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = bg.darkened(0.18) if state.ends_with("pressed") else (bg.darkened(0.4) if state == "disabled" else bg)
		s.border_color = border
		s.set_border_width_all(3)
		s.set_corner_radius_all(6)
		s.shadow_color = Color(0, 0, 0, 0.3)
		s.shadow_offset = Vector2(0, 3)
		s.shadow_size = 1
		s.content_margin_left = pad
		s.content_margin_right = pad
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, font)


func _make_card(broth: BrothData) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_card", 8, Vector2(14, 13)))
	card.custom_minimum_size = Vector2(244, 156)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)
	var pot_path := KIT + "pot_" + broth.id.trim_suffix("_broth") + ".png"
	var pot := HuntUI.texture_rect(load(pot_path) if ResourceLoader.exists(pot_path) else load(KIT + "pot_tomato.png"), 56)
	pot.size_flags_vertical = SIZE_SHRINK_BEGIN
	row.add_child(pot)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(col)
	var name_label := HuntUI.label(broth.display_name, 18, HuntUI.INK)
	name_label.clip_text = true
	col.add_child(name_label)
	var sub := HuntUI.label("", 14, HuntUI.INK_SOFT)
	col.add_child(sub)
	var chips_row := HBoxContainer.new()
	chips_row.add_theme_constant_override("separation", 2)
	col.add_child(chips_row)
	var chips := {}
	for id in broth.ingredients:
		chips_row.add_child(HuntUI.texture_rect(HuntUI.ingredient_texture(id), 26))
		var c := HuntUI.label("", 15, HuntUI.INK)
		chips_row.add_child(c)
		chips[id] = c
	var button := HuntUI.button("Nấu", 0)
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(_on_card_pressed.bind(broth))
	col.add_child(button)
	_cards[broth.id] = {"button": button, "chips": chips, "sub": sub, "card": card}
	return card


func _refresh_cards() -> void:
	var free := (_menu_slot != null and _menu_slot.is_idle()) or _free_stove() != null
	for broth in Database.broths_for_day(GameState.day):
		if not _cards.has(broth.id):
			continue
		var ui: Dictionary = _cards[broth.id]
		var chips: Dictionary = ui["chips"]
		for id in broth.ingredients:
			var need := int(broth.ingredients[id])
			var prepped := GameState.get_prepped_count(id)
			var have := prepped + GameState.get_item_count(id)
			var label: Label = chips[id]
			label.text = "%d/%d " % [mini(have, 99), need]
			# Xanh: đủ đồ đã sơ chế; cam: phải dùng đồ thô; đỏ: thiếu.
			var col := HuntUI.GOOD if prepped >= need else (Color("d9822b") if have >= need else HuntUI.BAD)
			label.add_theme_color_override("font_color", col)
		(ui["sub"] as Label).text = "%s · %d phần" % [GameState.format_money(broth.price), servings()]
		var button: Button = ui["button"]
		var can := GameState.can_cook(broth.ingredients)
		var prepped_ok := GameState.has_prepped(broth.ingredients)
		var pc := Database.prep_config
		var secs := ceili(broth.cook_time * Database.upgrade_value("stove") * (1.0 if prepped_ok else pc.raw_cook_time))
		if can and free:
			button.text = ("Nấu · %ds" if prepped_ok else "Nấu đồ thô · %ds") % secs
			button.disabled = false
		elif can:
			button.text = "Bếp đang bận"
			button.disabled = true
		else:
			button.text = "Thiếu nguyên liệu"
			button.disabled = true


func _update_info() -> void:
	var cooking := 0
	for slot in _stoves:
		if not slot.is_idle():
			cooking += 1
	var staff := _prep_staff.size() + (1 if _sous != null else 0)
	_info.text = "Bếp đang nấu: %d/%d  ·  Nhân viên: %d  ·  Mỗi mẻ ra %d phần  ·  Kho lạnh giữ %d ngày" % [
		cooking, _stoves.size(), staff, servings(), GameState.shelf_days()]
	var has_hud := get_tree().get_first_node_in_group("hud") != null
	_timer_label.visible = DayManager.timer_running and not has_hud
	_timer_label.text = "Còn lại " + DayManager.time_left_text()


# --- Nấu -----------------------------------------------------------------------

func _free_stove() -> StoveSlot:
	for slot in _stoves:
		if slot.is_idle():
			return slot
	return null


func _on_card_pressed(broth: BrothData) -> void:
	if not GameState.can_cook(broth.ingredients):
		return
	var slot := _menu_slot if _menu_slot != null and _menu_slot.is_idle() else null
	if not _cook(broth, _chef, slot):
		_chef.say("Hết bếp trống!", Color("ffccbc"))
	_close_menu()


func _cook(broth: BrothData, actor: KitchenActor, on_slot: StoveSlot = null) -> bool:
	var slot := on_slot if on_slot != null and on_slot.is_idle() else _free_stove()
	if slot == null:
		return false
	var used := GameState.consume_for_cook(broth.ingredients)
	if not bool(used["ok"]):
		return false
	# Chất lượng sơ chế đổi thời gian nấu; có đồ thô thì nấu chậm hơn (PrepConfig).
	var pc := Database.prep_config
	var raw_units := int(used["raw_units"])
	var mult := pc.raw_cook_time if raw_units > 0 else pc.cook_time_mult(roundi(float(used["quality"])))
	slot.start(broth, broth.cook_time * Database.upgrade_value("stove") * mult, servings(), bool(used["expired"]), used["taken"])
	slot.cook_actor = actor
	if bool(used["expired"]):
		actor.say("Đồ cũ, coi chừng!", Color("ffab91"))
	elif raw_units > 0:
		actor.say("Đồ chưa sơ chế...", Color("ffcc80"))
		if randf() < pc.raw_star_risk:
			GameState.lose_star(pc.raw_star_loss)
			_float_text("Nấu đồ thô, khách chê! -%s sao" % str(pc.raw_star_loss), slot.position + Vector2(STOVE_W / 2.0, 30), Color("ff8a80"))
	_send_to_stove(actor, slot)
	_sfx("splash", -10.0)
	_refresh_cards()
	return true


## Người nấu đi tới bếp, khuấy nồi rồi quay về chỗ cũ.
func _send_to_stove(actor: KitchenActor, slot: StoveSlot) -> void:
	var x := slot.position.x + STOVE_W * 0.5 - 44.0
	var t := actor.walk_to(x)
	t.tween_callback(func():
		actor.face(true)
		actor.ninja_slash(0.8, slot.global_position + Vector2(STOVE_W * 0.5, 40.0))
		_sfx("slice", -10.0))
	t.tween_interval(0.9)
	t.tween_callback(func():
		if _prep_panel != null and actor == _chef:
			actor.walk_to(CHEF_HOME)
		else:
			actor.go_home())


func _finish_stove(slot: StoveSlot) -> void:
	var b := slot.broth
	if b == null:
		return
	GameState.add_broth(b.id, slot.servings, -1, slot.expired)
	_float_text("+%d phần %s" % [slot.servings, b.display_name], slot.position + Vector2(STOVE_W / 2.0, -20), HuntUI.GOLD)
	slot.flash()
	slot.clear()
	_sfx("loot", -10.0)
	_refresh_cards()


func _on_stove_tapped(slot: StoveSlot) -> void:
	if slot.is_idle():
		if _menu_slot == slot:
			_close_menu()
		else:
			_open_menu(slot)
	else:
		_float_text("%s · còn %ds" % [slot.broth.display_name, ceili(slot.remaining)], slot.position + Vector2(STOVE_W / 2.0, 10), Color.WHITE)


func _open_menu(slot: StoveSlot) -> void:
	if _menu_slot != null:
		_menu_slot.set_selected(false)
	_menu_slot = slot
	slot.set_selected(true)
	_menu_title.text = "Chọn món nấu ở Bếp %d" % (slot.index + 1)
	_refresh_cards()
	if not _menu.visible:
		_menu.visible = true
		HuntUI.pop_in(_menu)
		var i := 0
		for id in _cards:
			HuntUI.pop_in((_cards[id] as Dictionary)["card"], 0.04 * i)
			i += 1
	_sfx("splash", -20.0)


func _close_menu() -> void:
	if _menu_slot != null:
		_menu_slot.set_selected(false)
	_menu_slot = null
	_menu.visible = false


# --- Nhân viên ----------------------------------------------------------------

## Phụ bếp: cứ mỗi staff_prep_interval giây sơ chế 1 phần nguyên liệu đang thiếu nhất.
func _staff_tick(delta: float) -> void:
	for i in _prep_staff.size():
		_staff_timers[i] += delta
		if _staff_timers[i] < cfg.staff_prep_interval:
			continue
		_staff_timers[i] = 0.0
		var id := _staff_pick()
		if id == "":
			continue
		if GameState.prep_items(id, 1, Database.prep_config.quick_quality) > 0:
			var a := _prep_staff[i]
			a.ninja_slash(0.6)
			_sfx("slice", -14.0)
			a.say("+1 " + GameState.item_display_name(id), Color("c8e6c9"))


func _staff_pick() -> String:
	var best := ""
	var best_short := 0
	var n := needs()
	for id in n:
		var short := int(n[id]) * cfg.staff_target_batches - GameState.get_prepped_count(id)
		if short > best_short and GameState.get_item_count(id) > 0:
			best = str(id)
			best_short = short
	return best


## Bếp phó: có bếp trống + đủ đồ sơ chế thì tự nấu món đắt nhất (đợi một chút để người chơi chọn trước).
func _sous_tick(delta: float) -> void:
	if _sous == null:
		return
	var best := _best_cookable()
	if _free_stove() == null or best == null:
		_sous_wait = 0.0
		return
	_sous_wait += delta
	if _sous_wait >= cfg.sous_chef_delay:
		_sous_wait = 0.0
		if _cook(best, _sous):
			_sous.say("Nấu " + best.display_name.trim_prefix("Lẩu "), Color("fff59d"))


func _best_cookable() -> BrothData:
	var best: BrothData = null
	for broth in Database.broths_for_day(GameState.day):
		if GameState.has_prepped(broth.ingredients) and (best == null or broth.price > best.price):
			best = broth
	return best


# --- Sơ chế, kho lạnh ------------------------------------------------------------

func _on_counter_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_open_prep("")


func _open_prep(focus: String) -> void:
	if _prep_panel != null or _leaving:
		return
	_close_menu()
	_chef.walk_to(CHEF_HOME)
	_prep_panel = PrepPanel.new()
	add_child(_prep_panel)
	_prep_panel.open(needs())
	if focus != "":
		_prep_panel.select(focus)
	_prep_panel.prepped.connect(func(_id: String): _chef.work(0.4, "chop"))
	_prep_panel.step_done.connect(func(): _chef.work(0.3, "chop"))
	_prep_panel.closed.connect(func():
		_prep_panel = null
		_refresh_cards())


func _on_fridge_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	if _storage_open:
		return
	_storage_open = true
	_fridge.texture = load(KIT + "fridge_open.png")
	_sfx("splash", -18.0)
	var popup := StoragePopup.new()
	add_child(popup)
	popup.tree_exited.connect(func():
		_storage_open = false
		if is_instance_valid(_fridge):
			_fridge.texture = load(KIT + "fridge_closed.png"))


# --- Kết thúc buổi nấu -----------------------------------------------------------

func _on_leave_pressed() -> void:
	var unfinished := 0
	for slot in _stoves:
		if not slot.is_idle() and slot.progress() < cfg.keep_ratio_on_leave:
			unfinished += 1
	if unfinished > 0:
		_confirm_leave(unfinished)
	else:
		_go_sell()


func _on_time_up() -> void:
	_go_sell()


func _go_sell() -> void:
	if _leaving:
		return
	_leaving = true
	if _prep_panel != null:
		_prep_panel.close_panel()
	_wrap_up()
	DayManager.next_phase()


## Nồi đã nấu >= keep_ratio_on_leave coi như chín; nồi còn non thì nhấc ra, trả đồ sơ chế về kho.
func _wrap_up() -> void:
	for slot in _stoves:
		if slot.is_idle():
			continue
		if slot.progress() >= cfg.keep_ratio_on_leave:
			_finish_stove(slot)
		else:
			GameState.refund_cook(slot.taken)
			slot.clear()


## ESC / nút Back (menu tạm dừng gọi): đóng bảng đang mở trên cùng, quay về bếp.
## Thứ tự: hộp hỏi "Còn nồi chưa chín" > bảng Kho > bảng sơ chế > bảng chọn món. Không có gì mở thì trả về false.
func handle_back() -> bool:
	if is_instance_valid(_leave_layer) and not _leave_layer.is_queued_for_deletion():
		_leave_layer.queue_free()
		return true
	for child in get_children():
		if child is StoragePopup and not child.is_queued_for_deletion():
			child.queue_free()
			return true
	if _prep_panel != null:
		_prep_panel.close_panel()
		return true
	if _menu.visible:
		_close_menu()
		return true
	return false


## Bấm ra khoảng trống thì đóng bảng chọn món. Màn bếp là lớp nhận chạm dưới cùng: chạm nào rơi xuống tới đây
## là chạm vào chỗ không có nút / bếp / tủ lạnh nào.
func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _menu.visible:
		_close_menu()


func _confirm_leave(count: int) -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	layer.mouse_filter = MOUSE_FILTER_STOP
	add_child(layer)
	_leave_layer = layer
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_panel", 8, Vector2(26, 20)))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(HuntUI.label("Còn %d nồi chưa chín!" % count, 24, HuntUI.RUST))
	var msg := HuntUI.label("Nồi nấu chưa được một nửa sẽ bị nhấc ra, nguyên liệu đã sơ chế được trả về kho.", 18, HuntUI.INK)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(460, 0)
	box.add_child(msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var stay := HuntUI.button("Ở lại nấu", 200)
	stay.pressed.connect(layer.queue_free)
	row.add_child(stay)
	var go := HuntUI.button("Mở quán »", 200)
	go.pressed.connect(func():
		layer.queue_free()
		_go_sell())
	row.add_child(go)
	HuntUI.pop_in(panel)


# --- Tiện ích --------------------------------------------------------------------

func _float_text(text: String, at: Vector2, color: Color) -> void:
	var l := HuntUI.outlined_label(text, 20, color)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.custom_minimum_size = Vector2(240, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = at - Vector2(120, 0)
	_stage.add_child(l)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", at.y - 50, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.8)
	t.chain().tween_callback(l.queue_free)


func _sfx(name: String, db: float) -> void:
	var path := "res://assets/audio/sfx/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
