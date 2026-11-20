class_name QualityTitle
extends TextureRect
## Chữ tên chất lượng kiểu pixel, mỗi mức một phong cách:
## - Thượng hạng (2): vàng viền nâu, từng chữ gợn sóng, tia lấp lánh quanh chữ.
## - Thường (1): cam viền nâu, đứng yên.
## - Kém (0): xám, bóng xanh rêu, chữ run run.
## Cách làm: vẽ chữ Be Vietnam Pro cỡ nhỏ, tắt khử răng cưa, trong một SubViewport trong suốt, rồi phóng to ×PIXEL
## bằng lọc "nearest" -> nét răng cưa vuông như chữ pixel mà vẫn đủ dấu tiếng Việt (font pixel thường thiếu dấu).

const PIXEL := 3.0 ## Mỗi điểm ảnh của chữ nhỏ = 3×3 điểm trên màn.
const FONT_SIZE := 14
const PAD := 4 ## Lề trong khung chữ nhỏ: chừa chỗ cho viền, bóng và biên độ sóng / rung.
const BOLD_FONT := preload("res://assets/fonts/BeVietnamPro-Bold.ttf")
const STYLES := [
	{"color": Color("a39d90"), "outline": Color("2e2a24"), "shadow": Color("55702c"), "bbcode": "[shake rate=7.0 level=12 connected=1]%s[/shake]"},
	{"color": Color("f2a33a"), "outline": Color("5a2d0c"), "shadow": Color("b06f2e"), "bbcode": "%s"},
	{"color": Color("ffd54f"), "outline": Color("5a3300"), "shadow": Color("c98a1b"), "bbcode": "[wave amp=26.0 freq=3.0 connected=1]%s[/wave]"},
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
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _grade != 1 else SubViewport.UPDATE_ONCE
	add_child(viewport)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.position = Vector2(PAD, PAD - 1)
	label.size = Vector2(small) - Vector2(PAD, PAD)
	label.add_theme_font_override("normal_font", font)
	label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	label.add_theme_color_override("default_color", style["color"])
	label.add_theme_color_override("font_outline_color", style["outline"])
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_shadow_color", style["shadow"])
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 3)
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
