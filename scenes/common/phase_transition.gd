class_name PhaseTransition
extends CanvasLayer
## Chuyển cảnh giữa các buổi "Sôi sùng sục" (S16 v2). DayManager gọi: cover() -> đổi màn -> hold() -> uncover().
## - cover: bọt sôi pixel trồi từ đáy màn, phình to phủ kín. Trong bọt là bầu trời theo giờ của buổi mới.
## - hold: thẻ tên buổi. Mặt trời / trăng trượt theo cung (tua nhanh ~1,5 giờ), mây trôi, sao nhấp nháy,
##   buổi chiều tối thì quán lên đèn; tên buổi rơi từng chữ. Chạm / bấm phím để bỏ qua.
## - uncover: bọt vỡ từ dưới lên, lộ màn mới.
## Mọi node con dùng chung shader bọt của gốc (use_parent_material) nên cùng hiện trong bọt.
## Chạy cả lúc game tạm dừng (sổ tổng kết, menu "Chơi mới").

const SHADER := preload("res://scenes/common/canvas_ui_phase_bubbles.gdshader")
const ART := "res://assets/sprites/"
const LAYER_INDEX := 50 ## Trên màn chơi, dưới HUD (60) để vẫn thấy đồng hồ mặt trời trượt sang buổi mới.

# --- Thời lượng (giây) ---
const COVER_SECONDS := 0.55 ## Bọt phồng phủ kín.
const HOLD_SECONDS := 1.2 ## Thẻ tên buổi: mặt trời trượt hết khoảng giờ của thẻ.
const SKIP_AFTER := 0.25 ## Chạm để bỏ qua thẻ, nhưng chỉ sau chừng này giây cho kịp thấy tên buổi.
const UNCOVER_SECONDS := 0.5 ## Bọt vỡ lộ màn mới.
const SUBTITLE_DELAY := 0.25 ## Dòng phụ hiện sau tên buổi.

# --- Bố cục (đơn vị canvas, màn gốc cao 720) ---
const ART_SCALE := 4.0 ## Sprite pixel phóng 4 lần như các màn khác.
const LAND_SCALE_MIN := 3.0 ## Ảnh đồi + quán (432x180) phóng tối thiểu 3 lần; màn rộng hơn thì phóng thêm cho phủ hết bề ngang.
const LAND_TOP := 360.0 ## Mép trên ảnh đồi.
const RESTAURANT_IN_LAND := Vector2(215, 46) ## Tâm quán trong ảnh landscape.png (điểm ảnh gốc).
const HORIZON_Y := 520.0 ## Mặt trời / trăng xuống dưới mức này là khuất sau núi.
const ARC_HEIGHT := 380.0 ## Đỉnh cung mặt trời cao hơn chân trời bao nhiêu (đỉnh ở y 140, quầng sáng không chui dưới HUD).
const ARC_LEFT := 0.06 ## Mọc ở 6% bề ngang...
const ARC_RIGHT := 0.94 ## ...lặn ở 94%.
const TITLE_Y := 196.0 ## Mép trên dòng tên buổi (chữ pixel x4: chân chữ hoa ở y 276, cách dòng phụ ~24 px).
const SUBTITLE_Y := 300.0 ## Mép trên dòng phụ.
const SUBTITLE_RISE := 14.0 ## Dòng phụ trượt lên bao nhiêu khi hiện.
const TITLE_PIXEL_SCALE := 4 ## Tên buổi dùng font pixel PixelTitle phóng 4 lần, khớp ART_SCALE và ô bọt pixel_size 4 của shader.
const SUBTITLE_SIZE := 30
const SKY_BANDS := 8 ## Số dải màu trời (kiểu sky.png).
const STAR_COUNT := 18
const STAR_TOP := 100.0 ## Sao nằm trong dải y 100..330.
const STAR_HEIGHT := 230.0
const STAR_SEED := 20261124
const CLOUDS := [ ## [ảnh, y, tốc độ trôi (đơn vị/giây), vị trí x ban đầu theo tỉ lệ bề ngang]
	["cloud_big", 150.0, 14.0, 0.12],
	["cloud_small", 215.0, 22.0, 0.6],
	["cloud_big", 112.0, 9.0, 0.82],
]
const LAMP_SIZE := 280.0 ## Quầng đèn quán.
const LAMP_STEPS := 5 ## Số bậc sáng của quầng đèn (kiểu pixel, không mượt).
const LAMP_RAMP_HOURS := 1.5 ## Đèn quán bật từ DayLight.LAMP_ON_FROM, sáng hết sau 1,5 giờ (thẻ chỉ tua tới 18h18; trong game là 2,5 giờ).

# --- Màu ---
const SUBTITLE_COLOR := Color("fbe9d0")
const MENU_FLASH_COLOR := Color("fff4d6") ## Khớp FLASH_COLOR của menu chính: menu kết thúc bằng màn sáng phủ kín.
const STAR_COLOR := Color("fff4c8")
const LAMP_COLOR := Color(1.0, 0.7, 0.36)
const SUNSET_SUN := Color(1.0, 0.62, 0.4) ## Mặt trời sát chân trời ngả cam.
## Giờ -> [màu đỉnh trời, màu chân trời]; nội suy giữa các mốc (giống DayLight.TINT_KEYS).
const SKY_KEYS := [
	[0.0, Color("0d1130"), Color("262b57")],
	[4.0, Color("121840"), Color("363266")],
	[5.3, Color("26306c"), Color("85598a")],
	[6.3, Color("5a84d4"), Color("f5b088")],
	[8.0, Color("4f8de4"), Color("bcdffc")],
	[12.0, Color("3d86ea"), Color("a8d6fd")],
	[16.0, Color("4a7dd2"), Color("f2d3a0")],
	[17.6, Color("5a58a6"), Color("ff9a5a")],
	[18.6, Color("392d6c"), Color("c65a69")],
	[20.0, Color("1a1d48"), Color("3c2e60")],
	[24.0, Color("0d1130"), Color("262b57")],
]

# --- Âm thanh ---
const BUBBLE_DB := -6.0
const POP_DB := -8.0

var _root: Control
var _material: ShaderMaterial
var _sky_gradient: Gradient
var _stars: Array[ColorRect] = []
var _star_seeds: Array[Vector3] = [] ## Mỗi sao: (x theo tỉ lệ bề ngang, y theo tỉ lệ dải sao, pha nhấp nháy)
var _moon: TextureRect
var _sun_glow: TextureRect
var _sun: TextureRect
var _clouds: Array[TextureRect] = []
var _lamp: TextureRect
var _land: TextureRect
var _title: RichTextLabel
var _pop: PopInEffect ## Hiệu ứng chữ rơi của _title (độ trễ giữa các chữ đổi theo độ dài tên buổi).
var _subtitle: Label

var _flat := false ## Từ menu chính: chỉ phủ một màu sáng, không cảnh, không thẻ.
var _has_card := false
var _texts: Array[String] = ["", ""]
var _hours := Vector2(12.0, 12.0) ## Giờ đầu / cuối của thẻ.
var _time := 0.0 ## Giây kể từ lúc bắt đầu che.
var _hold_start := -1.0 ## _time lúc bắt đầu giữ thẻ (-1: chưa giữ, mặt trời đứng ở giờ đầu).
var _holding := false ## Đang giữ thẻ tên buổi (bấm lúc này = bỏ qua).
var _skip := false ## Người chơi đã chạm / bấm để bỏ qua thẻ.
var _star_alpha := 0.0 ## Độ hiện của sao theo giờ (0 ban ngày .. 1 ban đêm).


## Nằm trên màn chơi, chạy cả khi game tạm dừng; dựng sẵn cảnh và ẩn tới lần chuyển cảnh đầu tiên.
func _ready() -> void:
	layer = LAYER_INDEX
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	set_process(false)


## Thời gian trôi trong lúc chuyển cảnh: mặt trời / trăng, màu trời, mây, sao.
func _process(delta: float) -> void:
	_time += delta
	_apply_hour(_current_hour())
	_drift_clouds(delta)
	_twinkle_stars()


## Đang chuyển cảnh thì nuốt mọi lần bấm (không lọt xuống màn bên dưới); đang giữ thẻ thì bấm = bỏ qua.
func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	var pressed := (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) \
			and event.is_pressed() and not event.is_echo()
	if not pressed:
		return
	if _holding:
		_skip = true
	get_viewport().set_input_as_handled()


# --- API cho DayManager ---------------------------------------------------------

## Bọt phồng phủ kín màn (cảnh bên trong là buổi `phase`). Từ menu chính: phủ ngay bằng màu sáng của menu.
func cover(phase: int, from_menu: bool) -> void:
	_setup(phase, from_menu)
	_root.visible = true
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	if from_menu:
		_set_progress(1.0) # Menu chính đã tự phủ sáng kín màn bằng đúng màu này.
		return
	Sfx.play(self, Sfx.BUBBLE, BUBBLE_DB)
	_set_progress(0.0)
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, COVER_SECONDS)
	await tween.finished


## Giữ thẻ tên buổi HOLD_SECONDS giây (chạm để bỏ qua). Không có thẻ (từ menu, Game Over) thì đi tiếp ngay.
func hold() -> void:
	if not _has_card:
		return
	await get_tree().process_frame # Đợi màn mới dựng xong (khung nặng) rồi mới cho chữ rơi.
	_show_title()
	_hold_start = _time
	_skip = false
	_holding = true
	while not _hold_done():
		await get_tree().process_frame
	_holding = false


## Bọt vỡ từ dưới lên, lộ màn mới; xong thì ẩn hẳn và trả lại thao tác.
func uncover() -> void:
	Sfx.play(self, Sfx.POP, POP_DB)
	var tween := create_tween()
	tween.tween_method(_set_progress, 1.0, 2.0, UNCOVER_SECONDS)
	await tween.finished
	_root.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.text = ""
	_subtitle.text = ""
	set_process(false)


## [dòng lớn, dòng nhỏ] của thẻ tên buổi; dòng rỗng = không hiện thẻ.
static func card_text(phase: int) -> Array[String]:
	match phase:
		DayManager.Phase.HUNT:
			return ["NGÀY %d · SÁNG" % GameState.shown_day(), "Đi săn nguyên liệu"]
		DayManager.Phase.COOK:
			return ["TRƯA", "Sơ chế và nấu lẩu"]
		DayManager.Phase.SELL:
			return ["CHIỀU TỐI", "Mở quán bán hàng"]
		DayManager.Phase.SHOP:
			return ["CỬA HÀNG NÂNG CẤP", "Chuẩn bị ngày %d" % GameState.day]
	return ["", ""] # Game Over đã có tiêu đề "Quán đóng cửa" riêng: chỉ có cảnh đêm, không thẻ.


## Khoảng giờ cảnh trong bọt tua qua (giờ đầu, giờ cuối) để mỗi buổi có đúng không khí của nó.
static func card_hours(phase: int) -> Vector2:
	match phase:
		DayManager.Phase.HUNT:
			return Vector2(6.0, 7.2) # Mặt trời nhô lên sau đồi.
		DayManager.Phase.COOK:
			return Vector2(11.0, 12.5) # Mặt trời lên đỉnh.
		DayManager.Phase.SELL:
			return Vector2(16.5, 18.3) # Hoàng hôn, quán lên đèn.
		DayManager.Phase.SHOP:
			return Vector2(4.6, 6.0) # Trăng lặn, sao tắt dần, rạng đông (HUD cửa hàng chỉ 06:00): chuẩn bị ngày mới.
		DayManager.Phase.GAME_OVER:
			return Vector2(22.0, 22.0)
	return Vector2(12.0, 12.0)


## Màu trời [đỉnh, chân] lúc `h` giờ, nội suy giữa các mốc SKY_KEYS.
static func sky_at(h: float) -> Array[Color]:
	for i in range(SKY_KEYS.size() - 1):
		var a: Array = SKY_KEYS[i]
		var b: Array = SKY_KEYS[i + 1]
		if h <= float(b[0]):
			var t := clampf((h - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
			return [(a[1] as Color).lerp(b[1], t), (a[2] as Color).lerp(b[2], t)]
	var last: Array = SKY_KEYS[SKY_KEYS.size() - 1]
	return [last[1] as Color, last[2] as Color]


## Độ "đêm" (0 ban ngày .. 1 ban đêm) theo giờ, cho sao hiện / tắt.
static func night_amount(h: float) -> float:
	if h < 12.0:
		return 1.0 - smoothstep(4.6, 6.2, h)
	return smoothstep(18.4, 19.8, h)


## Độ sáng đèn quán theo giờ: bật từ 16h30 như DayLight, sáng hết sau LAMP_RAMP_HOURS; đóng cửa (sau 21h, trước trưa) thì tắt.
static func lamp_amount(h: float) -> float:
	if h < 12.0 or h > 21.0:
		return 0.0
	return clampf((h - DayLight.LAMP_ON_FROM) / LAMP_RAMP_HOURS, 0.0, 1.0)


# --- Dựng cảnh -------------------------------------------------------------------

## Dựng mọi node một lần (ẩn sẵn); thứ tự thêm = thứ tự vẽ: trời -> sao -> trăng -> mặt trời -> mây -> đèn -> đồi -> chữ.
func _build() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.material = _material
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_sky_gradient = Gradient.new()
	_sky_gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in SKY_BANDS:
		offsets.append(float(i) / SKY_BANDS)
		colors.append(Color.BLACK)
	_sky_gradient.offsets = offsets
	_sky_gradient.colors = colors
	var sky_texture := GradientTexture2D.new()
	sky_texture.gradient = _sky_gradient
	sky_texture.width = 4
	sky_texture.height = SKY_BANDS * 8
	sky_texture.fill_from = Vector2(0.0, 0.0)
	sky_texture.fill_to = Vector2(0.0, 1.0)
	var sky := TextureRect.new()
	sky.texture = sky_texture
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add(sky)

	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	for i in STAR_COUNT:
		var star := ColorRect.new()
		star.color = STAR_COLOR
		star.size = Vector2.ONE * ART_SCALE * (2.0 if i % 5 == 0 else 1.0) # vài sao to gấp đôi
		_add(star)
		_stars.append(star)
		_star_seeds.append(Vector3(rng.randf(), rng.randf(), rng.randf() * TAU))

	_moon = _sprite("ui/result/moon", 1.25)
	_sun_glow = _sprite("scenery/sun_glow", ART_SCALE)
	_sun = _sprite("scenery/sun", ART_SCALE)
	for c in CLOUDS:
		_clouds.append(_sprite("scenery/" + str(c[0]), ART_SCALE))
	_lamp = _stepped_glow(LAMP_SIZE)
	_land = _sprite("scenery/landscape", LAND_SCALE_MIN)

	_title = RichTextLabel.new()
	_title.bbcode_enabled = true
	_title.fit_content = true
	_title.scroll_active = false
	_title.clip_contents = false # chữ rơi từ trên xuống, không cắt phần ló ra ngoài khung
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Chữ pixel mập tự vẽ (assets/fonts/pixel_title): màu, viền, bóng vẽ sẵn; mỗi buổi một bảng màu (đặt lại trong _setup).
	PixelTitle.apply_rich(_title, "noon", TITLE_PIXEL_SCALE)
	_pop = PopInEffect.new()
	_title.install_effect(_pop)
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.position.y = TITLE_Y
	_add(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", SUBTITLE_SIZE)
	_subtitle.add_theme_color_override("font_color", SUBTITLE_COLOR)
	_subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	_subtitle.add_theme_constant_override("outline_size", PixelButton.outline_for(SUBTITLE_SIZE))
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_add(_subtitle)


## Thêm node vào gốc: dùng chung shader bọt của gốc, không nhận chạm.
func _add(node: Control) -> void:
	node.use_parent_material = true
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(node)


## Ảnh pixel (lọc nearest) phóng `scale` lần, thêm vào gốc.
func _sprite(path: String, scale: float) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.texture = load(ART + path + ".png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.size = sprite.texture.get_size() * scale
	_add(sprite)
	return sprite


## Quầng sáng tròn `size` x `size`, sáng nhất ở tâm, nhạt dần theo LAMP_STEPS bậc (kiểu pixel); nhuộm màu bằng modulate.
## Mốc cuối ở rìa trong suốt hẳn, nên 4 góc texture (xa tâm hơn bán kính) không lộ thành khung vuông.
func _stepped_glow(size: float) -> TextureRect:
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in LAMP_STEPS:
		offsets.append(float(i) / LAMP_STEPS)
		colors.append(Color(1.0, 1.0, 1.0, pow(1.0 - float(i) / LAMP_STEPS, 1.6)))
	offsets.append(1.0)
	colors.append(Color(1.0, 1.0, 1.0, 0.0))
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = int(size / ART_SCALE)
	texture.height = int(size / ART_SCALE)
	var glow := TextureRect.new()
	glow.texture = texture
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.size = Vector2.ONE * size
	_add(glow)
	return glow


## Chuẩn bị một lần chuyển cảnh: chữ, khoảng giờ, bố cục theo bề ngang màn hiện tại.
func _setup(phase: int, from_menu: bool) -> void:
	_time = 0.0
	_hold_start = -1.0
	_holding = false
	_skip = false
	_flat = from_menu
	_texts = card_text(phase)
	_has_card = not from_menu and _texts[0] != ""
	_hours = card_hours(phase)
	PixelTitle.apply_rich(_title, PixelTitle.for_phase(phase), TITLE_PIXEL_SCALE)
	_pop.lamps = phase == DayManager.Phase.SELL # chiều tối: chữ rơi xong thì lần lượt "lên đèn" như quán
	_title.text = ""
	_subtitle.text = ""
	var scenery: Array[Control] = [_land, _sun, _sun_glow, _moon, _lamp]
	scenery.append_array(_clouds)
	scenery.append_array(_stars)
	for node in scenery:
		node.visible = not from_menu
	if from_menu:
		var flat := PackedColorArray()
		flat.resize(SKY_BANDS)
		flat.fill(MENU_FLASH_COLOR)
		_sky_gradient.colors = flat
	_layout()
	_apply_hour(_hours.x)


## Đặt đồi, đèn quán, sao, mây theo bề ngang màn hiện tại (màn rộng hơn 16:9 thì cảnh rộng theo).
func _layout() -> void:
	var size := _root.size
	_material.set_shader_parameter("screen_size", size)
	var land_px := _land.texture.get_size()
	var land_scale := maxf(LAND_SCALE_MIN, maxf(size.x / land_px.x, (size.y - LAND_TOP) / land_px.y))
	_land.size = land_px * land_scale
	_land.position = Vector2((size.x - _land.size.x) / 2.0, LAND_TOP)
	_lamp.position = _land.position + RESTAURANT_IN_LAND * land_scale - _lamp.size / 2.0
	for i in _stars.size():
		var s := _star_seeds[i]
		_stars[i].position = Vector2(s.x * size.x, STAR_TOP + s.y * STAR_HEIGHT).snapped(Vector2.ONE * ART_SCALE)
	for i in _clouds.size():
		_clouds[i].position = Vector2(float(CLOUDS[i][3]) * size.x, float(CLOUDS[i][1]))


## Cảnh trong bọt lúc `h` giờ: màu trời, sao, mặt trời / trăng theo cung, màu đồi + mây, đèn quán.
func _apply_hour(h: float) -> void:
	if _flat:
		return
	var sky := sky_at(h)
	var colors := PackedColorArray()
	for i in SKY_BANDS:
		colors.append(sky[0].lerp(sky[1], float(i) / (SKY_BANDS - 1)))
	_sky_gradient.colors = colors
	_star_alpha = night_amount(h)
	var tint := DayLight.tint_at(h)
	_land.modulate = tint
	for cloud in _clouds:
		cloud.modulate = tint
	var sun_p := (h - 6.0) / 12.0
	_place_on_arc(_sun, sun_p)
	_place_on_arc(_sun_glow, sun_p)
	var low := 1.0 - clampf(sin(clampf(sun_p, 0.0, 1.0) * PI) * 2.5, 0.0, 1.0) # 1 = sát chân trời
	_sun.modulate = Color.WHITE.lerp(SUNSET_SUN, low)
	_sun_glow.modulate = Color(_sun.modulate, 0.75)
	_place_on_arc(_moon, fposmod(h - 18.0, 24.0) / 12.0)
	_lamp.modulate = Color(LAMP_COLOR, lamp_amount(h))


## Đặt mặt trời / trăng trên cung trời theo `p` (0 = mọc bên trái, 1 = lặn bên phải); ra ngoài thì khuất sau núi.
## Cung: x = lerp(ARC_LEFT, ARC_RIGHT, p) × bề ngang, y = HORIZON_Y − sin(pπ) × ARC_HEIGHT.
func _place_on_arc(node: Control, p: float) -> void:
	var x := lerpf(ARC_LEFT, ARC_RIGHT, p) * _root.size.x
	var y := HORIZON_Y - sin(p * PI) * ARC_HEIGHT
	node.position = (Vector2(x, y) - node.size / 2.0).snapped(Vector2.ONE * ART_SCALE)
	node.visible = p > -0.15 and p < 1.15


## Giờ hiện tại của cảnh: đứng ở giờ đầu lúc che, trượt tới giờ cuối (sine in-out) lúc giữ thẻ.
func _current_hour() -> float:
	if _hold_start < 0.0:
		return _hours.x
	var elapsed := minf(_time - _hold_start, HOLD_SECONDS)
	return float(Tween.interpolate_value(_hours.x, _hours.y - _hours.x, elapsed, HOLD_SECONDS, Tween.TRANS_SINE, Tween.EASE_IN_OUT))


## Mây trôi sang phải, ra khỏi mép phải thì quay lại từ mép trái.
func _drift_clouds(delta: float) -> void:
	for i in _clouds.size():
		var cloud := _clouds[i]
		cloud.position.x += float(CLOUDS[i][2]) * delta
		if cloud.position.x > _root.size.x:
			cloud.position.x = -cloud.size.x


## Sao nhấp nháy lệch pha nhau; ban ngày tắt hẳn.
func _twinkle_stars() -> void:
	for i in _stars.size():
		var star := _stars[i]
		star.modulate.a = _star_alpha * (0.55 + 0.45 * sin(_time * 3.0 + _star_seeds[i].z))
		star.visible = not _flat and _star_alpha > 0.01


## Hiện tên buổi (rơi từng chữ) và dòng phụ (trượt lên, hiện dần).
func _show_title() -> void:
	_pop.stagger = minf(PopInEffect.STAGGER, PopInEffect.STAGGER_BUDGET / maxf(1.0, _texts[0].length()))
	_title.text = "[center][pop]%s[/pop][/center]" % _texts[0] # đổi chữ -> hiệu ứng [pop] chạy lại từ đầu
	_subtitle.text = _texts[1]
	_subtitle.modulate.a = 0.0
	_subtitle.position.y = SUBTITLE_Y + SUBTITLE_RISE
	var tween := _subtitle.create_tween().set_parallel(true)
	tween.tween_property(_subtitle, "modulate:a", 1.0, 0.3).set_delay(SUBTITLE_DELAY)
	tween.tween_property(_subtitle, "position:y", SUBTITLE_Y, 0.35).set_delay(SUBTITLE_DELAY) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Thẻ đã giữ đủ lâu, hoặc người chơi chạm bỏ qua (sau SKIP_AFTER giây).
func _hold_done() -> bool:
	var elapsed := _time - _hold_start
	return elapsed >= HOLD_SECONDS or (_skip and elapsed >= SKIP_AFTER)


## Tiến độ bọt cho shader: 0..1 phồng phủ kín, 1..2 vỡ lộ màn mới.
func _set_progress(value: float) -> void:
	_material.set_shader_parameter("progress", value)


## Hiệu ứng chữ [pop]...[/pop]: từng chữ rơi xuống rồi nảy nhẹ (back-out), chữ sau trễ hơn chữ trước.
## Chữ rơi theo từng nấc STEP_PX (đúng 1 điểm ảnh của font pixel) cho chất game retro, không trượt mượt.
## lamps = true (chiều tối): chữ rơi trong tối, chạm đất thì "bật đèn" (sáng, chớp nhẹ, sáng hẳn) như quán lên đèn.
## elapsed_time tự về 0 mỗi khi đổi chữ của RichTextLabel.
class PopInEffect extends RichTextEffect:
	const STAGGER := 0.05 ## Giây giữa hai chữ (tên buổi ngắn).
	const STAGGER_BUDGET := 0.5 ## Tên buổi dài thì co độ trễ để chữ cuối bắt đầu rơi trước 0,5 giây.
	const DROP := 40.0 ## Rơi từ cao bao nhiêu (đơn vị canvas).
	const DURATION := 0.4 ## Mỗi chữ rơi trong bao lâu.
	const FADE_PART := 0.35 ## Chữ hiện rõ hẳn sau 35% thời gian rơi.
	const STEP_PX := float(TITLE_PIXEL_SCALE) ## Nấc rơi = 1 điểm ảnh của font pixel.
	const LAMP_AT := 0.7 ## Chữ bật đèn khi đã rơi được 70% (lúc vừa chạm đất, trước nhịp nảy).
	const LAMP_DIM := 0.55 ## Độ sáng lúc chưa bật đèn.
	const LAMP_FLICK := [[0.06, 1.0], [0.12, 0.72]] ## [tới giây thứ, độ sáng] ngay sau khi bật; sau đó sáng hẳn.

	var bbcode := "pop"
	var stagger := STAGGER
	var lamps := false

	## Vị trí và độ rõ của từng chữ: offset_y = −DROP × (1 − back_out(t)) làm tròn theo STEP_PX,
	## alpha tăng dần trong FADE_PART đầu.
	func _process_custom_fx(fx: CharFXTransform) -> bool:
		var start := fx.relative_index * stagger
		var t := clampf(fx.elapsed_time - start, 0.0, DURATION)
		var k: float = Tween.interpolate_value(0.0, 1.0, t, DURATION, Tween.TRANS_BACK, Tween.EASE_OUT)
		fx.offset = Vector2(0.0, roundf(-DROP * (1.0 - k) / STEP_PX) * STEP_PX)
		fx.color.a *= clampf(t / (DURATION * FADE_PART), 0.0, 1.0)
		if lamps:
			var b := _lamp(fx.elapsed_time - start - DURATION * LAMP_AT)
			fx.color = Color(fx.color.r * b, fx.color.g * b, fx.color.b * b, fx.color.a)
		return true

	## Độ sáng của chữ sau lúc bật đèn `since` giây (âm = chưa bật).
	func _lamp(since: float) -> float:
		if since < 0.0:
			return LAMP_DIM
		for step in LAMP_FLICK:
			if since < float(step[0]):
				return float(step[1])
		return 1.0
