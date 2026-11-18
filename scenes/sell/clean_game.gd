class_name CleanGame
extends Control
## Một bước dọn dẹp trong CleanPanel (vẽ pixel, thao tác bằng 1 ngón tay / chuột trái):
## - "bowls": mặt bàn có bát đũa dơ, chạm từng bát để xếp lên khay. Chạm trượt bị trừ điểm.
## - "wipe": cầm khăn chà qua lại lên các vết nước lẩu trên bàn.
## - "mop": cầm cây lau nhà lau vũng nước trên sàn, giống "wipe".
## - "sweep": kéo từng mẩu rác vào hốt rác (chổi đi theo ngón tay). Thả ra ngoài hốt rác bị trừ điểm.
## Xong -> `step_finished(score)` với điểm 0..100.

signal step_finished(score: int)

const AREA := Vector2(800, 280)
const TABLE_C := Vector2(380, 150)
const TABLE_R := Vector2(320, 112)
const BOWL_R := 40.0 ## Bán kính vùng chạm bát (>= 56 px đường kính).
const TRAY := Rect2(668, 170, 116, 80)
const PAN := Rect2(640, 110, 140, 120) ## Vùng hốt rác (thả rác vào đây).
const SPOT_R := 30.0
const CLEAN_DIST := 260.0 ## px phải chà qua 1 vết cho sạch.
const GRAB_R := 48.0

var game := "bowls"
var mistakes := 0
var _done := false
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
# bowls
var _bowls: Array = [] ## [{pos, gone}]
var _stacked := 0
# wipe / mop
var _spots: Array = [] ## [{pos, dirt 1..0, seed}]
var _rubbing := false
var _last := Vector2.ZERO
var _finger := Vector2(-999, -999)
# sweep
var _trash: Array = [] ## [{pos, look, gone}]
var _held := -1
var _total := 1


func _init(game_kind: String) -> void:
	game = game_kind
	size = AREA
	custom_minimum_size = AREA
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	_rng.randomize()
	match game:
		"bowls":
			var n := _rng.randi_range(4, 6)
			for i in n:
				var a := TAU * i / n + _rng.randf_range(-0.2, 0.2)
				_bowls.append({"pos": TABLE_C + Vector2(cos(a) * TABLE_R.x * 0.68, sin(a) * TABLE_R.y * 0.62), "gone": false})
			_total = n
		"wipe":
			_make_spots(5, func() -> Vector2:
				var a := _rng.randf() * TAU
				var r := sqrt(_rng.randf()) * 0.75
				return TABLE_C + Vector2(cos(a) * TABLE_R.x * r, sin(a) * TABLE_R.y * r))
		"mop":
			var c := Vector2(330, 150)
			_make_spots(7, func() -> Vector2:
				return c + Vector2(_rng.randf_range(-170, 170), _rng.randf_range(-60, 60)))
		_:
			var n := _rng.randi_range(3, 5)
			for i in n:
				_trash.append({"pos": Vector2(_rng.randf_range(60, 540), _rng.randf_range(50, 240)),
					"look": FloorMess.TRASH_KINDS[_rng.randi() % FloorMess.TRASH_KINDS.size()], "gone": false,
					"rot": _rng.randf_range(-0.5, 0.5)})
			_total = n


func _make_spots(n: int, pick: Callable) -> void:
	var tries := 0
	while _spots.size() < n and tries < 300:
		tries += 1
		var p: Vector2 = pick.call()
		var ok := true
		for s in _spots:
			if (s.pos as Vector2).distance_to(p) < SPOT_R * 1.6:
				ok = false
				break
		if ok:
			_spots.append({"pos": p, "dirt": 1.0, "seed": _rng.randi()})
	_total = _spots.size()


## Tiến độ bước 0..1 (cho thanh dưới bảng).
func progress() -> float:
	match game:
		"bowls":
			return float(_stacked) / maxf(_total, 1)
		"sweep":
			return float(_trash.filter(func(t): return t.gone).size()) / maxf(_total, 1)
		_:
			var left := 0.0
			for s in _spots:
				left += s.dirt
			return 1.0 - left / maxf(_total, 1)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


# --- Thao tác ----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		accept_event()
		if event.pressed:
			_press(p)
		else:
			_release(p)
	elif event is InputEventMouseMotion:
		_finger = event.position
		if _rubbing:
			_rub(event.position)
			accept_event()
		elif _held >= 0:
			_trash[_held].pos = event.position
			accept_event()


func _press(p: Vector2) -> void:
	_finger = p
	match game:
		"bowls":
			for b in _bowls:
				if not b.gone and p.distance_to(b.pos) <= BOWL_R:
					_take_bowl(b)
					return
			_mistake(p, "Trượt!")
		"sweep":
			for i in _trash.size():
				if not _trash[i].gone and p.distance_to(_trash[i].pos) <= GRAB_R:
					_held = i
					return
		_:
			_rubbing = true
			_last = p


func _release(p: Vector2) -> void:
	_rubbing = false
	if game == "sweep" and _held >= 0:
		var t: Dictionary = _trash[_held]
		_held = -1
		if PAN.grow(10).has_point(p):
			t.gone = true
			_pop(p + Vector2(-30, -50), "Vào rồi!", Color("c8e6c9"))
			_sfx("slice")
			if _trash.all(func(x): return x.gone):
				_finish("Sàn sạch bong!")
		else:
			_mistake(p, "Rơi ra ngoài!")


func _take_bowl(b: Dictionary) -> void:
	b.gone = true
	_stacked += 1
	_pop(b.pos + Vector2(-30, -50), "Chuẩn!", Color("c8e6c9"))
	_sfx("slice")
	if _stacked >= _total:
		_finish("Dọn xong bát đũa!")


func _rub(p: Vector2) -> void:
	var moved := p.distance_to(_last)
	for s in _spots:
		if s.dirt <= 0.0:
			continue
		var near := Geometry2D.get_closest_point_to_segment(s.pos, _last, p)
		if near.distance_to(s.pos) <= SPOT_R + 14.0:
			s.dirt = maxf(0.0, s.dirt - moved / CLEAN_DIST)
			if s.dirt <= 0.0:
				_pop(s.pos + Vector2(-24, -50), "Sạch!", Color("e3f2fd"))
	_last = p
	if _spots.all(func(s): return s.dirt <= 0.0):
		_rubbing = false
		_finish("Sạch bong!" if game == "wipe" else "Khô ráo!")


func _mistake(p: Vector2, text: String) -> void:
	mistakes += 1
	_pop(p + Vector2(-40, -50), text, Color("ff8a80"))
	_sfx("hit")


func _finish(text: String) -> void:
	if _done:
		return
	_done = true
	_pop(AREA / 2.0 + Vector2(-80, -90), text, HuntUI.GOLD)
	_sfx("splash")
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		step_finished.emit(clampi(100 - CleanPanel.PENALTY * mistakes, 0, 100)))


func _pop(at: Vector2, text: String, color: Color) -> void:
	var l := HuntUI.outlined_label(text, 22, color)
	l.position = at
	l.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(l)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", at.y - 40, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	t.chain().tween_callback(l.queue_free)


func _sfx(name: String) -> void:
	var path := "res://assets/audio/sfx/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = -14.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


# --- Vẽ ----------------------------------------------------------------------

func _draw() -> void:
	if game == "bowls" or game == "wipe":
		_draw_table()
	else:
		_draw_floor()
	match game:
		"bowls":
			_draw_bowls()
		"wipe", "mop":
			_draw_spots()
			_draw_tool("cloth" if game == "wipe" else "mop", _rubbing)
		_:
			_draw_sweep()


func _draw_floor() -> void:
	var tile := 56.0
	for y in int(AREA.y / tile) + 1:
		for x in int(AREA.x / tile) + 1:
			var c := Color("b8693e") if (x + y) % 2 == 0 else Color("a95f38")
			draw_rect(Rect2(x * tile, y * tile, tile, tile), c)
			draw_rect(Rect2(x * tile, y * tile, tile, 3), Color("8a4a2a"))
			draw_rect(Rect2(x * tile, y * tile, 3, tile), Color("8a4a2a"))


func _draw_table() -> void:
	draw_rect(Rect2(Vector2.ZERO, AREA), Color("7a4a2c"))
	draw_colored_polygon(TableVisual._ellipse(TABLE_C + Vector2(0, 16), TABLE_R.x, TABLE_R.y, 64), Color("7d3f1f"))
	draw_colored_polygon(TableVisual._ellipse(TABLE_C, TABLE_R.x, TABLE_R.y, 64), Color("c97a43"))
	draw_colored_polygon(TableVisual._ellipse(TABLE_C + Vector2(0, -8), TABLE_R.x * 0.72, TABLE_R.y * 0.62, 64), Color("d68a50"))
	draw_colored_polygon(TableVisual._ellipse(TABLE_C, 54, 22, 40), Color("2a1a12"))


func _draw_bowls() -> void:
	# Khay xếp bát bên phải, bát đã dọn chồng lên nhau.
	draw_rect(TRAY, Color("6b4423"))
	draw_rect(TRAY.grow(-6), Color("9a6a3c"))
	for k in _stacked:
		var p := Vector2(TRAY.get_center().x, TRAY.end.y - 22 - k * 9)
		_bowl_at(p, true)
	var pulse := 1.0 + sin(_clock * 6.0) * 0.08
	var first := true
	for b in _bowls:
		if b.gone:
			continue
		_bowl_at(b.pos, false)
		# Đôi đũa vứt cạnh bát.
		draw_line(b.pos + Vector2(14, -10), b.pos + Vector2(40, 6), Color("c49a5a"), 4.0)
		draw_line(b.pos + Vector2(18, -14), b.pos + Vector2(44, 2), Color("c49a5a"), 4.0)
		draw_arc(b.pos, BOWL_R * pulse, 0.0, TAU, 32, Color(0, 0, 0, 0.35), 6.0)
		draw_arc(b.pos, BOWL_R * pulse, 0.0, TAU, 32, HuntUI.GOLD if first else Color("ffe082"), 3.0)
		first = false


func _bowl_at(p: Vector2, clean: bool) -> void:
	draw_colored_polygon(TableVisual._ellipse(p + Vector2(0, 6), 26, 10), Color("b8ad98"))
	draw_colored_polygon(TableVisual._ellipse(p, 26, 11), Color("f4eee0"))
	draw_colored_polygon(TableVisual._ellipse(p, 19, 7), Color("d8cdb8") if clean else Color("8a4b2a"))


func _draw_spots() -> void:
	for s in _spots:
		var a: float = s.dirt
		if a <= 0.0:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = s.seed
		var r := SPOT_R * (0.55 + 0.45 * a)
		for k in 10:
			var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-0.7, 0.7)) * r * 0.8
			var sz := rng.randf_range(10.0, 18.0) * (0.5 + 0.5 * a)
			var col: Color
			if game == "mop":
				col = Color(0.3, 0.55, 0.8) if k % 3 == 0 else Color(0.45, 0.72, 0.92)
			else:
				col = Color(0.45, 0.2, 0.08) if k % 3 == 0 else Color(0.6, 0.3, 0.12)
			draw_rect(Rect2(s.pos + off - Vector2(sz, sz) / 2.0, Vector2(sz, sz)).abs(), Color(col, 0.8 * a))
		if game == "mop" and a > 0.3:
			draw_rect(Rect2(s.pos + Vector2(-8, -6), Vector2(8, 4)), Color(1, 1, 1, 0.6 * a))


## Dụng cụ đi theo ngón tay khi đang thao tác, còn không thì nằm chờ ở góc.
func _draw_tool(tool: String, active: bool) -> void:
	var at := _finger if active and _finger.x > -900 else Vector2(720, 220)
	var offset := Vector2(0, -24) if tool == "mop" else Vector2.ZERO
	CleanTools.draw_tool(self, tool, at + offset, 5.0)


func _draw_sweep() -> void:
	# Hốt rác lớn bên phải.
	CleanTools.draw_tool(self, "broom", PAN.get_center() + Vector2(-34, 10), 10.0, "pan_only")
	var pulse := 0.5 + 0.5 * sin(_clock * 5.0)
	draw_rect(PAN, Color(1, 0.9, 0.5, 0.12 + 0.12 * pulse), false, 3.0)
	for i in _trash.size():
		var t: Dictionary = _trash[i]
		if t.gone:
			continue
		draw_set_transform(t.pos, t.rot if i != _held else 0.0, Vector2.ONE)
		FloorMess.draw_trash(self, t.look, Vector2.ZERO, 6.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if i != _held:
			draw_arc(t.pos, GRAB_R * 0.8, 0.0, TAU, 32, Color("ffe082", 0.7), 2.0)
	# Chổi theo tay khi đang kéo rác.
	var at: Vector2 = _trash[_held].pos + Vector2(-46, -20) if _held >= 0 else Vector2(520, 236)
	CleanTools.draw_tool(self, "broom", at, 6.0, "broom_only")
