class_name PrepPeelGame
extends PrepGame
## Bóc vỏ (tôm): nhấn và giữ vào con tôm trên thớt, vòng tròn đầy là bóc xong.

var _tray: TextureRect
var _board: TextureRect
var _queue: Array[TextureRect] = []
var _current: TextureRect = null
var _holding := false
var _hold := 0.0
var _bits_t := 0.0


func title() -> String:
	return "BÓC VỎ VÀ SƠ CHẾ " + item_name().to_upper()


func hint() -> String:
	return "Nhấn và giữ vào con tôm trên thớt để bóc vỏ (thả tay thì vòng tụt dần)."


func partial() -> float:
	return _hold


func status_text() -> String:
	return "Tiến độ: %d/%d con · Đang bóc %d%%" % [done, units, roundi(_hold * 100.0)]


func _build() -> void:
	_tray = sprite(kit("tray"), 3.0, Vector2(8, 168))
	for i in units:
		_queue.append(sprite(icon(), 2.0, Vector2(18 + i * 36, 160)))
	_board = sprite(kit("board_big"), 4.0, Vector2(290, 112))
	caption("Nhấn và giữ để bóc vỏ!", Vector2(330, 268), 18, HuntUI.INK_SOFT)
	caption("Đã bóc:", Vector2(604, 56), 18, HuntUI.RUST)
	_next()


func _next() -> void:
	if _current != null or _queue.is_empty() or is_finished():
		return
	_current = _queue.pop_front()
	move_child(_current, -1) # Nằm trên thớt.
	move_sprite(_current, Vector2(_board.position.x + 140 - 64, _board.position.y + 70 - 72), Vector2(128, 128), 0.25)


func _process(delta: float) -> void:
	if _current == null:
		return
	if _holding:
		_hold += delta / cfg.peel_hold_seconds
		_bits_t += delta
		if _bits_t >= 0.12:
			_bits_t = 0.0
			burst(kit("shell_bit"), _current.position + _current.size / 2.0, 2, 4.0, 74.0)
		if _hold >= 1.0:
			_peel_done()
	else:
		_hold = maxf(0.0, _hold - delta * 0.6)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if is_press(event) and _current != null and hit(_current, (event as InputEventMouseButton).position, 24.0):
		_holding = true
		accept_event()
	elif is_release(event):
		_holding = false


func _peel_done() -> void:
	_holding = false
	_hold = 0.0
	var c := _current
	_current = null
	c.texture = kit("shrimp_peeled")
	c.size = Vector2(26, 18) * 4.0
	c.position += Vector2(12, 28)
	var k := done
	move_sprite(c, Vector2(604 + (k % 2) * 84, 90 + (k / 2) * 46), Vector2(52, 36), 0.3)
	pop_text("Bóc xong!", Vector2(380, 100), HuntUI.GOLD, 24)
	sfx("loot", -14.0)
	_finish_unit()
	queue_redraw()
	get_tree().create_timer(0.3).timeout.connect(_next)


func _draw() -> void:
	if _current == null:
		return
	var center := _current.position + _current.size / 2.0
	draw_arc(center, 84.0, 0.0, TAU, 48, Color(0, 0, 0, 0.25), 8.0)
	if _hold > 0.0:
		draw_arc(center, 84.0, -PI / 2.0, -PI / 2.0 + TAU * _hold, 48, Color("ffd54f"), 8.0)
