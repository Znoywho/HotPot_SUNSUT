class_name FxParticles
extends RefCounted
## Hạt pixel cho trận đánh, dùng CPUParticles2D (chạy được trên web / renderer Compatibility): tia lửa, "nước ép"
## bắn ra theo màu quái, hơi nước, bọt độc, than hồng, và vỡ vụn sprite thành hạt bốc hơi khi quái gục.
## Hạt là ô vuông 1 px phóng to (4-8 px), lọc nearest cho đúng chất pixel; độ trong tắt theo bậc, không mượt.
## Hạt một lần (burst, disintegrate) tự xoá khi xong. Hạt cũng chậm theo Engine.time_scale nên đứng hình cùng hitstop.

static var _pixel: ImageTexture
static var _fade: Gradient


static func pixel_texture() -> Texture2D:
	if _pixel == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_pixel = ImageTexture.create_from_image(img)
	return _pixel


## Độ trong theo bậc (kiểu pixel): rõ hẳn -> mờ 60% -> tắt.
static func fade_ramp() -> Gradient:
	if _fade == null:
		_fade = Gradient.new()
		_fade.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		_fade.offsets = PackedFloat32Array([0.0, 0.62, 0.84])
		_fade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	return _fade


static func _make(amount: int, life: float, one_shot: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = pixel_texture()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.lifetime_randomness = 0.35
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.local_coords = false
	p.color_ramp = fade_ramp()
	return p


static func _launch(layer: Node, p: CPUParticles2D, global_pos: Vector2) -> void:
	layer.add_child(p)
	p.global_position = global_pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	# Lưới an toàn: lỡ "finished" không tới thì vẫn xoá sau một lúc (nối thẳng vào queue_free: hạt mất trước thì
	# Godot tự ngắt kết nối, không lỗi).
	layer.get_tree().create_timer(p.lifetime * 3.0 + 1.0).timeout.connect(p.queue_free)


## Tia lửa / nước ép bắn ra một lần từ `global_pos` theo hướng `dir` (xoè `spread` độ), rơi theo `gravity`.
static func burst(layer: Node, global_pos: Vector2, color: Color, amount := 8, dir := Vector2.UP, spread := 60.0, speed := Vector2(140, 300), gravity := 700.0, life := 0.45, size := Vector2(4, 8)) -> CPUParticles2D:
	var p := _make(amount, life, true)
	p.direction = dir.normalized()
	p.spread = spread
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector2(0, gravity)
	p.damping_min = 30.0
	p.damping_max = 90.0
	p.scale_amount_min = size.x
	p.scale_amount_max = size.y
	p.color = color
	p.hue_variation_min = -0.03
	p.hue_variation_max = 0.03
	_launch(layer, p, global_pos)
	return p


## Vỡ sprite thành hạt cùng màu từng pixel rồi bốc lên như hơi nồi lẩu (quái gục). Hạt to bằng `step` pixel ảnh.
## Theo đúng vị trí / góc nghiêng hiện tại của sprite (đang ngã nghiêng cũng được).
static func disintegrate(layer: Node, sprite: TextureRect, step := 2) -> CPUParticles2D:
	var tex := sprite.texture
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	var tex_size := Vector2(img.get_size())
	var k := minf(sprite.size.x / tex_size.x, sprite.size.y / tex_size.y) # STRETCH_KEEP_ASPECT_CENTERED
	var origin := (sprite.size - tex_size * k) / 2.0
	var xf := sprite.get_global_transform()
	var center := xf * (sprite.size / 2.0)
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			points.append(xf * (origin + (Vector2(x, y) + Vector2.ONE * step * 0.5) * k) - center)
			colors.append(Color(c.r, c.g, c.b, 1.0))
	if points.is_empty():
		return null
	var p := _make(points.size(), 0.95, true)
	p.explosiveness = 0.8
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = points
	p.emission_colors = colors
	p.direction = Vector2.UP
	p.spread = 40.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, -170) # bay lên như hơi nước
	p.damping_min = 10.0
	p.damping_max = 40.0
	p.scale_amount_min = k * step
	p.scale_amount_max = k * step
	_launch(layer, p, center)
	return p


## Hạt chạy liên tục quanh đơn vị (gắn làm con, tự canh vị trí): "poison" bọt xanh, "burn" than hồng, "rage" tia đỏ.
## `area`: khung phát hạt (px). Tắt bằng emitting = false rồi xoá.
static func ambient(kind: String, area: Vector2) -> CPUParticles2D:
	var p := _make(6, 1.0, false)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area / 2.0
	p.direction = Vector2.UP
	p.spread = 20.0
	match kind:
		"poison":
			p.amount = 6
			p.lifetime = 1.1
			p.gravity = Vector2(0, -45)
			p.initial_velocity_min = 5.0
			p.initial_velocity_max = 20.0
			p.color = Color("9be36a")
			p.scale_amount_min = 4.0
			p.scale_amount_max = 8.0
		"burn":
			p.amount = 9
			p.lifetime = 0.7
			p.gravity = Vector2(0, -140)
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 40.0
			p.color = Color("ff9a3a")
			p.hue_variation_min = -0.06
			p.hue_variation_max = 0.02
			p.scale_amount_min = 4.0
			p.scale_amount_max = 6.0
		_:
			p.amount = 8
			p.lifetime = 0.6
			p.gravity = Vector2(0, -120)
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 50.0
			p.color = Color("ff4a3a")
			p.scale_amount_min = 4.0
			p.scale_amount_max = 6.0
	p.emitting = true
	return p
