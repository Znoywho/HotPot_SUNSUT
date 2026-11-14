extends PrepAction
## TAP_TARGETS: chạm đúng các điểm đánh dấu trên nguyên liệu (cuống, túi mực, lá úa, gân...).
## Chạm trượt ra ngoài điểm nào cũng bị trừ điểm. Điểm nhỏ dần khi độ khó tăng.
## Điểm nằm trên phần có hình của nguyên liệu; bước gỡ bỏ (lá úa, cuống, túi mực...) thì mẩu đó
## bị khoét khỏi nguyên liệu và rơi xuống.

var _targets: Array[Vector2] = []
var _radius := 40.0
var _hand: TextureRect


func _build() -> void:
	_radius = maxf(24.0, cfg.tap_radius / difficulty)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(item_id + step.title)
	var half := item.size / 2.0 - Vector2(18, 18)
	var tries := 0
	while _targets.size() < step.count and tries < 200:
		tries += 1
		var p := item_center + Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y))
		var ok := true
		for q in _targets:
			if q.distance_to(p) < _radius * 1.7:
				ok = false
				break
		if ok and tries < 150 and not opaque_at(p):
			ok = false # Ưu tiên điểm nằm trên nguyên liệu; thử quá nhiều thì chấp nhận.
		if ok:
			_targets.append(p)
	var t := step.title.to_lower()
	if t.begins_with("nhặt") or t.begins_with("loại"):
		for q in _targets:
			wither_spot(q, _radius * 0.5 / _px) # Lá úa / phần hỏng ngả vàng để biết chỗ cần nhặt.
	if not _targets.is_empty():
		_hand = pointer(_targets[0] + Vector2(-8, 4), "tap")


func _process(delta: float) -> void:
	super(delta)
	redraw()


func _gui_input(event: InputEvent) -> void:
	if is_done() or not is_press(event):
		return
	var p := (event as InputEventMouseButton).position
	accept_event()
	if _hand != null:
		_hand.queue_free()
		_hand = null
	for i in _targets.size():
		if p.distance_to(_targets[i]) <= _radius:
			var at := _targets[i]
			_targets.remove_at(i)
			if removal_mode() == "carve":
				_pop_bit(at)
			burst(kit("bubble"), at, 4, 3.0, 36.0)
			good(at + Vector2(-30, -50), "Chuẩn!", "slice")
			if _targets.is_empty():
				complete_soon(0.35)
			return
	mistake(p + Vector2(-30, -50), "Trượt!")


## Mẩu bị gỡ rơi ra. Nhặt lá / loại con hỏng / bỏ cuống / cắt râu thì khoét hẳn; còn lại (gân, hạt,
## túi mực, mắt...) nằm bên trong nên chỉ rơi ra mẩu nhỏ và chỗ đó sáng lên, không thủng lỗ.
func _pop_bit(at: Vector2) -> void:
	var t := step.title.to_lower()
	var whole := t.begins_with("nhặt") or t.begins_with("loại") or t.begins_with("cắt râu") or "cuống" in t
	var c := to_px(at)
	var radius := _radius * 0.5 / _px
	var bit: TextureRect
	if whole:
		# Gỡ mẩu mà không để lại lỗ: mẩu úa rơi xuống, chỗ cũ liền lại bằng màu xung quanh.
		var ring := func(p: Vector2) -> bool: return p.distance_to(c) <= radius + 4.0
		bit = heal_carve(circle(c, radius), ring)
	else:
		bit = carve(circle(c, _radius * 0.4 / _px), false, Color(1, 0.95, 0.88, 0.35))
	drop_piece(bit, (at - item_center).normalized() * 0.6)


func _paint(c: CanvasItem) -> void:
	var pulse := 1.0 + sin(_clock * 6.0) * 0.08
	for i in _targets.size():
		var p := _targets[i]
		c.draw_circle(p, _radius * 0.42, Color(0.36, 0.2, 0.12, 0.75))
		c.draw_arc(p, _radius * pulse, 0.0, TAU, 32, Color(0, 0, 0, 0.45), 7.0)
		c.draw_arc(p, _radius * pulse, 0.0, TAU, 32, HuntUI.GOLD if i == 0 else Color("ffe082"), 4.0)
