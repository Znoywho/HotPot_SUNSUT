class_name HuntUI
extends RefCounted
## Tiện ích dựng UI cho màn săn: style, nút cảm ứng, đường dẫn sprite.
## Quy tắc cảm ứng: nút >= 56px, chữ >= 18px, không hover/tooltip.

const BUTTON_HEIGHT := 64
const FONT := 20
const FONT_SMALL := 18
const GOLD := Color("f2a33a") ## Chữ vàng viền đen, dùng trên nền khu săn.
const PANEL_BG := Color(0.12, 0.07, 0.05, 0.82)
const BACKGROUND := "res://assets/sprites/backgrounds/hunt_background.png"
const FALLBACK_SPRITE := "res://icon.svg"
const UI_DIR := "res://assets/sprites/ui/"

## Bảng màu "sổ giấy da" (chữ trên nền giấy).
const INK := Color("3b2416") ## Chữ thường.
const INK_SOFT := Color("7a5a44") ## Chữ phụ / mờ.
const RUST := Color("a3461a") ## Tiêu đề, điểm nhấn.
const TEAL := Color("2f6f68") ## Thông tin phụ (thú cưỡi...).
const GOOD := Color("2e7d32")
const WARN := Color("b26a00")
const BAD := Color("c62828")
const GOLDEN_INK := Color("b8860b") ## Đồ hoàng kim trên nền giấy.
const PIXEL_SCALE := 3 ## Khung UI được vẽ sẵn ở tỉ lệ x3.


static func item_name(id: String) -> String:
	return GameState.item_display_name(id)


static func describe_items(items: Dictionary) -> String:
	var parts: Array[String] = []
	for id in items:
		parts.append("%s x%d" % [item_name(id), int(items[id])])
	return ", ".join(parts)


static func panel_style(bg := PANEL_BG, border := Color(0, 0, 0, 0), radius := 10, border_width := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width if border.a > 0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


## Khung giấy da 9-slice (paper_panel, paper_card, paper_button...). Phần giữa lặp lại để giữ nét pixel.
static func paper_style(kind := "paper_panel", margin := 8, content := Vector2(16, 12)) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(UI_DIR + kind + ".png")
	var m := margin * PIXEL_SCALE
	s.texture_margin_left = m
	s.texture_margin_right = m
	s.texture_margin_top = m
	s.texture_margin_bottom = m
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	s.content_margin_left = content.x
	s.content_margin_right = content.x
	s.content_margin_top = content.y
	s.content_margin_bottom = content.y
	return s


## Chữ trên nền giấy: màu mực, không viền.
static func label(text: String, size := FONT, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Chữ đặt thẳng trên nền khu săn (trời, cỏ): có viền đen cho dễ đọc.
static func outlined_label(text: String, size := FONT, color := Color.WHITE) -> Label:
	var l := label(text, size, color)
	l.add_theme_color_override("font_outline_color", Color("1a0f0b"))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func button(text: String, min_width := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, BUTTON_HEIGHT)
	b.add_theme_font_size_override("font_size", FONT)
	b.focus_mode = Control.FOCUS_NONE
	var normal := paper_style("paper_button", 5, Vector2(14, 6))
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", paper_style("paper_button_pressed", 5, Vector2(14, 6)))
	b.add_theme_stylebox_override("hover_pressed", paper_style("paper_button_pressed", 5, Vector2(14, 6)))
	b.add_theme_stylebox_override("disabled", paper_style("paper_button_disabled", 5, Vector2(14, 6)))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, INK)
	b.add_theme_color_override("font_disabled_color", Color("6e6457"))
	return b


## Nút dạng thẻ giấy (thẻ trận, boss).
static func card_button() -> Button:
	var b := button("")
	var card := paper_style("paper_card", 8, Vector2(14, 12))
	b.add_theme_stylebox_override("normal", card)
	b.add_theme_stylebox_override("hover", card)
	var pressed := paper_style("paper_card", 8, Vector2(14, 12))
	pressed.modulate_color = Color(0.88, 0.82, 0.72)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	var off := paper_style("paper_card", 8, Vector2(14, 12))
	off.modulate_color = Color(0.7, 0.68, 0.65)
	b.add_theme_stylebox_override("disabled", off)
	return b


# --- Animation giao diện ----------------------------------------------------

## Bật lên: phóng từ 85% + mờ -> rõ (có độ nảy). delay để các thẻ hiện lần lượt.
static func pop_in(c: Control, delay := 0.0) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2(0.85, 0.85)
	c.resized.connect(func(): c.pivot_offset = c.size / 2.0, CONNECT_ONE_SHOT)
	c.pivot_offset = c.size / 2.0
	var t := c.create_tween().set_parallel(true)
	t.tween_property(c, "modulate:a", 1.0, 0.18).set_delay(delay)
	t.tween_property(c, "scale", Vector2.ONE, 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Mở như mở sổ: bề ngang từ 0 -> đầy.
static func book_open(c: Control) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2(0.05, 1.0)
	var setup := func(): c.pivot_offset = c.size / 2.0
	c.resized.connect(setup, CONNECT_ONE_SHOT)
	setup.call()
	var t := c.create_tween().set_parallel(true)
	t.tween_property(c, "modulate:a", 1.0, 0.12)
	t.tween_property(c, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Lật thẻ: thu bề ngang về 0 (gọi on_hidden ở giữa để đổi nội dung).
static func flip_out(c: Control, duration := 0.14) -> Tween:
	c.pivot_offset = c.size / 2.0
	var t := c.create_tween()
	t.tween_property(c, "scale:x", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return t


static func flip_in(c: Control, delay := 0.0, duration := 0.18) -> void:
	c.scale = Vector2(0.0, 1.0)
	var setup := func(): c.pivot_offset = c.size / 2.0
	c.resized.connect(setup, CONNECT_ONE_SHOT)
	setup.call()
	var t := c.create_tween()
	t.tween_property(c, "scale:x", 1.0, duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Nút chứa nội dung tùy ý (thẻ trận): con không bắt chạm để nút nhận được.
static func ignore_mouse_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		ignore_mouse_recursive(child)


static func texture_rect(tex: Texture2D, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t


static func combatant_texture(data: CombatantData) -> Texture2D:
	var path := FALLBACK_SPRITE
	if data != null:
		for candidate in ["res://assets/sprites/characters/%s.png" % data.id, "res://assets/sprites/monsters/%s.png" % data.id]:
			if ResourceLoader.exists(candidate):
				path = candidate
				break
	return load(path)


static func ingredient_texture(id: String) -> Texture2D:
	var path := "res://assets/sprites/ingredients/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else load(FALLBACK_SPRITE)


## Hàng icon nguyên liệu: [icon] x2  [icon] x3 ...
static func items_row(items: Dictionary, icon_size := 36) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if items.is_empty():
		row.add_child(label("(không có)", FONT_SMALL, INK_SOFT))
	for id in items:
		row.add_child(texture_rect(ingredient_texture(id), icon_size))
		var golden: bool = String(id).begins_with(GameState.GOLDEN_PREFIX)
		row.add_child(label("x%d" % int(items[id]), FONT_SMALL, GOLDEN_INK if golden else INK))
	return row


static func background() -> TextureRect:
	var bg := TextureRect.new()
	bg.texture = load(BACKGROUND)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg


## Thanh máu có viền giống khung bảng giấy: ngoài nâu đậm, đường kem mảnh, trong xanh ngọc.
static func hp_bar(ally: bool) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 24)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("2b1a14")
	bg.border_color = Color("4a2c1c")
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("66bb6a") if ally else Color("ef5350")
	fill.set_corner_radius_all(3)
	# Phần máu nằm lọt trong viền (co vào 4px mỗi cạnh).
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		fill.set_expand_margin(side, -4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	_bar_ring(bar, 2, 1, Color("f3e3c3"), 4) # đường kem
	_bar_ring(bar, 3, 1, TEAL, 3) # viền trong xanh ngọc
	return bar


## Vẽ 1 vòng viền (chỉ nét, không nền) lùi vào `inset` px bên trong thanh.
static func _bar_ring(bar: Control, inset: int, width: int, color: Color, radius: int) -> void:
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.draw_center = false
	st.border_color = color
	st.set_border_width_all(width)
	st.set_corner_radius_all(radius)
	ring.add_theme_stylebox_override("panel", st)
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.offset_left = inset
	ring.offset_top = inset
	ring.offset_right = -inset
	ring.offset_bottom = -inset
	bar.add_child(ring)
