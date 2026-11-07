class_name StoragePopup
extends Control
## Bảng xem kho: nguyên liệu + nước cốt chia theo ngày nhập, mỗi lô có dấu "!" và số ngày còn dùng được.
## Dùng: add_child(StoragePopup.new()) – tự đóng khi bấm "Đóng".

const POT_ICON := "res://assets/sprites/ui/broth_pot.png"


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_panel", 8, Vector2(26, 20)))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(HuntUI.label("Kho của quán", 28, HuntUI.RUST))
	box.add_child(HuntUI.label("Đồ giữ được %d ngày. Nấu và bán luôn lấy lô cũ nhất trước." % GameState.SHELF_DAYS, HuntUI.FONT_SMALL, HuntUI.INK_SOFT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	list.add_child(HuntUI.label("Nguyên liệu", 22, HuntUI.RUST))
	var item_ids := GameState.item_batches.keys()
	item_ids.sort()
	if item_ids.is_empty():
		list.add_child(HuntUI.label("(trống)", HuntUI.FONT_SMALL, HuntUI.INK_SOFT))
	for id in item_ids:
		list.add_child(_row(HuntUI.ingredient_texture(id), GameState.item_display_name(id), GameState.item_batch_list(id)))
	list.add_child(HSeparator.new())
	list.add_child(HuntUI.label("Nước cốt đã nấu", 22, HuntUI.RUST))
	var broth_ids := GameState.broth_batches.keys()
	if broth_ids.is_empty():
		list.add_child(HuntUI.label("(trống)", HuntUI.FONT_SMALL, HuntUI.INK_SOFT))
	var pot: Texture2D = load(POT_ICON) if ResourceLoader.exists(POT_ICON) else null
	for id in broth_ids:
		var broth := Database.get_broth(id)
		list.add_child(_row(pot, broth.display_name if broth else id, GameState.broth_batch_list(id)))

	var close := HuntUI.button("Đóng", 220)
	close.size_flags_horizontal = SIZE_SHRINK_CENTER
	close.pressed.connect(queue_free)
	box.add_child(close)
	HuntUI.book_open(panel)


func _row(icon: Texture2D, name: String, batches: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if icon != null:
		row.add_child(HuntUI.texture_rect(icon, 40))
	var n := HuntUI.label(name, HuntUI.FONT_SMALL)
	n.custom_minimum_size = Vector2(170, 0)
	row.add_child(n)
	var chips := HFlowContainer.new()
	chips.size_flags_horizontal = SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 4)
	for batch in batches:
		chips.add_child(batch_chip(batch))
	row.add_child(chips)
	return row


## Ô nhỏ "x6  !2 ngày": số lượng + dấu chấm than và hạn còn lại (đỏ khi là ngày cuối, tím khi đã hết hạn).
static func batch_chip(batch: Dictionary) -> Control:
	var left := GameState.days_left(batch)
	var expired: bool = batch["expired"] or left <= 0
	var color := Color("2e7d32")
	var text := "!%d ngày" % left
	if expired:
		color = Color("6a1b9a")
		text = "! Hết hạn"
	elif left == 1:
		color = Color("c62828")
		text = "! Ngày cuối"
	elif left == 2:
		color = Color("b8860b")
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.14)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.add_child(HuntUI.label("x%d" % int(batch["count"]), HuntUI.FONT_SMALL))
	line.add_child(HuntUI.label(text, HuntUI.FONT_SMALL, color))
	chip.add_child(line)
	return chip
