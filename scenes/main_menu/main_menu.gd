extends Control
## Menu chính: phong cảnh đồng quê nhiều lớp (trời, mặt trời, mây trôi, quán lẩu lớn trên đỉnh núi giữa),
## tên game ở trên, nút ở giữa, đầu bếp đứng bên phải, đống đồ bếp ở góc trái,
## 3 nhân viên vây quanh một con quái trên đồi phải thay nhau chém (quái gục thì con khác nhảy ra, lặp mãi).
## Ảnh vẽ bằng tools/make_menu_art.py.
## Các số chỉnh giao diện để @export: chọn node MainMenu trong editor là sửa được, không cần đụng code.

const SKY := preload("res://assets/sprites/scenery/sky.png")
const LANDSCAPE := preload("res://assets/sprites/scenery/landscape.png")
const KITCHEN_CLUTTER := preload("res://assets/sprites/scenery/kitchen_clutter.png")
const BUFFALO := preload("res://assets/sprites/characters/mount_buffalo.png") ## Trâu (thú cưỡi) có sẵn, nhìn sang phải.
const LAND_SIZE := Vector2(432, 180) ## Cỡ ảnh phong cảnh (điểm ảnh, rộng hơn 16:9 cho màn điện thoại); toạ độ nhân vật trên đồi tính theo ảnh này.
const SUN := preload("res://assets/sprites/scenery/sun.png")
const SUN_GLOW := preload("res://assets/sprites/scenery/sun_glow.png")
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
const STAFF_LUNGE := 28.0 ## Nhân viên lao tới chừng này px (ở cỡ gốc) khi chặt quái.
const PIXEL := 4.0 ## 1 điểm ảnh của bộ phong cảnh = 4 px màn hình (nền 320x180 trên 1280x720).
const BOLD_FONT := preload("res://assets/fonts/BeVietnamPro-Bold.ttf")
const RESTAURANT_DOOR := Vector2(216, 66) ## Cửa quán trên đỉnh núi (điểm ảnh phong cảnh): đầu bếp chạy về đây khi vào game.
const CHEF_FAR_SCALE := 0.25 ## Chạy tới cửa quán thì đầu bếp nhỏ còn chừng này (đi xa dần).
const FADE_DELAY := 0.5 ## Đầu bếp chạy được chừng này giây thì màn bắt đầu tối dần.
const FADE_SECONDS := 0.8

@export var title_text := "SÔI SÙNG SỤC"
@export var title_font_size := 72
@export var title_color := Color("f2a33a")
@export var chef_scale := 2.2 ## Đầu bếp gốc 128px, nhân thêm chừng này.
@export_range(0.0, 1.0) var chef_x_ratio := 0.87 ## Vị trí đầu bếp theo bề ngang màn hình.
@export_range(0.0, 1.0) var chef_feet_ratio := 0.94 ## Chân đầu bếp theo bề dọc màn hình.
## Toạ độ chân quái / nhân viên / bò tính bằng ĐIỂM ẢNH TRÊN PHONG CẢNH 432x180 (không phải px màn hình),
## nên màn rộng hay hẹp thì nhân vật vẫn đứng đúng trên đồi. Đồi phải: y = 70 + 0.005 * (x - 356)^2.
## Nhân viên đầu danh sách đứng phía sau quái (vẽ trước), mấy người sau đứng hai bên.
@export var monster_feet := Vector2(346, 92) ## Giữa mặt đồi phải (đỉnh đồi y = 70, chân đồi y = 112).
@export var staff_feet: Array[Vector2] = [Vector2(352, 87), Vector2(326, 94), Vector2(368, 94)]
@export var fight_scale := 0.5 ## Nhân vật trên đồi = cỡ gốc (32 điểm ảnh) nhân chừng này, vì ở xa.
@export var buffalo_feet: Array[Vector2] = [Vector2(66, 77), Vector2(88, 76.5), Vector2(108, 81)] ## Đồi trái.
@export var buffalo_scale := 0.45 ## Trâu gốc 32 điểm ảnh, ở xa nên thu nhỏ còn chừng này.
@export var buffalo_wander := 6.0 ## Trâu đi tới đi lui chừng này điểm ảnh.
@export var clutter_scale := 3.0 ## Đồ bếp góc trái phóng chừng này lần.
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
var _buttons: Array[PixelButton] = []
var _leaving := false ## Đang chạy hiệu ứng vào game: chặn bấm thêm lần nữa.
var _clouds: Array[TextureRect] = []
var _cloud_speeds: Array[float] = []


## Dựng toàn bộ giao diện bằng code, xếp từ xa tới gần.
func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_add_cover_layer(SKY)
	_build_sun()
	_build_clouds()
	_add_cover_layer(LANDSCAPE)
	_build_buffaloes()
	_build_clutter()
	_build_fight()
	_build_chef()
	_build_title()
	_build_buttons()
	add_child(RotateHint.new())


## Mây trôi sang phải, ra khỏi mép phải thì quay lại từ mép trái.
func _process(delta: float) -> void:
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


## Đống đồ bếp lộn xộn sát góc trái dưới.
func _build_clutter() -> void:
	var clutter := TextureRect.new()
	clutter.texture = KITCHEN_CLUTTER
	clutter.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clutter.size = KITCHEN_CLUTTER.get_size() * clutter_scale
	clutter.position = Vector2(clutter_margin.x, get_viewport_rect().size.y - clutter.size.y - clutter_margin.y)
	clutter.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(clutter)


## Một con quái giữa, nhân viên vây quanh quay mặt vào quái, mỗi người chém theo nhịp hẹn giờ riêng.
## Cỡ nhân vật theo tỉ lệ phóng phong cảnh để luôn cân với ngọn đồi.
func _build_fight() -> void:
	var size_scale := fight_scale * _land_scale() / PIXEL # nhân vật gốc 128px ứng với 32 điểm ảnh x PIXEL
	var monster_base := _land_to_screen(monster_feet)
	var monster_size := MONSTER_SIZE * size_scale
	var monster := HuntUI.texture_rect(MONSTER_TEXTURES[randi() % MONSTER_TEXTURES.size()], monster_size)
	monster.size = Vector2(monster_size, monster_size)
	monster.position = monster_base - Vector2(monster_size / 2.0, monster_size)
	monster.pivot_offset = Vector2(monster_size / 2.0, monster_size)
	monster.set_meta("hp", MONSTER_HP)
	monster.set_meta("home_x", monster.position.x) # chỗ đứng gốc cố định: nhiều đòn dồn dập không làm quái trôi

	for i in STAFF_TEXTURES.size():
		if i == 1:
			add_child(monster) # người đầu đứng sau quái, những người sau đứng trước
			_start_monster_idle(monster)
		var feet := _land_to_screen(staff_feet[i % staff_feet.size()])
		var staff := KitchenActor.new()
		add_child(staff)
		staff.setup(STAFF_TEXTURES[i], feet.x, feet.y, "", feet.x < monster_base.x)
		staff.pivot_offset = Vector2(KitchenActor.SIZE / 2.0, KitchenActor.SIZE)
		staff.scale = Vector2.ONE * size_scale
		staff.set_meta("home_x", staff.position.x)

		var timer := Timer.new()
		timer.wait_time = randf_range(1.2, 2.0)
		timer.timeout.connect(_staff_attack.bind(staff, monster))
		add_child(timer)
		timer.start(randf_range(0.2, 1.6))


## Quái nhún tại chỗ (co giãn quanh chân).
func _start_monster_idle(monster: TextureRect) -> void:
	var tween := monster.create_tween().set_loops()
	tween.tween_property(monster, "scale", Vector2(1.06, 0.92), 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(monster, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)


## Nhân viên lao tới chặt quái dưới đất (không bay lên chém để luôn đứng trên đồi), vệt chém hiện trên quái, rồi lùi về.
func _staff_attack(staff: KitchenActor, monster: TextureRect) -> void:
	var target := monster.get_global_rect().get_center()
	var direction := signf(target.x - staff.center_x())
	var home_x: float = staff.get_meta("home_x")
	var lunge := create_tween()
	lunge.tween_property(staff, "position:x", home_x + STAFF_LUNGE * staff.scale.x * direction, 0.1)
	lunge.tween_callback(staff.work.bind(0.3, "chop"))
	lunge.tween_callback(func() -> void: HuntFX.play(self, "slash", target, 5.0 * staff.scale.x))
	lunge.tween_callback(_hit_monster.bind(monster, direction))
	lunge.tween_interval(0.25)
	lunge.tween_property(staff, "position:x", home_x, 0.2)


## Quái trúng đòn: nháy trắng + bật lùi theo hướng đòn (direction = -1 sang trái, 1 sang phải);
## hết máu thì khói bốc lên và đổi sang quái khác.
func _hit_monster(monster: TextureRect, direction: float) -> void:
	if monster.get_meta("hp") <= 0:
		return # đang gục, chờ con mới nhảy ra
	var hp: int = monster.get_meta("hp") - 1
	monster.set_meta("hp", hp)
	var home_x: float = monster.get_meta("home_x")
	var tween := create_tween()
	tween.tween_property(monster, "modulate", Color(3, 3, 3), 0.05)
	tween.parallel().tween_property(monster, "position:x", home_x + 10.0 * direction, 0.08)
	tween.tween_property(monster, "modulate", Color.WHITE, 0.1)
	tween.parallel().tween_property(monster, "position:x", home_x, 0.15)
	if hp > 0:
		return
	HuntFX.play(self, "smoke", monster.get_global_rect().get_center(), 1.8 * monster.size.x / MONSTER_SIZE) # khói co theo cỡ quái trên đồi
	tween.tween_property(monster, "modulate:a", 0.0, 0.1)
	tween.tween_interval(0.6)
	tween.tween_callback(_respawn_monster.bind(monster))
	tween.tween_property(monster, "modulate:a", 1.0, 0.2)


## Quái mới nhảy ra cùng chỗ, đủ máu.
func _respawn_monster(monster: TextureRect) -> void:
	monster.texture = MONSTER_TEXTURES[randi() % MONSTER_TEXTURES.size()]
	monster.flip_h = randf() < 0.5
	monster.set_meta("hp", MONSTER_HP)


## Tên game chữ đậm, viền tối để đọc rõ trên nền trời.
func _build_title() -> void:
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", BOLD_FONT)
	title.add_theme_font_size_override("font_size", title_font_size)
	title.add_theme_color_override("font_color", title_color)
	title.add_theme_color_override("font_outline_color", Color("2b1a14"))
	title.add_theme_constant_override("outline_size", 14)
	add_child(title)
	title.set_anchors_and_offsets_preset(PRESET_TOP_WIDE, PRESET_MODE_MINSIZE, 16)


## Cột nút pixel ở giữa màn hình: Chơi mới, Tiếp tục, Thoát.
func _build_buttons() -> void:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", button_gap)
	add_child(list)

	_add_menu_button(list, "CHƠI MỚI", _enter_game.bind(DayManager.start_new_game))
	var continue_button := _add_menu_button(list, "TIẾP TỤC", _enter_game.bind(DayManager.continue_game))
	continue_button.disabled = not SaveManager.has_save()
	if not OS.has_feature("web"): # Trên web không thoát được tab, nên ẩn nút.
		_add_menu_button(list, "THOÁT", get_tree().quit)

	list.set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_MINSIZE)
	list.grow_horizontal = GROW_DIRECTION_BOTH
	list.grow_vertical = GROW_DIRECTION_BOTH
	list.position.y += buttons_offset_y


## Thêm một PixelButton (nút dùng chung) vào cột, cỡ theo button_size.
func _add_menu_button(parent: Control, text: String, callback: Callable) -> PixelButton:
	var button := PixelButton.new(text, menu_font_size)
	button.custom_minimum_size = button_size
	button.pressed.connect(callback)
	parent.add_child(button)
	_buttons.append(button)
	return button


## Hiệu ứng vào game: khoá nút, đầu bếp chạy về cửa quán trên đỉnh núi và nhỏ dần (đi xa),
## màn tối dần rồi mới gọi start (DayManager.start_new_game / continue_game). Cửa hàng tự sáng dần khi mở.
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
			child.stop() # ngừng đánh quái: hiệu ứng chém/khói tạo sau sẽ nằm đè lên màn tối

	var door := _land_to_screen(RESTAURANT_DOOR)
	var run_seconds := absf(door.x - chef.center_x()) / KitchenActor.WALK_SPEED
	chef.walk_to(door.x) # walk_to tự phát animation chạy và quay mặt đúng hướng
	var shrink := chef.create_tween().set_parallel(true)
	shrink.tween_property(chef, "scale", Vector2.ONE * CHEF_FAR_SCALE, run_seconds).set_ease(Tween.EASE_IN)
	shrink.tween_property(chef, "position:y", door.y - KitchenActor.SIZE, run_seconds).set_trans(Tween.TRANS_SINE)

	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = MOUSE_FILTER_STOP
	fade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(fade)
	var tween := fade.create_tween()
	tween.tween_interval(FADE_DELAY)
	tween.tween_property(fade, "color:a", 1.0, FADE_SECONDS)
	tween.tween_callback(start)

