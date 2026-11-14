extends Control
## Cửa hàng nâng cấp: mở trước ngày 1 (Chơi mới), sau mỗi ngày đạt KPI (game vừa được lưu) và khi Tiếp tục.
## Nền dùng lại phong cảnh của menu chính (phủ tối), bảng giữa có 3 tab Bếp / Chiến đấu / Quán theo
## UpgradeData.category. Mỗi nâng cấp là một thẻ: tên, cấp, mô tả luôn hiện (điện thoại không có hover), nút mua đỏ.
## Giá và hiệu ứng nằm trong data/upgrades/*.tres. TODO(Hạo): tiến hóa khi max cấp, Lầu 2, phòng riêng, nhân viên.
##
## Số bàn tầng 1 là nâng cấp "Thêm bàn" (data/upgrades/tables.tres, tối đa 10 bàn); đủ 10 bàn thì
## mở "Phí phục vụ" (service.tres) qua trường evolves_into. TODO(nhóm): cân bằng giá.

const SKY := preload("res://assets/sprites/scenery/sky.png")
const LANDSCAPE := preload("res://assets/sprites/scenery/landscape.png")
const BOLD_FONT := preload("res://assets/fonts/BeVietnamPro-Bold.ttf")
const TAB_NAMES := {
	UpgradeData.Category.KITCHEN: "BẾP",
	UpgradeData.Category.COMBAT: "CHIẾN ĐẤU",
	UpgradeData.Category.RESTAURANT: "QUÁN",
}
const BOARD_COLOR := Color("2b1a14", 0.94)
const BOARD_BORDER := Color("6b2a22")
const CARD_COLOR := Color("f1e3c4")
const CARD_BORDER := Color("461619")
const INK := Color("3a2418") ## Chữ tối trên thẻ màu kem.
const TEXT_LIGHT := Color("fbecd2")
const ACCENT := Color("f2a33a")
const TAB_DIM := Color(0.55, 0.55, 0.55) ## Tab chưa chọn tối đi.
const FADE_IN_SECONDS := 0.5
const FLASH_COLOR := Color("fff4d6") ## Màu ánh sáng khi rời menu (khớp FLASH_COLOR trong main_menu.gd): màn tan dần từ màu này.
const BOARD_DROP_SECONDS := 0.9 ## Bảng rơi từ trên xuống và nảy khi chạm chỗ.
const CARD_POP_SECONDS := 0.45
const CARD_POP_STAGGER := 0.07 ## Thẻ sau nảy ra trễ hơn thẻ trước chừng này giây.

var _tab: UpgradeData.Category = UpgradeData.Category.KITCHEN
var _tab_buttons := {} ## Category -> PixelButton
var _cards: GridContainer
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
			.set_delay(0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	var board := PanelContainer.new()
	board.add_theme_stylebox_override("panel", _box_style(BOARD_COLOR, BOARD_BORDER, 6, 24))
	margin.add_child(board)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	board.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _make_label("CỬA HÀNG NÂNG CẤP · CHUẨN BỊ NGÀY %d" % GameState.day, 30, ACCENT, true)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	_money_label = _make_label("", 24, TEXT_LIGHT, true)
	header.add_child(_money_label)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	column.add_child(tabs)
	for category in TAB_NAMES:
		var tab := PixelButton.new(TAB_NAMES[category], 24)
		tab.custom_minimum_size = Vector2(220, 56)
		tab.pressed.connect(_select_tab.bind(category))
		tabs.add_child(tab)
		_tab_buttons[category] = tab

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
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


## Chọn tab: tab đang chọn sáng, tab khác tối đi, rồi đổ lại thẻ.
func _select_tab(category: UpgradeData.Category) -> void:
	_tab = category
	for key in _tab_buttons:
		(_tab_buttons[key] as Control).modulate = Color.WHITE if key == category else TAB_DIM
	_rebuild_cards()


## Đổ thẻ cho các nâng cấp thuộc tab đang chọn (bỏ qua nâng cấp tiến hóa chưa mở khóa).
## pop_in = thẻ lần lượt nảy ra (mở màn, đổi tab); mua xong thì vẽ lại thẳng, không nảy.
func _rebuild_cards(pop_in := true) -> void:
	for child in _cards.get_children():
		_cards.remove_child(child) # gỡ ngay để lưới xếp lại chỉ với thẻ mới
		child.queue_free()
	var new_cards: Array[Control] = []
	for upgrade in Database.upgrades:
		if upgrade.category == _tab and not _is_locked(upgrade):
			var card := _make_card(upgrade)
			if pop_in:
				card.modulate.a = 0.0
			_cards.add_child(card)
			new_cards.append(card)
	if not pop_in:
		return
	await get_tree().process_frame # chờ lưới xếp chỗ để biết cỡ thẻ (tâm phóng to)
	for i in new_cards.size():
		var card := new_cards[i]
		if not is_instance_valid(card) or card.is_queued_for_deletion():
			continue # đổi tab nhanh: thẻ cũ đã bị gỡ
		card.pivot_offset = card.size / 2.0
		card.scale = Vector2.ONE * 0.6
		var tween := card.create_tween().set_parallel(true)
		tween.tween_property(card, "scale", Vector2.ONE, CARD_POP_SECONDS).set_delay(i * CARD_POP_STAGGER) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(i * CARD_POP_STAGGER)


## Thẻ một nâng cấp: tên + cấp, mô tả, nút mua (MAX hoặc thiếu tiền thì nút xám).
func _make_card(upgrade: UpgradeData) -> Control:
	var level := GameState.get_upgrade_level(upgrade.id)
	var cost := upgrade.cost_for_next(level)
	var card := PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _box_style(CARD_COLOR, CARD_BORDER, 4, 16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	var name_label := _make_label(upgrade.display_name, 24, INK, true)
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.add_child(_make_label("Cấp %d/%d" % [level, upgrade.max_level()], 20, INK))

	var description := _make_label(upgrade.description, 18, INK)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(description)

	var buy := PixelButton.new("ĐÃ TỐI ĐA" if cost < 0 else "MUA · %s" % GameState.format_money(cost), 22)
	buy.custom_minimum_size = Vector2(0, 56)
	buy.disabled = cost < 0 or not GameState.can_afford(cost)
	buy.pressed.connect(_buy_upgrade.bind(upgrade))
	box.add_child(buy)
	return card


## Mua 1 cấp: trừ tiền, lên cấp, cập nhật số bàn nếu là "Thêm bàn", báo mở khóa tiến hóa khi max cấp.
func _buy_upgrade(upgrade: UpgradeData) -> void:
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
	_rebuild_cards(false)


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
			label.add_theme_constant_override("outline_size", 8)
	return label
