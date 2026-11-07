class_name DayLight
extends Control
## Ánh sáng theo giờ trong game: sáng ban ngày, ngả vàng buổi chiều, tối dần sau 18h và bật đèn.
## Bám theo đồng hồ mặt trời của HUD (nếu có HUD), không có thì tự tính giờ từ DayManager giống HUD.
## Đặt ngay trên nền + đồ vật, dưới chữ và nút để chữ luôn dễ đọc. Dùng chung cho bếp và nhà hàng.

## Giờ -> màu nhân lên cảnh (multiply).
const TINT_KEYS := [
	[5.0, Color(0.72, 0.74, 0.92)],
	[6.5, Color(1.0, 0.92, 0.84)],
	[9.0, Color(1.0, 1.0, 1.0)],
	[15.0, Color(1.0, 0.98, 0.93)],
	[17.0, Color(1.0, 0.88, 0.72)],
	[18.3, Color(0.92, 0.7, 0.62)],
	[19.5, Color(0.62, 0.6, 0.8)],
	[21.0, Color(0.5, 0.52, 0.74)],
	[24.0, Color(0.44, 0.47, 0.7)],
]
const LAMP_ON_FROM := 16.5 ## Đèn bắt đầu sáng lúc 16h30...
const LAMP_FULL_AT := 19.0 ## ...sáng hẳn lúc 19h.

static var _glow_texture: Texture2D

var lamp_color := Color(1.0, 0.76, 0.44)
## 1 = đổi màu cả cảnh theo giờ; nhỏ hơn thì nhẹ hơn (dùng khi phủ lên cả chữ/nút để vẫn dễ đọc).
var strength := 1.0
var _tint: ColorRect
var _lamps: Array[Dictionary] = [] ## {node: TextureRect, strength: float}
var _progress := -1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_tint = ColorRect.new()
	_tint.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_tint.mouse_filter = MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_tint.material = mat
	add_child(_tint)
	_update(0.0)


func _process(delta: float) -> void:
	_update(delta)


## Thêm 1 vùng sáng của đèn (tròn, sáng theo bậc kiểu pixel), tự bật khi trời tối.
func add_lamp(center: Vector2, radius: float, strength := 1.0, squash := 1.0) -> void:
	var glow := TextureRect.new()
	glow.texture = _glow()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = MOUSE_FILTER_IGNORE
	glow.size = Vector2(radius * 2.0, radius * 2.0 * squash)
	glow.position = center - glow.size / 2.0
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.modulate = Color(lamp_color, 0.0)
	add_child(glow)
	_lamps.append({"node": glow, "strength": strength})


## Giờ trong game hiện tại (6.0 .. 23.0).
func hour() -> float:
	return 6.0 + maxf(_progress, 0.0) * 12.0


func _update(delta: float) -> void:
	var target := _hud_progress()
	if target < 0.0:
		target = target_progress()
		if _progress < 0.0 or target < _progress - 0.5:
			_progress = target
		else:
			var speed := maxf(0.08, absf(target - _progress) * 2.5)
			_progress = move_toward(_progress, target, delta * speed)
	else:
		_progress = target
	var h := hour()
	_tint.color = Color.WHITE.lerp(tint_at(h), strength)
	var k := clampf((h - LAMP_ON_FROM) / (LAMP_FULL_AT - LAMP_ON_FROM), 0.0, 1.0)
	for lamp in _lamps:
		var node: TextureRect = lamp["node"]
		node.modulate = Color(lamp_color, k * float(lamp["strength"]))


## Đọc đúng vị trí mặt trời HUD đang hiện (nếu có HUD) để ánh sáng khớp đồng hồ.
func _hud_progress() -> float:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and "_sun_progress" in hud:
		return float(hud.get("_sun_progress"))
	return -1.0


static func tint_at(h: float) -> Color:
	for i in range(TINT_KEYS.size() - 1):
		var a: Array = TINT_KEYS[i]
		var b: Array = TINT_KEYS[i + 1]
		if h <= float(b[0]):
			var t := clampf((h - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
			return (a[1] as Color).lerp(b[1] as Color, t)
	var last: Array = TINT_KEYS[TINT_KEYS.size() - 1]
	return last[1] as Color


## Cùng cách tính giờ với HUD: săn 6h–11h, nấu 11h–13h, bán 13h–22h, tổng kết 22h, cửa hàng 23h.
static func target_progress() -> float:
	match DayManager.current_phase:
		DayManager.Phase.HUNT:
			return lerpf(_at(6), _at(11), 1.0 - DayManager.time_left / DayManager.HUNT_DURATION)
		DayManager.Phase.COOK:
			return lerpf(_at(11), _at(13), 1.0 - DayManager.time_left / DayManager.COOK_DURATION)
		DayManager.Phase.SELL:
			return lerpf(_at(13), _at(22), 1.0 - DayManager.time_left / DayManager.SELL_DURATION)
		DayManager.Phase.DAY_END, DayManager.Phase.GAME_OVER:
			return _at(22)
		DayManager.Phase.SHOP:
			return _at(23)
	return _at(12) # Chạy thử riêng 1 màn: giữa trưa.


static func _at(h: float) -> float:
	return (h - 6.0) / 12.0


## Vầng sáng tròn nhiều bậc (pixel), dùng chung cho mọi đèn.
static func _glow() -> Texture2D:
	if _glow_texture != null:
		return _glow_texture
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.28, 0.52, 0.76, 0.98])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.34), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 48
	tex.height = 48
	_glow_texture = tex
	return tex
