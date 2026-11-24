extends PrepAction
## TIMED_STAGE: chờ đúng lúc (chần, ướp, ngâm, để ráo). Kim chạy qua lại trên thanh, bấm "Xong!"
## khi kim trong vùng xanh. Bấm trượt bị trừ điểm và vùng xanh đổi chỗ; trượt stage_max_misses lần thì hết bước.

const BAR := Rect2(110, 40, 480, 26)
const GRACE := 0.1 ## Giây bù trễ: kim còn trong vùng xanh trong khoảng này trước lúc bấm vẫn tính trúng (độ trễ chạm / khung hình).

var _zone_c := 0.7
var _zone_w := 0.22
var _misses := 0
var _button: Button
var _fx_t := 0.0
var _rng := RandomNumberGenerator.new()


func _build() -> void:
	_rng.seed = hash(item_id + step.title)
	_zone_w = clampf(cfg.stage_zone / difficulty, 0.08, 0.6)
	_move_zone()
	_button = HuntUI.button("Xong!", 160)
	_button.position = Vector2(604, 150)
	_button.custom_minimum_size = Vector2(160, 76)
	_button.add_theme_font_size_override("font_size", 28)
	_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS # Nhận lúc nhấn xuống; mặc định là lúc thả tay -> kim đã chạy ra khỏi vùng.
	_button.pressed.connect(_press)
	add_child(_button)
	var label := {"pot": "Đang chần...", "bowl": "Đang ngâm / ướp...", "basket": "Đang để ráo..."}
	caption(str(label.get(step.prop, "Chờ đúng lúc...")), Vector2(BAR.position.x, BAR.end.y + 8), 18, Color.WHITE)


func _move_zone() -> void:
	_zone_c = _rng.randf_range(0.3 + _zone_w / 2.0, 0.95 - _zone_w / 2.0)


func needle(at := -1.0) -> float:
	var ph := fmod(maxf(0.0, _clock if at < 0.0 else at) / maxf(0.3, step.duration), 2.0)
	return ph if ph <= 1.0 else 2.0 - ph


## Kim có nằm trong vùng xanh ở bất kỳ lúc nào trong GRACE giây vừa qua không.
func _hit() -> bool:
	for k in 5:
		if absf(needle(_clock - GRACE * k / 4.0) - _zone_c) <= _zone_w / 2.0:
			return true
	return false


func _process(delta: float) -> void:
	super(delta)
	if not is_done():
		_fx_t += delta
		if _fx_t >= 0.25:
			_fx_t = 0.0
			if step.prop == "basket":
				burst(kit("bubble"), item_center + Vector2(randf_range(-60, 60), 60), 1, 2.0, 30.0, -0.8) # nước nhỏ giọt
			else:
				burst(kit("bubble"), item_center + Vector2(randf_range(-50, 50), -10), 2, 3.0, 40.0, 1.2) # hơi bốc lên
	redraw()


func _press() -> void:
	if is_done():
		return
	var v := needle()
	if _hit():
		_button.disabled = true
		good(Vector2(BAR.position.x + BAR.size.x * v - 40, BAR.end.y + 30), "Vừa tới!", "loot")
		complete_soon(0.4)
		return
	_misses += 1
	mistake(Vector2(BAR.position.x + BAR.size.x * v - 40, BAR.end.y + 30), "Sớm quá!" if v < _zone_c else "Quá rồi!")
	if _misses >= cfg.stage_max_misses:
		_button.disabled = true
		complete_soon(0.5)
	else:
		_move_zone()


func _paint(c: CanvasItem) -> void:
	c.draw_rect(BAR.grow(3), Color("2b1a14"))
	c.draw_rect(BAR, Color("1e2a33"))
	var zx := BAR.position.x + BAR.size.x * (_zone_c - _zone_w / 2.0)
	c.draw_rect(Rect2(zx, BAR.position.y, BAR.size.x * _zone_w, BAR.size.y), Color("66bb6a"))
	var nx := BAR.position.x + BAR.size.x * needle()
	c.draw_line(Vector2(nx, BAR.position.y - 8), Vector2(nx, BAR.end.y + 8), Color.WHITE, 5.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(nx - 9, BAR.position.y - 14), Vector2(nx + 9, BAR.position.y - 14), Vector2(nx, BAR.position.y - 4)]), Color.WHITE)
