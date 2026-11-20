class_name WaitingBoard
extends PanelContainer
## Bảng "Khách đang chờ" cạnh phải sàn quán: chỉ để nhìn, không chạm được.
## - Nhóm đang đứng chờ xếp bàn: ảnh người đầu nhóm + số người + thanh kiên nhẫn đổi màu xanh -> đỏ.
## - Số bàn đang chờ món / đang ăn.
## Mỗi hàng nhóm dựng sẵn một lần, mỗi frame chỉ cập nhật chữ và thanh (không tạo node mới).
## shortcut: một cột cho tầng 1; khi có tầng 2 thì thêm một bảng thứ hai hoặc tiêu đề tầng vào cùng cột này.

const WIDTH := 236.0
const BAR_WIDTH := 124.0
const BAR_HEIGHT := 12.0
const AVATAR_SIZE := 44.0
const SPECIAL_TEXT := {"critic": "Nhà phê bình", "michelin": "Khách lạ"}
const SPECIAL_COLOR := {"critic": Color("6a3d9a"), "michelin": Color("8a6d3b")}

var _rows: Array[Dictionary] = [] ## Mỗi hàng: {box, avatar, name, fill}
var _empty_label: Label
var _status_label: Label


## Dựng khung bảng với `slots` hàng nhóm chờ (bằng số nhóm tối đa được đứng chờ).
func _init(slots: int) -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", HuntUI.paper_style("paper_panel", 8, Vector2(16, 12)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(column)

	var title := HuntUI.label("KHÁCH ĐANG CHỜ", 18, HuntUI.RUST)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_empty_label = HuntUI.label("Chưa có khách chờ", 18, HuntUI.INK_SOFT)
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_empty_label)
	for i in slots:
		_rows.append(_make_group_row(column))
	var line := ColorRect.new()
	line.color = HuntUI.INK_SOFT
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(line)
	_status_label = HuntUI.label("", 18, HuntUI.INK)
	column.add_child(_status_label)


## Cập nhật bảng: `groups` là hàng đợi của SellPhase ({size, looks, special, wait}), `queue_wait` là kiên nhẫn đầy.
func refresh(groups: Array[Dictionary], queue_wait: float, tables_waiting_food: int, tables_eating: int) -> void:
	_empty_label.visible = groups.is_empty()
	for i in _rows.size():
		var row := _rows[i]
		(row["box"] as Control).visible = i < groups.size()
		if i >= groups.size():
			continue
		var group := groups[i]
		var special: String = group["special"]
		var name_label: Label = row["name"]
		name_label.text = SPECIAL_TEXT.get(special, "Nhóm %d người" % int(group["size"]))
		name_label.add_theme_color_override("font_color", SPECIAL_COLOR.get(special, HuntUI.INK))
		(row["avatar"] as TextureRect).texture = (group["looks"] as Array)[0]
		var ratio := clampf(float(group["wait"]) / queue_wait, 0.0, 1.0)
		var fill: ColorRect = row["fill"]
		fill.size.x = (BAR_WIDTH - 4.0) * ratio
		fill.color = TableVisual._patience_color(ratio)
	_status_label.text = "Chờ món: %d bàn\nĐang ăn: %d bàn" % [tables_waiting_food, tables_eating]


## Một hàng nhóm chờ: ảnh người đầu nhóm bên trái; bên phải là tên nhóm và thanh kiên nhẫn.
func _make_group_row(parent: Control) -> Dictionary:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(avatar)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	side.size_flags_vertical = SIZE_SHRINK_CENTER
	side.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(side)
	var name_label := HuntUI.label("", 18, HuntUI.INK)
	side.add_child(name_label)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	side.add_child(bar)
	var back := ColorRect.new()
	back.color = Color("3b2416")
	back.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	back.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(back)
	var fill := ColorRect.new()
	fill.position = Vector2(2, 2)
	fill.size = Vector2(BAR_WIDTH - 4.0, BAR_HEIGHT - 4.0)
	fill.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(fill)
	return {"box": box, "avatar": avatar, "name": name_label, "fill": fill}
