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
	# Tự vẽ bằng assets/sprites/fx/make_combat_fx.py:
	"impact_star": [32, 5, 24.0, 3.0], ## Tia chạm lúc đòn trúng.
	"slash_arc": [48, 5, 22.0, 3.0], ## Vệt smear lưỡi dao (Cắt thái), xoay chéo thành chữ X.
	"bonk_star": [16, 4, 10.0, 3.0], ## Sao lấp lánh quanh đầu khi bị muôi gõ.
	"shockwave": [64, 6, 20.0, 3.0], ## Vòng xung kích: chí mạng, boss gục.
	"dust": [24, 5, 16.0, 3.0], ## Bụi dưới chân lúc bật người lao tới.
	"broth_blob": [12, 2, 8.0, 4.0], ## Giọt nước lẩu bay (Hất lẩu).
}



## Phát hiệu ứng tại vị trí global (tâm). Trả về Sprite2D (đã tự xóa khi xong).
## rotation (radian) và flip_h để xoay / lật hiệu ứng (vd 2 vệt chém chéo nhau).
static func play(layer: CanvasItem, fx_name: String, global_center: Vector2, scale := -1.0, tint := Color.WHITE, speed := 1.0, rotation := 0.0, flip_h := false) -> Sprite2D:
	var s := sprite(fx_name, scale)
	if s == null:
		return null
	var info: Array = FX[fx_name]
	s.modulate = tint
	s.rotation = rotation
	s.flip_h = flip_h
	layer.add_child(s)
	s.global_position = global_center
	var duration := (int(info[1]) / float(info[2])) / maxf(speed, 0.1)
	var t := s.create_tween()
	t.tween_property(s, "frame", int(info[1]) - 1, duration).from(0)
	t.tween_callback(s.queue_free)
	return s


## Sprite2D đã cắt khung của hiệu ứng nhưng chưa phát (tự điều khiển frame / vị trí, vd giọt lẩu bay, sao xoay).
static func sprite(fx_name: String, scale := -1.0) -> Sprite2D:
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
	var k: float = info[3] if scale < 0.0 else scale
	s.scale = Vector2(k, k)
	return s
