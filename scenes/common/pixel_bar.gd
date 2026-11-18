class_name PixelBar
extends TextureProgressBar
## Thanh tiến độ pixel dùng chung cho cả game, cùng kiểu thanh KPI trong sổ tổng kết
## (ảnh assets/sprites/ui/book/bar_*.png: rãnh nâu, phần đầy 3 tông màu, bóng đổ dưới chân).
## Dùng: var bar := PixelBar.new(PixelBar.GREEN); bar.value = 40. Đổi màu: bar.fill_color = PixelBar.RED.
## Màu GREEN / RED / GOLD dùng đúng ảnh của sổ; màu khác tự tạo 3 tông (sáng / thân / tối) từ khuôn bar_fill_white.png.
## Cao bao nhiêu cũng được: chỉ các hàng giữa của ảnh bị kéo dãn nên viền pixel không méo.

const GREEN := Color("66bb6a") ## Đạt / máu phe ta.
const RED := Color("ff7b6b") ## Trượt / máu quái.
const GOLD := Color("ffcc4d") ## Vượt mức / hoàn thành.
const UNDER := preload("res://assets/sprites/ui/book/bar_under.png")
const WHITE_FILL := preload("res://assets/sprites/ui/book/bar_fill_white.png")
const FILL_TEXTURES := {
	GREEN: preload("res://assets/sprites/ui/book/bar_fill_pass.png"),
	RED: preload("res://assets/sprites/ui/book/bar_fill_fail.png"),
	GOLD: preload("res://assets/sprites/ui/book/bar_fill_over.png"),
}
const SHADOW := Color(0, 0, 0, 0.25)

const LIGHTEN := 0.3 ## Dải sáng phía trên = màu chọn sáng thêm 30% (như vàng nhạt trên thanh GOLD).
const DARKEN := 0.22 ## Dải tối phía dưới = màu chọn tối đi 22%.

static var _custom_fills := {} ## Color -> ImageTexture đã tạo, dùng lại cho thanh cùng màu.

## Màu phần đầy; đổi lúc nào cũng được.
var fill_color := GREEN:
	set(value):
		fill_color = value
		texture_progress = FILL_TEXTURES[value] if FILL_TEXTURES.has(value) else _custom_fill(value)


## Ảnh phần đầy cho màu tùy chọn: tô 3 tông của bar_fill_white.png theo màu chọn.
## Xám 255 = dải sáng (color sáng thêm LIGHTEN), xám 230 = thân (đúng color), tối hơn = dải tối (color tối đi DARKEN).
static func _custom_fill(color: Color) -> ImageTexture:
	if not _custom_fills.has(color):
		var image := WHITE_FILL.get_image()
		image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		for y in image.get_height():
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				if pixel.a == 0.0:
					continue
				var tone := color.lightened(LIGHTEN) if pixel.r > 0.95 else (color if pixel.r > 0.85 else color.darkened(DARKEN))
				image.set_pixel(x, y, Color(tone, pixel.a))
		_custom_fills[color] = ImageTexture.create_from_image(image)
	return _custom_fills[color]


## Tạo thanh với màu cho trước, cao mặc định 20px như trong sổ.
func _init(color := GREEN) -> void:
	texture_under = UNDER
	fill_color = color
	nine_patch_stretch = true
	stretch_margin_left = 20 # đầu bo tròn bên trái
	stretch_margin_right = 16
	stretch_margin_top = 4 # hàng 4..13 cùng màu, chỉ kéo dãn đoạn đó
	stretch_margin_bottom = 6
	custom_minimum_size = Vector2(0, 20)
	mouse_filter = MOUSE_FILTER_IGNORE
	_add_shadow(6, 0, 3) # bóng rộng sát chân thanh
	_add_shadow(30, 3, 2) # bóng hẹp mờ hơn bên dưới


## Một dải bóng đổ dưới chân thanh: thụt vào inset px mỗi bên, cách chân top px, dày height px.
func _add_shadow(inset: float, top: float, height: float) -> void:
	var shadow := ColorRect.new()
	shadow.color = SHADOW
	shadow.show_behind_parent = true
	shadow.mouse_filter = MOUSE_FILTER_IGNORE
	shadow.anchor_top = 1.0
	shadow.anchor_right = 1.0
	shadow.anchor_bottom = 1.0
	shadow.offset_left = inset
	shadow.offset_right = -inset
	shadow.offset_top = top
	shadow.offset_bottom = top + height
	add_child(shadow)
