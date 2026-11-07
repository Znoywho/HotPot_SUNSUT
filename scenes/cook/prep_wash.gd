class_name PrepWashGame
extends PrepGame
## Rửa rồi cắt (cà chua, rau): chạm từng quả trong bồn để rửa sạch, rồi vuốt ngang trên thớt để cắt.

var _sink: TextureRect
var _board: TextureRect
var _dirty: Array[TextureRect] = []
var _scrubs: Array[int] = []
var _queue: Array[TextureRect] = [] ## Đã rửa, chờ cắt.
var _current: TextureRect = null
var _washed := 0
var _swiping := false
var _swipe_from := Vector2.ZERO
var _swipe_to := Vector2.ZERO
var _t := 0.0


func title() -> String:
	return "RỬA VÀ CẮT " + item_name().to_upper()


func hint() -> String:
	return "1. Chạm từng quả trong bồn để rửa (%d lần).  2. Vuốt ngang trên thớt để cắt." % cfg.wash_taps_per_unit


func partial() -> float:
	if _current != null or not _queue.is_empty():
		return 0.5
	var best := 0
	for s in _scrubs:
		best = maxi(best, s)
	return 0.5 * float(best) / float(cfg.wash_taps_per_unit)


func status_text() -> String:
	return "Đã rửa %d/%d · Đã cắt %d/%d" % [_washed, units, done, units]


func _build() -> void:
	_sink = sprite(kit("sink_big"), 3.0, Vector2(8, 96))
	var dirty := dirty_icon()
	for i in units:
		var r := sprite(dirty, 2.0, Vector2(30 + (i % 3) * 66, 124 + (i / 3) * 38))
		r.set_meta("home_y", r.position.y)
		_dirty.append(r)
		_scrubs.append(0)
	_board = sprite(kit("board_big"), 4.0, Vector2(290, 112))
	caption("1. Chạm để rửa", Vector2(60, 248), 18, HuntUI.INK_SOFT)
	caption("2. Vuốt để cắt »", Vector2(352, 270), 18, HuntUI.INK_SOFT)
	caption("Đã cắt:", Vector2(600, 56), 18, HuntUI.RUST)


func _process(delta: float) -> void:
	_t += delta
	for i in _dirty.size():
		var r := _dirty[i]
		r.position.y = float(r.get_meta("home_y")) + sin(_t * 3.0 + i) * 2.0


func _gui_input(event: InputEvent) -> void:
	if is_press(event):
		var p := (event as InputEventMouseButton).position
		for i in range(_dirty.size() - 1, -1, -1):
			if hit(_dirty[i], p, 6.0):
				_scrub(i)
				accept_event()
				return
		if _current != null and hit(_board, p, 12.0):
			_swiping = true
			_swipe_from = p
			_swipe_to = p
			accept_event()
	elif is_release(event) and _swiping:
		_swiping = false
		if (_swipe_to - _swipe_from).length() >= cfg.swipe_min_distance:
			_cut()
		queue_redraw()
	elif event is InputEventMouseMotion and _swiping:
		_swipe_to = (event as InputEventMouseMotion).position
		queue_redraw()


func _scrub(i: int) -> void:
	if is_finished():
		return
	var r := _dirty[i]
	_scrubs[i] += 1
	burst(kit("bubble"), r.position + r.size / 2.0, 4, 3.0, 40.0)
	sfx("splash", -16.0)
	if _scrubs[i] < cfg.wash_taps_per_unit:
		pop_text("Kỳ kỳ!", r.position + Vector2(0, -12), Color("e3f2fd"), 20)
		return
	_dirty.remove_at(i)
	_scrubs.remove_at(i)
	r.texture = icon()
	_washed += 1
	pop_text("Sạch!", r.position + Vector2(0, -12), Color("b3e5fc"), 22)
	_queue.append(r)
	move_child(r, -1)
	_layout_queue()
	_next_current()


func _layout_queue() -> void:
	for k in _queue.size():
		move_sprite(_queue[k], Vector2(296 + k * 34, 52), Vector2(48, 48), 0.25)


func _next_current() -> void:
	if _current != null or _queue.is_empty():
		return
	_current = _queue.pop_front()
	move_child(_current, -1) # Nằm trên thớt.
	move_sprite(_current, Vector2(_board.position.x + 140 - 48, _board.position.y + 70 - 54), Vector2(96, 96), 0.25)
	_layout_queue()


func _cut() -> void:
	if _current == null or is_finished():
		return
	var c := _current
	_current = null
	var tex := kit("tomato_half") if base_id() == "tomato" else kit("greens_cut")
	var center := c.position + c.size / 2.0
	var k := done
	var target := Vector2(604 + (k % 2) * 82, 92 + (k / 2) * 56)
	for side in [-1.0, 1.0]:
		var half := sprite(tex, 3.0, center - tex.get_size() * 1.5)
		var t := half.create_tween()
		t.tween_property(half, "position", half.position + Vector2(side * 26, 4), 0.12)
		t.tween_property(half, "position", target + Vector2((side + 1.0) * 14, 0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	c.queue_free()
	pop_text("Xoẹt!", center + Vector2(-20, -60), Color.WHITE, 26)
	sfx("slice", -10.0)
	_finish_unit()
	_next_current()


func _draw() -> void:
	if _swiping:
		draw_line(_swipe_from, _swipe_to, Color(1, 1, 1, 0.85), 6.0)
		draw_circle(_swipe_to, 6.0, Color(1, 1, 1, 0.9))
