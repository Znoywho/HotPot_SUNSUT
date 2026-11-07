extends PrepAction
## DRAG_PULL: kéo núm (bộ phận cần gỡ: vỏ, chỉ lưng, đầu mực...) theo mũi tên cho tới cuối đường chấm.
## Kéo nhanh quá giới hạn (thanh "Lực kéo" chuyển đỏ) thì đứt: bị trừ điểm và kéo lại từ đầu.
## Bộ phận đang kéo (lá, vỏ, đầu mực, chỉ lưng...) là mảnh tách từ chính ảnh nguyên liệu, đi theo núm
## và rơi xuống khi kéo ra xong (xem PrepAction.removal_mode()).

const PEEL_FLESH := Color(1.0, 0.88, 0.76, 0.45) ## Chỗ vừa lột vỏ sáng lên màu thịt.
## Bộ phận không nằm theo hướng kéo: "nguyên liệu/tên bước" -> vùng của khung bao hình (0..1).
const PART_REGION := {
	"squid/Tách đầu khỏi thân": Rect2(0, 0.62, 1, 0.38), # Đầu + râu ở phía dưới.
}

const DIRS := [Vector2(1, 0), Vector2(0.71, -0.71), Vector2(-1, 0), Vector2(-0.71, -0.71)]
## Lột vỏ / da: bẩy mép vỏ lên trên (vỏ lật lên quanh mép như cái nắp rồi mới rời ra).
const PEEL_DIRS := [Vector2(0.71, -0.71), Vector2(-0.71, -0.71), Vector2(0, -1)]
## Cạy vỏ: lòng vỏ (xà cừ) + miếng thịt (vẽ tay theo hình dáng nguyên liệu).
const SHELL_IN := Color("f4ecdd")
const SHELL_IN_DEEP := Color("cbbca4")
const MEAT := Color("f2b98c")
const MEAT_EDGE := Color("c27a52")
const MEAT_SHINE := Color("ffe2c6")
const KNOB_R := 30.0
const METER := Rect2(600, 112, 160, 16)

var _i := 0
var _dir := Vector2.RIGHT
var _home := Vector2.ZERO
var _knob := Vector2.ZERO
var _dragging := false
var _speed := 0.0
var _last_us := 0
var _max_speed := 1000.0
var _hand: TextureRect
var _part: TextureRect ## Bộ phận đang bị kéo ra.
var _part_base := Vector2.ZERO
var _peel := false
var _hinge_side := 1.0 ## Mảnh vỏ nằm bên phải (+1) hay trái (-1) bản lề.


func _build() -> void:
	_max_speed = cfg.pull_max_speed / difficulty
	caption("Lực kéo", METER.position + Vector2(0, -28), 18, Color.WHITE)
	_start_pull()


## Quãng kéo: kéo thẳng lên thì ngắn hơn để núm không ra khỏi khung.
func _dist() -> float:
	return cfg.pull_distance * (0.72 if _dir.y < -0.9 else 1.0)


func _start_pull() -> void:
	var mode := removal_mode()
	_peel = mode == "peel" or mode == "pry"
	var dirs: Array = [Vector2(0, -1)] if mode == "pry" else (PEEL_DIRS if _peel else DIRS)
	_dir = dirs[_i % dirs.size()]
	_home = item_center + _dir * 44.0
	_knob = _home
	if _hand != null:
		_hand.queue_free()
	_hand = pointer(_home + Vector2(-6, 0), "swipe", _dir) if _i == 0 else null
	_part = _make_part()
	if _part != null:
		_part_base = _part.position
		if mode == "pry":
			# Bản lề nắp vỏ ở mép trái phía dưới: nắp lật lên từ bên phải.
			_part.pivot_offset = Vector2(0, _part.size.y * 0.85)
			_hinge_side = 1.0
		elif _peel:
			# Bản lề = điểm của mảnh gần tâm nguyên liệu nhất.
			var body := _item_home + _body_center * _px
			_part.pivot_offset = (body - _part.position).clamp(Vector2.ZERO, _part.size)
			_hinge_side = signf(_part.size.x / 2.0 - _part.pivot_offset.x)
			if _hinge_side == 0.0:
				_hinge_side = 1.0 if _dir.x >= 0.0 else -1.0


func _make_part() -> TextureRect:
	match removal_mode():
		"carve", "split":
			var key := item_id.trim_prefix(GameState.GOLDEN_PREFIX) + "/" + step.title
			if PART_REGION.has(key):
				return carve(body_part(PART_REGION[key]))
			if step.title.to_lower().begins_with("bóc"):
				# Bóc lá ngoài: chỉ lớp viền ngoài cùng ở phía đang kéo, không khoét vào lõi.
				var wd := wedge(_dir, 0.9, 0.0)
				var band := edge_band(3)
				return carve(func(p: Vector2) -> bool: return wd.call(p) and band.call(p))
			return carve(wedge(_dir, 1.0 if step.count == 1 else 0.6))
		"peel":
			var w := wedge(_dir, 0.9)
			# Không lột phần cuống/lá xanh.
			return carve(func(p: Vector2) -> bool:
				var c := _img.get_pixelv(Vector2i(p.floor()))
				return w.call(p) and not (c.g > c.r and c.g > c.b), false, PEEL_FLESH)
		"strand":
			return _make_strand()
		"pry":
			return _make_lid()
	return null


## Nắp vỏ = bản sao cả con nghêu; bên dưới thay bằng nửa vỏ đã mở có miếng thịt.
func _make_lid() -> TextureRect:
	var lid := carve(func(_p: Vector2) -> bool: return true, false)
	if lid == null:
		return null
	_img = _open_shell(_img)
	item.texture = ImageTexture.create_from_image(_img)
	return lid


## Vẽ nửa vỏ mở theo đúng dáng hình gốc: viền giữ màu vỏ (sẫm hơn), lòng vỏ sáng màu xà cừ,
## giữa là miếng thịt tròn có viền sẫm và vệt bóng.
func _open_shell(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var half := _body_rect.size / 2.0
	var meat_c := _body_center + Vector2(0, half.y * 0.12)
	var meat_r := Vector2(half.x * 0.5, half.y * 0.42)
	var golden := item_id.begins_with(GameState.GOLDEN_PREFIX)
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a <= 0.5:
				continue
			var edge := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or src.get_pixelv(q).a <= 0.5:
					edge = true
					break
			var p := Vector2(x + 0.5, y + 0.5)
			var col: Color
			if edge:
				col = c.darkened(0.25)
			else:
				var dn := ((p - _body_center) / half).length()
				col = SHELL_IN.lerp(SHELL_IN_DEEP, clampf(dn, 0.0, 1.0))
				var e := ((p - meat_c) / meat_r).length()
				if e <= 1.0:
					col = MEAT_EDGE if e > 0.78 else MEAT
					if e < 0.4 and p.x < meat_c.x and p.y < meat_c.y:
						col = MEAT_SHINE
					if golden:
						col = col.lerp(Color("ffd54f"), 0.35)
			out.set_pixel(x, y, Color(col, c.a))
	return out


## Sợi chỉ lưng tôm (sẫm) / xương mực (trong) chạy ngang thân, kéo ra theo hướng kéo.
func _make_strand() -> TextureRect:
	if not _ensure_img():
		return null
	var n := int(_img.get_width() * 0.7)
	var img := Image.create(n, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color("4a2a1a") if "chỉ" in step.title.to_lower() else Color(0.95, 0.95, 0.88, 0.9))
	var r := sprite(ImageTexture.create_from_image(img), _px, Vector2.ZERO)
	r.z_index = 2
	r.position = item_center + Vector2(0, -item.size.y * 0.1) - r.size / 2.0
	r.pivot_offset = r.size / 2.0
	return r


func _process(delta: float) -> void:
	super(delta)
	if not _dragging:
		_speed = maxf(0.0, _speed - delta * _max_speed * 3.0)
	if _part != null:
		var t := clampf((_knob - _home).length() / maxf(1.0, _dist()), 0.0, 1.0)
		if _peel:
			# Nửa đầu: vỏ lật lên quanh bản lề; nửa sau: bong hẳn và đi theo núm.
			_part.rotation = -_hinge_side * minf(1.0, t * 1.8) * 1.1
			_part.position = _part_base + (_knob - _home) * maxf(0.0, t - 0.45) / 0.55
		else:
			_part.position = _part_base + (_knob - _home)
			_part.rotation = t * 0.25 * (1.0 if _dir.x >= 0.0 else -1.0)
	redraw()


func _gui_input(event: InputEvent) -> void:
	if is_done():
		return
	if is_press(event):
		var p := (event as InputEventMouseButton).position
		if p.distance_to(_knob) <= KNOB_R + 18.0:
			_dragging = true
			_speed = 0.0
			_last_us = Time.get_ticks_usec()
			if _hand != null:
				_hand.queue_free()
				_hand = null
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var m := event as InputEventMouseMotion
		var now := Time.get_ticks_usec()
		var dt := maxf(1.0 / 120.0, float(now - _last_us) / 1000000.0)
		_last_us = now
		_speed = lerpf(_speed, m.relative.length() / dt, 0.5)
		var along := clampf((m.position - _home).dot(_dir), 0.0, _dist() + 10.0)
		_knob = _home + _dir * along
		if _speed > _max_speed:
			_dragging = false
			mistake(_knob + Vector2(-40, -60), "Đứt rồi!")
			_snap_back()
		elif along >= _dist():
			_dragging = false
			_pulled()
		accept_event()
	elif is_release(event) and _dragging:
		_dragging = false
		_snap_back()
		accept_event()


func _snap_back() -> void:
	var t := create_tween()
	t.tween_method(func(v: Vector2): _knob = v, _knob, _home, 0.18)


func _pulled() -> void:
	burst(kit("shell_bit"), _knob, 5, 3.0, 50.0)
	good(_knob + Vector2(-40, -60), "Ra rồi!", "loot")
	if removal_mode() == "split":
		_lay_down(_part)
	else:
		# Nắp vỏ văng sang phải để không rơi đè lên nửa vỏ có thịt.
		drop_piece(_part, Vector2(2.2, -0.4) if removal_mode() == "pry" else _dir)
	_part = null
	_i += 1
	if _i >= step.count:
		_knob = _home + _dir * (_dist() + 40.0)
		complete_soon(0.4)
	else:
		get_tree().create_timer(0.3).timeout.connect(_start_pull)


## Tách để dùng: lá / cụm rơi nhẹ xuống nằm cạnh trên thớt (không bỏ đi).
func _lay_down(r: TextureRect) -> void:
	if r == null:
		return
	var rest := r.position + Vector2(0, 26)
	rest.y = minf(rest.y, AREA.y - r.size.y - 6.0)
	var t := r.create_tween().set_parallel(true)
	t.tween_property(r, "position", rest, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_property(r, "rotation", r.rotation + (0.5 if _dir.x >= 0.0 else -0.5), 0.3)


## Tách để dùng thì bước sau vẫn thấy đủ (hình trước bước này).
func result_texture() -> Texture2D:
	if removal_mode() == "split":
		return carry
	return super()


func _paint(c: CanvasItem) -> void:
	# Đường chấm + mũi tên chỉ hướng kéo.
	var end := _home + _dir * _dist()
	dashed(c, _home, end, Color(1, 1, 1, 0.85), 5.0, 12.0)
	var side := Vector2(-_dir.y, _dir.x)
	c.draw_line(end, end - _dir * 18.0 + side * 12.0, Color.WHITE, 5.0)
	c.draw_line(end, end - _dir * 18.0 - side * 12.0, Color.WHITE, 5.0)
	# Núm cần kéo.
	c.draw_line(item_center, _knob, Color("f2d6b0"), 8.0)
	c.draw_circle(_knob, KNOB_R + 4.0, Color("2b1a14"))
	c.draw_circle(_knob, KNOB_R, Color("f2a33a"))
	c.draw_circle(_knob + Vector2(-8, -8), 8.0, Color("ffe082"))
	# Thanh lực kéo: xanh -> đỏ khi gần đứt.
	var r := clampf(_speed / _max_speed, 0.0, 1.0)
	c.draw_rect(METER.grow(3), Color("2b1a14"))
	c.draw_rect(METER, Color("1e2a33"))
	c.draw_rect(Rect2(METER.position, Vector2(METER.size.x * r, METER.size.y)), Color("66bb6a").lerp(Color("e53935"), r))
