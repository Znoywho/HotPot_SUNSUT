class_name PrepSortGame
extends PrepGame
## Nhặt và rửa (nấm, nấm kim châm): kéo từng cây từ rổ bẩn sang rổ sạch.

var _dirty_basket: TextureRect
var _clean_basket: TextureRect
var _pieces: Array[TextureRect] = []
var _drag: TextureRect = null
var _drag_offset := Vector2.ZERO


func title() -> String:
	return "NHẶT VÀ RỬA " + item_name().to_upper()


func hint() -> String:
	return "Kéo từng cây %s từ rổ bẩn sang rổ sạch." % item_name().to_lower()


func status_text() -> String:
	return "Tiến độ: %d/%d %s" % [done, units, item_name().to_lower()]


func _build() -> void:
	_dirty_basket = sprite(kit("basket_dirty"), 4.0, Vector2(16, 148))
	_clean_basket = sprite(kit("basket_clean"), 4.0, Vector2(530, 148))
	caption("Rổ bẩn", Vector2(100, 272), 18, HuntUI.INK_SOFT)
	caption("Rổ sạch", Vector2(612, 272), 18, HuntUI.GOOD)
	var arrow := HuntUI.outlined_label("»  »  »", 34, HuntUI.GOLD)
	arrow.position = Vector2(318, 178)
	arrow.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(arrow)
	var tex := dirty_icon()
	for i in units:
		var r := sprite(tex, 2.0, Vector2(30 + i * 38, 104 + (i % 2) * 20))
		r.set_meta("origin", r.position)
		_pieces.append(r)


func _gui_input(event: InputEvent) -> void:
	if is_press(event):
		var p := (event as InputEventMouseButton).position
		for i in range(_pieces.size() - 1, -1, -1):
			if hit(_pieces[i], p, 8.0):
				_drag = _pieces[i]
				_drag_offset = p - _drag.position
				move_child(_drag, -1)
				_drag.scale = Vector2(1.12, 1.12)
				accept_event()
				return
	elif event is InputEventMouseMotion and _drag != null:
		_drag.position = (event as InputEventMouseMotion).position - _drag_offset
		accept_event()
	elif is_release(event) and _drag != null:
		var piece := _drag
		_drag = null
		piece.scale = Vector2.ONE
		var zone := Rect2(_clean_basket.position - Vector2(30, 70), _clean_basket.size + Vector2(60, 80))
		if zone.has_point(piece.position + piece.size / 2.0):
			_drop_clean(piece)
		else:
			move_sprite(piece, piece.get_meta("origin"), Vector2.ZERO, 0.2)
		accept_event()


func _drop_clean(piece: TextureRect) -> void:
	_pieces.erase(piece)
	piece.texture = icon()
	var k := done
	move_sprite(piece, Vector2(548 + k * 36, 108 + (k % 2) * 18), Vector2.ZERO, 0.2)
	burst(kit("bubble"), piece.position + piece.size / 2.0, 5, 3.0, 46.0)
	pop_text("Sạch!", piece.position + Vector2(0, -16), Color("b3e5fc"), 22)
	sfx("splash", -14.0)
	_finish_unit()
