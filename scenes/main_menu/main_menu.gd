extends Control
## Menu chính: phong cảnh đồng quê nhiều lớp (trời, mặt trời, mây trôi, quán lẩu lớn trên đỉnh núi giữa),
## logo ở trên, nút ở giữa, đầu bếp đứng bên phải, trâu + 3 mèo nhảy ở góc trái,
## trên đồi phải 3 nhân viên đứng giữa bị một vòng quái vây quanh, sau lưng có boss to; nhân viên chém quái quanh mình,
## quái nhảy vào cắn, boss dậm đất (quái gục thì con khác rơi vào chỗ cũ, lặp mãi).
## Ảnh vẽ bằng tools/make_menu_art.py.
## Các số chỉnh giao diện để @export: chọn node MainMenu trong editor là sửa được, không cần đụng code.

const SKY := preload("res://assets/sprites/scenery/sky.png")
const LANDSCAPE := preload("res://assets/sprites/scenery/landscape.png")
const KIT := "res://assets/sprites/kitchen/"
const DANCE_FRAMES := 8 ## Số khung một điệu nhảy (ảnh dải ngang), xem tools/make_menu_art.py.
const DANCE_FPS := 6.0
## Đội nhảy góc trái kiểu 2.5D: [ảnh, cỡ 1 khung (điểm ảnh), chân đứng (điểm ảnh trong nhóm), tỉ lệ, độ sáng, chậm mấy khung].
## Trâu Thần Tài đứng sau cùng (chân cao hơn trên màn, hơi nhạt vì xa; trâu to mập nên vẫn nổi), 3 mèo xếp vòng cung
## phía trước: 2 con bên hơi lùi và nhỏ hơn, mèo cam ở giữa gần nhất. Vẽ theo thứ tự danh sách (xa trước).
const DANCE_TROUPE := [
	["buffalo_dance", Vector2(50, 54), Vector2(41, 10), 0.95, 0.88, 0],
	["cat_dance_grey", Vector2(24, 28), Vector2(12, 34), 0.9, 0.95, 1],
	["cat_dance_black", Vector2(24, 28), Vector2(70, 34), 0.9, 0.95, 1],
	["cat_dance_orange", Vector2(24, 28), Vector2(41, 39), 1.0, 1.0, 0],
]
const DANCE_GROUP_SIZE := Vector2(84, 40) ## Khung cả đội (điểm ảnh ở tỉ lệ 1), đáy = chân con đứng trước.
const TITLE_TEXTURE := preload("res://assets/sprites/scenery/title_pixel.png") ## Logo pixel (tools/make_title_logo.py).
const TITLE_SHINE := preload("res://scenes/main_menu/title_shine.gdshader")
const BUFFALO := preload("res://assets/sprites/characters/mount_buffalo.png") ## Trâu (thú cưỡi) có sẵn, nhìn sang phải.
const LAND_SIZE := Vector2(432, 180) ## Cỡ ảnh phong cảnh (điểm ảnh, rộng hơn 16:9 cho màn điện thoại); toạ độ nhân vật trên đồi tính theo ảnh này.
const SUN := preload("res://assets/sprites/scenery/sun.png")
const SUN_GLOW := preload("res://assets/sprites/scenery/sun_glow.png")
const DOOR_LEAF := preload("res://assets/sprites/scenery/door_leaf.png")
const CLOUDS: Array[Texture2D] = [
	preload("res://assets/sprites/scenery/cloud_big.png"),
	preload("res://assets/sprites/scenery/cloud_small.png"),
]
const CHEF_TEXTURE := preload("res://assets/sprites/characters/player.png")
const STAFF_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/characters/staff_lan.png"),
	preload("res://assets/sprites/characters/staff_minh.png"),
	preload("res://assets/sprites/characters/staff_tung.png"),
]
const MONSTER_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/monsters/mad_bull.png"),
	preload("res://assets/sprites/monsters/tomato_warrior.png"),
	preload("res://assets/sprites/monsters/angry_chili.png"),
	preload("res://assets/sprites/monsters/jumping_shrimp.png"),
	preload("res://assets/sprites/monsters/enoki_archer.png"),
	preload("res://assets/sprites/monsters/bouncy_beef_ball.png"),
	preload("res://assets/sprites/monsters/napa_cabbage.png"),
	preload("res://assets/sprites/monsters/armored_lobster.png"),
]
const MONSTER_SIZE := 104.0
const MONSTER_HP := 3 ## Số nhát chém trước khi quái gục và con khác nhảy ra.
const BOSS_TEXTURE := preload("res://assets/sprites/monsters/boss_hotpot_golem.png")
const BOSS_SCALE := 2.6 ## Boss to gấp chừng này quái thường cho nổi bật.
const STAFF_LUNGE := 28.0 ## Nhân viên lao tới chừng này px (ở cỡ gốc) khi chặt quái.
const PIXEL := 4.0 ## 1 điểm ảnh của bộ phong cảnh = 4 px màn hình (nền 320x180 trên 1280x720).
const RESTAURANT_DOOR := Vector2(216, 66) ## Cửa quán trên đỉnh núi (điểm ảnh phong cảnh): đầu bếp chạy về đây khi vào game.
const CHEF_FAR_SCALE := 0.25 ## Chạy tới cửa quán thì đầu bếp nhỏ còn chừng này (đi xa dần).
const DOOR_LEFT_LEAF := Vector2(211, 54) ## Góc trái trên cánh cửa trái (điểm ảnh phong cảnh), cánh phải nằm ngay bên phải.
const DOOR_OPEN_SECONDS := 0.5
const DOOR_OPEN_LEAD := 0.6 ## Cửa mở trước khi đầu bếp tới nơi chừng này giây.
const LIGHT_COLOR := Color("ffe9a8") ## Ánh đèn vàng ấm hắt ra từ cửa quán.
const LIGHT_CORE_RADIUS := 60.0 ## Lõi sáng quanh cửa (px màn hình ở 1280x720, co giãn theo phong cảnh).
const LIGHT_HALO_RADIUS := 240.0 ## Quầng sáng mờ toả rộng.
const GLARE_SECONDS := 1.0 ## Loá sáng: quầng sáng hiện dần, bùng to rồi dịu lại khi cửa mở.
const STEP_IN_SECONDS := 0.5 ## Tới cửa rồi đầu bếp còn bước thêm chừng này giây vào trong (lúc này mờ hẳn).
const CHEF_FADE_FROM := 0.35 ## Đầu bếp bắt đầu mờ dần khi chạy được chừng này phần quãng đường.
const FADE_SECONDS := 1.0 ## Ánh sáng tràn ra phủ kín màn rồi mới vào game.
const FLASH_COLOR := Color("fff4d6") ## Màu ánh sáng tràn màn khi vào quán (cửa hàng tan dần từ màu này).

@export var title_scale := 3 ## Phóng logo pixel số nguyên lần để điểm ảnh không méo.
@export var chef_scale := 2.2 ## Đầu bếp gốc 128px, nhân thêm chừng này.
@export_range(0.0, 1.0) var chef_x_ratio := 0.87 ## Vị trí đầu bếp theo bề ngang màn hình.
@export_range(0.0, 1.0) var chef_feet_ratio := 0.94 ## Chân đầu bếp theo bề dọc màn hình.
## Toạ độ trận đánh / bò tính bằng ĐIỂM ẢNH TRÊN PHONG CẢNH 432x180 (không phải px màn hình),
## nên màn rộng hay hẹp thì nhân vật vẫn đứng đúng trên đồi. Đồi phải: y = 70 + 0.005 * (x - 356)^2.
@export var fight_center := Vector2(343, 87) ## Giữa vòng vây: 3 nhân viên đứng quanh điểm này.
@export var ring_radius := Vector2(27, 7.5) ## Bán kính vòng quái (dẹt vì nhìn chéo từ trên xuống).
@export var ring_count := 6 ## Số quái trong vòng vây.
@export var staff_radius := Vector2(7, 2.5) ## Nhân viên đứng tựa lưng nhau quanh tâm.
@export var boss_feet := Vector2(356, 78) ## Boss đứng sau vòng vây (xa hơn nên vẽ trước).
@export var fight_scale := 0.5 ## Nhân vật trên đồi = cỡ gốc (32 điểm ảnh) nhân chừng này, vì ở xa.
@export var buffalo_feet: Array[Vector2] = [Vector2(66, 77), Vector2(88, 76.5), Vector2(108, 81)] ## Đồi trái.
@export var buffalo_scale := 0.45 ## Trâu gốc 32 điểm ảnh, ở xa nên thu nhỏ còn chừng này.
@export var buffalo_wander := 6.0 ## Trâu đi tới đi lui chừng này điểm ảnh.
@export var clutter_scale := 5.0 ## Đội nhảy góc trái phóng chừng này lần (con đứng trước).
@export var clutter_margin := Vector2(48, 24) ## Cách mép trái / mép dưới màn hình (px).
@export var sun_position_ratio := Vector2(0.88, 0.14) ## Tâm mặt trời theo tỉ lệ màn hình (góc trên phải).
@export var sun_bob_height := 8.0 ## Mặt trời nhấp nhô lên xuống chừng này px.
@export var cloud_count := 4
@export var cloud_speed_range := Vector2(10, 26) ## Tốc độ mây trôi sang phải (px/giây), mỗi đám một tốc độ.
@export var menu_font_size := 30
@export var button_size := PixelButton.DEFAULT_SIZE
@export var button_gap := 14
@export var buttons_offset_y := 56.0 ## Hạ cột nút xuống để không che quán trên đỉnh núi.

var chef: KitchenActor
var _door_leaves: Array[TextureRect] = [] ## [trái, phải]
var _door_lights: Array[TextureRect] = [] ## Quầng rồi lõi sáng; ẩn tới khi cửa mở.
var _light_tweens: Array[Tween] = [] ## Tween loá/thở của ánh sáng, dừng khi ánh sáng tràn màn.
var _buttons: Array[PixelButton] = []
var _leaving := false ## Đang chạy hiệu ứng vào game: chặn bấm thêm lần nữa.
var _clouds: Array[TextureRect] = []
var _dance_frames: Array[AtlasTexture] = []
var _dance_time := 0.0
var _cloud_speeds: Array[float] = []
var _resize_timer: SceneTreeTimer = null ## Đang chờ dựng lại menu sau khi đổi cỡ màn.


## Dựng toàn bộ giao diện bằng code, xếp từ xa tới gần.
func _ready() -> void:
	SettingsPanel.load_and_apply() # âm lượng đã lưu (game luôn mở từ menu chính)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_add_cover_layer(SKY)
	_build_clouds()
	_build_sun() # vẽ sau mây: mây trôi qua phía sau, không che mặt trời
	_add_cover_layer(LANDSCAPE)
	_build_door()
	_build_buffaloes()
	_build_clutter()
	_build_fight()
	_build_chef()
	_build_title()
	_build_record()
	_build_buttons()
	add_child(RotateHint.new())
	get_viewport().size_changed.connect(_on_viewport_resized)


## Mọi thứ trên menu đặt theo cỡ màn lúc _ready; web/điện thoại còn đổi cỡ canvas sau khi mở (hoặc xoay máy)
## nên dựng lại menu cho khớp. Đợi cỡ màn đứng yên một chút để không dựng lại liên tục khi kéo cửa sổ.
func _on_viewport_resized() -> void:
	if _leaving:
		return
	if _resize_timer == null:
		_resize_timer = get_tree().create_timer(0.2)
		_resize_timer.timeout.connect(func() -> void:
			if not _leaving:
				get_tree().reload_current_scene())


## Mây trôi sang phải, ra khỏi mép phải thì quay lại từ mép trái; mèo góc trái nhảy.
func _process(delta: float) -> void:
	_animate_dance(delta)
	var screen_width := get_viewport_rect().size.x
	for i in _clouds.size():
		var cloud := _clouds[i]
		cloud.position.x += _cloud_speeds[i] * delta
		if cloud.position.x > screen_width:
			cloud.position.x = -cloud.size.x


## Một lớp phong cảnh phủ kín màn hình, giữ tỉ lệ (cắt bớt mép nếu màn hình khác 16:9).
func _add_cover_layer(texture: Texture2D) -> void:
	var layer := TextureRect.new()
	layer.texture = texture
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	layer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(layer)


## Tỉ lệ phóng phong cảnh khi phủ kín màn (KEEP_ASPECT_COVERED): scale = max(rộng / 432, cao / 180).
func _land_scale() -> float:
	var screen := get_viewport_rect().size
	return maxf(screen.x / LAND_SIZE.x, screen.y / LAND_SIZE.y)


## Đổi điểm ảnh trên phong cảnh sang px màn hình: màn = (cỡ màn - cỡ ảnh * scale) / 2 + điểm * scale.
func _land_to_screen(point: Vector2) -> Vector2:
	var land_scale := _land_scale()
	return (get_viewport_rect().size - LAND_SIZE * land_scale) / 2.0 + point * land_scale


## Hai cánh cửa quán đóng sẵn che ô cửa sáng trên phong cảnh, cùng quầng sáng ẩn sẵn sau cửa
## (tạo trước đầu bếp để đầu bếp chạy tới thì đứng đè lên ánh sáng).
func _build_door() -> void:
	var land_scale := _land_scale()
	var leaf_size := DOOR_LEAF.get_size() * land_scale
	for i in 2:
		var leaf := TextureRect.new()
		leaf.texture = DOOR_LEAF
		leaf.flip_h = i == 1 # ảnh là cánh trái, lật ra cánh phải
		leaf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		leaf.size = leaf_size
		leaf.position = _land_to_screen(DOOR_LEFT_LEAF) + Vector2(leaf_size.x * i, 0)
		leaf.pivot_offset = Vector2(leaf_size.x * i, 0) # bản lề ở mép ngoài: cánh trái xoay quanh mép trái
		leaf.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(leaf)
		_door_leaves.append(leaf)

	var door_center := _land_to_screen(DOOR_LEFT_LEAF) + Vector2(leaf_size.x, leaf_size.y / 2.0)
	var light_scale := _land_scale() / PIXEL # số px đặt cho màn 1280x720, màn khác co giãn theo
	_door_lights.append(_add_soft_light(door_center, LIGHT_HALO_RADIUS * light_scale, 0.45)) # quầng
	_door_lights.append(_add_soft_light(door_center, LIGHT_CORE_RADIUS * light_scale, 1.0)) # lõi


## Một quầng sáng tròn mượt (cộng sáng lên cảnh): tâm sáng nhất, mờ dần ra mép theo đường cong êm
## (nhiều điểm gradient + ảnh 256px nên không thấy vòng/khối). Ẩn sẵn (scale 0).
func _add_soft_light(origin: Vector2, radius: float, strength: float) -> TextureRect:
	var gradient := Gradient.new()
	const STEPS := 12
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in STEPS + 1:
		var t := float(i) / STEPS
		var falloff := pow(1.0 - t, 2.2) # tắt êm, không có mép
		offsets.append(t)
		colors.append(Color(LIGHT_COLOR, strength * falloff))
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var light := TextureRect.new()
	light.texture = texture
	light.material = material
	light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR # mượt, không vỡ pixel
	light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	light.size = Vector2.ONE * radius * 2.0
	light.pivot_offset = light.size / 2.0
	light.position = origin - light.pivot_offset
	light.scale = Vector2.ONE * 0.4
	light.modulate.a = 0.0
	light.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(light)
	return light


## Mở cửa quán: 2 cánh thu hẹp về phía bản lề (như mở vào trong); ánh sáng loá bùng to rồi dịu lại,
## sau đó thở nhẹ như đèn thật.
func _open_door() -> void:
	var tween := create_tween().set_parallel(true)
	for leaf in _door_leaves:
		tween.tween_property(leaf, "scale:x", 0.0, DOOR_OPEN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for light in _door_lights:
		var glare := light.create_tween()
		_light_tweens.append(glare)
		glare.tween_property(light, "modulate:a", 1.0, GLARE_SECONDS * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		glare.parallel().tween_property(light, "scale", Vector2.ONE * 1.35, GLARE_SECONDS * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		glare.tween_property(light, "scale", Vector2.ONE, GLARE_SECONDS * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glare.tween_callback(_breathe.bind(light))


## Ánh sáng thở nhẹ (to/nhỏ, sáng/mờ chút xíu), lặp mãi.
func _breathe(light: TextureRect) -> void:
	var period := randf_range(0.6, 0.9)
	var loop := light.create_tween().set_loops()
	_light_tweens.append(loop)
	loop.tween_property(light, "scale", Vector2.ONE * 1.05, period).set_trans(Tween.TRANS_SINE)
	loop.parallel().tween_property(light, "modulate:a", 0.85, period).set_trans(Tween.TRANS_SINE)
	loop.tween_property(light, "scale", Vector2.ONE, period).set_trans(Tween.TRANS_SINE)
	loop.parallel().tween_property(light, "modulate:a", 1.0, period).set_trans(Tween.TRANS_SINE)


## Trâu gặm cỏ trên đồi trái: đi chậm sang một bên, đứng gặm, quay đầu đi về, lặp mãi.
func _build_buffaloes() -> void:
	var land_scale := _land_scale()
	for feet in buffalo_feet:
		var buffalo := TextureRect.new()
		buffalo.texture = BUFFALO
		buffalo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		buffalo.size = BUFFALO.get_size() * land_scale * buffalo_scale
		buffalo.position = _land_to_screen(feet) - Vector2(buffalo.size.x / 2.0, buffalo.size.y)
		buffalo.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(buffalo)
		var home_x := buffalo.position.x
		var reach := buffalo_wander * land_scale
		var tween := buffalo.create_tween().set_loops()
		tween.tween_interval(randf_range(0.5, 3.0))
		tween.tween_callback(func() -> void: buffalo.flip_h = false) # ảnh trâu nhìn phải
		tween.tween_property(buffalo, "position:x", home_x + reach, randf_range(4.0, 7.0))
		tween.tween_interval(randf_range(1.5, 4.0))
		tween.tween_callback(func() -> void: buffalo.flip_h = true)
		tween.tween_property(buffalo, "position:x", home_x, randf_range(4.0, 7.0))


## Ảnh pixel phóng PIXEL lần, tâm đặt tại center.
func _add_pixel_sprite(texture: Texture2D, center: Vector2) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.texture = texture
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.size = texture.get_size() * PIXEL
	sprite.pivot_offset = sprite.size / 2.0
	sprite.position = center - sprite.size / 2.0
	sprite.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(sprite)
	return sprite


## Mặt trời góc trên phải: nhấp nhô chậm, quầng sáng phập phồng.
func _build_sun() -> void:
	var center := get_viewport_rect().size * sun_position_ratio
	var glow := _add_pixel_sprite(SUN_GLOW, center)
	var sun := _add_pixel_sprite(SUN, center)

	var pulse := glow.create_tween().set_loops()
	pulse.tween_property(glow, "scale", Vector2.ONE * 1.12, 1.6).set_trans(Tween.TRANS_SINE)
	pulse.parallel().tween_property(glow, "modulate:a", 0.65, 1.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)
	pulse.parallel().tween_property(glow, "modulate:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE)

	for sprite: TextureRect in [glow, sun]:
		var bob := sprite.create_tween().set_loops()
		bob.tween_property(sprite, "position:y", sprite.position.y - sun_bob_height, 3.0).set_trans(Tween.TRANS_SINE)
		bob.tween_property(sprite, "position:y", sprite.position.y, 3.0).set_trans(Tween.TRANS_SINE)


## Vài đám mây rải ngẫu nhiên trên trời, mỗi đám trôi một tốc độ (di chuyển trong _process).
func _build_clouds() -> void:
	var screen := get_viewport_rect().size
	for i in cloud_count:
		var center := Vector2(randf() * screen.x, randf_range(0.05, 0.3) * screen.y)
		_clouds.append(_add_pixel_sprite(CLOUDS[i % CLOUDS.size()], center))
		_cloud_speeds.append(randf_range(cloud_speed_range.x, cloud_speed_range.y))


## Đầu bếp đứng thở, chớp mắt, quay mặt vào giữa (dùng lại KitchenActor của màn bếp), phóng to quanh chân.
func _build_chef() -> void:
	var screen := get_viewport_rect().size
	chef = KitchenActor.new()
	add_child(chef)
	chef.setup(CHEF_TEXTURE, screen.x * chef_x_ratio, screen.y * chef_feet_ratio, "", false)
	chef.pivot_offset = Vector2(KitchenActor.SIZE / 2.0, KitchenActor.SIZE)
	chef.scale = Vector2.ONE * chef_scale


## Góc trái dưới: trâu áo đỏ nón đỏ và 3 con mèo đứng 2 chân nhảy cùng một điệu (giơ tay, nhún, nghiêng
## trái phải, bật nhảy), xếp có chiều sâu kiểu 2.5D: xa thì nhỏ và cao hơn, mỗi con có bóng pixel dưới chân;
## 2 mèo hàng giữa chậm 1 nhịp cho sinh động.
func _build_clutter() -> void:
	var s := clutter_scale
	var group := Control.new()
	group.mouse_filter = MOUSE_FILTER_IGNORE
	group.size = DANCE_GROUP_SIZE * s
	group.position = Vector2(clutter_margin.x, get_viewport_rect().size.y - group.size.y - clutter_margin.y)
	add_child(group)
	for member in DANCE_TROUPE:
		var frame: Vector2 = member[1]
		var feet: Vector2 = member[2] * s
		var depth: float = member[3]
		var px := s * depth # cỡ 1 điểm ảnh của con này trên màn
		var shadow_tex: Texture2D = load("res://assets/sprites/scenery/%s.png" % ("shadow_buffalo" if member[0] == "buffalo_dance" else "shadow_cat"))
		var shadow := TextureRect.new()
		shadow.texture = shadow_tex
		shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.size = shadow_tex.get_size() * px # cùng cỡ điểm ảnh với nhân vật
		shadow.mouse_filter = MOUSE_FILTER_IGNORE
		shadow.position = feet - Vector2(shadow.size.x / 2.0, 1.0 * px) # ngay dưới chân như bóng của mọi nhân vật khác
		group.add_child(shadow)
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/sprites/scenery/%s.png" % member[0])
		atlas.region = Rect2(Vector2.ZERO, frame)
		atlas.set_meta("offset", member[5])
		var dancer := TextureRect.new()
		dancer.texture = atlas
		dancer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dancer.size = frame * px
		dancer.position = feet - Vector2(dancer.size.x / 2.0, dancer.size.y - 2.0 * px) # chân ảnh cách đáy 2 điểm ảnh
		dancer.mouse_filter = MOUSE_FILTER_IGNORE
		var light: float = member[4] # xa thì hơi tối/nhạt
		dancer.modulate = Color(light, light, light)
		group.add_child(dancer)
		_dance_frames.append(atlas)


## Đổi khung điệu nhảy theo thời gian (gọi từ _process).
func _animate_dance(delta: float) -> void:
	_dance_time += delta
	var frame := int(_dance_time * DANCE_FPS)
	for atlas in _dance_frames:
		var f: int = (frame - int(atlas.get_meta("offset")) + DANCE_FRAMES) % DANCE_FRAMES
		atlas.region.position.x = atlas.region.size.x * f


## Trận trên đồi: boss to đứng sau, một vòng quái vây 3 nhân viên ở giữa. Vẽ theo chân từ xa tới gần
## (y nhỏ trước) để người đứng trước che người đứng sau. Cỡ nhân vật theo tỉ lệ phóng phong cảnh để luôn cân với ngọn đồi.
func _build_fight() -> void:
	var size_scale := fight_scale * _land_scale() / PIXEL # nhân vật gốc 128px ứng với 32 điểm ảnh x PIXEL
	var center := _land_to_screen(fight_center)
	var monster_size := MONSTER_SIZE * size_scale
	var actors: Array[Control] = []

	var boss := _make_fight_monster(BOSS_TEXTURE, _land_to_screen(boss_feet), monster_size * BOSS_SCALE)
	boss.set_meta("boss", true)
	actors.append(boss)

	var monsters: Array[TextureRect] = []
	for i in ring_count:
		var angle := TAU * (i + 0.5) / ring_count + PI / 2.0
		var feet := _land_to_screen(fight_center + Vector2(cos(angle), sin(angle)) * ring_radius)
		var monster := _make_fight_monster(MONSTER_TEXTURES[i % MONSTER_TEXTURES.size()], feet, monster_size)
		monster.flip_h = feet.x < center.x # ảnh quái nhìn sang trái: quái bên trái lật lại để nhìn vào giữa
		monsters.append(monster)
		actors.append(monster)

	var staff_list: Array[KitchenActor] = []
	for i in STAFF_TEXTURES.size():
		var angle := TAU * i / STAFF_TEXTURES.size() - PI / 2.0
		var feet := center + Vector2(cos(angle), sin(angle)) * staff_radius * _land_scale()
		var staff := KitchenActor.new()
		staff.setup(STAFF_TEXTURES[i], feet.x, feet.y, "", feet.x >= center.x) # quay mặt ra ngoài đón quái
		staff.pivot_offset = Vector2(KitchenActor.SIZE / 2.0, KitchenActor.SIZE)
		staff.scale = Vector2.ONE * size_scale
		staff.set_meta("home", staff.position)
		staff.set_meta("feet_y", feet.y)
		staff_list.append(staff)
		actors.append(staff)

	actors.sort_custom(func(a: Control, b: Control) -> bool: return _feet_y(a) < _feet_y(b))
	for actor in actors:
		add_child(actor)
	for actor in actors:
		if actor is TextureRect:
			_start_monster_idle(actor, actor == boss)

	for staff in staff_list:
		_add_loop_timer(randf_range(1.0, 1.6), _staff_attack.bind(staff, monsters, boss))
	for monster in monsters:
		_add_loop_timer(randf_range(2.5, 4.5), _monster_pounce.bind(monster, staff_list, center))
	_add_loop_timer(randf_range(4.5, 6.0), _boss_stomp.bind(boss, staff_list, monsters))


## Quái (TextureRect) đứng chân tại feet, gốc co giãn ở chân.
func _make_fight_monster(texture: Texture2D, feet: Vector2, monster_size: float) -> TextureRect:
	var monster := HuntUI.texture_rect(texture, monster_size)
	monster.size = Vector2(monster_size, monster_size)
	monster.position = feet - Vector2(monster_size / 2.0, monster_size)
	monster.pivot_offset = Vector2(monster_size / 2.0, monster_size)
	monster.mouse_filter = MOUSE_FILTER_IGNORE
	monster.set_meta("hp", MONSTER_HP)
	monster.set_meta("home", monster.position) # chỗ đứng gốc cố định: nhiều đòn dồn dập không làm quái trôi
	monster.set_meta("feet_y", feet.y)
	return monster


func _feet_y(actor: Control) -> float:
	return actor.get_meta("feet_y")


## Hẹn giờ lặp (dừng hết khi vào game, xem _enter_game).
func _add_loop_timer(wait: float, callback: Callable) -> void:
	var timer := Timer.new()
	timer.wait_time = wait
	timer.timeout.connect(callback)
	add_child(timer)
	timer.start(randf_range(0.2, wait))


## Quái nhún tại chỗ (co giãn quanh chân); boss nhún chậm và nặng hơn.
func _start_monster_idle(monster: TextureRect, heavy := false) -> void:
	var period := 0.7 if heavy else randf_range(0.35, 0.45)
	var squash := Vector2(1.04, 0.95) if heavy else Vector2(1.06, 0.92)
	var tween := monster.create_tween().set_loops()
	tween.tween_property(monster, "scale", squash, period).set_trans(Tween.TRANS_SINE)
	tween.tween_property(monster, "scale", Vector2.ONE, period).set_trans(Tween.TRANS_SINE)


## Tâm thân một nhân vật (giữa ảnh) theo toạ độ màn hình.
func _body_center(actor: Control) -> Vector2:
	return actor.get_global_rect().get_center()


## Nhân viên chém con quái gần mình nhất (thỉnh thoảng chém boss): quay mặt về phía nó, lao tới,
## vệt chém hiện trên quái, rồi lùi về.
func _staff_attack(staff: KitchenActor, monsters: Array[TextureRect], boss: TextureRect) -> void:
	var home: Vector2 = staff.get_meta("home")
	var target: TextureRect = boss
	if randf() > 0.2:
		var best := INF
		for monster in monsters:
			var d := _body_center(monster).distance_to(_body_center(staff)) + randf() * 30.0 # hơi ngẫu nhiên để đổi mục tiêu
			if monster.get_meta("hp") > 0 and d < best:
				best = d
				target = monster
	var hit_at := _body_center(target)
	var direction := (hit_at - _body_center(staff)).normalized()
	staff.face(direction.x > 0.0)
	var lunge := create_tween()
	lunge.tween_property(staff, "position", home + direction * STAFF_LUNGE * staff.scale.x, 0.1)
	lunge.tween_callback(staff.work.bind(0.3, "chop"))
	var slash_scale := 5.0 * staff.scale.x * (1.6 if target == boss else 1.0)
	lunge.tween_callback(func() -> void: HuntFX.play(self, "slash", hit_at, slash_scale))
	lunge.tween_callback(_hit_monster.bind(target, direction))
	lunge.tween_interval(0.25)
	lunge.tween_property(staff, "position", home, 0.2)


## Quái nhảy vào cắn nhân viên gần nhất (vồng lên rồi về chỗ); nhân viên bị cắn nháy đỏ, giật lùi.
func _monster_pounce(monster: TextureRect, staff_list: Array[KitchenActor], center: Vector2) -> void:
	if monster.get_meta("hp") <= 0:
		return
	var home: Vector2 = monster.get_meta("home")
	var victim := staff_list[0]
	for staff in staff_list:
		if _body_center(staff).distance_to(_body_center(monster)) < _body_center(victim).distance_to(_body_center(monster)):
			victim = staff
	var reach := (center - (home + monster.pivot_offset)) * 0.45
	var jump := monster.size.y * 0.35
	var tween := monster.create_tween()
	tween.tween_property(monster, "position", home + reach + Vector2(0, -jump), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(monster, "position", home + reach, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_flinch.bind(victim, signf(reach.x)))
	tween.tween_property(monster, "position", home, 0.25).set_trans(Tween.TRANS_SINE)


## Nhân viên trúng đòn: nháy đỏ và giật lùi một chút theo hướng đòn.
func _flinch(staff: KitchenActor, direction: float) -> void:
	var home: Vector2 = staff.get_meta("home")
	var tween := staff.create_tween()
	tween.tween_property(staff, "modulate", Color(1.8, 0.6, 0.6), 0.05)
	tween.parallel().tween_property(staff, "position:x", home.x + 6.0 * direction * staff.scale.x, 0.06)
	tween.tween_property(staff, "modulate", Color.WHITE, 0.15)
	tween.parallel().tween_property(staff, "position:x", home.x, 0.15)


## Boss dậm đất: rướn người lên rồi nện xuống, bụi tung ở chân, nhân viên và quái bị hất nảy lên.
func _boss_stomp(boss: TextureRect, staff_list: Array[KitchenActor], monsters: Array[TextureRect]) -> void:
	var home: Vector2 = boss.get_meta("home")
	var tween := boss.create_tween()
	tween.tween_property(boss, "scale", Vector2(0.94, 1.12), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(boss, "position:y", home.y - boss.size.y * 0.08, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(boss, "scale", Vector2(1.14, 0.86), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(boss, "position:y", home.y, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_stomp_impact.bind(boss, staff_list, monsters))
	tween.tween_property(boss, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _stomp_impact(boss: TextureRect, staff_list: Array[KitchenActor], monsters: Array[TextureRect]) -> void:
	var feet := boss.position + Vector2(boss.size.x / 2.0, boss.size.y * 0.9)
	HuntFX.play(self, "smoke", feet, 1.4 * boss.size.x / MONSTER_SIZE)
	for staff in staff_list:
		_bounce(staff)
	for monster in monsters:
		if monster.get_meta("hp") > 0:
			_bounce(monster)


## Nảy nhẹ tại chỗ (bị dư chấn hất lên).
func _bounce(actor: Control) -> void:
	var home: Vector2 = actor.get_meta("home")
	var tween := actor.create_tween()
	tween.tween_property(actor, "position:y", home.y - actor.size.y * actor.scale.y * 0.18, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(actor, "position:y", home.y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Quái trúng đòn: nháy trắng + bật lùi theo hướng đòn; hết máu thì khói bốc lên và quái mới rơi vào chỗ cũ.
## Boss không bao giờ gục (chỉ nháy trắng, rung nhẹ).
func _hit_monster(monster: TextureRect, direction: Vector2) -> void:
	if monster.get_meta("hp") <= 0:
		return # đang gục, chờ con mới nhảy ra
	var home: Vector2 = monster.get_meta("home")
	var is_boss: bool = monster.get_meta("boss", false)
	var knock := direction * (4.0 if is_boss else 10.0) * monster.size.x / MONSTER_SIZE
	var tween := create_tween()
	tween.tween_property(monster, "modulate", Color(3, 3, 3), 0.05)
	tween.parallel().tween_property(monster, "position", home + knock, 0.08)
	tween.tween_property(monster, "modulate", Color.WHITE, 0.1)
	tween.parallel().tween_property(monster, "position", home, 0.15)
	if is_boss:
		return
	var hp: int = monster.get_meta("hp") - 1
	monster.set_meta("hp", hp)
	if hp > 0:
		return
	HuntFX.play(self, "smoke", _body_center(monster), 1.8 * monster.size.x / MONSTER_SIZE) # khói co theo cỡ quái trên đồi
	tween.tween_property(monster, "modulate:a", 0.0, 0.1)
	tween.tween_interval(0.8)
	tween.tween_callback(_respawn_monster.bind(monster))


## Quái mới (loại ngẫu nhiên) từ trên rơi xuống đúng chỗ cũ, đủ máu.
func _respawn_monster(monster: TextureRect) -> void:
	var home: Vector2 = monster.get_meta("home")
	monster.texture = MONSTER_TEXTURES[randi() % MONSTER_TEXTURES.size()]
	monster.position = home - Vector2(0, monster.size.y * 0.8)
	var tween := monster.create_tween()
	tween.tween_property(monster, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(monster, "position", home, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(monster.set_meta.bind("hp", MONSTER_HP))


## Dòng "Kỷ lục: trụ được N ngày" giữa đáy màn (chưa có lần chơi nào kết thúc thì không hiện).
func _build_record() -> void:
	var best := BestRecord.best_days()
	if best <= 0:
		return
	var label := Label.new()
	label.text = "Kỷ lục: trụ được %d ngày" % best
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", PixelButton.BOLD_FONT)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", PixelButton.TEXT_COLOR)
	label.add_theme_color_override("font_outline_color", PixelButton.TEXT_OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", PixelButton.outline_for(24))
	add_child(label)
	label.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM, PRESET_MODE_MINSIZE, 16)
	label.grow_horizontal = GROW_DIRECTION_BOTH


## Logo pixel mập "SÔI SÙNG SỤC" (Ô = nồi lẩu, dấu huyền = ớt, dấu nặng = cà chua) có ánh kim lướt qua chữ
## (title_shine.gdshader); bong bóng sủi từ đỉnh chữ bay lên vỡ (sôi sùng sục); cả logo nhấp nhô nhẹ.
func _build_title() -> void:
	var logo := TextureRect.new()
	logo.texture = TITLE_TEXTURE
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.mouse_filter = MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = TITLE_SHINE
	logo.material = material
	add_child(logo)
	var text_size := TITLE_TEXTURE.get_size() * title_scale
	logo.size = text_size
	logo.position = Vector2((get_viewport_rect().size.x - text_size.x) / 2.0, 6.0)
	logo.pivot_offset = text_size / 2.0

	var bob := logo.create_tween().set_loops()
	bob.tween_property(logo, "position:y", logo.position.y + 5.0, 1.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(logo, "position:y", logo.position.y, 1.6).set_trans(Tween.TRANS_SINE)

	var bubbles := Timer.new()
	bubbles.wait_time = 0.35
	bubbles.timeout.connect(_spawn_title_bubble.bind(logo, text_size))
	add_child(bubbles)
	bubbles.start()


## Bong bóng kem nhỏ nổi lên từ đỉnh chữ, lắc nhẹ, phồng rồi vỡ (nằm sau chữ).
func _spawn_title_bubble(logo: Control, text_size: Vector2) -> void:
	var bubble := TextureRect.new()
	bubble.texture = load(KIT + "bubble.png")
	bubble.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var d := randf_range(10.0, 20.0)
	bubble.size = Vector2(d, d)
	bubble.pivot_offset = bubble.size / 2.0
	bubble.modulate = Color(1.0, 0.95, 0.8, 0.0)
	bubble.position = Vector2(randf_range(0.08, 0.92) * text_size.x, text_size.y * 0.3) - bubble.pivot_offset
	bubble.mouse_filter = MOUSE_FILTER_IGNORE
	logo.add_child(bubble)
	logo.move_child(bubble, 0)
	var life := randf_range(1.0, 1.6)
	var tween := bubble.create_tween().set_parallel(true)
	tween.tween_property(bubble, "position:y", bubble.position.y - randf_range(26.0, 44.0), life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(bubble, "position:x", bubble.position.x + randf_range(-8.0, 8.0), life).set_trans(Tween.TRANS_SINE)
	tween.tween_property(bubble, "modulate:a", 0.9, 0.2)
	tween.tween_property(bubble, "scale", Vector2.ONE * 1.4, 0.12).set_delay(life - 0.12)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.12).set_delay(life - 0.12)
	tween.chain().tween_callback(bubble.queue_free)


## Cột nút pixel ở giữa màn hình: Chơi mới, Tiếp tục, Cài đặt, Thoát.
func _build_buttons() -> void:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", button_gap)
	add_child(list)

	_add_menu_button(list, "CHƠI MỚI", _enter_game.bind(DayManager.start_new_game))
	var continue_button := _add_menu_button(list, "TIẾP TỤC", _enter_game.bind(DayManager.continue_game))
	continue_button.disabled = not SaveManager.has_save()
	_add_menu_button(list, "CÀI ĐẶT", func(): get_tree().root.add_child(SettingsPanel.new()))
	if not OS.has_feature("web"): # Trên web không thoát được tab, nên ẩn nút.
		_add_menu_button(list, "THOÁT", get_tree().quit)

	list.set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_MINSIZE)
	list.grow_horizontal = GROW_DIRECTION_BOTH
	list.grow_vertical = GROW_DIRECTION_BOTH
	list.position.y += buttons_offset_y
	# Mép trên giữ như cột 3 nút (không đè cửa quán): nút thứ 4 (THOÁT, chỉ có trên máy tính) nối xuống dưới.
	list.position.y += maxi(0, _buttons.size() - 3) * (button_size.y + button_gap) / 2.0


## Thêm một PixelButton (nút dùng chung) vào cột, cỡ theo button_size.
func _add_menu_button(parent: Control, text: String, callback: Callable) -> PixelButton:
	var button := PixelButton.new(text, menu_font_size)
	button.custom_minimum_size = button_size
	button.pressed.connect(callback)
	parent.add_child(button)
	_buttons.append(button)
	return button


## Hiệu ứng vào game: khoá nút, đầu bếp chạy về cửa quán trên đỉnh núi và nhỏ dần (đi xa), cửa quán mở
## toả sáng, ánh sáng tràn trắng màn rồi mới gọi start (DayManager.start_new_game / continue_game).
## Cửa hàng mở ra tan dần từ cùng màu sáng đó.
func _enter_game(start: Callable) -> void:
	if _leaving:
		return
	_leaving = true
	var list := _buttons[0].get_parent() as Control
	list.mouse_filter = MOUSE_FILTER_IGNORE
	for button in _buttons:
		button.mouse_filter = MOUSE_FILTER_IGNORE # khoá bấm nhưng không đổi sang màu xám
	list.create_tween().tween_property(list, "modulate:a", 0.0, 0.3) # cột nút mờ dần cho đầu bếp chạy qua
	for child in get_children():
		if child is Timer:
			child.stop() # ngừng đánh quái: hiệu ứng chém/khói tạo sau sẽ nằm đè lên lớp sáng phủ màn

	# 1) Đầu bếp chạy về cửa quán, nhỏ dần (đi xa). 2) Gần tới thì cửa mở, ánh sáng loá bùng.
	# 3) Đầu bếp bước vào ánh sáng, khuất sau cửa. 4) Ánh sáng tràn phủ kín màn rồi vào game.
	var door := _land_to_screen(RESTAURANT_DOOR)
	var run_seconds := clampf(absf(door.x - chef.center_x()) / KitchenActor.WALK_SPEED, 0.12, KitchenActor.MAX_WALK_SECONDS)
	chef.walk_to(door.x) # walk_to tự phát animation chạy và quay mặt đúng hướng
	var shrink := chef.create_tween().set_parallel(true)
	shrink.tween_property(chef, "scale", Vector2.ONE * CHEF_FAR_SCALE, run_seconds).set_ease(Tween.EASE_IN)
	shrink.tween_property(chef, "position:y", door.y - KitchenActor.SIZE, run_seconds).set_trans(Tween.TRANS_SINE)

	get_tree().create_timer(maxf(0.0, run_seconds - DOOR_OPEN_LEAD)).timeout.connect(_open_door)

	# Càng tới gần cửa càng mờ và ám màu ánh đèn, bước qua cửa thì tan hẳn vào ánh sáng.
	var fade_start := run_seconds * CHEF_FADE_FROM
	var step_in := chef.create_tween()
	step_in.tween_interval(fade_start)
	step_in.tween_property(chef, "modulate", Color(LIGHT_COLOR, 0.0), run_seconds - fade_start + STEP_IN_SECONDS) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var step_shrink := chef.create_tween()
	step_shrink.tween_interval(run_seconds)
	step_shrink.tween_property(chef, "scale", Vector2.ONE * CHEF_FAR_SCALE * 0.8, STEP_IN_SECONDS).set_trans(Tween.TRANS_SINE)

	var fade := ColorRect.new()
	fade.color = Color(FLASH_COLOR, 0.0)
	fade.mouse_filter = MOUSE_FILTER_STOP
	fade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(fade)
	var fill_at := run_seconds + STEP_IN_SECONDS * 0.5 # màn sáng dần lúc đầu bếp sắp tan hẳn
	var tween := fade.create_tween()
	tween.tween_interval(fill_at)
	tween.tween_callback(_flood_light)
	tween.tween_property(fade, "color:a", 1.0, FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(start)


## Ánh sáng từ cửa nở to tràn ra cả màn (màn trắng phủ theo cùng lúc).
func _flood_light() -> void:
	for t in _light_tweens:
		if t.is_valid():
			t.kill()
	for light in _door_lights:
		var grow := light.create_tween().set_parallel(true)
		grow.tween_property(light, "scale", Vector2.ONE * 6.0, FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		grow.tween_property(light, "modulate:a", 1.0, FADE_SECONDS * 0.4).set_trans(Tween.TRANS_SINE)
