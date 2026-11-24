class_name WaitingBoard
extends VBoxContainer
## Cột thẻ khách đang chờ ở cạnh phải sàn: chỉ để nhìn, không chạm được. Lúc mở bảng Dọn dẹp vẫn nổi trên lớp tối.
## Mỗi nhóm chờ là một thẻ nhỏ: ảnh người đầu nhóm + "x<số người>" + thanh kiên nhẫn mỏng (xanh -> cam -> đỏ).
## Dựng sẵn mọi thẻ một lần, mỗi frame chỉ đổi ảnh / chữ / thanh.

const WIDTH := 84.0
const AVATAR_SIZE := 32.0
const BAR_HEIGHT := 6.0
const CARD_BG := Color("4a2e20") ## Trùng PauseMenu.PANEL_BG.
const CARD_BORDER := Color("a8764a") ## Trùng PauseMenu.PANEL_BORDER.
const TEXT_COLOR := Color("f3e2c0")

var _cards: Array[Dictionary] = [] ## Mỗi thẻ: {card, avatar, count, fill}


## Dựng cột với `slots` thẻ (bằng số nhóm tối đa được đứng chờ).
func _init(slots: int) -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 10)
	for i in slots:
		_cards.append(_make_card())


## Cập nhật thẻ theo hàng đợi của SellPhase ({size, looks, wait}); `queue_wait` là kiên nhẫn đầy.
func refresh(groups: Array[Dictionary], queue_wait: float) -> void:
	for i in _cards.size():
		var card := _cards[i]
		(card["card"] as Control).visible = i < groups.size()
		if i >= groups.size():
			continue
		var group := groups[i]
		(card["avatar"] as TextureRect).texture = (group["looks"] as Array)[0]
		(card["count"] as Label).text = "x%d" % int(group["size"])
		var ratio := clampf(float(group["wait"]) / queue_wait, 0.0, 1.0)
		var fill: ColorRect = card["fill"]
		fill.size.x = (fill.get_parent() as Control).size.x * ratio
		fill.color = TableVisual._patience_color(ratio)


## Một thẻ: hàng trên là ảnh + "xN", hàng dưới là thanh kiên nhẫn.
func _make_card() -> Dictionary:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = CARD_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(column)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(row)
	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(avatar)
	var count := HuntUI.label("", 18, TEXT_COLOR)
	count.size_flags_vertical = SIZE_SHRINK_CENTER
	count.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(count)

	var bar := ColorRect.new()
	bar.color = Color("2b1a14")
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(bar)
	var fill := ColorRect.new()
	fill.size.y = BAR_HEIGHT
	fill.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(fill)
	return {"card": card, "avatar": avatar, "count": count, "fill": fill}
