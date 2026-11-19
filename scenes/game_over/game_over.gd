extends Control
## Màn Game Over: quán không đạt KPI. Nền là phong cảnh menu chính nhuốm màu chiều tối,
## bảng giữa ghi ngày thua, doanh thu so với KPI (thanh %), số ngày trụ được, sao; 2 nút Chơi lại / Về menu.
## Save đã bị xóa trước khi vào màn này (DayManager.next_phase), nên số liệu đọc thẳng từ GameState.

const SKY := preload("res://assets/sprites/scenery/sky.png")
const LANDSCAPE := preload("res://assets/sprites/scenery/landscape.png")
const BOLD_FONT := preload("res://assets/fonts/BeVietnamPro-Bold.ttf")
const DUSK_TINT := Color(0.55, 0.38, 0.42) ## Nhuộm phong cảnh sang chiều tối, buồn hơn menu chính.
const BOARD_COLOR := Color("2b1a14", 0.94)
const BOARD_BORDER := Color("6b2a22")
const TEXT_LIGHT := Color("fbecd2")
const ACCENT := Color("f2a33a")
const FAIL_RED := Color("e0533d")
const FADE_IN_SECONDS := 0.8
const BOARD_DROP_SECONDS := 0.7


## Dựng nền, bảng kết quả, lớp nhắc xoay ngang, rồi cho màn sáng dần lên từ đen.
func _ready() -> void:
	for texture in [SKY, LANDSCAPE]:
		_add_cover_layer(texture)
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
			.set_delay(0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var board := PanelContainer.new()
	board.custom_minimum_size = Vector2(760, 0)
	board.add_theme_stylebox_override("panel", _box_style(BOARD_COLOR, BOARD_BORDER, 6, 32))
	center.add_child(board)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	board.add_child(column)

	column.add_child(_make_label("QUÁN ĐÓNG CỬA", 56, FAIL_RED, true))
	column.add_child(_make_label("Ngày %d không đạt KPI." % GameState.day, 24, TEXT_LIGHT))

	var revenue := GameState.today_revenue
	var kpi := GameState.kpi_target
	column.add_child(_make_row("Doanh thu hôm nay", GameState.format_money(revenue)))
	column.add_child(_make_row("KPI cần đạt", GameState.format_money(kpi)))
	column.add_child(_make_row("Còn thiếu", GameState.format_money(maxi(0, kpi - revenue)), FAIL_RED))
	column.add_child(_make_kpi_bar(kpi_percent(revenue, kpi)))
	column.add_child(_make_row("Số ngày trụ được", "%d ngày" % (GameState.day - 1)))
	column.add_child(_make_row("Đánh giá quán", "%.1f / 5 sao" % GameState.stars))

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


## Khung nền phẳng có viền, góc vuông nhẹ cho hợp pixel (giống cửa hàng).
func _box_style(fill: Color, border: Color, border_width: int, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(padding)
	return style


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
