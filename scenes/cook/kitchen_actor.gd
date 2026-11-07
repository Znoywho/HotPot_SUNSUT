class_name KitchenActor
extends Control
## Nhân vật trong bếp (đầu bếp, phụ bếp, bếp phó): đứng thở, chớp mắt, đi lại, làm việc, hiện chữ nổi.
## Cùng kiểu animation với nhân vật màn săn (co giãn quanh chân, chớp mắt).

const SIZE := 128.0
const WALK_SPEED := 460.0 ## px / giây.

var display_name := ""
var sprite: TextureRect
var home_x := 0.0
var feet_y := 0.0
var _open_texture: Texture2D
var _blink_texture: Texture2D
var _idle_tween: Tween
var _move_tween: Tween
var _hop_tween: Tween
var _work_tween: Tween


func setup(texture: Texture2D, x: float, feet: float, name_text := "", facing_right := true) -> void:
	display_name = name_text
	size = Vector2(SIZE, SIZE)
	mouse_filter = MOUSE_FILTER_IGNORE
	_open_texture = texture
	_blink_texture = CombatantView._make_blink_texture(texture)
	sprite = HuntUI.texture_rect(texture, SIZE)
	sprite.size = Vector2(SIZE, SIZE)
	sprite.pivot_offset = Vector2(SIZE / 2.0, SIZE * 0.9)
	sprite.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(sprite)
	home_x = x
	feet_y = feet
	position = Vector2(x - SIZE / 2.0, feet - SIZE)
	face(facing_right)
	_start_idle()
	_schedule_blink()


func center_x() -> float:
	return position.x + SIZE / 2.0


func face(right: bool) -> void:
	sprite.flip_h = not right


## Đi tới vị trí x (nhún nhảy theo bước). Trả về tween để chờ nếu cần.
func walk_to(x: float) -> Tween:
	if _move_tween != null and _move_tween.is_running():
		_move_tween.kill()
	var dist := absf(x - center_x())
	var duration := clampf(dist / WALK_SPEED, 0.12, 1.4)
	if dist > 2.0:
		face(x > center_x())
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position:x", x - SIZE / 2.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hop(duration)
	return _move_tween


func go_home() -> Tween:
	return walk_to(home_x)


## Làm việc: "chop" = nhịp dao xuống lên, "stir" = khuấy nồi (lắc người).
func work(duration := 0.6, kind := "chop") -> void:
	if _work_tween != null and _work_tween.is_running():
		_work_tween.kill()
	_stop_idle()
	var beats := maxi(1, int(duration / 0.16))
	_work_tween = create_tween()
	for i in beats:
		if kind == "stir":
			_work_tween.tween_property(sprite, "rotation", deg_to_rad(5 if i % 2 == 0 else -5), 0.08)
		else:
			_work_tween.tween_property(sprite, "scale", Vector2(1.08, 0.9), 0.06)
			_work_tween.tween_property(sprite, "scale", Vector2.ONE, 0.1)
	_work_tween.tween_property(sprite, "rotation", 0.0, 0.08)
	_work_tween.tween_callback(_start_idle)


## Chữ nổi trên đầu (vd "+1 Thịt bò").
func say(text: String, color := Color.WHITE) -> void:
	var l := HuntUI.outlined_label(text, 18, color)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.position = Vector2(SIZE / 2.0 - 60, -10)
	l.custom_minimum_size = Vector2(120, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", -46.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.5)
	t.chain().tween_callback(l.queue_free)


## Hiện ra (vd nhân viên mới vào làm).
func appear(delay := 0.0) -> void:
	modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(self, "modulate:a", 1.0, 0.3)


func _hop(duration: float) -> void:
	if _hop_tween != null and _hop_tween.is_running():
		_hop_tween.kill()
	var steps := maxi(1, int(duration / 0.18))
	_hop_tween = create_tween()
	for i in steps:
		_hop_tween.tween_property(sprite, "position:y", -6.0, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_hop_tween.tween_property(sprite, "position:y", 0.0, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _start_idle() -> void:
	_stop_idle()
	sprite.scale = Vector2.ONE
	var period := randf_range(0.55, 0.75)
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_interval(randf_range(0.0, 0.3))
	_idle_tween.tween_property(sprite, "scale", Vector2(1.04, 0.95), period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(sprite, "scale", Vector2.ONE, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_idle() -> void:
	if _idle_tween != null:
		_idle_tween.kill()
		_idle_tween = null


func _schedule_blink() -> void:
	if _blink_texture == null or not is_inside_tree():
		return
	get_tree().create_timer(randf_range(2.0, 4.5)).timeout.connect(_blink)


func _blink() -> void:
	if not is_inside_tree():
		return
	sprite.texture = _blink_texture
	await get_tree().create_timer(0.12).timeout
	if is_inside_tree():
		sprite.texture = _open_texture
		_schedule_blink()
