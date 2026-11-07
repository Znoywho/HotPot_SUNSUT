extends PrepAction
## SCRUB: chà qua lại lên nguyên liệu để sạch các vết bẩn (cọ vỏ nghêu...). Mỗi vết mờ dần theo quãng
## đường ngón tay chà qua nó; sạch hết là xong. Chà mạnh tay quá (thanh "Lực chà" đỏ) bị trừ điểm.
## step.count = số vết bẩn thêm (tổng = 4 + count).

const SPOT_R := 24.0
const CLEAN_DIST := 240.0 ## px phải chà qua 1 vết cho sạch (nhân độ khó).
const METER := Rect2(600, 112, 160, 16)
const DIRT := Color(0.33, 0.23, 0.13)
const DIRT_DARK := Color(0.2, 0.13, 0.07)

var _spots: Array = [] ## [{pos: Vector2, dirt: float 1..0, seed: int}]
var _rubbing := false
var _last := Vector2.ZERO
var _last_us := 0
var _speed := 0.0
var _max_speed := 2400.0
var _cool := 0.0
var _foam := 0.0
var _stream: TextureRect
var _hand: TextureRect


func _build() -> void:
	_max_speed = cfg.pull_max_speed * 3.5 / difficulty
	if step.prop == "sink":
		_stream = faucet(Vector2(item_center.x - 80, 36), item_center.y - 10)
	caption("Lực chà", METER.position + Vector2(0, -28), 18, Color.WHITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(item_id + step.title)
	var half := item.size / 2.0 - Vector2(14, 14)
	var tries := 0
	while _spots.size() < 4 + step.count and tries < 300:
		tries += 1
		var p := item_center + Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y))
		if tries < 250 and not opaque_at(p):
			continue
		var ok := true
		for s in _spots:
			if (s.pos as Vector2).distance_to(p) < SPOT_R * 1.5:
				ok = false
				break
		if ok:
			_spots.append({"pos": p, "dirt": 1.0, "seed": rng.randi()})
	if not _spots.is_empty():
		_hand = pointer(_spots[0].pos + Vector2(-50, 0), "swipe", Vector2.RIGHT)


func _process(delta: float) -> void:
	super(delta)
	_cool -= delta
	if not _rubbing:
		_speed = maxf(0.0, _speed - delta * _max_speed * 3.0)
	redraw()


func _gui_input(event: InputEvent) -> void:
	if is_done():
		return
	if is_press(event):
		_rubbing = true
		_last = (event as InputEventMouseButton).position
		_last_us = Time.get_ticks_usec()
		_speed = 0.0
		if _hand != null:
			_hand.queue_free()
			_hand = null
		accept_event()
	elif event is InputEventMouseMotion and _rubbing:
		_rub((event as InputEventMouseMotion).position)
		accept_event()
	elif is_release(event) and _rubbing:
		_rubbing = false
		item.rotation = 0.0
		accept_event()


func _rub(p: Vector2) -> void:
	var now := Time.get_ticks_usec()
	var dt := maxf(1.0 / 120.0, float(now - _last_us) / 1000000.0)
	_last_us = now
	var moved := p.distance_to(_last)
	_speed = lerpf(_speed, moved / dt, 0.5)
	if _speed > _max_speed:
		if _cool <= 0.0:
			_cool = 0.8
			mistake(p + Vector2(-60, -60), "Mạnh tay quá!")
		_last = p
		return
	for s in _spots:
		if s.dirt <= 0.0:
			continue
		var near := Geometry2D.get_closest_point_to_segment(s.pos, _last, p)
		if near.distance_to(s.pos) <= SPOT_R + 12.0:
			s.dirt = maxf(0.0, s.dirt - moved / (CLEAN_DIST * difficulty))
			if s.dirt <= 0.0:
				burst(kit("bubble"), s.pos, 4, 3.0, 36.0)
				pop_text("Sạch!", s.pos + Vector2(-24, -50), Color("e3f2fd"), 20)
	_foam += moved
	if _foam > 45.0:
		_foam = 0.0
		burst(kit("bubble"), p, 1, 2.0, 26.0)
	item.rotation = sin(_clock * 30.0) * 0.03
	_last = p
	if _spots.all(func(s): return s.dirt <= 0.0):
		_rubbing = false
		item.rotation = 0.0
		good(item_center + Vector2(-60, -120), "Sạch bong!", "splash")
		complete_soon(0.5)


func _paint(c: CanvasItem) -> void:
	# Vết bẩn: cụm ô vuông nhỏ (hợp pixel art), mờ và co lại dần khi chà.
	for s in _spots:
		var a: float = s.dirt
		if a <= 0.0:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = s.seed
		var r := SPOT_R * (0.55 + 0.45 * a)
		for k in 9:
			var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * r * 0.7
			var sz := rng.randf_range(8.0, 14.0) * (0.5 + 0.5 * a)
			var col := DIRT_DARK if k % 3 == 0 else DIRT
			c.draw_rect(Rect2(s.pos + off - Vector2(sz, sz) / 2.0, Vector2(sz, sz)).abs(), Color(col, 0.85 * a))
	# Thanh lực chà: xanh -> đỏ khi quá mạnh tay.
	var ratio := clampf(_speed / _max_speed, 0.0, 1.0)
	c.draw_rect(METER.grow(3), Color("2b1a14"))
	c.draw_rect(METER, Color("1e2a33"))
	c.draw_rect(Rect2(METER.position, Vector2(METER.size.x * ratio, METER.size.y)), Color("66bb6a").lerp(Color("e53935"), ratio))
