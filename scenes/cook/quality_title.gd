class_name QualityTitle
extends TextureRect
## Chữ tên chất lượng kiểu pixel, mỗi mức một phong cách:
## - Thượng hạng (2): vàng viền nâu đậm, từng chữ gợn sóng nhẹ, tia lấp lánh quanh chữ.
## - Thường (1): cam viền nâu đậm, đứng yên.
## - Kém (0): xám xanh rêu viền đen, cả chữ lắc lư chậm (lắc cả khối nên không bao giờ bị cắt mép).
## Cách làm: vẽ chữ Be Vietnam Pro cỡ nhỏ, tắt khử răng cưa, trong một SubViewport trong suốt, rồi phóng to ×PIXEL
## bằng lọc "nearest" -> nét răng cưa vuông như chữ pixel mà vẫn đủ dấu tiếng Việt (font pixel thường thiếu dấu).

const PIXEL := 2.0 ## Mỗi điểm ảnh của chữ nhỏ = 2×2 điểm trên màn.
const FONT_SIZE := 20 ## Đủ lớn để dấu tiếng Việt (ượ, ạ, é) không vỡ khi tắt khử răng cưa.
const PAD := 7 ## Lề trong khung chữ nhỏ: viền (2) + bóng (2) + biên độ sóng (~2), dư 1 cho chắc.
const SWAY_DEGREES := 4.0 ## Kém: góc lắc lư mỗi bên.
const SWAY_SECONDS := 1.1 ## Kém: thời gian lắc từ bên này sang bên kia.
const BOLD_FONT := preload("res://assets/fonts/BeVietnamPro-Bold.ttf")
## Viền và bóng đều tối để chữ nổi rõ trên nền giấy; màu chữ là thứ duy nhất khác nhau giữa các mức (kèm hiệu ứng).
const STYLES := [
	{"color": Color("b7c29a"), "outline": Color("231f1a"), "shadow": Color(0.14, 0.12, 0.1, 0.55), "bbcode": "%s"},
	{"color": Color("ffb64d"), "outline": Color("3d1d08"), "shadow": Color(0.24, 0.11, 0.03, 0.55), "bbcode": "%s"},
	{"color": Color("ffe066"), "outline": Color("3d2300"), "shadow": Color(0.24, 0.14, 0.0, 0.55), "bbcode": "[wave amp=18.0 freq=2.5 connected=1]%s[/wave]"},
]
const SPARKLE_COLOR := Color("fff6c0")

static var _pixel_font: FontFile ## Bản sao font đậm, tắt khử răng cưa (dùng chung mọi QualityTitle).

var _grade := 1
var _time := 0.0
var _sparkles: Control


## `grade`: 0 Kém, 1 Thường, 2 Thượng hạng; `text`: chữ hiển thị (thường là GameState.QUALITY_NAMES[grade]).
func _init(grade: int, text: String) -> void:
	_grade = clampi(grade, 0, 2)
	var style: Dictionary = STYLES[_grade]
	var font := _font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var small := Vector2i(ceili(text_size.x) + PAD * 2, ceili(font.get_height(FONT_SIZE)) + PAD * 2)

	var viewport := SubViewport.new()
	viewport.size = small
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _grade == 2 else SubViewport.UPDATE_ONCE
	add_child(viewport)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_contents = false # để viền / bóng / sóng tràn ra lề PAD thay vì bị cắt
	label.position = Vector2(PAD, PAD)
	label.size = Vector2(small) - Vector2(PAD, PAD) * 2.0
	label.add_theme_font_override("normal_font", font)
	label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	label.add_theme_color_override("default_color", style["color"])
	label.add_theme_color_override("font_outline_color", style["outline"])
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_shadow_color", style["shadow"])
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 4)
	label.text = str(style["bbcode"]) % text
	viewport.add_child(label)

	texture = viewport.get_texture()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	custom_minimum_size = Vector2(small) * PIXEL
	mouse_filter = MOUSE_FILTER_IGNORE

	if _grade == 2:
		_sparkles = Control.new()
		_sparkles.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_sparkles.mouse_filter = MOUSE_FILTER_IGNORE
		_sparkles.draw.connect(_draw_sparkles)
		add_child(_sparkles)


## Font đậm tắt khử răng cưa, tạo một lần rồi dùng lại.
static func _font() -> FontFile:
	if _pixel_font == null:
		_pixel_font = BOLD_FONT.duplicate() as FontFile
		_pixel_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_pixel_font.hinting = TextServer.HINTING_NONE
		_pixel_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _pixel_font


## Godot tự bật _process khi node vào cây nếu script có _process, nên phải tắt ở đây chứ không phải trong _init.
func _ready() -> void:
	set_process(_grade == 2)
	if _grade == 0:
		pivot_offset = custom_minimum_size / 2.0
		var t := create_tween().set_loops()
		t.tween_property(self, "rotation_degrees", SWAY_DEGREES, SWAY_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).from(-SWAY_DEGREES)
		t.tween_property(self, "rotation_degrees", -SWAY_DEGREES, SWAY_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	_time += delta
	_sparkles.queue_redraw()


## Tia lấp lánh hình dấu cộng ở 4 góc chữ (đơn vị = điểm ảnh chữ nhỏ); mỗi tia nhấp nháy lệch pha:
## hiện khi sin > 0, tỏa 4 cánh khi sin > 0,6.
func _draw_sparkles() -> void:
	var small := custom_minimum_size / PIXEL
	var spots := [Vector2(1, 2), Vector2(small.x - 2, 1), Vector2(small.x * 0.55, small.y - 2), Vector2(small.x * 0.2, small.y - 1)]
	for i in spots.size():
		var s := sin(_time * 4.0 + i * 1.9)
		if s <= 0.0:
			continue
		var p: Vector2 = (spots[i] as Vector2).floor()
		_sparkle_cell(p)
		if s > 0.6:
			for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				_sparkle_cell(p + dir)


## Tô một điểm ảnh lấp lánh (đã phóng to ×PIXEL).
func _sparkle_cell(p: Vector2) -> void:
	_sparkles.draw_rect(Rect2(p * PIXEL, Vector2(PIXEL, PIXEL)), SPARKLE_COLOR)
