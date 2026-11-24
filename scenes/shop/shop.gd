extends Control
## Cửa hàng nâng cấp: mở trước ngày 1 (Chơi mới), sau mỗi ngày đạt KPI (game vừa được lưu) và khi Tiếp tục.
## Nền dùng lại phong cảnh của menu chính (phủ tối), bảng giữa có 3 tab Bếp / Chiến đấu / Quán theo
## UpgradeData.category, cùng tab Vũ khí (data/weapons/, mua một lần, chọn 1 cái để cầm). Mỗi nâng cấp là một thẻ: tên, cấp, mô tả luôn hiện (điện thoại không có hover), nút mua đỏ.
## Giá và hiệu ứng nằm trong data/upgrades/*.tres. TODO(Hạo): tiến hóa khi max cấp, Lầu 2, phòng riêng, nhân viên.
##
## Số bàn tầng 1 là nâng cấp "Thêm bàn" (data/upgrades/tables.tres, tối đa 10 bàn); đủ 10 bàn thì
## mở "Phí phục vụ" (service.tres) qua trường evolves_into. TODO(nhóm): cân bằng giá.

const SKY := preload("res://assets/sprites/scenery/sky.png")
const LANDSCAPE := preload("res://assets/sprites/scenery/landscape.png")
const BOLD_FONT := preload("res://assets/fonts/BeVietnamPro-Bold.ttf")
const TAB_WEAPONS := 3 ## Không phải UpgradeData.Category: vũ khí mua một lần, chọn 1 cái để cầm.
const TAB_MOUNT := 4 ## Không phải UpgradeData.Category: nâng cấp thú cưỡi tách khỏi tab Chiến đấu cho dễ thấy.
const TAB_DECOR := 5 ## Không phải UpgradeData.Category: đồ trang trí mua lẻ, mỗi chỗ trong quán đặt 1 món.
const MOUNT_UPGRADES := ["mount"] ## Nâng cấp hiện ở tab Thú cưỡi thay vì tab theo category của nó.
const ART := "res://assets/sprites/"
const SHOP_ICONS := "res://assets/sprites/ui/shop/" ## Icon vẽ bằng tools/make_shop_icons.py.
## Tab con: [khoá tab, chữ, icon].
const TABS := [
	[UpgradeData.Category.KITCHEN, "BẾP", ART + "ui/broth_pot.png"],
	[UpgradeData.Category.COMBAT, "CHIẾN ĐẤU", SHOP_ICONS + "swords.png"],
	[TAB_WEAPONS, "VŨ KHÍ", SHOP_ICONS + "cleaver.png"],
	[TAB_MOUNT, "THÚ CƯỠI", ART + "characters/mount_buffalo.png"],
	[UpgradeData.Category.RESTAURANT, "QUÁN", SHOP_ICONS + "table.png"],
	[TAB_DECOR, "TRANG TRÍ", SHOP_ICONS + "lantern.png"],
]
## Tab 2 tầng: tầng trên chọn nhóm, tầng dưới là các tab con của nhóm đó. [chữ, icon, các khoá tab con theo thứ tự].
const GROUPS := [
	["QUÁN LẨU", ART + "ui/broth_pot.png", [UpgradeData.Category.KITCHEN, UpgradeData.Category.RESTAURANT, TAB_DECOR]],
	["ĐI SĂN", SHOP_ICONS + "swords.png", [UpgradeData.Category.COMBAT, TAB_WEAPONS, TAB_MOUNT]],
]
## Hình đầu thẻ của từng nâng cấp: đường dẫn ảnh, hoặc [ảnh dải nhiều khung, cỡ 1 khung] thì lấy khung đầu.
const UPGRADE_ICONS := {
	"pot": ART + "kitchen/pot_empty.png",
	"stove": ART + "kitchen/stove_gas.png",
	"staff": ART + "characters/staff_lan.png",
	"cold_storage": ART + "kitchen/fridge_closed.png",
	"knife": ART + "kitchen/knife_big.png",
	"armor": SHOP_ICONS + "armor.png",
	"sharp_mind": SHOP_ICONS + "sharp_mind.png",
	"hawk_eye": SHOP_ICONS + "hawk.png",
	"dragon_blade": SHOP_ICONS + "dragon_blade.png",
	"battle_robe": SHOP_ICONS + "battle_robe.png",
	"mount": ART + "characters/mount_buffalo.png",
	"tables": SHOP_ICONS + "table.png",
	"furniture": SHOP_ICONS + "lantern.png",
	"service": [ART + "ui/hud/hud_coin.png", 32],
}
const CARD_ICON_SIZE := 44.0
## Tab con kiểu "mép sổ" (khác hẳn nút pixel đỏ của tầng nhóm): nằm trong khay nâu tối.
const SUB_TRAY_COLOR := Color("1e120d") ## Khay chứa hàng tab con.
const SUB_TAB_IDLE := Color("6b4a33") ## Tab con chưa chọn: nâu, chữ kem.
const SUB_TAB_IDLE_HOVER := Color("7d5a40")
const SUB_TAB_ACTIVE_LINE := Color("f2a33a") ## Gạch chân cam dưới tab con đang chọn.
const TAB_ICON_SIZE := 30
const BOARD_COLOR := Color("2b1a14", 0.94)
const BOARD_BORDER := Color("6b2a22")
const CARD_COLOR := Color("f1e3c4")
const CARD_BORDER := Color("461619")
const INK := Color("3a2418") ## Chữ tối trên thẻ màu kem.
const TEXT_LIGHT := Color("fbecd2")
const ACCENT := Color("f2a33a")
const TAB_DIM := Color(0.55, 0.55, 0.55) ## Tab chưa chọn tối đi.
const INK_SOFT := Color("7a5a44") ## Chữ phụ ("Hiện tại", "Cấp sau") nhạt hơn chữ chính.
const GAIN_COLOR := Color("2e7d32") ## Phần cộng thêm khi lên cấp: xanh lá, nổi trên nền kem.
const MAXED_COLOR := Color("c77a12") ## Cấp tối đa: cam vàng.
const NONE_COLOR := Color("9a8a7a") ## Chưa có hiệu ứng (cấp 0).
const POOR_COLOR := Color("c62828") ## Thiếu tiền.
const EFFECT_BG := Color("e6d3a8") ## Ô hiệu ứng trong thẻ, đậm hơn nền thẻ một chút.
const HUNT_CONFIG: HuntConfig = preload("res://data/combatants/hunt_config.tres") ## Chí mạng gốc, trâu +%/cấp.
const FADE_IN_SECONDS := 0.5
const FLASH_COLOR := Color("fff4d6") ## Màu ánh sáng khi rời menu (khớp FLASH_COLOR trong main_menu.gd): màn tan dần từ màu này.
const BOARD_DROP_SECONDS := 0.7 ## Bảng rơi từ trên xuống, trượt quá một chút rồi êm về chỗ.
const CARD_POP_SECONDS := 0.45
const CARD_POP_STAGGER := 0.07 ## Thẻ sau nảy ra trễ hơn thẻ trước chừng này giây.
const PURCHASE_FLASH := Color(1.35, 1.25, 0.9) ## Thẻ vừa mua loé sáng màu vàng ấm rồi về màu thường.

var _tab: int = UpgradeData.Category.KITCHEN ## UpgradeData.Category, TAB_WEAPONS, TAB_MOUNT hoặc TAB_DECOR
var _tab_buttons := {} ## khoá tab con -> Button (chỉ các tab con của nhóm đang chọn)
var _group := -1 ## Nhóm đang chọn (chỉ số trong GROUPS)
var _group_buttons: Array[PixelButton] = []
var _sub_tabs: HBoxContainer ## Hàng tab con, dựng lại mỗi lần đổi nhóm
var _cards: GridContainer
var _scroll: ScrollContainer
var _scroll_at_press := 0 ## Vị trí cuộn lúc ngón tay chạm nút mua: đã cuộn thì thả tay không tính là mua.
var _money_label: Label
var _message: Label


## Dựng nền, bảng, lớp nhắc xoay ngang rồi đổ thẻ của tab đầu tiên.
func _ready() -> void:
	_add_cover_layer(SKY)
	_add_cover_layer(LANDSCAPE)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(shade)
	_build_board()
	_fade_in()
	add_child(RotateHint.new())
	GameState.money_changed.connect(_on_money_changed)
	_on_money_changed(GameState.money)
	if GameState.is_milestone_day():
		_message.text = "Mốc ngày %d: quái mạnh hơn, có thể mở khóa nội dung mới." % GameState.day
	else:
		_message.text = "Lượng khách hiện tại: %d%%" % roundi(GameState.customer_multiplier * 100)
	_select_tab(_tab)


## Màn sáng phủ lên rồi tan dần: nối tiếp ánh sáng tràn màn khi rời menu chính.
func _fade_in() -> void:
	var fade := ColorRect.new()
	fade.color = FLASH_COLOR
	fade.mouse_filter = MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(fade)
	var tween := fade.create_tween()
	tween.tween_property(fade, "color:a", 0.0, FADE_IN_SECONDS)
	tween.tween_callback(fade.queue_free)


## Một lớp phong cảnh phủ kín màn, giữ tỉ lệ (giống menu chính).
func _add_cover_layer(texture: Texture2D) -> void:
	var layer := TextureRect.new()
	layer.texture = texture
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	layer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(layer)


## Bảng giữa: tiêu đề + tiền, hàng tab, lưới thẻ cuộn được, dòng thông báo + nút bắt đầu ngày.
func _build_board() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 64)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	add_child(margin)
	margin.position.y = -get_viewport_rect().size.y # bắt đầu trên mép màn, rơi xuống chỗ cũ (y = 0)
	margin.create_tween().tween_property(margin, "position:y", 0.0, BOARD_DROP_SECONDS) \
			.set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) # 1 nhịp nảy mềm thay vì đập nhiều lần

	var board := PanelContainer.new()
	board.add_theme_stylebox_override("panel", _box_style(BOARD_COLOR, BOARD_BORDER, 6, 24))
	margin.add_child(board)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	board.add_child(column)

	# Tầng trên: 2 nhóm (thay chỗ dòng tiêu đề để danh sách thẻ không bị hẹp lại), tiền ở góc phải.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	for i in GROUPS.size():
		var group_button := _make_tab_button(GROUPS[i][0], GROUPS[i][1], 24)
		group_button.custom_minimum_size = Vector2(300, 60)
		group_button.pressed.connect(_select_group.bind(i))
		header.add_child(group_button)
		_group_buttons.append(group_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(spacer)
	_money_label = _make_label("", 24, TEXT_LIGHT, true)
	header.add_child(_money_label)

	# Tầng dưới: tab con của nhóm đang chọn (dựng trong _select_group).
	var tray := PanelContainer.new()
	var tray_style := _box_style(SUB_TRAY_COLOR, Color(BOARD_BORDER, 0.8), 2, 6)
	tray_style.set_corner_radius_all(6)
	tray.add_theme_stylebox_override("panel", tray_style)
	column.add_child(tray)
	_sub_tabs = HBoxContainer.new()
	_sub_tabs.add_theme_constant_override("separation", 6)
	tray.add_child(_sub_tabs)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12 # chạm hơi rung tay vẫn là bấm, không bị tính là vuốt
	column.add_child(scroll)
	_scroll = scroll
	_cards = GridContainer.new()
	_cards.columns = 2
	_cards.size_flags_horizontal = SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("h_separation", 16)
	_cards.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_cards)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)
	_message = _make_label("", 20, TEXT_LIGHT)
	_message.size_flags_horizontal = SIZE_EXPAND_FILL
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_message)
	var start := PixelButton.new("BẮT ĐẦU NGÀY %d »" % GameState.day, 26)
	start.pressed.connect(DayManager.next_phase)
	footer.add_child(start)


## Nút tab pixel có icon bên trái chữ (icon pixel phóng tới TAB_ICON_SIZE).
func _make_tab_button(text: String, icon_path: String, font_size: int) -> PixelButton:
	var button := PixelButton.new(text, font_size)
	button.custom_minimum_size = Vector2(0, 56)
	button.icon = load(icon_path)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", TAB_ICON_SIZE)
	button.add_theme_constant_override("h_separation", 8)
	# Godot căn chữ giữa phần còn lại sau icon nên chữ lệch phải: chừa bên phải đúng bằng icon + khoảng cách
	# để chữ nằm giữa CẢ nút.
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBox
		style.content_margin_right = style.get_margin(SIDE_RIGHT) + TAB_ICON_SIZE + 8
		button.add_theme_stylebox_override(state, style)
	return button


## Tab con kiểu mép sổ: chữ đậm + icon, chia đều bề ngang khay, cao 56px cho ngón tay.
func _make_sub_tab(text: String, icon_path: String) -> Button:
	var tab := Button.new()
	tab.text = text
	tab.icon = load(icon_path)
	tab.expand_icon = true
	tab.focus_mode = Control.FOCUS_NONE
	tab.custom_minimum_size = Vector2(0, 56)
	tab.size_flags_horizontal = SIZE_EXPAND_FILL
	tab.add_theme_constant_override("icon_max_width", TAB_ICON_SIZE)
	tab.add_theme_constant_override("h_separation", 10)
	tab.add_theme_font_override("font", BOLD_FONT)
	tab.add_theme_font_size_override("font_size", 20)
	PixelTitle.style_if_supported(tab, text, 20) # CHIẾN ĐẤU / VŨ KHÍ...: font pixel chung, màu vẫn do _style_sub_tab
	return tab


## Tô tab con: đang chọn = nền kem như thẻ, chữ nâu đậm, gạch chân cam; chưa chọn = nền nâu, chữ kem.
func _style_sub_tab(tab: Button, active: bool) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = CARD_COLOR if active else (SUB_TAB_IDLE_HOVER if state.begins_with("hover") else SUB_TAB_IDLE)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.border_color = SUB_TAB_ACTIVE_LINE if active else Color(SUB_TAB_IDLE.darkened(0.3))
		style.border_width_bottom = 5 if active else 2
		style.set_content_margin_all(8)
		style.content_margin_right = 8 + TAB_ICON_SIZE + 10 # chừa bằng icon + khoảng cách: chữ nằm giữa CẢ tab
		tab.add_theme_stylebox_override(state, style)
	var text_color := INK if active else TEXT_LIGHT
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		tab.add_theme_color_override(key, text_color)
	# Font pixel: tab đang chọn chữ nâu đậm trên nền kem -> bản trơn (viền tối sẽ dính vào chữ tối); chưa chọn -> có viền.
	PixelTitle.style_if_supported(tab, tab.text, 20, not active)


## Chọn nhóm (Quán lẩu / Đi săn): nút nhóm sáng, dựng lại hàng tab con rồi mở tab con đầu tiên.
func _select_group(index: int, open_first := true) -> void:
	_group = index
	for i in _group_buttons.size():
		_group_buttons[i].modulate = Color.WHITE if i == index else TAB_DIM
	for child in _sub_tabs.get_children():
		_sub_tabs.remove_child(child)
		child.queue_free()
	_tab_buttons.clear()
	for key in GROUPS[index][2]:
		var spec: Array = TABS.filter(func(t): return t[0] == key)[0]
		var tab := _make_sub_tab(spec[1], spec[2])
		tab.pressed.connect(_select_tab.bind(key))
		_sub_tabs.add_child(tab)
		_tab_buttons[key] = tab
	if open_first:
		_select_tab(GROUPS[index][2][0])


## Chọn tab con: tự chuyển sang nhóm chứa tab đó nếu cần; tab đang chọn sáng, tab khác tối, rồi đổ lại thẻ.
func _select_tab(category: int) -> void:
	for i in GROUPS.size():
		if category in GROUPS[i][2] and i != _group:
			_select_group(i, false)
	_tab = category
	for key in _tab_buttons:
		_style_sub_tab(_tab_buttons[key], key == category)
	_scroll.scroll_vertical = 0 # tab mới bắt đầu từ thẻ đầu tiên
	_rebuild_cards()


## Đổ thẻ cho các nâng cấp thuộc tab đang chọn (bỏ qua nâng cấp tiến hóa chưa mở khóa).
## pop_in = thẻ lần lượt nảy ra (mở màn, đổi tab); mua xong thì vẽ lại thẳng, chỉ thẻ `bought_id` nảy + loé.
func _rebuild_cards(pop_in := true, bought_id := "") -> void:
	for child in _cards.get_children():
		_cards.remove_child(child) # gỡ ngay để lưới xếp lại chỉ với thẻ mới
		child.queue_free()
	var new_cards: Array[Control] = []
	var bought: Control = null
	if _tab == TAB_DECOR:
		for decor in Database.decors:
			var decor_card := _make_decor_card(decor)
			if decor.id == bought_id:
				bought = decor_card
			if pop_in:
				decor_card.modulate.a = 0.0
			_cards.add_child(decor_card)
			new_cards.append(decor_card)
	if _tab == TAB_WEAPONS:
		for weapon in Database.weapons:
			var weapon_card := _make_weapon_card(weapon)
			if weapon.id == bought_id:
				bought = weapon_card
			if pop_in:
				weapon_card.modulate.a = 0.0
			_cards.add_child(weapon_card)
			new_cards.append(weapon_card)
	for upgrade in Database.upgrades:
		if _tab_of(upgrade) == _tab and not _is_locked(upgrade):
			var card := _make_card(upgrade)
			if upgrade.id == bought_id:
				bought = card
			if pop_in:
				card.modulate.a = 0.0
			_cards.add_child(card)
			new_cards.append(card)
	if _tab == TAB_MOUNT:
		var preview := _make_mount_preview()
		if pop_in:
			preview.modulate.a = 0.0
		_cards.add_child(preview)
		new_cards.append(preview)
	if not pop_in:
		if bought != null:
			_celebrate_purchase(bought)
		return
	await get_tree().process_frame # chờ lưới xếp chỗ để biết cỡ thẻ (tâm phóng to)
	for i in new_cards.size():
		var card := new_cards[i]
		if not is_instance_valid(card) or card.is_queued_for_deletion():
			continue # đổi tab nhanh: thẻ cũ đã bị gỡ
		card.pivot_offset = card.size / 2.0
		card.scale = Vector2.ONE * 0.85
		var tween := card.create_tween().set_parallel(true)
		tween.tween_property(card, "scale", Vector2.ONE, CARD_POP_SECONDS).set_delay(i * CARD_POP_STAGGER) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(i * CARD_POP_STAGGER)


## Thẻ vừa mua: kêu "ting", nảy lên và loé sáng rồi về như cũ.
func _celebrate_purchase(card: Control) -> void:
	Sfx.play(self, Sfx.LOOT)
	await get_tree().process_frame # chờ lưới xếp chỗ để biết cỡ thẻ (tâm phóng to)
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2.ONE * 1.06
	card.modulate = PURCHASE_FLASH
	var tween := card.create_tween().set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate", Color.WHITE, 0.35)


## Tab chứa nâng cấp này: thú cưỡi tách sang tab riêng, còn lại theo category.
func _tab_of(upgrade: UpgradeData) -> int:
	return TAB_MOUNT if upgrade.id in MOUNT_UPGRADES else upgrade.category


## Hình đầu thẻ của nâng cấp (ảnh dải nhiều khung thì cắt khung đầu); không có thì null.
func _upgrade_icon(id: String) -> Texture2D:
	var spec: Variant = UPGRADE_ICONS.get(id)
	if spec == null:
		return null
	if spec is String:
		return load(spec)
	var atlas := AtlasTexture.new()
	atlas.atlas = load(spec[0])
	var frame := float(spec[1])
	atlas.region = Rect2(0, 0, frame, frame)
	return atlas


## Ô hình vuông cỡ `side`, giữ tỉ lệ ảnh, điểm ảnh sắc (không làm mượt).
func _make_icon(texture: Texture2D, side: float) -> Control:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(side, side)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.size_flags_vertical = SIZE_SHRINK_CENTER
	rect.mouse_filter = MOUSE_FILTER_PASS
	return rect


## Ô xem trước trâu ở tab Thú cưỡi: hình trâu to + chỉ số trâu ở cấp hiện tại (cấp 0 thì xem trước cấp 1).
## Chỉ số = chỉ số gốc (data/combatants/mount_buffalo.tres) x (1 + bonus/cấp x (cấp - 1)), giống HuntSession.create_mount().
func _make_mount_preview() -> Control:
	var data: CombatantData = HUNT_CONFIG.mount
	var level := GameState.get_upgrade_level("mount")
	var shown_level := maxi(level, 1)
	var mult := 1.0 + HUNT_CONFIG.mount_bonus_per_level * (shown_level - 1)
	var card := PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.mouse_filter = MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", _box_style(CARD_COLOR, CARD_BORDER, 4, 16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var title := _make_label(data.display_name + (" của bạn" if level > 0 else " (chưa có)"), 24, INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var picture := _make_icon(load(UPGRADE_ICONS["mount"]), 128.0)
	picture.size_flags_horizontal = SIZE_SHRINK_CENTER
	if level == 0:
		picture.modulate = Color(0.45, 0.45, 0.45) # chưa có: hình tối
	box.add_child(picture)
	var label := "[color=#%s]%s:[/color] " % [INK_SOFT.to_html(false), "Cấp %d" % level if level > 0 else "Mở ở cấp 1"]
	label += "Máu [b]%d[/b]  ·  Dame [b]%d[/b]  ·  Tốc [b]%d[/b]" % [roundi(data.max_hp * mult), roundi(data.damage * mult), data.speed]
	label += "\n[color=#%s]Đứng trước đầu bếp, quái đánh trâu trước.[/color]" % INK_SOFT.to_html(false)
	box.add_child(_make_rich_box(label))
	return card


## Thẻ một nâng cấp: tên + cấp, mô tả, nút mua (MAX hoặc thiếu tiền thì nút xám).
func _make_card(upgrade: UpgradeData) -> Control:
	var level := GameState.get_upgrade_level(upgrade.id)
	var cost := upgrade.cost_for_next(level)
	var card := PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.mouse_filter = MOUSE_FILTER_PASS # cho cú vuốt trên thẻ đi tiếp lên ScrollContainer (điện thoại)
	card.add_theme_stylebox_override("panel", _box_style(CARD_COLOR, CARD_BORDER, 4, 16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)
	top.add_child(_make_icon(_upgrade_icon(upgrade.id), CARD_ICON_SIZE))
	var name_label := _make_label(upgrade.display_name, 24, INK, true)
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(name_label)
	var maxed := level >= upgrade.max_level()
	top.add_child(_make_label("Cấp %d/%d" % [level, upgrade.max_level()], 20, MAXED_COLOR if maxed else INK, maxed))

	var description := _make_label(upgrade.description, 18, INK)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(description)
	box.add_child(_make_effect_box(upgrade, level))

	var affordable := cost >= 0 and GameState.can_afford(cost)
	var buy_text := "ĐÃ TỐI ĐA" if cost < 0 else ("MUA · %s" if affordable else "THIẾU TIỀN · %s") % GameState.format_money(cost)
	var buy := PixelButton.new(buy_text, 22)
	buy.custom_minimum_size = Vector2(0, 56)
	buy.disabled = not affordable
	buy.mouse_filter = MOUSE_FILTER_PASS # vuốt bắt đầu trên nút vẫn cuộn được
	buy.button_down.connect(func(): _scroll_at_press = _scroll.scroll_vertical)
	buy.pressed.connect(_buy_upgrade.bind(upgrade))
	box.add_child(buy)
	return card


## Ô hiệu ứng trong thẻ: "Hiện tại" (đang được gì) và "Cấp sau" (sẽ được gì, phần cộng thêm tô xanh).
## Đã max thì chỉ còn "Hiện tại" + chữ "Đã tối đa" màu cam.
func _make_effect_box(upgrade: UpgradeData, level: int) -> Control:
	var now := _effect_at(upgrade, level)
	var now_bb := "[color=#%s]%s[/color]" % [NONE_COLOR.to_html(false), now] if now == "Chưa có" else "[b]%s[/b]" % now
	var lines := "[color=#%s]Hiện tại:[/color] %s" % [INK_SOFT.to_html(false), now_bb]
	if level >= upgrade.max_level():
		lines += "  [color=#%s][b]Đã tối đa[/b][/color]" % MAXED_COLOR.to_html(false)
	else:
		lines += "\n[color=#%s]Cấp %d:[/color] [b]%s[/b]  [color=#%s][b]%s[/b][/color]" % [
			INK_SOFT.to_html(false), level + 1, _effect_at(upgrade, level + 1), GAIN_COLOR.to_html(false), _gain_text(upgrade, level)]
	return _make_rich_box(lines)


## Ô chữ màu (BBCode) nền kem đậm trong thẻ: dùng cho hiệu ứng nâng cấp và chỉ số vũ khí.
func _make_rich_box(bbcode: String) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = MOUSE_FILTER_PASS
	var style := _box_style(EFFECT_BG, Color(CARD_BORDER, 0.35), 2, 8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	panel.add_theme_stylebox_override("panel", style)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.mouse_filter = MOUSE_FILTER_PASS
	text.add_theme_font_size_override("normal_font_size", 18)
	text.add_theme_font_size_override("bold_font_size", 18)
	text.add_theme_font_override("bold_font", BOLD_FONT)
	text.add_theme_color_override("default_color", INK)
	text.text = bbcode
	panel.add_child(text)
	return panel


# --- Tab Trang trí -------------------------------------------------------------

## Hình xem trước một món trang trí, vẽ bằng DecorArt (cùng hàm vẽ trong quán), phóng nguyên lần vừa ô.
class DecorPreview extends Control:
	var slot: String
	var style: String

	func _init(decor: DecorData, box_size: Vector2) -> void:
		slot = decor.slot
		style = decor.style
		custom_minimum_size = box_size
		mouse_filter = MOUSE_FILTER_PASS

	func _draw() -> void:
		var box := Vector2(DecorArt.BOX[slot])
		var px := maxf(1.0, floorf(minf(size.x / box.x, size.y / box.y))) # nguyên lần cho điểm ảnh vuông
		DecorArt.draw(self, slot, style, ((size - box * px) / 2.0).floor(), px)


## Thẻ một món trang trí: hình xem trước + tên + trạng thái, chỗ đặt, mô tả, % tip, nút Mua / Đặt / Cất.
func _make_decor_card(decor: DecorData) -> Control:
	var owned := GameState.owns_decor(decor.id)
	var placed: bool = GameState.decor_placed.get(decor.slot, "") == decor.id
	var card := PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.mouse_filter = MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", _box_style(CARD_COLOR, MAXED_COLOR if placed else CARD_BORDER, 4, 16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	var preview_bg := PanelContainer.new()
	preview_bg.add_theme_stylebox_override("panel", _box_style(Color("b0703a"), Color(CARD_BORDER, 0.5), 2, 4)) # nền như tường gạch
	preview_bg.mouse_filter = MOUSE_FILTER_PASS
	preview_bg.add_child(DecorPreview.new(decor, Vector2(104, 56)))
	top.add_child(preview_bg)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(names)
	names.add_child(_make_label(decor.display_name, 22, INK, true))
	names.add_child(_make_label("Chỗ đặt: " + str(DecorArt.SLOT_NAMES.get(decor.slot, decor.slot)), 18, INK_SOFT))
	if placed:
		top.add_child(_make_label("Đang đặt", 20, MAXED_COLOR, true))
	elif owned:
		top.add_child(_make_label("Đã có", 20, GAIN_COLOR))

	var description := _make_label(decor.description, 18, INK)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(description)
	var lines := "[color=#%s]Khi đặt trong quán:[/color] khách tip [color=#%s][b]+%d%%[/b][/color]" % [
			INK_SOFT.to_html(false), GAIN_COLOR.to_html(false), roundi(decor.tip_bonus * 100.0)]
	var current := Database.get_decor(str(GameState.decor_placed.get(decor.slot, "")))
	if current != null and not placed:
		lines += "\n[color=#%s]Chỗ này đang đặt:[/color] %s" % [INK_SOFT.to_html(false), current.display_name]
	box.add_child(_make_rich_box(lines))

	var affordable := GameState.can_afford(decor.cost)
	var text := "CẤT ĐI" if placed else ("ĐẶT VÀO QUÁN" if owned else (
			("MUA · %s" if affordable else "THIẾU TIỀN · %s") % GameState.format_money(decor.cost)))
	var button := PixelButton.new(text, 22)
	button.custom_minimum_size = Vector2(0, 56)
	button.disabled = not owned and not affordable
	button.mouse_filter = MOUSE_FILTER_PASS
	button.button_down.connect(func(): _scroll_at_press = _scroll.scroll_vertical)
	button.pressed.connect(_on_decor_pressed.bind(decor))
	box.add_child(button)
	return card


## Bấm nút món trang trí: chưa có thì mua (mua xong đặt luôn), có rồi thì đặt vào quán, đang đặt thì cất đi.
func _on_decor_pressed(decor: DecorData) -> void:
	if _scroll.scroll_vertical != _scroll_at_press:
		return # vừa vuốt cuộn rồi thả trên nút: không mua nhầm
	var slot_name := str(DecorArt.SLOT_NAMES.get(decor.slot, decor.slot))
	if GameState.decor_placed.get(decor.slot, "") == decor.id:
		GameState.remove_decor(decor.slot)
		_message.text = "Đã cất %s, chỗ %s để trống." % [decor.display_name, slot_name.to_lower()]
	elif GameState.owns_decor(decor.id):
		GameState.place_decor(decor.id, decor.slot)
		_message.text = "Đã đặt %s vào quán." % decor.display_name
	elif GameState.buy_decor(decor.id, decor.slot, decor.cost):
		_message.text = "Đã mua và đặt %s! Khách tip thêm %d%%." % [decor.display_name, roundi(decor.tip_bonus * 100.0)]
		_rebuild_cards(false, decor.id)
		return
	else:
		return
	_rebuild_cards(false)


# --- Tab Vũ khí ----------------------------------------------------------------

## Thẻ một vũ khí: tên + trạng thái, mô tả, chỉ số (cộng xanh, trừ đỏ), so với vũ khí đang cầm, nút Mua / Cầm.
func _make_weapon_card(weapon: WeaponData) -> Control:
	var owned := GameState.owns_weapon(weapon.id)
	var equipped := GameState.equipped_weapon == weapon.id
	var card := PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.mouse_filter = MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", _box_style(CARD_COLOR, MAXED_COLOR if equipped else CARD_BORDER, 4, 16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)
	top.add_child(_make_icon(load(SHOP_ICONS + weapon.id + ".png"), CARD_ICON_SIZE))
	var name_label := _make_label(weapon.display_name, 24, INK, true)
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(name_label)
	if equipped:
		top.add_child(_make_label("Đang cầm", 20, MAXED_COLOR, true))
	elif owned:
		top.add_child(_make_label("Đã có", 20, GAIN_COLOR))

	var description := _make_label(weapon.description, 18, INK)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(description)

	var lines := "[color=#%s]Chỉ số:[/color] %s" % [INK_SOFT.to_html(false), _weapon_stats_bbcode(
			weapon.damage_bonus, weapon.speed_bonus, weapon.crit_chance_bonus, "[b]Không cộng gì[/b]")]
	if not equipped:
		var current := Database.equipped_weapon()
		lines += "\n[color=#%s]So với %s:[/color] %s" % [INK_SOFT.to_html(false), current.display_name, _weapon_stats_bbcode(
				weapon.damage_bonus - current.damage_bonus, weapon.speed_bonus - current.speed_bonus,
				weapon.crit_chance_bonus - current.crit_chance_bonus, "[b]Như nhau[/b]")]
	box.add_child(_make_rich_box(lines))

	var affordable := GameState.can_afford(weapon.cost)
	var text := "ĐANG CẦM" if equipped else ("CẦM VŨ KHÍ NÀY" if owned else (
			("MUA · %s" if affordable else "THIẾU TIỀN · %s") % GameState.format_money(weapon.cost)))
	var button := PixelButton.new(text, 22)
	button.custom_minimum_size = Vector2(0, 56)
	button.disabled = equipped or (not owned and not affordable)
	button.mouse_filter = MOUSE_FILTER_PASS
	button.button_down.connect(func(): _scroll_at_press = _scroll.scroll_vertical)
	button.pressed.connect(_on_weapon_pressed.bind(weapon))
	box.add_child(button)
	return card


## "Dame +6 · Tốc -3 · Chí mạng +5%": số cộng màu xanh, số trừ màu đỏ, bỏ qua chỉ số bằng 0.
func _weapon_stats_bbcode(damage: int, speed: int, crit: float, when_zero: String) -> String:
	var parts: Array[String] = []
	for stat in [["Dame", damage, ""], ["Tốc", speed, ""], ["Chí mạng", roundi(crit * 100.0), "%"]]:
		var value: int = stat[1]
		if value == 0:
			continue
		var color := GAIN_COLOR if value > 0 else POOR_COLOR
		parts.append("%s [color=#%s][b]%+d%s[/b][/color]" % [stat[0], color.to_html(false), value, stat[2]])
	return when_zero if parts.is_empty() else "  ·  ".join(parts)


## Bấm nút vũ khí: chưa có thì mua (mua xong cầm luôn), có rồi thì đổi sang cầm.
func _on_weapon_pressed(weapon: WeaponData) -> void:
	if _scroll.scroll_vertical != _scroll_at_press:
		return # vừa vuốt cuộn rồi thả trên nút: không mua nhầm
	if GameState.owns_weapon(weapon.id):
		GameState.equip_weapon(weapon.id)
		_message.text = "Đã cầm %s." % weapon.display_name
	elif GameState.buy_weapon(weapon.id, weapon.cost):
		_message.text = "Đã mua và cầm %s!" % weapon.display_name
		_rebuild_cards(false, weapon.id)
		return
	else:
		return
	_rebuild_cards(false)


## Hiệu ứng ở một cấp, viết cho người chơi đọc (giá trị lấy từ values[] trong .tres).
func _effect_at(upgrade: UpgradeData, level: int) -> String:
	var v := upgrade.value_at(level)
	match upgrade.id:
		"pot":
			return "%d phần mỗi mẻ" % v
		"stove":
			var speed := roundi((1.0 - v) * 100.0)
			return "%d bếp, %s" % [1 + level, "nấu tốc độ gốc" if speed == 0 else "nấu nhanh hơn %d%%" % speed]
		"staff":
			return ["Chưa có", "1 phụ bếp", "2 phụ bếp", "2 phụ bếp + bếp phó"][clampi(level, 0, 3)]
		"cold_storage":
			return "Giữ đồ %d ngày" % (GameState.SHELF_DAYS + int(v))
		"knife", "dragon_blade":
			return "Chưa có" if v == 0.0 else "+%d dame" % v
		"armor", "battle_robe":
			return "Chưa có" if v == 0.0 else "+%d máu" % v
		"sharp_mind":
			return "Chí mạng %d%%" % roundi((HUNT_CONFIG.base_crit_chance + v) * 100.0)
		"hawk_eye":
			return "Chí mạng gây x%s dame" % _short_number(HUNT_CONFIG.base_crit_multiplier + v)
		"mount":
			if level <= 0:
				return "Chưa có"
			return "Có trâu chiến" if level == 1 else "Trâu khỏe thêm %d%%" % roundi(HUNT_CONFIG.mount_bonus_per_level * (level - 1) * 100.0)
		"tables":
			return "%d bàn" % v
		"furniture":
			return "Chưa có" if v == 0.0 else "+%d%% tip" % roundi(v * 100.0)
		"service":
			return "Chưa có" if v == 0.0 else "+%d%% phí phục vụ" % roundi(v * 100.0)
	return _short_number(v)


## Phần cộng thêm khi lên từ `level` lên level + 1 (chữ xanh trên thẻ): cộng = giá trị cấp sau - giá trị cấp này.
func _gain_text(upgrade: UpgradeData, level: int) -> String:
	var diff := upgrade.value_at(level + 1) - upgrade.value_at(level)
	match upgrade.id:
		"pot":
			return "+%d phần" % diff
		"stove":
			return "+1 bếp, +%d%%" % roundi(-diff * 100.0)
		"staff":
			return "+ bếp phó" if level + 1 >= 3 else "+1 phụ bếp"
		"cold_storage":
			return "+%d ngày" % diff
		"knife", "dragon_blade":
			return "+%d" % diff
		"armor", "battle_robe":
			return "+%d" % diff
		"sharp_mind", "furniture", "service":
			return "+%d%%" % roundi(diff * 100.0)
		"hawk_eye":
			return "+%s" % _short_number(diff)
		"mount":
			return "Mở khoá" if level == 0 else "+%d%%" % roundi(HUNT_CONFIG.mount_bonus_per_level * 100.0)
		"tables":
			return "+%d bàn" % diff
	return "+%s" % _short_number(diff)


## Số gọn cho người đọc: số nguyên thì bỏ phần thập phân (2 thay vì 2.0), còn lại giữ 1 chữ số (1.9).
static func _short_number(x: float) -> String:
	return str(roundi(x)) if is_equal_approx(x, roundf(x)) else "%.1f" % x


## Mua 1 cấp: trừ tiền, lên cấp, cập nhật số bàn nếu là "Thêm bàn", báo mở khóa tiến hóa khi max cấp.
func _buy_upgrade(upgrade: UpgradeData) -> void:
	if _scroll.scroll_vertical != _scroll_at_press:
		return # ngón tay vừa vuốt cuộn rồi thả trên nút: không mua nhầm
	var level := GameState.get_upgrade_level(upgrade.id)
	var cost := upgrade.cost_for_next(level)
	if cost < 0 or not GameState.spend_money(cost):
		return
	GameState.set_upgrade_level(upgrade.id, level + 1)
	_message.text = "Đã nâng %s lên cấp %d." % [upgrade.display_name, level + 1]
	if upgrade.id == "tables":
		GameState.tables_floor1 = int(upgrade.value_at(level + 1))
		_message.text += " Tầng 1 có %d bàn." % GameState.tables_floor1
	if level + 1 == upgrade.max_level() and upgrade.evolves_into != "":
		var next := Database.get_upgrade(upgrade.evolves_into)
		_message.text = "%s đã max cấp! Mở khóa %s." % [upgrade.display_name, next.display_name if next else upgrade.evolves_into]
	_rebuild_cards(false, upgrade.id)


## Nâng cấp mở khóa nhờ tiến hóa (vd Phí phục vụ) chỉ hiện khi nâng cấp gốc đã max cấp.
func _is_locked(upgrade: UpgradeData) -> bool:
	for other in Database.upgrades:
		if other.evolves_into == upgrade.id:
			return GameState.get_upgrade_level(other.id) < other.max_level()
	return false


## Cập nhật số tiền góc phải bảng.
func _on_money_changed(value: int) -> void:
	_money_label.text = "Tiền: %s" % GameState.format_money(value)


## Khung nền phẳng có viền (bảng tối / thẻ kem), góc vuông nhẹ cho hợp pixel.
func _box_style(fill: Color, border: Color, border_width: int, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(padding)
	return style


## Label với cỡ chữ, màu; bold = chữ đậm có viền tối (dùng trên nền tối).
func _make_label(text: String, font_size: int, color: Color, bold := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", BOLD_FONT)
		if color != INK:
			label.add_theme_color_override("font_outline_color", Color("2b1a14"))
			label.add_theme_constant_override("outline_size", PixelButton.outline_for(font_size))
	return label
