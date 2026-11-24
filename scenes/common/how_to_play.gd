class_name HowToPlay
extends CanvasLayer
## Bảng "Cách chơi" của từng buổi: vài dòng hướng dẫn + nút "Đã hiểu".
## DayManager tự mở lần đầu người chơi vào mỗi buổi (sau chuyển cảnh); menu tạm dừng có nút "Cách chơi" để xem lại.
## Mở thì game tạm dừng (đồng hồ buổi đứng yên), đóng thì trả lại đúng trạng thái cũ.
## Đã xem buổi nào thì ghi vào user://settings.cfg (cùng file cài đặt, không lẫn vào save game).

const LAYER := 115 ## Trên menu tạm dừng (110) vì mở được từ đó, dưới bảng cài đặt (120).
const SECTION := "how_to_play"
const PANEL_WIDTH := 820.0
const DIM := Color(0, 0, 0, 0.6)
const PANEL_BG := Color("4a2e20")
const PANEL_BORDER := Color("a8764a")
const TITLE_COLOR := Color("ffd36b")
const TEXT_COLOR := Color("f5f1e6")
const OUTLINE := Color("1a0f0a")
const BUTTON_BG := Color("7a2a1e")
## Nội dung theo DayManager.Phase. Font không có glyph ▶ → nên đầu dòng dùng "›".
const PAGES := {
	DayManager.Phase.SHOP: {
		"title": "Cách chơi: Một ngày ở quán",
		"lines": [
			"Mỗi ngày gồm 3 buổi: Sáng đi săn nguyên liệu » Trưa nấu lẩu » Chiều tối bán hàng.",
			"Cuối ngày phải đạt KPI doanh thu (ô KPI trên cùng). Không đạt là quán đóng cửa.",
			"Đạt KPI thì vào cửa hàng này: nhóm Quán lẩu (Bếp, Quán, Trang trí) và nhóm Đi săn (Chiến đấu, Vũ khí, Thú cưỡi).",
			"KPI ngày sau cao hơn doanh thu hôm nay, nên nâng cấp đều tay. Bấm \"Bắt đầu ngày\" để đi săn.",
		],
	},
	DayManager.Phase.HUNT: {
		"title": "Cách chơi: Buổi sáng đi săn",
		"lines": [
			"Chạm một bụi cỏ để đánh quái. Thắng thì nhận nguyên liệu như hình trên thẻ.",
			"Trong trận: chạm quái để chọn mục tiêu, rồi chọn chiêu. Bật \"Tự đánh\" nếu muốn nhanh.",
			"Bỏ chạy thì mất đồ rơi. Thắng đủ trận sẽ mở Boss, rơi nguyên liệu hoàng kim giá gấp 3.",
			"Xem \"Công thức hôm nay cần\" bên trái để săn đúng thứ. Hết giờ hoặc bấm \"Về bếp nấu lẩu\" để sang trưa.",
		],
	},
	DayManager.Phase.COOK: {
		"title": "Cách chơi: Buổi trưa nấu lẩu",
		"lines": [
			"Chạm bảng \"Sơ chế nguyên liệu\": mỗi bước là một ô, vàng Hoàn hảo / cam Ổn / đỏ Hỏng. Gần như toàn ô vàng mới được huy chương Thượng hạng: nấu nhanh hơn, đồ nhúng bán đắt hơn.",
			"Chạm một bếp trống rồi chọn món để nấu. Nâng cấp Nồi để mỗi mẻ ra nhiều phần hơn.",
			"Chạm tủ lạnh để xem kho. Nguyên liệu và nồi lẩu để lâu sẽ hết hạn.",
			"Nấu đủ thì bấm \"Mở quán bán hàng\". Lẩu nấu xong được mang ra quầy bếp ở màn bán.",
		],
	},
	DayManager.Phase.SELL: {
		"title": "Cách chơi: Buổi chiều tối bán hàng",
		"lines": [
			"Khách xếp hàng ở quầy lễ tân (bảng Khách đang chờ bên phải cho biết số nhóm và độ kiên nhẫn): chạm một bàn trống đủ ghế để mời khách vào ngồi.",
			"Bàn gọi món xong thì chạm bàn đó để bưng lẩu ra. Bưng nhanh được cộng sao.",
			"Khách chờ lâu sẽ bỏ về và bị trừ sao. Mấy ngày đầu khách tới thưa, càng về sau càng đông. Hết lẩu thì quán tạm ngừng đón khách.",
			"Khách về để lại bàn bẩn, rác, vũng nước: chạm vào để dọn. Sàn bẩn làm khách mất kiên nhẫn nhanh hơn.",
		],
	},
}

var _phase: int
var _was_paused := false


## Bảng hướng dẫn của buổi `phase` (một trong các khóa của PAGES).
func _init(phase: int) -> void:
	_phase = phase


## Buổi này có bảng hướng dẫn không.
static func has_page(phase: int) -> bool:
	return PAGES.has(phase)


## Buổi này có bảng hướng dẫn mà người chơi chưa xem trên máy này.
static func should_show(phase: int) -> bool:
	if not has_page(phase):
		return false
	var config := ConfigFile.new()
	config.load(SettingsPanel.SETTINGS_PATH) # chưa có file = chưa xem gì
	return not bool(config.get_value(SECTION, str(phase), false))


## Ghi nhớ đã xem bảng của buổi này (giữ nguyên các mục cài đặt khác trong file).
static func mark_seen(phase: int) -> void:
	var config := ConfigFile.new()
	config.load(SettingsPanel.SETTINGS_PATH)
	config.set_value(SECTION, str(phase), true)
	config.save(SettingsPanel.SETTINGS_PATH)



## Đã chơi xong Ngày 0 hướng dẫn trên máy này chưa.
static func tutorial_done() -> bool:
	var config := ConfigFile.new()
	config.load(SettingsPanel.SETTINGS_PATH)
	return bool(config.get_value(SECTION, "tutorial_done", false))


## Ghi nhớ đã xong Ngày 0 (giữ nguyên các mục khác trong file).
static func mark_tutorial_done() -> void:
	var config := ConfigFile.new()
	config.load(SettingsPanel.SETTINGS_PATH)
	config.set_value(SECTION, "tutorial_done", true)
	config.save(SettingsPanel.SETTINGS_PATH)


## Dựng bảng: nền tối chặn chạm, khung giữa màn có tiêu đề, các dòng hướng dẫn và nút "Đã hiểu".
func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	var page: Dictionary = PAGES[_phase]

	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = PANEL_WIDTH
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := _label(page["title"], 32, TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for line in page["lines"]:
		var row := _label("›  " + str(line), 20, TEXT_COLOR)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(row)

	var ok := Button.new()
	ok.text = "Đã hiểu"
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(260, 60)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.add_theme_font_size_override("font_size", 24)
	ok.add_theme_color_override("font_color", TEXT_COLOR)
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = BUTTON_BG.lightened(0.15) if state == "pressed" else BUTTON_BG
		s.border_color = PANEL_BORDER
		s.set_border_width_all(3)
		s.set_corner_radius_all(4)
		ok.add_theme_stylebox_override(state, s)
	ok.pressed.connect(close)
	box.add_child(ok)


## Đóng bảng, ghi đã xem, trả game về trạng thái tạm dừng như trước khi mở.
func close() -> void:
	mark_seen(_phase)
	get_tree().paused = _was_paused
	queue_free()


## ESC / nút Back cũng đóng bảng (để không mở menu tạm dừng chồng lên).
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.keycode == KEY_BACK):
		get_viewport().set_input_as_handled()
		close()


## Một dòng chữ có viền tối.
func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 4)
	return label
