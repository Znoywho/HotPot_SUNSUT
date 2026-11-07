extends PrepAction
## SKEWER: xiên que. Các viên xếp hàng trên thớt; vuốt từ đầu que (bên trái) xuyên qua hết các viên theo
## đường chấm. Que đi theo ngón tay; vuốt lệch quá swipe_tolerance hoặc chưa xuyên hết thì bị trừ, vuốt lại.
## Xong thì hiện xiên hoàn chỉnh (hình nguyên liệu). step.count = số viên.

const GAP := 64.0
const BALL_R := 28.0
const STICK_LEN := 330.0
const WOOD := Color("d8b27a")
const WOOD_DARK := Color("5a3a1e")

var _balls: Array[Vector2] = []
var _a := Vector2.ZERO ## Đầu que lúc bắt đầu.
var _b := Vector2.ZERO ## Cuối đường xiên.
var _tip := 0.0 ## 0..1: đầu que đang ở đâu trên đường a -> b.
var _swiping := false
var _path := PackedVector2Array()
var _pierced := 0
var _finished := false
var _hand: TextureRect


func _build() -> void:
	item.visible = false
	var n := maxi(1, step.count)
	for k in n:
		_balls.append(Vector2(item_center.x + 40.0 + (k - (n - 1) / 2.0) * GAP, item_center.y))
	_a = Vector2(_balls[0].x - BALL_R - 70.0, item_center.y)
	_b = Vector2(_balls[n - 1].x + BALL_R + 30.0, item_center.y)
	_hand = pointer(_a + Vector2(-6, 6), "swipe", Vector2.RIGHT)


func _process(delta: float) -> void:
	super(delta)
	redraw()


func _t_of(p: Vector2) -> float:
	var ab := _b - _a
	return clampf((p - _a).dot(ab) / ab.length_squared(), 0.0, 1.0)


func _gui_input(event: InputEvent) -> void:
	if is_done() or _finished:
		return
	if is_press(event):
		var p := (event as InputEventMouseButton).position
		_swiping = true
		_path = PackedVector2Array([p])
		if _hand != null:
			_hand.queue_free()
			_hand = null
		accept_event()
	elif event is InputEventMouseMotion and _swiping:
		var p := (event as InputEventMouseMotion).position
		_path.append(p)
		if absf(p.y - _a.y) <= cfg.swipe_tolerance / difficulty * 1.5:
			_tip = maxf(_tip, _t_of(p))
			_update_pierced()
		accept_event()
	elif is_release(event) and _swiping:
		_swiping = false
		_judge()
		accept_event()


## Đếm viên đầu que đã xuyên qua; viên vừa xuyên nảy nhẹ + "Phập!".
func _update_pierced() -> void:
	var x := _a.lerp(_b, _tip).x
	while _pierced < _balls.size() and x >= _balls[_pierced].x:
		var at := _balls[_pierced]
		pop_text("Phập!", at + Vector2(-26, -70), HuntUI.GOLD, 20)
		sfx("slice", -14.0)
		_pierced += 1


func _judge() -> void:
	if _path.size() < 2:
		return
	var dev := 0.0
	var t_min := 1.0
	for p in _path:
		dev += absf(p.y - _a.y)
		t_min = minf(t_min, _t_of(p))
	dev /= _path.size()
	var ok := dev <= cfg.swipe_tolerance / difficulty and t_min <= 0.2 and _pierced >= _balls.size()
	if ok:
		_finished = true
		var t := create_tween()
		t.tween_method(func(v: float): _tip = v, _tip, 1.0, 0.15)
		t.tween_callback(_show_result)
	else:
		mistake(_path[_path.size() - 1] + Vector2(-40, -60), "Lệch que!" if dev > cfg.swipe_tolerance / difficulty else "Chưa xuyên hết!")
		_tip = 0.0
		_pierced = 0


## Thay hàng viên + que vẽ tay bằng hình xiên hoàn chỉnh.
func _show_result() -> void:
	good(item_center + Vector2(-60, -120), "Xiên xong!", "loot")
	item.visible = true
	item.scale = Vector2(0.6, 0.6)
	item.create_tween().tween_property(item, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_balls.clear()
	complete_soon(0.6)


func result_texture() -> Texture2D:
	return HuntUI.ingredient_texture(item_id)


func _paint(c: CanvasItem) -> void:
	if _balls.is_empty():
		return
	if not _finished:
		dashed(c, _a, _b, Color(0, 0, 0, 0.4), 8.0, 12.0)
		dashed(c, _a, _b, Color.WHITE, 4.0, 12.0)
	# Que vẽ trước để nằm "trong" các viên.
	var tip := _a.lerp(_b, _tip)
	var tail := tip - Vector2(STICK_LEN, 0)
	c.draw_line(tail, tip, WOOD_DARK, 12.0)
	c.draw_line(tail, tip, WOOD, 6.0)
	c.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -6), tip + Vector2(16, 0), tip + Vector2(0, 6)]), WOOD_DARK)
	for k in _balls.size():
		var hop := -6.0 if k < _pierced else 0.0
		draw_meatball(c, _balls[k] + Vector2(0, hop), BALL_R, 0.0, k, k * 1.3)
