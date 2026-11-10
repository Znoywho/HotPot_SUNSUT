class_name SpriteFrameLayer
extends TextureRect
## Lớp phát animation theo khung, đặt làm con của sprite nhân vật (32x32 phóng to).
## Khi phát thì ẩn hình tĩnh của sprite cha, xong thì hiện lại; co giãn, xoay, nháy màu của cha vẫn áp dụng.
## Sheet tạo bằng tools/make_character_anim.py: <tên>_anim.png cạnh <tên>.png.

signal animation_finished

const SOURCE_FRAME := 32.0 ## Cỡ hình tĩnh gốc.
const FRAME := 56.0 ## Cỡ mỗi khung trong sheet (thêm lề cho muôi, vệt chém).
## Thứ tự hàng và số khung phải khớp với tools/make_character_anim.py.
const ANIMATIONS := {
	"run": {"row": 0, "frames": 4, "fps": 8.0, "loop": true},
	"ninja": {"row": 1, "frames": 6, "fps": 18.0, "loop": true},
	"attack": {"row": 2, "frames": 6, "fps": 16.0, "loop": false},
	"slice": {"row": 3, "frames": 7, "fps": 18.0, "loop": false},
	"splash": {"row": 4, "frames": 7, "fps": 14.0, "loop": false},
}

var _owner_sprite: TextureRect
var _atlas: AtlasTexture
var _current := ""
var _elapsed := 0.0


## Tìm sheet animation đi kèm hình tĩnh; không có thì trả về null.
static func sheet_for(still: Texture2D) -> Texture2D:
	if still == null or still.resource_path.is_empty():
		return null
	var path := still.resource_path.trim_suffix(".png") + "_anim.png"
	return load(path) if ResourceLoader.exists(path) else null


## Gắn lớp vào sprite nhân vật; trả về null nếu nhân vật không có sheet.
static func attach_to(sprite: TextureRect) -> SpriteFrameLayer:
	var sheet := sheet_for(sprite.texture)
	if sheet == null:
		return null
	var layer := SpriteFrameLayer.new()
	layer._setup(sprite, sheet)
	return layer


## Đặt kích thước theo tỉ lệ phóng to của sprite cha để khung trùng khít với hình tĩnh.
func _setup(sprite: TextureRect, sheet: Texture2D) -> void:
	_owner_sprite = sprite
	_atlas = AtlasTexture.new()
	_atlas.atlas = sheet
	texture = _atlas
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var pixel_scale := sprite.size.x / SOURCE_FRAME
	size = Vector2.ONE * FRAME * pixel_scale
	position = -Vector2.ONE * (FRAME - SOURCE_FRAME) / 2.0 * pixel_scale
	sprite.add_child(self)


## Godot tự bật _process khi node vào cây, nên phải tắt ở đây cho tới khi play().
func _ready() -> void:
	set_process(false)


## Sheet có hàng này không (sheet nhân viên chỉ có hàng chạy và ninja).
func has_animation(anim_name: String) -> bool:
	if not ANIMATIONS.has(anim_name):
		return false
	var rows := int(_atlas.atlas.get_height() / FRAME)
	return int(ANIMATIONS[anim_name]["row"]) < rows


## Phát một chuyển động từ đầu.
func play(anim_name: String) -> void:
	if not has_animation(anim_name):
		return
	_current = anim_name
	_elapsed = 0.0
	flip_h = _owner_sprite.flip_h
	visible = true
	_owner_sprite.self_modulate.a = 0.0
	_show_frame(0)
	set_process(true)


## Dừng và trả về hình tĩnh.
func stop() -> void:
	_current = ""
	visible = false
	set_process(false)
	if _owner_sprite != null:
		_owner_sprite.self_modulate.a = 1.0


func _process(delta: float) -> void:
	var info: Dictionary = ANIMATIONS[_current]
	_elapsed += delta
	var index := int(_elapsed * float(info["fps"]))
	if index >= int(info["frames"]) and not info["loop"]:
		stop()
		animation_finished.emit()
		return
	_show_frame(index % int(info["frames"]))


## Chọn vùng ảnh của khung: x = cột × FRAME, y = hàng × FRAME.
func _show_frame(column: int) -> void:
	var row := int(ANIMATIONS[_current]["row"])
	_atlas.region = Rect2(column * FRAME, row * FRAME, FRAME, FRAME)
