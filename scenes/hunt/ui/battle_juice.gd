class_name BattleJuice
extends Node
## "Juice" cho trận đánh (theo skill game-feel): hitstop, rung màn theo trauma, zoom giật vào mục tiêu, quay chậm
## cú kết liễu cuối, impact frame (boss gục / bò tót nổ) và viền tối khi boss ra đòn.
## Chỉ xê dịch phần hình (đấu trường + ảnh nền) và đổi Engine.time_scale, không đụng logic trận.
## - Hitstop / quay chậm: hạ Engine.time_scale rồi trả lại bằng timer bỏ qua time_scale; chỉ lần gọi mới nhất được trả.
## - Rung: trauma 0..1 cộng dồn theo cú đánh, giảm đều theo THỜI GIAN THẬT (không đơ lệch tâm lúc hitstop),
##   độ rung = trauma² nên cú nhẹ chỉ nhích, cú nặng mới giật mạnh; dao động bằng tổng các sin (không nhiễu từng khung).
## - Luôn trả Engine.time_scale về 1 khi trận đóng (reset() trong _exit_tree).

const STOP_SCALE := 0.05 ## time_scale lúc hitstop: gần như đứng hình.
const SHAKE_DECAY := 1.2 ## trauma mất mỗi giây thật.
const SHAKE_MAX := Vector2(12.0, 8.0) ## Độ lệch tối đa (px) ở trauma 1.
const BACKDROP_OVERSCAN := 1.04 ## Ảnh nền phóng hơn màn một chút để rung / zoom không lộ mép.
const FLASH_GAP_MS := 400 ## Ít nhất 0,4 s giữa 2 lần nháy cả màn (<= 3 lần mỗi giây, WCAG 2.3.1).
const IMPACT_FRAME_SEC := 0.035 ## Mỗi khung của impact frame (~2 khung hình ở 60 fps).
const IMPACT_SHADER := preload("res://scenes/hunt/ui/impact_frame.gdshader")
const VIGNETTE_STEPS := 4 ## Viền tối kiểu pixel: vài bậc tối dần, không mượt.

var speed := 1.0 ## 2 khi bật Tốc độ x2: mọi thời lượng chia đôi.
var trauma := 0.0

var _arena: Control
var _backdrop: Control
var _overlay_parent: Control
var _arena_base := Vector2.ZERO
var _backdrop_base := Vector2.ZERO
var _shaking := false
var _t := 0.0
var _stop_id := 0
var _slow_id := 0
var _stopping := false
var _base_scale := 1.0 ## time_scale ngoài lúc hitstop: 1, hoặc thấp hơn khi đang quay chậm.
var _zoom_tween: Tween
var _vignette_tween: Tween
var _last_flash_ms := -100000
var _impact: ColorRect
var _vignette: TextureRect


## arena: phần có nhân vật (rung + zoom). backdrop: ảnh nền (rung, phóng nhẹ). overlay_parent: nơi gắn lớp phủ cả màn.
func setup(arena: Control, backdrop: Control, overlay_parent: Control) -> void:
	_arena = arena
	_backdrop = backdrop
	_overlay_parent = overlay_parent
	if _backdrop != null:
		_backdrop.scale = Vector2.ONE * BACKDROP_OVERSCAN
		_backdrop.resized.connect(_center_backdrop_pivot)
		_center_backdrop_pivot()


func _center_backdrop_pivot() -> void:
	if is_instance_valid(_backdrop):
		_backdrop.pivot_offset = _backdrop.size / 2.0


func _process(delta: float) -> void:
	if not _shaking:
		return
	var real := delta / maxf(Engine.time_scale, 0.0001)
	trauma = maxf(trauma - SHAKE_DECAY * real, 0.0)
	_t += real * 30.0
	var s := trauma * trauma
	_apply(Vector2(SHAKE_MAX.x * s * _wave(_t, 0.0), SHAKE_MAX.y * s * _wave(_t * 1.3, 2.1)).round())
	if trauma <= 0.0:
		_apply(Vector2.ZERO)
		_shaking = false


## Dao động mượt: 2 sin lệch nhịp (kiểu noise rẻ), không phải số ngẫu nhiên mỗi khung.
static func _wave(t: float, seed_value: float) -> float:
	return 0.6 * sin(t * 1.7 + seed_value) + 0.4 * sin(t * 3.1 + seed_value * 2.0)


func _apply(offset: Vector2) -> void:
	if is_instance_valid(_arena):
		_arena.position = _arena_base + offset
	if is_instance_valid(_backdrop):
		_backdrop.position = _backdrop_base + offset


## Cộng trauma (0..1): cú nhẹ 0,1-0,2, chí mạng ~0,55, boss gục 1. Cộng dồn, không đặt lại.
func add_trauma(amount: float) -> void:
	if amount <= 0.0 or not is_instance_valid(_arena):
		return
	if not _shaking:
		_arena_base = _arena.position
		_backdrop_base = _backdrop.position if is_instance_valid(_backdrop) else Vector2.ZERO
		_shaking = true
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Đứng hình `seconds` giây thật (cả người đánh lẫn người bị đánh, vì cả trận chậm lại).
func hit_stop(seconds: float) -> void:
	if seconds <= 0.0 or not is_inside_tree():
		return
	_stop_id += 1
	var mine := _stop_id
	_stopping = true
	Engine.time_scale = STOP_SCALE
	await get_tree().create_timer(seconds / speed, true, false, true).timeout
	if mine == _stop_id:
		_stopping = false
		Engine.time_scale = _base_scale


## Quay chậm `real_seconds` giây thật ở tốc độ `time_scale` (vd cú kết liễu cuối trận).
func slow_mo(time_scale: float, real_seconds: float) -> void:
	if not is_inside_tree():
		return
	_slow_id += 1
	var mine := _slow_id
	_base_scale = time_scale
	if not _stopping:
		Engine.time_scale = time_scale
	await get_tree().create_timer(real_seconds / speed, true, false, true).timeout
	if mine == _slow_id:
		_base_scale = 1.0
		if not _stopping:
			Engine.time_scale = 1.0


## Giật zoom đấu trường vào điểm `global_pos` (camera emphasis), chạy theo thời gian thật nên vẫn zoom lúc hitstop.
func punch_zoom(global_pos: Vector2, amount := 1.06, seconds := 0.3) -> void:
	if not is_instance_valid(_arena):
		return
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_arena.scale = Vector2.ONE
	_arena.pivot_offset = _arena.get_global_transform().affine_inverse() * global_pos
	var k := 1.0 / speed
	_zoom_tween = _arena.create_tween().set_ignore_time_scale(true)
	_zoom_tween.tween_property(_arena, "scale", Vector2.ONE * amount, 0.06 * k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_interval(maxf(0.0, seconds - 0.26) * k)
	_zoom_tween.tween_property(_arena, "scale", Vector2.ONE, 0.2 * k).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Impact frame: cả màn 2 màu theo độ sáng 1 khung, rồi khung đảo ngược, rồi tắt. Bị bỏ qua nếu vừa nháy < 0,4 s.
func impact_frame() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_flash_ms < FLASH_GAP_MS or not is_instance_valid(_overlay_parent) or not is_inside_tree():
		return
	_last_flash_ms = now
	if _impact == null:
		_impact = ColorRect.new()
		_impact.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_impact.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = IMPACT_SHADER
		_impact.material = mat
		_overlay_parent.add_child(_impact)
	_overlay_parent.move_child(_impact, -1)
	var m := _impact.material as ShaderMaterial
	m.set_shader_parameter("invert", false)
	_impact.visible = true
	await get_tree().create_timer(IMPACT_FRAME_SEC, true, false, true).timeout
	if not is_instance_valid(_impact):
		return
	m.set_shader_parameter("invert", true)
	await get_tree().create_timer(IMPACT_FRAME_SEC, true, false, true).timeout
	if is_instance_valid(_impact):
		_impact.visible = false


## Viền tối quanh màn trong `seconds` giây (boss sắp ra đòn): tối dần theo bậc kiểu pixel rồi tan.
func vignette(strength := 0.6, seconds := 0.35) -> void:
	if not is_instance_valid(_overlay_parent):
		return
	if _vignette == null:
		var g := Gradient.new()
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		var offsets := PackedFloat32Array([0.0])
		var colors := PackedColorArray([Color(0, 0, 0, 0)])
		for i in VIGNETTE_STEPS:
			offsets.append(0.55 + 0.45 * i / VIGNETTE_STEPS)
			colors.append(Color(0, 0, 0, 0.25 + 0.75 * (i + 1) / VIGNETTE_STEPS))
		g.offsets = offsets
		g.colors = colors
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.05, 1.05)
		tex.width = 64
		tex.height = 36
		_vignette = TextureRect.new()
		_vignette.texture = tex
		_vignette.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_vignette.stretch_mode = TextureRect.STRETCH_SCALE
		_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vignette.modulate.a = 0.0
		_overlay_parent.add_child(_vignette)
	_overlay_parent.move_child(_vignette, -1)
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	var k := 1.0 / speed
	_vignette_tween = _vignette.create_tween()
	_vignette_tween.tween_property(_vignette, "modulate:a", strength, 0.08 * k)
	_vignette_tween.tween_interval(maxf(0.0, seconds - 0.28) * k)
	_vignette_tween.tween_property(_vignette, "modulate:a", 0.0, 0.2 * k)


## Trả mọi thứ về nghỉ: time_scale 1, hết rung, hết zoom, tắt lớp phủ. Lần chờ trả time_scale nào còn treo cũng vô hiệu.
func reset() -> void:
	_stop_id += 1
	_slow_id += 1
	_stopping = false
	_base_scale = 1.0
	Engine.time_scale = 1.0
	trauma = 0.0
	if _shaking:
		_apply(Vector2.ZERO)
		_shaking = false
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	if is_instance_valid(_arena):
		_arena.scale = Vector2.ONE
	if is_instance_valid(_impact):
		_impact.visible = false
	if is_instance_valid(_vignette):
		_vignette.modulate.a = 0.0


func _exit_tree() -> void:
	reset()
