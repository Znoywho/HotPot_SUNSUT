class_name HuntFX
extends RefCounted
## Phát hiệu ứng sprite sheet (nổ, chém, lửa...) một lần rồi tự xóa.
## Sheet xếp khung theo hàng ngang. Thêm hiệu ứng mới: bỏ PNG vào assets/sprites/fx/ và khai báo ở FX.

const DIR := "res://assets/sprites/fx/"

## tên -> [rộng khung, số khung, khung/giây, độ phóng mặc định]
const FX := {
	"slash": [16, 5, 18.0, 5.0],
	"flame": [16, 6, 14.0, 4.0],
	"poison": [16, 6, 12.0, 4.0],
	"heal": [16, 6, 12.0, 4.0],
	"shield": [16, 5, 12.0, 5.0],
	"burst": [48, 7, 16.0, 2.4], ## Ansimuz – chí mạng.
	"explosion_fire": [64, 8, 14.0, 2.4], ## Ansimuz – kết liễu boss.
	"explosion_big": [128, 12, 16.0, 2.2], ## Ansimuz – bò tót phát nổ.
	"smoke": [80, 12, 18.0, 1.8], ## Ansimuz – quái gục.
	"splash_broth": [64, 7, 14.0, 2.0], ## Ansimuz (water blob, đổi màu sang nước lẩu) – hất lẩu, nồi sôi.
}



## Phát hiệu ứng tại vị trí global (tâm). Trả về Sprite2D (đã tự xóa khi xong).
static func play(layer: CanvasItem, fx_name: String, global_center: Vector2, scale := -1.0, tint := Color.WHITE, speed := 1.0) -> Sprite2D:
	if not FX.has(fx_name):
		return null
	var info: Array = FX[fx_name]
	var path := DIR + fx_name + ".png"
	if not ResourceLoader.exists(path):
		return null
	var s := Sprite2D.new()
	s.texture = load(path)
	s.hframes = int(info[1])
	s.frame = 0
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.modulate = tint
	var k: float = info[3] if scale < 0.0 else scale
	s.scale = Vector2(k, k)
	layer.add_child(s)
	s.global_position = global_center
	var duration := (int(info[1]) / float(info[2])) / maxf(speed, 0.1)
	var t := s.create_tween()
	t.tween_property(s, "frame", int(info[1]) - 1, duration).from(0)
	t.tween_callback(s.queue_free)
	return s
