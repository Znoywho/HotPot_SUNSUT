class_name ExpiredPopup
extends Control
## Đầu ngày mới: liệt kê đồ vừa quá hạn sử dụng, mỗi món chọn "Bán tiếp" (rủi ro bị phát hiện) hoặc "Bỏ".
## Hiện khi GameState.newly_expired() không rỗng; tự đóng khi đã quyết hết. Giờ săn tạm dừng trong lúc mở.

signal finished

const POT_ICON := "res://assets/sprites/ui/broth_pot.png"

var _left := 0
var _timer_was_running := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_timer_was_running = DayManager.timer_running
	DayManager.timer_running = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
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
	box.add_child(HuntUI.label("Hết hạn sử dụng!", 28, HuntUI.BAD))
	var note := HuntUI.label("Các món dưới đây đã để quá %d ngày. Bán tiếp thì mỗi nồi có thể bị khách phát hiện (phải bồi thường, trừ sao), thanh tra tới là bị phạt." % GameState.shelf_days(), HuntUI.FONT_SMALL, HuntUI.INK_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(720, 0)
	box.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(740, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var expired := GameState.newly_expired()
	_left = expired.size()
	for e in expired:
		list.add_child(_row(e))
	var all := HBoxContainer.new()
	all.alignment = BoxContainer.ALIGNMENT_CENTER
	all.add_theme_constant_override("separation", 12)
	box.add_child(all)
	var drop_all := HuntUI.button("Bỏ hết", 220)
	drop_all.pressed.connect(func(): _decide_all(expired, false))
	all.add_child(drop_all)
	var keep_all := HuntUI.button("Bán tiếp hết", 220)
	keep_all.pressed.connect(func(): _decide_all(expired, true))
	all.add_child(keep_all)
	HuntUI.book_open(panel)


func _row(e: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon: Texture2D
	var name: String
	if e["kind"] == "item" or e["kind"] == "prepped":
		icon = HuntUI.ingredient_texture(e["id"])
		name = GameState.item_display_name(e["id"]) + (" (đã sơ chế)" if e["kind"] == "prepped" else "")
	else:
		icon = load(POT_ICON) if ResourceLoader.exists(POT_ICON) else null
		var broth := Database.get_broth(e["id"])
		name = "Nồi " + (broth.display_name if broth else str(e["id"]))
	if icon != null:
		row.add_child(HuntUI.texture_rect(icon, 40))
	var l := HuntUI.label("%s x%d (nhập ngày %d)" % [name, e["count"], e["day"]], HuntUI.FONT_SMALL)
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(l)
	var keep := HuntUI.button("Bán tiếp", 150)
	var drop := HuntUI.button("Bỏ", 110)
	keep.pressed.connect(func(): _decide(row, e, true))
	drop.pressed.connect(func(): _decide(row, e, false))
	row.add_child(keep)
	row.add_child(drop)
	return row


func _decide(row: Control, e: Dictionary, keep: bool) -> void:
	if row.has_meta("done"):
		return
	row.set_meta("done", true)
	GameState.resolve_expired(e["kind"], e["id"], e["day"], keep)
	for child in row.get_children():
		if child is Button:
			child.disabled = true
	row.modulate = Color(1, 1, 1, 0.45)
	_left -= 1
	if _left <= 0:
		_close()


func _decide_all(expired: Array[Dictionary], keep: bool) -> void:
	for e in expired:
		GameState.resolve_expired(e["kind"], e["id"], e["day"], keep)
	_close()


func _close() -> void:
	DayManager.timer_running = _timer_was_running
	finished.emit()
	queue_free()
