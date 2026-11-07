class_name PrepChopGame
extends PrepGame
## Thái (thịt bò, ớt...): chạm liên tục vào thớt hoặc nút THÁI! — mỗi phần cần vài nhát dao.

var _taps := 0
var _board: TextureRect
var _slab: TextureRect
var _knife: TextureRect
var _knife_home := Vector2.ZERO
var _slices: Array[TextureRect] = [] ## Miếng vừa thái của phần đang làm.
var _knife_tween: Tween


func title() -> String:
	return "THÁI " + item_name().to_upper()


func hint() -> String:
	return "Chạm liên tục vào thớt (hoặc nút THÁI!) để thái. Mỗi phần %d nhát." % cfg.chop_taps_per_unit


func partial() -> float:
	return float(_taps) / float(cfg.chop_taps_per_unit)


func status_text() -> String:
	return "Tiến độ thái: %d%% · Xong %d/%d phần" % [roundi(progress() * 100.0), done, units]


func _build() -> void:
	_board = sprite(kit("board_big"), 4.0, Vector2(24, 92))
	var beef := base_id() == "beef"
	_slab = sprite(kit("beef_slab") if beef else icon(), 4.0 if beef else 3.0, Vector2.ZERO)
	_slab.position = Vector2(52, _board.position.y + 70 - _slab.size.y / 2.0)
	_slab.pivot_offset = Vector2(0, _slab.size.y / 2.0)
	_knife = sprite(kit("knife_big"), 4.0, Vector2.ZERO)
	_knife_home = Vector2(_slab.position.x + _slab.size.x - 34, _slab.position.y - 46)
	_knife.position = _knife_home
	_knife.pivot_offset = Vector2(124, 20)
	caption("Đã thái:", Vector2(330, 52), 18, HuntUI.RUST)
	var button := HuntUI.button("THÁI!", 170)
	button.position = Vector2(596, 140)
	button.size = Vector2(170, 76)
	button.add_theme_font_size_override("font_size", 28)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, HuntUI.BAD)
	button.pressed.connect(_chop)
	add_child(button)
	caption("Nhấn liên tục để thái!", Vector2(584, 228), 18, HuntUI.INK_SOFT)


func _gui_input(event: InputEvent) -> void:
	if is_press(event) and hit(_board, (event as InputEventMouseButton).position, 8.0):
		_chop()
		accept_event()


func _chop() -> void:
	if is_finished():
		return
	_taps += 1
	# Dao chặt xuống rồi nhấc lên.
	if _knife_tween != null and _knife_tween.is_running():
		_knife_tween.kill()
	_knife.rotation = 0.0
	_knife.position = _knife_home
	_knife_tween = create_tween()
	_knife_tween.tween_property(_knife, "rotation", 0.42, 0.05)
	_knife_tween.parallel().tween_property(_knife, "position:y", _knife_home.y + 14, 0.05)
	_knife_tween.tween_property(_knife, "rotation", 0.0, 0.12)
	_knife_tween.parallel().tween_property(_knife, "position:y", _knife_home.y, 0.12)
	# Miếng thái rơi xuống thớt.
	var beef := base_id() == "beef"
	var slice_tex := kit("beef_slice") if beef else kit("chili_ring")
	var edge := Vector2(_slab.position.x + _slab.size.x * _slab.scale.x - 10, _slab.position.y + _slab.size.y / 2.0)
	var piece := sprite(slice_tex, 3.0, edge - slice_tex.get_size() * 1.5)
	var land := Vector2(196 + (_taps % 4) * 18 + randf_range(-4, 4), _board.position.y + 40 + (_taps % 3) * 22)
	move_sprite(piece, land, Vector2.ZERO, 0.18)
	_slices.append(piece)
	_slab.scale.x = maxf(0.45, 1.0 - 0.08 * _taps)
	pop_text(["Chặt!", "Xoẹt!", "Xoành!", "Phập!"][randi() % 4], _knife_home + Vector2(randf_range(-10, 60), -20), Color.WHITE, 24)
	sfx("slice", -10.0)
	if _taps >= cfg.chop_taps_per_unit:
		_taps = 0
		_complete_portion(slice_tex)


func _complete_portion(slice_tex: Texture2D) -> void:
	var k := done
	var target := Vector2(336 + (k % 3) * 82, 84 + (k / 3) * 70)
	for i in _slices.size():
		var s := _slices[i]
		move_sprite(s, target + Vector2(i * 4, -i * 3), Vector2.ZERO, 0.28)
	_slices.clear()
	_slab.scale = Vector2(0.6, 1.0)
	create_tween().tween_property(_slab, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_text("+1 phần", target + Vector2(0, -26), HuntUI.GOLD, 22)
	_finish_unit()
