class_name PixelButton
extends Button
## Nút pixel bát giác đỏ viền kem dùng chung cho mọi màn (menu chính, cài đặt, game over, cửa hàng...).
## Ảnh khung vẽ bằng tools/make_menu_art.py. Dùng: var b := PixelButton.new("CHƠI MỚI"); b.pressed.connect(...)
## Rê chuột thì sáng lên, bấm thì tối đi và chữ lún xuống; disabled thì xám.

const TEXTURES := {
	"normal": preload("res://assets/sprites/ui/button_red_normal.png"),
	"pressed": preload("res://assets/sprites/ui/button_red_pressed.png"),
	"disabled": preload("res://assets/sprites/ui/button_red_disabled.png"),
}
const TEXTURE_MARGIN := 20.0 ## Phần góc vát của ảnh (px) giữ nguyên khi kéo dãn nút.
const PRESS_DEPTH := 6.0 ## Chữ lún xuống chừng này px khi bấm.
const BOLD_FONT := preload("res://assets/fonts/BeVietnamPro-Bold.ttf")
const TEXT_COLOR := Color("fbecd2")
const TEXT_OUTLINE_COLOR := Color("461619")
const DEFAULT_SIZE := Vector2(340, 68) ## Quy tắc cảm ứng: nút cao >= 56px.


## Tạo nút với chữ và cỡ chữ cho trước.
func _init(label := "", font_size := 30) -> void:
	text = label
	custom_minimum_size = DEFAULT_SIZE
	add_theme_font_override("font", BOLD_FONT)
	add_theme_font_size_override("font_size", font_size)
	add_theme_constant_override("outline_size", 8)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		add_theme_color_override(color_name, TEXT_COLOR)
	add_theme_color_override("font_disabled_color", Color(TEXT_COLOR, 0.6))
	add_theme_color_override("font_outline_color", TEXT_OUTLINE_COLOR)
	add_theme_stylebox_override("normal", _make_style("normal"))
	add_theme_stylebox_override("hover", _make_style("normal", Color(1.15, 1.15, 1.15)))
	add_theme_stylebox_override("pressed", _make_style("pressed", Color.WHITE, PRESS_DEPTH))
	add_theme_stylebox_override("hover_pressed", _make_style("pressed", Color.WHITE, PRESS_DEPTH))
	add_theme_stylebox_override("disabled", _make_style("disabled"))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Khung nút từ ảnh pixel, kéo dãn phần giữa, giữ nguyên góc vát; push_down = chữ lún xuống khi bấm.
static func _make_style(state: String, tint := Color.WHITE, push_down := 0.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = TEXTURES[state]
	style.set_texture_margin_all(TEXTURE_MARGIN)
	style.modulate_color = tint
	style.content_margin_top = push_down # mặc định lấy lề ảnh (20px) làm chữ lệch lên, nên đặt lại
	style.content_margin_bottom = 0.0
	return style
