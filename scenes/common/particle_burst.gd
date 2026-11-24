class_name ParticleBurst
## Bắn một chùm hạt (CPUParticles2D) đúng một lần rồi tự xoá; mỗi hạt là một khung cắt từ sprite sheet trong assets/sprites/fx/.
## Dùng CPUParticles2D (không phải GPUParticles2D) để chạy ổn trên bản web WebGL 2 và điện thoại.
## Dùng: ParticleBurst.play(self, ParticleBurst.SPARKLE, card.get_global_rect().get_center())

const DIR := "res://assets/sprites/fx/"

## Sao vàng lấp lánh bung ra rồi rơi nhẹ: mua đồ, đạt KPI.
const SPARKLE := {
	"sheet": "bonk_star", "frames": 4, "frame": 2,
	"amount": 14, "lifetime": 0.8, "speed": 260.0, "gravity": 420.0, "damping": 80.0, "scale": 3.0,
}
## Bụi toả ngang sát mặt giấy: con dấu đập xuống sổ.
const DUST := {
	"sheet": "dust", "frames": 5, "frame": 1,
	"amount": 8, "lifetime": 0.5, "speed": 220.0, "gravity": 0.0, "damping": 380.0, "scale": 2.0,
}


## Bắn chùm hạt `preset` tại vị trí global `global_center`, gắn vào `parent`; chạy cả lúc game tạm dừng, xong thì tự xoá.
static func play(parent: Node, preset: Dictionary, global_center: Vector2) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.texture = _frame_texture(preset)
	particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particles.process_mode = Node.PROCESS_MODE_ALWAYS # màn tổng kết mở đè lên màn bán đang pause
	particles.one_shot = true
	particles.explosiveness = 1.0 # bắn hết hạt cùng lúc
	particles.amount = preset.amount
	particles.lifetime = preset.lifetime
	particles.spread = 180.0 # toả đều mọi hướng
	particles.initial_velocity_min = preset.speed * 0.5
	particles.initial_velocity_max = preset.speed
	particles.gravity = Vector2(0.0, preset.gravity)
	particles.damping_min = preset.damping
	particles.damping_max = preset.damping
	particles.scale_amount_min = preset.scale * 0.7
	particles.scale_amount_max = preset.scale
	particles.color_ramp = _fade_out_ramp()
	parent.add_child(particles)
	particles.global_position = global_center
	particles.finished.connect(particles.queue_free)
	particles.emitting = true
	return particles


## Cắt khung số `frame` từ sheet xếp ngang (các khung rộng bằng nhau) thành một texture riêng cho hạt.
static func _frame_texture(preset: Dictionary) -> AtlasTexture:
	var sheet: Texture2D = load(DIR + preset.sheet + ".png")
	var frame_width := sheet.get_width() / int(preset.frames)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(frame_width * int(preset.frame), 0, frame_width, sheet.get_height())
	return atlas


## Màu hạt theo tuổi: giữ nguyên tới 60% đời rồi mờ dần về trong suốt.
static func _fade_out_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.6, Color.WHITE)
	return ramp
