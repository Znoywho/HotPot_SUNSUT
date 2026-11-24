extends Control
## Màn Game Over: quán không đạt KPI, đóng cửa lúc tối. Nền là phong cảnh menu chính nhuốm màu tối, trời có trăng
## và sao nhấp nháy; giữa màn là tấm biển gỗ treo 2 dây thả từ trên xuống (rơi xuống rồi đung đưa), tiêu đề kẹp giữa
## nồi lẩu nguội và đèn lồng tắt; biển ghi ngày thua, doanh thu so với KPI (thanh %), số ngày trụ được, kỷ lục, sao;
## 2 nút Chơi lại / Về menu. Ảnh pixel vẽ bằng tools/make_result_art.py.
## Save đã bị xóa trước khi vào màn này (DayManager.next_phase), nên số liệu đọc thẳng từ GameState.

const SKY := preload("res://assets/sprites/scenery/sky.png")
const LANDSCAPE := preload("res://assets/sprites/scenery/landscape.png")
const BOLD_FONT := preload("res://assets/fonts/BeVietnamPro-Bold.ttf")
const DUSK_TINT := Color(0.55, 0.38, 0.42) ## Nhuộm phong cảnh sang chiều tối, buồn hơn menu chính.
const BOARD_TEXTURE := preload("res://assets/sprites/ui/result/board_wood.png")
const BOARD_TEXTURE_MARGIN := 21.0 ## Khung gỗ + ke sắt của ảnh (7 điểm ảnh × 3 px), giữ nguyên khi kéo dãn.
const BOARD_PADDING := 32.0
const ROPE := preload("res://assets/sprites/ui/result/rope.png")
const ROPE_KNOT := preload("res://assets/sprites/ui/result/rope_knot.png")
const ROPE_INSET := 64.0 ## Dây buộc cách mép trái / phải tấm biển chừng này px.
const COLD_POT := preload("res://assets/sprites/ui/result/cold_pot.png")
const LANTERN_OFF := preload("res://assets/sprites/ui/result/lantern_off.png")
const ICON_SHRINK := 2.0 / 3.0 ## Nồi, đèn cạnh tiêu đề: ảnh vẽ 3 px/điểm ảnh, hiện 2 px/điểm ảnh cho vừa hàng chữ.
const MOON := preload("res://assets/sprites/ui/result/moon.png")
const STAR := preload("res://assets/sprites/ui/result/star.png")
const STAR_COUNT := 16
const SKY_GLOW := Color(1.6, 1.6, 1.6) ## Trăng, sao sáng hơn để vẫn tỏ dưới lớp phủ tối của màn.
const BOARD_SWING_DEGREES: Array[float] = [1.6, -1.1, 0.6, -0.3, 0.0] ## Biển đung đưa tắt dần sau khi rơi xuống.
const TEXT_LIGHT := Color("fbecd2")
const ACCENT := Color("f2a33a")
const FAIL_RED := Color("e0533d")
const FADE_IN_SECONDS := 0.8
const BOARD_DROP_SECONDS := 0.7
const BOARD_DROP_DELAY := 0.3 ## Biển gỗ đợi chừng này giây rồi mới rơi.
const TITLE_TEXT := "QUÁN ĐÓNG CỬA"
const TITLE_PIXEL_SCALE := 3 ## Tiêu đề dùng font pixel PixelTitle phóng 3 lần (cao ~ chữ 56 cũ, vừa giữa nồi và đèn lồng).
const TITLE_BROKEN_LETTER := "Ó" ## Chữ "hỏng" của biển hiệu: sáng yếu, thỉnh thoảng nháy.


## Dựng nền, bảng kết quả, lớp nhắc xoay ngang, rồi cho màn sáng dần lên từ đen.
func _ready() -> void:
	_add_cover_layer(SKY)
	_build_night_sky() # sau trời, trước núi: núi che bớt sao
	_add_cover_layer(LANDSCAPE)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(shade)
	_build_board()
	_fade_in()
	add_child(RotateHint.new())


## Một lớp phong cảnh phủ kín màn, giữ tỉ lệ, nhuộm màu chiều tối.
func _add_cover_layer(texture: Texture2D) -> void:
	var layer := TextureRect.new()
	layer.texture = texture
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.modulate = DUSK_TINT
	layer.mouse_filter = MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(layer)


## Trời đêm: trăng khuyết góc trên phải và sao nhấp nháy (vị trí cố định, sao lớn nhỏ xen nhau).
func _build_night_sky() -> void:
	var screen := get_viewport_rect().size
	var moon := _pixel_rect(MOON)
	moon.self_modulate = SKY_GLOW
	moon.position = (Vector2(screen.x * 0.84, screen.y * 0.07)).round()
	add_child(moon)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in STAR_COUNT:
		var star := _pixel_rect(STAR)
		star.self_modulate = SKY_GLOW # self_modulate: không đè lên modulate:a đang nhấp nháy
		star.position = Vector2(rng.randf_range(0.0, screen.x), rng.randf_range(0.0, screen.y * 0.34)).round()
		star.scale = Vector2.ONE * (1.0 if i % 3 == 0 else 0.5) # 0.5 = 2 px/điểm ảnh, vẫn sắc
		add_child(star)
		var blink := rng.randf_range(0.6, 1.4)
		var tween := star.create_tween().set_loops()
		tween.tween_property(star, "modulate:a", 0.2, blink).set_trans(Tween.TRANS_SINE)
		tween.tween_property(star, "modulate:a", 1.0, blink).set_trans(Tween.TRANS_SINE)


## Màn đen phủ lên rồi tan dần.
func _fade_in() -> void:
	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.mouse_filter = MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(fade)
	var tween := fade.create_tween()
	tween.tween_property(fade, "color:a", 0.0, FADE_IN_SECONDS)
	tween.tween_callback(fade.queue_free)


## Bảng giữa màn: tiêu đề, lý do thua, các dòng số liệu, thanh % KPI, 2 nút.
func _build_board() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	center.position.y = -get_viewport_rect().size.y # rơi từ trên xuống như bảng cửa hàng
	center.create_tween().tween_property(center, "position:y", 0.0, BOARD_DROP_SECONDS) \
			.set_delay(BOARD_DROP_DELAY).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var board := PanelContainer.new()
	board.custom_minimum_size = Vector2(760, 0)
	board.add_theme_stylebox_override("panel", _board_style())
	center.add_child(board)
	_add_ropes(board)
	_swing_after_drop(board)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	board.add_child(column)

	var days := GameState.day - 1
	var new_record := BestRecord.submit_days(days)
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 18)
	title_row.add_child(_pixel_icon(COLD_POT))
	title_row.add_child(_make_pixel_title())
	var lantern := _pixel_icon(LANTERN_OFF)
	title_row.add_child(lantern)
	column.add_child(title_row)
	_sway(lantern)
	column.add_child(_make_label("Ngày %d không đạt KPI." % GameState.day, 24, TEXT_LIGHT))
	if new_record:
		column.add_child(_make_record_badge())

	var revenue := GameState.today_revenue
	var kpi := GameState.kpi_target
	column.add_child(_make_row("Doanh thu hôm nay", GameState.format_money(revenue)))
	column.add_child(_make_row("KPI cần đạt", GameState.format_money(kpi)))
	column.add_child(_make_row("Còn thiếu", GameState.format_money(maxi(0, kpi - revenue)), FAIL_RED))
	column.add_child(_make_kpi_bar(kpi_percent(revenue, kpi)))
	column.add_child(_make_row("Số ngày trụ được", "%d ngày" % days))
	column.add_child(_make_row("Kỷ lục", "%d ngày" % BestRecord.best_days(), ACCENT))
	# Cùng cách viết sao với sổ tổng kết: 4 -> "4", 3.5 -> "3,5".
	var stars := ("%.2f" % GameState.stars).rstrip("0").rstrip(".").replace(".", ",")
	column.add_child(_make_row("Đánh giá quán", "%s / 5 sao" % stars))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	column.add_child(buttons)
	var retry := PixelButton.new("CHƠI LẠI", 28)
	retry.pressed.connect(DayManager.start_new_game)
	buttons.add_child(retry)
	var menu := PixelButton.new("VỀ MENU", 28)
	menu.pressed.connect(DayManager.go_to_main_menu)
	buttons.add_child(menu)


## Dòng "KỶ LỤC MỚI!" vàng, phập phồng mãi cho người chơi muốn thử lại.
func _make_record_badge() -> Control:
	var badge := _make_label("KỶ LỤC MỚI!", 34, ACCENT, true)
	badge.resized.connect(func(): badge.pivot_offset = badge.size / 2.0)
	var tween := badge.create_tween().set_loops()
	tween.tween_property(badge, "scale", Vector2.ONE * 1.12, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(badge, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	return badge


## Phần trăm KPI đã đạt: percent = revenue / kpi × 100, chặn trong [0, 100]. KPI <= 0 coi như đạt 100%.
static func kpi_percent(revenue: int, kpi: int) -> float:
	if kpi <= 0:
		return 100.0
	return clampf(revenue * 100.0 / kpi, 0.0, 100.0)


## Một dòng "tên ........ giá trị" (tên trái, giá trị phải).
func _make_row(title: String, value: String, value_color := TEXT_LIGHT) -> HBoxContainer:
	var row := HBoxContainer.new()
	var left := _make_label(title, 22, TEXT_LIGHT)
	left.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(left)
	var right := _make_label(value, 22, value_color, true)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(right)
	return row


## Thanh pixel đỏ (cùng kiểu sổ tổng kết) cho biết đã đạt bao nhiêu % KPI; chạy từ 0 lên khi bảng rơi xong.
func _make_kpi_bar(percent: float) -> Control:
	var bar := PixelBar.new(PixelBar.RED)
	bar.custom_minimum_size = Vector2(0, 32)
	var label := _make_label("Đạt %d%% KPI" % floori(percent), 18, TEXT_LIGHT, true)
	label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bar.add_child(label)
	bar.create_tween().tween_property(bar, "value", percent, 0.8) \
			.set_delay(BOARD_DROP_SECONDS + 0.3).set_ease(Tween.EASE_OUT)
	return bar


## Tấm biển gỗ pixel (9 ô): 4 góc ke sắt giữ nguyên, khung và ván lát lặp (không kéo dãn) để điểm ảnh không méo.
func _board_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = BOARD_TEXTURE
	style.set_texture_margin_all(BOARD_TEXTURE_MARGIN)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.set_content_margin_all(BOARD_PADDING)
	return style


## Hai dây thừng thả từ mép trên màn xuống 2 góc trên tấm biển, đầu dây buộc nút đóng đinh vào khung.
## PanelContainer kéo mọi con theo vùng chữ, nên dây nằm trong một Control phủ vùng đó rồi đặt toạ độ âm (ra ngoài biển).
func _add_ropes(board: PanelContainer) -> void:
	var holder := Control.new()
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	board.add_child(holder)
	var rope_bottom := -BOARD_PADDING + 12.0 # chui vào khung trên của biển một chút
	for side: float in [0.0, 1.0]:
		var x := (ROPE_INSET - BOARD_PADDING) * (1.0 - 2.0 * side) # tính từ mép trái (side 0) hoặc mép phải (side 1)
		var rope := TextureRect.new()
		rope.texture = ROPE
		rope.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rope.stretch_mode = TextureRect.STRETCH_TILE
		rope.mouse_filter = MOUSE_FILTER_IGNORE
		_place(rope, side, x, rope_bottom - get_viewport_rect().size.y, rope_bottom, ROPE.get_width())
		holder.add_child(rope)
		var knot := _pixel_rect(ROPE_KNOT)
		var knot_top := -BOARD_PADDING + 2.0
		_place(knot, side, x, knot_top, knot_top + ROPE_KNOT.get_height(), ROPE_KNOT.get_width())
		holder.add_child(knot)


## Neo control theo mép trái (side 0) hoặc phải (side 1) của cha, tâm ngang tại x, dọc từ top tới bottom.
static func _place(control: Control, side: float, x: float, top: float, bottom: float, width: float) -> void:
	control.anchor_left = side
	control.anchor_right = side
	control.offset_left = x - width / 2.0
	control.offset_right = x + width / 2.0
	control.offset_top = top
	control.offset_bottom = bottom


## Biển rơi xuống xong thì đung đưa quanh mép trên rồi đứng yên.
func _swing_after_drop(board: Control) -> void:
	board.resized.connect(func(): board.pivot_offset = Vector2(board.size.x / 2.0, 0.0))
	var swing := board.create_tween()
	swing.tween_interval(0.3 + BOARD_DROP_SECONDS)
	for angle in BOARD_SWING_DEGREES:
		swing.tween_property(board, "rotation_degrees", angle, 0.32).set_trans(Tween.TRANS_SINE)


## Đèn lồng lắc nhẹ mãi quanh dây treo (mép trên).
func _sway(lantern: Control) -> void:
	lantern.pivot_offset = Vector2(lantern.custom_minimum_size.x / 2.0, 0.0)
	var tween := lantern.create_tween().set_loops()
	tween.tween_property(lantern, "rotation_degrees", 6.0, 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(lantern, "rotation_degrees", -6.0, 1.1).set_trans(Tween.TRANS_SINE)


## TextureRect đúng cỡ ảnh pixel, không chặn chạm.
func _pixel_rect(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	return rect


## Icon pixel thu còn ICON_SHRINK (giữ tỉ lệ), căn giữa theo chiều dọc hàng.
func _pixel_icon(texture: Texture2D) -> TextureRect:
	var rect := _pixel_rect(texture)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = texture.get_size() * ICON_SHRINK
	rect.size_flags_vertical = SIZE_SHRINK_CENTER
	return rect


## Tiêu đề "QUÁN ĐÓNG CỬA" bằng chữ pixel mập (PixelTitle, bảng màu game_over), kiểu biển hiệu đèn:
## biển rơi xuống thì chữ chập chờn bật sáng, rồi sáng hẳn trừ một chữ hỏng sáng yếu, thỉnh thoảng nháy.
func _make_pixel_title() -> RichTextLabel:
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.clip_contents = false
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.mouse_filter = MOUSE_FILTER_IGNORE
	title.size_flags_vertical = SIZE_SHRINK_CENTER
	title.custom_minimum_size.x = PixelTitle.text_width(TITLE_TEXT, "game_over", TITLE_PIXEL_SCALE)
	PixelTitle.apply_rich(title, "game_over", TITLE_PIXEL_SCALE)
	var flicker := PixelTitle.FlickerEffect.new()
	flicker.delay = BOARD_DROP_DELAY + BOARD_DROP_SECONDS # bật đèn lúc biển vừa rơi tới chỗ
	flicker.broken_index = TITLE_TEXT.find(TITLE_BROKEN_LETTER)
	title.install_effect(flicker)
	title.text = "[flicker]%s[/flicker]" % TITLE_TEXT
	return title


## Label căn giữa với cỡ chữ, màu; bold = chữ đậm có viền tối.
func _make_label(text: String, font_size: int, color: Color, bold := false) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", BOLD_FONT)
		label.add_theme_color_override("font_outline_color", Color("1a0f0b"))
		label.add_theme_constant_override("outline_size", PixelButton.outline_for(font_size))
	return label
