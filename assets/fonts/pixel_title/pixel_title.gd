class_name PixelTitle
extends RefCounted
## Font pixel mập tự vẽ (make_pixel_title_font.py) cho MỌI chữ in hoa của game: chữ IN HOA tiếng Việt đủ dấu,
## số 0-9, "đ" (tiền), ". , : · ! ? - – + % / ( ) » « › ‹". Không có chữ thường khác: chữ thường giữ Be Vietnam Pro.
## Hai bộ cùng độ dày nét: bộ LỚN (chữ hoa cao 12 px ảnh) và bộ NHỎ (cao 8, font small_*).
## - Tiêu đề có bảng màu riêng (morning, noon, evening...): apply_rich / apply_label.
## - Nhãn / nút giao diện: style(control, cỡ chữ cũ) chọn bộ + độ phóng nguyên lần gần nhất và dùng chữ TRẮNG để
##   Godot nhuộm theo màu chữ sẵn có của màn đó (font_color / modulate): "white" có viền tối vẽ sẵn, "plain" không viền.
## Màu, viền, bóng đã vẽ trong ảnh font nên không dùng viền động của Godot. Cỡ chữ luôn là bội NGUYÊN của cỡ gốc
## (NATIVE_SIZE / SMALL_NATIVE_SIZE) để mỗi điểm ảnh của font thành ô vuông đều nhau.

const NATIVE_SIZE := 25 ## = "size" trong .fnt: chiều cao dòng gốc (px ảnh), Godot phóng theo cỡ chữ / NATIVE_SIZE.
const SMALL_NATIVE_SIZE := 21 ## Chiều cao dòng gốc của bộ nhỏ (small_*.fnt).
const FONTS := {
	"morning": preload("res://assets/fonts/pixel_title/morning.fnt"), ## Sáng: kem bơ -> đào -> cam (bình minh).
	"noon": preload("res://assets/fonts/pixel_title/noon.fnt"), ## Trưa: trắng vàng -> vàng -> hổ phách.
	"evening": preload("res://assets/fonts/pixel_title/evening.fnt"), ## Chiều tối: hồng cam -> san hô -> mận (hoàng hôn).
	"shop": preload("res://assets/fonts/pixel_title/shop.fnt"), ## Cửa hàng: bạc hà -> ngọc -> lam (rạng đông).
	"game_over": preload("res://assets/fonts/pixel_title/game_over.fnt"), ## Game Over: đỏ cam -> đỏ -> đỏ rượu (biển tắt đèn). Cũng là số sát thương.
	"heal": preload("res://assets/fonts/pixel_title/heal.fnt"), ## Số hồi máu trong trận: xanh lá.
	"armor": preload("res://assets/fonts/pixel_title/armor.fnt"), ## Số giáp trong trận: xanh dương.
	"white": preload("res://assets/fonts/pixel_title/white.fnt"), ## Chữ trắng có viền: nhuộm theo màu chữ (nhãn, nút, chữ báo trong trận).
	"plain": preload("res://assets/fonts/pixel_title/plain.fnt"), ## Chữ trắng không viền: nhuộm theo màu chữ (chữ trên nền giấy).
	"small_white": preload("res://assets/fonts/pixel_title/small_white.fnt"), ## Bộ nhỏ, có viền.
	"small_plain": preload("res://assets/fonts/pixel_title/small_plain.fnt"), ## Bộ nhỏ, không viền.
}


static func font(variant: String) -> Font:
	return FONTS.get(variant, FONTS["noon"])


## Bảng màu theo buổi của thẻ chuyển cảnh.
static func for_phase(phase: int) -> String:
	match phase:
		DayManager.Phase.HUNT:
			return "morning"
		DayManager.Phase.SELL:
			return "evening"
		DayManager.Phase.SHOP:
			return "shop"
		DayManager.Phase.GAME_OVER:
			return "game_over"
	return "noon"


## Cỡ chữ (px) khi phóng `scale` lần.
static func size_for(scale: int) -> int:
	return NATIVE_SIZE * maxi(1, scale)


## Bề ngang (px) của chuỗi khi phóng `scale` lần, để đặt min width cho RichTextLabel không ngắt dòng.
static func text_width(text: String, variant: String, scale: int) -> float:
	return font(variant).get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, size_for(scale)).x


## Gắn font pixel cho RichTextLabel (chữ thường trong bbcode tự đổi sang in hoa là việc của người gọi).
static func apply_rich(label: RichTextLabel, variant: String, scale := 4) -> void:
	label.add_theme_font_override("normal_font", font(variant))
	label.add_theme_font_size_override("normal_font_size", size_for(scale))
	label.add_theme_color_override("default_color", Color.WHITE) # giữ nguyên màu vẽ sẵn
	label.add_theme_constant_override("outline_size", 0) # viền đã vẽ trong ảnh font
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Chuỗi là chữ IN HOA vẽ được trọn bằng font pixel không: có ít nhất 1 chữ in hoa và mọi ký tự (trừ dấu cách) đều
## có trong font (chữ in hoa, số, "đ" của tiền, dấu câu đã vẽ). Số tiền đứng riêng ("64.000đ") hay chuỗi có chữ thường
## -> false: giữ font thường (không lẫn kiểu chữ trong cùng một cột số liệu, không hiện ô vuông).
static func supports(text: String) -> bool:
	var f := font("white")
	var has_upper := false
	for i in text.length():
		var code := text.unicode_at(i)
		if code == 32:
			continue
		if not f.has_char(code):
			return false
		var ch := text[i]
		has_upper = has_upper or ch.to_lower() != ch
	return has_upper


## Bộ chữ + độ phóng cho cỡ chữ cũ (px của font thường): [bộ nhỏ?, độ phóng]. Chữ hoa cao lần lượt 12 / 16 / 24 / 36 / 48 px.
static func pick(font_size: int) -> Array:
	if font_size <= 18:
		return [false, 1]
	if font_size <= 28:
		return [true, 2]
	if font_size <= 46:
		return [false, 2]
	if font_size <= 64:
		return [false, 3]
	return [false, 4]


## Đổi chữ in hoa của nhãn / nút giao diện sang font pixel, cỡ gần với `font_size` cũ, GIỮ màu chữ hiện có
## (font trắng nhuộm theo font_color / modulate). outlined = viền tối vẽ sẵn (chữ trên nền tối / ảnh); false = trơn
## (chữ trên nền giấy). Label, Button (cả PixelButton) và RichTextLabel đều được.
static func style(control: Control, font_size: int, outlined := true) -> void:
	var choice := pick(font_size)
	var small: bool = choice[0]
	var key := ("small_" if small else "") + ("white" if outlined else "plain")
	var px := (SMALL_NATIVE_SIZE if small else NATIVE_SIZE) * int(choice[1])
	if control is RichTextLabel:
		control.add_theme_font_override("normal_font", font(key))
		control.add_theme_font_size_override("normal_font_size", px)
	else:
		control.add_theme_font_override("font", font(key))
		control.add_theme_font_size_override("font_size", px)
	control.add_theme_constant_override("outline_size", 0) # viền đã vẽ trong ảnh font
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Như style() nhưng chỉ đổi khi chuỗi vẽ được trọn bằng font pixel (dùng ở hàm dựng nhãn chung cho mọi chữ).
static func style_if_supported(control: Control, text: String, font_size: int, outlined := true) -> bool:
	if not supports(text):
		return false
	style(control, font_size, outlined)
	return true


## Gắn font pixel cho Label; text được đổi sang in hoa.
static func apply_label(label: Label, variant: String, scale := 4) -> void:
	label.text = label.text.to_upper()
	label.add_theme_font_override("font", font(variant))
	label.add_theme_font_size_override("font_size", size_for(scale))
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 0)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Hiệu ứng chữ [flicker]...[/flicker]: biển hiệu chập chờn lúc mới bật (mỗi chữ nháy theo lịch riêng, càng về cuối
## càng ít tắt) rồi sáng hẳn; riêng chữ thứ broken_index sáng yếu và thỉnh thoảng nháy, như bóng đèn sắp hỏng.
## Chỉ nhân màu <= 1 nên chạy được trên renderer Compatibility / bản web. elapsed_time tự về 0 khi đổi chữ.
class FlickerEffect extends RichTextEffect:
	const SETTLE := 1.2 ## Giây chập chờn lúc mới bật.
	const STEP := 0.06 ## Mỗi bao lâu bốc thăm bật / tắt một lần.
	const OFF_CHANCE := 0.65 ## Lúc đầu mỗi bước có chừng này phần tắt, giảm dần về 0 ở cuối SETTLE.
	const OFF := 0.4 ## Độ sáng khi tắt (vẫn đọc được).
	const BROKEN := 0.62 ## Độ sáng của chữ hỏng.
	const BROKEN_CYCLE := 3.2 ## Chữ hỏng nháy sáng lại một nhịp ngắn mỗi chừng này giây.

	var bbcode := "flicker"
	var delay := 0.0 ## Chờ bao lâu mới bật đèn (vd đợi biển gỗ rơi xong); trước đó chữ ở độ sáng OFF.
	var broken_index := -1 ## relative_index của chữ hỏng (-1: không có).

	func _process_custom_fx(fx: CharFXTransform) -> bool:
		var t := fx.elapsed_time - delay
		var i := fx.relative_index
		var k := 1.0
		if t < 0.0:
			k = OFF
		elif t < SETTLE:
			if _roll(i, int(t / STEP)) < OFF_CHANCE * (1.0 - t / SETTLE):
				k = OFF
		elif i == broken_index:
			var c := fmod(t - SETTLE, BROKEN_CYCLE)
			k = 1.0 if (c > BROKEN_CYCLE - 0.24 and int(c / STEP) % 2 == 0) else BROKEN
		fx.color = Color(fx.color.r * k, fx.color.g * k, fx.color.b * k, fx.color.a)
		return true

	static func _roll(i: int, step: int) -> float:
		return float(posmod(hash(Vector2i(i, step)), 1000)) / 1000.0
