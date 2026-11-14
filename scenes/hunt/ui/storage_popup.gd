class_name StoragePopup
extends Control
## Bảng xem kho: nguyên liệu + nước cốt chia theo ngày nhập, mỗi lô có dấu "!" và số ngày còn dùng được.
## Thẻ thứ hai "Thực đơn" (MenuBook): giá, công thức các loại lẩu và giá đồ nhúng.
## Dùng: add_child(StoragePopup.new()) – tự đóng khi bấm "Đóng".

const POT_ICON := "res://assets/sprites/ui/broth_pot.png"
const TAB_NAMES: Array[String] = ["Kho", "Thực đơn"]

var start_tab := 0 ## Đặt 1 trước add_child để mở thẳng thẻ Thực đơn.
var _scroll: ScrollContainer
var _hint: Label
var _tab_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	# Bấm ra khoảng tối ngoài bảng thì đóng (giống ESC / nút "Đóng").
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			queue_free())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE # Để chạm ngoài bảng rơi xuống lớp tối phía dưới.
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_panel", 8, Vector2(26, 20)))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	box.add_child(tabs)
	_hint = HuntUI.label("", HuntUI.FONT_SMALL, HuntUI.INK_SOFT)
	_hint.custom_minimum_size = Vector2(760, 0) # Cố định bề rộng để bảng không co giãn khi đổi thẻ.
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hint)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(760, 370)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	for i in TAB_NAMES.size():
		var tab := HuntUI.button(TAB_NAMES[i], 200)
		tab.toggle_mode = true
		tab.pressed.connect(_show_tab.bind(i))
		tabs.add_child(tab)
		_tab_buttons.append(tab)

	var close := HuntUI.button("Đóng", 220)
	close.size_flags_horizontal = SIZE_SHRINK_CENTER
	close.pressed.connect(queue_free)
	box.add_child(close)
	_show_tab(start_tab)
	HuntUI.book_open(panel)


## 0 = Kho, 1 = Thực đơn.
func _show_tab(index: int) -> void:
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == index)
		_tab_buttons[i].modulate = Color.WHITE if i == index else Color(1, 1, 1, 0.6)
	for child in _scroll.get_children():
		_scroll.remove_child(child)
		child.queue_free()
	if index == 1:
		_hint.text = "Món đang bán hôm nay (Ngày %d). Nồi có sẵn = nước cốt đã nấu trong kho." % GameState.day
		_scroll.add_child(_with_scrollbar_gap(MenuBook.build()))
	else:
		_hint.text = "Đồ giữ được %d ngày (nâng Kho lạnh để giữ lâu hơn). Sơ chế, nấu và bán luôn lấy lô cũ nhất trước." % GameState.shelf_days()
		_scroll.add_child(_with_scrollbar_gap(_storage_list()))


## Chừa khe bên phải để thanh cuộn không đè lên chữ.
func _with_scrollbar_gap(content: Control) -> Control:
	var m := MarginContainer.new()
	m.size_flags_horizontal = SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_right", 18)
	m.add_child(content)
	return m


func _storage_list() -> Control:
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)

	list.add_child(HuntUI.label("Nguyên liệu", 22, HuntUI.RUST))
	var item_ids := GameState.item_batches.keys()
	item_ids.sort()
	if item_ids.is_empty():
		list.add_child(HuntUI.label("(trống)", HuntUI.FONT_SMALL, HuntUI.INK_SOFT))
	for id in item_ids:
		list.add_child(_row(HuntUI.ingredient_texture(id), GameState.item_display_name(id), GameState.item_batch_list(id)))
	list.add_child(HSeparator.new())
	list.add_child(HuntUI.label("Đã sơ chế (giữ hạn của lô thô)", 22, HuntUI.RUST))
	var prepped_ids := GameState.prepped_batches.keys()
	prepped_ids.sort()
	if prepped_ids.is_empty():
		list.add_child(HuntUI.label("(trống)", HuntUI.FONT_SMALL, HuntUI.INK_SOFT))
	for id in prepped_ids:
		list.add_child(_row(HuntUI.prepped_texture(id), GameState.item_display_name(id), GameState.prepped_batch_list(id), false, true))
	list.add_child(HSeparator.new())
	list.add_child(HuntUI.label("Nước cốt đã nấu", 22, HuntUI.RUST))
	var broth_ids := GameState.broth_batches.keys()
	if broth_ids.is_empty():
		list.add_child(HuntUI.label("(trống)", HuntUI.FONT_SMALL, HuntUI.INK_SOFT))
	var pot: Texture2D = load(POT_ICON) if ResourceLoader.exists(POT_ICON) else null
	for id in broth_ids:
		var broth := Database.get_broth(id)
		list.add_child(_row(pot, broth.display_name if broth else id, GameState.broth_batch_list(id), true))
	return list


func _row(icon: Texture2D, name: String, batches: Array, is_broth := false, is_prepped := false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if icon != null:
		var ic := HuntUI.texture_rect(icon, 40)
		ic.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(ic)
	var n := HuntUI.label(name, HuntUI.FONT_SMALL)
	n.custom_minimum_size = Vector2(170, 0)
	n.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(n)
	var chips := HFlowContainer.new()
	chips.size_flags_horizontal = SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 4)
	for batch in batches:
		chips.add_child(batch_chip(batch, is_broth, is_prepped))
	row.add_child(chips)
	return row


## Ô lô hàng: số lượng + vòng tròn "!" nhỏ ở góc trên bên phải. Chạm vào ô mới hiện hạn còn lại.
## Còn 1 ngày: tự hiện cảnh báo "Sắp hết hạn!" (đỏ). Đã quá hạn (giữ bán tiếp): hiện "Hết hạn" (tím).
static func batch_chip(batch: Dictionary, is_broth := false, is_prepped := false) -> Control:
	var left := GameState.days_left(batch)
	var expired: bool = batch["expired"] or left <= 0
	var color := Color("2e7d32")
	var detail := "còn %d ngày" % left
	var always_show := false
	if expired:
		color = Color("6a1b9a")
		# Nồi luôn tính hạn từ ngày nấu; nồi bị đánh dấu là do nấu từ nguyên liệu hết hạn.
		detail = "Nấu từ đồ cũ" if is_broth and left > 0 else "Hết hạn"
		always_show = true
	elif left == 1:
		color = Color("c62828")
		detail = "Sắp hết hạn!"
		always_show = true
	elif left == 2:
		color = Color("b8860b")
	var count_text := "x%d" % int(batch["count"])
	if is_prepped:
		count_text += " · %s" % str(GameState.QUALITY_NAMES[clampi(int(batch.get("q", 1)), 0, 2)])

	var chip := Button.new()
	chip.focus_mode = Control.FOCUS_NONE
	chip.custom_minimum_size = Vector2(76, 56) # Vùng chạm đủ lớn cho ngón tay.
	chip.add_theme_font_size_override("font_size", HuntUI.FONT_SMALL)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(color, 0.22 if state == "pressed" else 0.12)
		style.border_color = color if always_show else Color(color, 0.55)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		style.content_margin_right = 14
		chip.add_theme_stylebox_override(state, style)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		chip.add_theme_color_override(c, HuntUI.INK if not always_show else color.darkened(0.15))
	var full := "%s  %s" % [count_text, detail]
	chip.text = full if always_show else count_text
	if not always_show:
		chip.pressed.connect(func(): chip.text = count_text if chip.text == full else full)

	# Vòng tròn nhỏ bọc dấu "!" ở góc trên bên phải.
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color = color
	bs.border_color = Color("fff8e8")
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(11)
	bs.set_content_margin_all(0)
	badge.add_theme_stylebox_override("panel", bs)
	badge.custom_minimum_size = Vector2(22, 22)
	var mark := Label.new()
	mark.text = "!"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 15)
	mark.add_theme_color_override("font_color", Color.WHITE)
	badge.add_child(mark)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -14
	badge.offset_right = 8
	badge.offset_top = -8
	badge.offset_bottom = 14
	chip.add_child(badge)
	if always_show:
		# Nhấp nháy nhẹ cho dễ thấy.
		var t := badge.create_tween().set_loops()
		t.tween_property(badge, "modulate:a", 0.45, 0.5)
		t.tween_property(badge, "modulate:a", 1.0, 0.5)

	# Chừa chỗ cho vòng tròn nhô ra ngoài ô.
	var holder := MarginContainer.new()
	holder.add_theme_constant_override("margin_top", 8)
	holder.add_theme_constant_override("margin_bottom", 8) # cân với phía trên để ô nằm giữa hàng
	holder.add_theme_constant_override("margin_right", 8)
	holder.add_child(chip)
	return holder
