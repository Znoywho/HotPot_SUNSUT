class_name WindowSky
extends Control
## Cửa sổ bếp đổi màu theo giờ: bình minh, ban ngày, hoàng hôn, đêm có sao.
## Vẽ đè lên nền bếp (nằm trên lớp DayLight để giữ màu trời đúng ý), lấy giờ từ DayLight.
## Lớp ảnh tạo bằng tools/make_window_layers.py.

const SKY_TEXTURE := preload("res://assets/sprites/kitchen/kitchen_window_sky.png")
const LAND_TEXTURE := preload("res://assets/sprites/kitchen/kitchen_window_land.png")
const STAGE_SIZE := Vector2(1280, 720)
const ART_PIXEL := 4.0 ## 1 điểm ảnh nền = 4 px màn hình.
const DAY_SKY := Color("c2dcdc") ## Trời ban ngày đúng như nền bếp gốc.
const SKY_KEYS := [
	[5.0, HudSunDial.SKY_NIGHT],
	[6.0, HudSunDial.SKY_DAWN],
	[8.0, DAY_SKY],
	[16.0, DAY_SKY],
	[17.5, HudSunDial.SKY_GOLD],
	[18.5, HudSunDial.SKY_DUSK],
	[20.0, HudSunDial.SKY_NIGHT],
	[24.0, HudSunDial.SKY_NIGHT],
] ## Giờ -> màu trời.
const LAND_KEYS := [
	[5.0, Color(0.32, 0.36, 0.55)],
	[7.0, Color.WHITE],
	[16.5, Color.WHITE],
	[18.5, Color(0.85, 0.62, 0.55)],
	[20.0, Color(0.32, 0.36, 0.55)],
	[24.0, Color(0.32, 0.36, 0.55)],
] ## Giờ -> màu nhân lên mây và đồi.
const STAR_START_HOUR := 18.5
const STAR_FULL_HOUR := 20.0
## Vị trí sao theo điểm ảnh nền, nằm trong phần trời của 2 cửa sổ.
const STARS := [
	Vector2(119, 19), Vector2(127, 26), Vector2(137, 21), Vector2(146, 28), Vector2(122, 33),
	Vector2(209, 20), Vector2(216, 28), Vector2(226, 26), Vector2(234, 20), Vector2(238, 30),
]

var _light: DayLight
var _sky: TextureRect
var _land: TextureRect
var _star_alpha := 0.0


## Gắn cửa sổ vào nguồn giờ và dựng 2 lớp ảnh phủ đúng nền bếp.
func setup(light: DayLight) -> void:
	_light = light
	size = STAGE_SIZE
	mouse_filter = MOUSE_FILTER_IGNORE
	_sky = _make_layer(SKY_TEXTURE)
	_land = _make_layer(LAND_TEXTURE)


func _process(_delta: float) -> void:
	apply_hour(_light.hour())


## Đổi màu trời, cảnh và độ sáng của sao theo giờ.
func apply_hour(hour: float) -> void:
	_sky.modulate = color_at(SKY_KEYS, hour)
	_land.modulate = color_at(LAND_KEYS, hour)
	var alpha := star_alpha_at(hour)
	if not is_equal_approx(alpha, _star_alpha):
		_star_alpha = alpha
		queue_redraw()


## Nội suy tuyến tính giữa hai mốc giờ: c = a + (b - a) × (h - h_a) / (h_b - h_a).
static func color_at(keys: Array, hour: float) -> Color:
	for i in range(keys.size() - 1):
		var from_key: Array = keys[i]
		var to_key: Array = keys[i + 1]
		if hour <= float(to_key[0]):
			var t := clampf((hour - float(from_key[0])) / (float(to_key[0]) - float(from_key[0])), 0.0, 1.0)
			return (from_key[1] as Color).lerp(to_key[1] as Color, t)
	return keys[keys.size() - 1][1] as Color


## Độ sáng của sao: alpha = (h - giờ bắt đầu) / (giờ sáng hẳn - giờ bắt đầu), giới hạn trong 0..1.
static func star_alpha_at(hour: float) -> float:
	return clampf((hour - STAR_START_HOUR) / (STAR_FULL_HOUR - STAR_START_HOUR), 0.0, 1.0)


func _draw() -> void:
	if _star_alpha <= 0.0:
		return
	for star in STARS:
		draw_rect(Rect2(star * ART_PIXEL, Vector2.ONE * ART_PIXEL), Color(1, 1, 0.85, _star_alpha))


## Tạo một lớp ảnh phủ toàn bộ nền bếp, phóng to giữ nét pixel.
func _make_layer(texture_value: Texture2D) -> TextureRect:
	var layer := TextureRect.new()
	layer.texture = texture_value
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.size = STAGE_SIZE
	layer.mouse_filter = MOUSE_FILTER_IGNORE
	layer.show_behind_parent = true
	add_child(layer)
	return layer
