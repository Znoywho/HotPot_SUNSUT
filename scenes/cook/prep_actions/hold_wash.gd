extends PrepAction
## HOLD_WASH: giữ ngón tay để rửa / ngâm. Kim chạy dần lên; thả tay khi kim nằm trong vùng xanh.
## Thả sớm: chưa sạch, giữ tiếp (không trừ). Giữ quá vùng xanh: "Quá lâu!" bị trừ điểm và bước kết thúc.

const BAR := Rect2(190, 270, 400, 18)

var _fill := 0.0
var _zone := 0.35
var _holding := false
var _stream: TextureRect
var _hand: TextureRect
var _bubble_t := 0.0


func _build() -> void:
	_zone = cfg.hold_zone / difficulty
	if step.prop == "sink":
		_stream = faucet(Vector2(item_center.x - 80, 36), item_center.y - 10)
		_stream.visible = false
	item.texture = dirty_tex()
	caption("Giữ để rửa, thả ở vùng xanh", Vector2(BAR.position.x + 40, BAR.position.y - 30), 18, Color.WHITE)
	_hand = pointer(item_center + Vector2(10, -10), "hold")


func _max_fill() -> float:
	return 1.0 + _zone + 0.3


func _process(delta: float) -> void:
	super(delta)
	if is_done():
		return
	if _holding:
		_fill += delta / maxf(0.2, step.duration)
		_bubble_t += delta
		item.rotation = sin(_clock * 28.0) * 0.05
		if _bubble_t >= 0.12:
			_bubble_t = 0.0
			burst(kit("bubble"), item_center + Vector2(randf_range(-50, 50), randf_range(-20, 30)), 2, 3.0, 40.0)
		if _fill > 1.0 + _zone:
			_set_holding(false)
			mistake(item_center + Vector2(-60, -110), "Quá lâu!")
			item.texture = icon_tex()
			complete_soon(0.5)
	redraw()


func _set_holding(on: bool) -> void:
	_holding = on
	item.rotation = 0.0
	if _stream != null:
		_stream.visible = on
	if on and _hand != null:
		_hand.queue_free()
		_hand = null


func _gui_input(event: InputEvent) -> void:
	if is_done():
		return
	if is_press(event):
		_set_holding(true)
		sfx("splash", -14.0)
		accept_event()
	elif is_release(event) and _holding:
		_set_holding(false)
		if _fill >= 1.0:
			item.texture = icon_tex()
			good(item_center + Vector2(-40, -110), "Sạch bong!", "splash")
			complete_soon(0.45)
		else:
			pop_text("Chưa sạch, giữ tiếp!", item_center + Vector2(-90, -110), Color("e3f2fd"), 20)
		accept_event()


func _x(v: float) -> float:
	return BAR.position.x + BAR.size.x * clampf(v / _max_fill(), 0.0, 1.0)


func _paint(c: CanvasItem) -> void:
	c.draw_rect(BAR.grow(3), Color("2b1a14"))
	c.draw_rect(BAR, Color("1e2a33"))
	c.draw_rect(Rect2(_x(1.0), BAR.position.y, _x(1.0 + _zone) - _x(1.0), BAR.size.y), Color("66bb6a"))
	c.draw_rect(Rect2(BAR.position, Vector2(_x(_fill) - BAR.position.x, BAR.size.y)), Color(0.24, 0.6, 0.91, 0.75))
	var nx := _x(_fill)
	c.draw_line(Vector2(nx, BAR.position.y - 6), Vector2(nx, BAR.end.y + 6), Color.WHITE, 4.0)
