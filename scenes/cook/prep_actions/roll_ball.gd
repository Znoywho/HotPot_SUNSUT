extends PrepAction
## ROLL_BALL: vo viên. Xoay ngón tay thành vòng tròn quanh nắm thịt tới khi viên tròn đều (vòng vàng đầy);
## viên xong lăn sang hàng bên trái rồi tới nắm tiếp theo. Xoay nhanh quá thì thịt nát: bị trừ điểm,
## mất bớt tiến độ. step.count = số viên.

const LUMP_R := 46.0
const BALL_R := 26.0
const TURNS := 2.0 ## Số vòng phải xoay mỗi viên (nhân độ khó).
const METER := Rect2(600, 112, 160, 16)

var _i := 0
var _angle := 0.0
var _prev := 0.0
var _rolling := false
var _spin := 0.0
var _last_us := 0
var _speed := 0.0
var _max_speed := 2400.0
var _cool := 0.0
var _balls: Array[Vector2] = [] ## Viên đã vo xong (vị trí hiện tại, có thể đang lăn).
var _hand: TextureRect


func _build() -> void:
	item.visible = false
	_max_speed = cfg.pull_max_speed * 2.2 / difficulty
	caption("Lực tay", METER.position + Vector2(0, -28), 18, Color.WHITE)
	_hand = pointer(item_center + Vector2(10, -6), "circle")


func _progress() -> float:
	return clampf(_angle / (TAU * TURNS * difficulty), 0.0, 1.0)


func _tray_pos(k: int) -> Vector2:
	return Vector2(70 + k * 62, 236)


func _process(delta: float) -> void:
	super(delta)
	_cool -= delta
	if not _rolling:
		_speed = maxf(0.0, _speed - delta * _max_speed * 3.0)
	redraw()


func _gui_input(event: InputEvent) -> void:
	if is_done() or _i >= step.count:
		return
	if is_press(event):
		var p := (event as InputEventMouseButton).position
		if p.distance_to(item_center) <= LUMP_R + 80.0:
			_rolling = true
			_prev = (p - item_center).angle()
			_last_us = Time.get_ticks_usec()
			_speed = 0.0
			if _hand != null:
				_hand.queue_free()
				_hand = null
		accept_event()
	elif event is InputEventMouseMotion and _rolling:
		var m := event as InputEventMouseMotion
		var now := Time.get_ticks_usec()
		var dt := maxf(1.0 / 120.0, float(now - _last_us) / 1000000.0)
		_last_us = now
		_speed = lerpf(_speed, m.relative.length() / dt, 0.5)
		var v := m.position - item_center
		if v.length() >= 10.0:
			var a := v.angle()
			var d := wrapf(a - _prev, -PI, PI)
			_prev = a
			if _speed > _max_speed:
				if _cool <= 0.0:
					_cool = 0.8
					mistake(item_center + Vector2(-50, -100), "Nát rồi!")
					_angle = maxf(0.0, _angle - TAU)
			else:
				_angle += absf(d)
				_spin += d
				if _progress() >= 1.0:
					_finish_ball()
		accept_event()
	elif is_release(event) and _rolling:
		_rolling = false
		accept_event()


func _finish_ball() -> void:
	_rolling = false
	good(item_center + Vector2(-50, -100), "Tròn đẹp!", "slice")
	var k := _balls.size()
	_balls.append(item_center)
	create_tween().tween_method(func(p: Vector2): _balls[k] = p, item_center, _tray_pos(k), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_i += 1
	_angle = 0.0
	_spin = 0.0
	if _i >= step.count:
		complete_soon(0.5)


## Sang bước sau (xiên) không dùng lại hình này: trả về ảnh gốc.
func result_texture() -> Texture2D:
	return null


func _paint(c: CanvasItem) -> void:
	for k in _balls.size():
		draw_meatball(c, _balls[k], BALL_R, 0.0, k, k * 1.3)
	if _i < step.count:
		var t := _progress()
		var r := lerpf(LUMP_R, BALL_R * 1.1, t)
		draw_meatball(c, item_center, r, 1.0 - t, 100 + _i, _spin)
		c.draw_arc(item_center, LUMP_R + 18.0, -PI / 2.0, -PI / 2.0 + TAU, 48, Color(0, 0, 0, 0.35), 8.0)
		if t > 0.0:
			c.draw_arc(item_center, LUMP_R + 18.0, -PI / 2.0, -PI / 2.0 + TAU * t, 48, HuntUI.GOLD, 6.0)
	var ratio := clampf(_speed / _max_speed, 0.0, 1.0)
	c.draw_rect(METER.grow(3), Color("2b1a14"))
	c.draw_rect(METER, Color("1e2a33"))
	c.draw_rect(Rect2(METER.position, Vector2(METER.size.x * ratio, METER.size.y)), Color("66bb6a").lerp(Color("e53935"), ratio))
