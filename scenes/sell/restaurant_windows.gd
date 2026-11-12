class_name RestaurantWindows
extends WindowSky
## Cửa sổ nhà hàng đổi màu trời theo giờ, dùng lại cách làm của cửa sổ bếp (WindowSky)
## nhưng với lớp ảnh và vị trí sao của nền nhà hàng (assets/sprites/restaurant/make_restaurant_bg.py).

const RESTAURANT_SKY := preload("res://assets/sprites/restaurant/restaurant_window_sky.png")
const RESTAURANT_LAND := preload("res://assets/sprites/restaurant/restaurant_window_land.png")
## Sao của 2 cửa sổ bếp, dời sang chỗ 2 cửa sổ nhà hàng (điểm ảnh nền).
const RESTAURANT_STARS := [
	Vector2(53, 26), Vector2(61, 33), Vector2(71, 28), Vector2(80, 35), Vector2(56, 40),
	Vector2(119, 27), Vector2(126, 35), Vector2(136, 33), Vector2(144, 27), Vector2(148, 37),
]


func setup(light: DayLight) -> void:
	_light = light
	size = STAGE_SIZE
	mouse_filter = MOUSE_FILTER_IGNORE
	_sky = _make_layer(RESTAURANT_SKY)
	_land = _make_layer(RESTAURANT_LAND)


func _draw() -> void:
	if _star_alpha <= 0.0:
		return
	for star in RESTAURANT_STARS:
		draw_rect(Rect2(star * ART_PIXEL, Vector2.ONE * ART_PIXEL), Color(1, 1, 0.85, _star_alpha))
