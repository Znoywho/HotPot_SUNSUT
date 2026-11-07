extends CanvasLayer
## HUD chung: thanh ngang trên cùng gồm tiền, ngày, KPI, sao đánh giá, thời gian (mặt trời mọc/lặn).
## Tự đọc GameState / DayManager mỗi khung hình, chỉ cần thêm hud.tscn vào màn chơi.
## Màn chơi nên chừa HEIGHT px phía trên cho thanh này.

const HEIGHT := 90 ## Chiều cao thanh HUD (px).
const ICON_DIR := "res://assets/sprites/ui/hud/"
const ICON_FRAME := 32
const ICON_SCALE := 2
const STAR_FRAME := 18
const STAR_SCALE := 2
const MAX_STARS := 5

const BAR_BG := Color("1f2a2e")
const BAR_EDGE := Color("0d1316")
const PANEL_BG := Color("34464d")
const PANEL_BORDER := Color("8aa3a8")
const VALUE_BG := Color("162026")
const VALUE_BORDER := Color("0d1316")
const TITLE_COLOR := Color("f3e6c4")
const OUTLINE := Color("10171a")
const MONEY_COLOR := Color("ffd34e")
const TEXT_COLOR := Color("f5f1e6")
const BAR_FILL := Color("4cc552")
const BAR_DONE := Color("ffd34e")

var _money_label: Label
var _day_label: Label
var _kpi_bar: ProgressBar
var _kpi_label: Label
var _stars: Array[TextureRect] = []
var _sun: HudSunDial
var _phase_label: Label
var _time_label: Label
var _icons: Array[Dictionary] = [] ## {atlas, frames, fps, loop, t}
var _shown_money := -1
var _shown_day := -1
var _sun_progress := 0.0
var _storage_alert: Label ## Dấu "!" trên nút Kho khi có món sắp/đã hết hạn.


func _ready() -> void:
	add_to_group("hud") # Các màn dựa vào nhóm này để ẩn dòng "Còn lại".
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, HEIGHT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = BAR_BG
	bar_style.border_color = BAR_EDGE
	bar_style.border_width_bottom = 3
	bar_style.content_margin_left = 8
	bar_style.content_margin_right = 8
	bar_style.content_margin_top = 5
	bar_style.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", bar_style)
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)

	_money_label = _value_label(MONEY_COLOR)
	row.add_child(_section(_icon("hud_coin", 8, 10.0, 0.0), "TIỀN", _value_box(_money_label), 1.2))
	_day_label = _value_label(TEXT_COLOR)
	row.add_child(_section(_icon("hud_calendar", 6, 10.0, 3.0), "NGÀY", _value_box(_day_label), 0.9))
	row.add_child(_section(_icon("hud_target", 8, 12.0, 2.2), "KPI", _kpi_widget(), 1.3))
	row.add_child(_stars_section())
	row.add_child(_time_section())
	row.add_child(_storage_section())
	_refresh(true)


func _process(delta: float) -> void:
	_animate_icons(delta)
	_refresh(false)


# --- Cập nhật số liệu ------------------------------------------------------

func _refresh(force: bool) -> void:
	if force or GameState.money != _shown_money:
		_shown_money = GameState.money
		_money_label.text = GameState.format_money(GameState.money)
		if not force:
			_play_icon(0)
	if force or GameState.day != _shown_day:
		_shown_day = GameState.day
		_day_label.text = "Ngày %02d" % GameState.day
		_play_icon(1)
	var target := maxi(GameState.kpi_target, 1)
	_kpi_bar.max_value = target
	_kpi_bar.value = mini(GameState.today_revenue, target)
	_kpi_label.text = "%s / %s" % [_short_money(GameState.today_revenue), _short_money(GameState.kpi_target)]
	var fill := _kpi_bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = BAR_DONE if GameState.is_kpi_reached() else BAR_FILL
	_update_stars()
	_update_time()
	_update_storage_alert()


func _update_stars() -> void:
	var value := clampf(GameState.stars, 0.0, MAX_STARS)
	for i in _stars.size():
		var frame := 2 # rỗng
		if value >= i + 1:
			frame = 0
		elif value >= i + 0.5:
			frame = 1
		(_stars[i].texture as AtlasTexture).region = Rect2(frame * STAR_FRAME, 0, STAR_FRAME, STAR_FRAME)


## Vị trí mặt trời/trăng và giờ trong game theo giai đoạn của ngày.
## Ngày (mặt trời) 6:00–17:59, đêm (trăng) 18:00–5:59: progress 0 -> 6h, 1 -> 18h, 2 -> 6h hôm sau.
## Săn 6h–11h, nấu 11h–13h, bán 13h–22h (mặt trời lặn lúc 18h giữa buổi bán), tổng kết 22h, cửa hàng 23h.
func _update_time() -> void:
	var target := 0.0
	match DayManager.current_phase:
		DayManager.Phase.HUNT:
			target = lerpf(_at(6), _at(11), 1.0 - DayManager.time_left / DayManager.HUNT_DURATION)
		DayManager.Phase.COOK:
			target = lerpf(_at(11), _at(13), 1.0 - DayManager.time_left / DayManager.COOK_DURATION)
		DayManager.Phase.SELL:
			target = lerpf(_at(13), _at(22), 1.0 - DayManager.time_left / DayManager.SELL_DURATION)
		DayManager.Phase.DAY_END, DayManager.Phase.GAME_OVER:
			target = _at(22) # Đóng cửa tổng kết.
		DayManager.Phase.SHOP:
			target = _at(23) # Mua sắm chuẩn bị ngày mai.
		_:
			target = 0.0
	# Trượt mượt khi đổi giai đoạn, nhảy thẳng khi qua ngày mới.
	if target < _sun_progress - 0.5:
		_sun_progress = target
	else:
		# Kết thúc buổi sớm thì đồng hồ tua nhanh tới buổi sau (khoảng 1–2 giây), trong buổi thì bám theo giờ.
		var gap := absf(target - _sun_progress)
		var speed := maxf(0.08, gap * 2.5)
		_sun_progress = move_toward(_sun_progress, target, get_process_delta_time() * speed)
	_sun.progress = _sun_progress
	var minutes := int(fposmod(6.0 * 60.0 + _sun_progress * 12.0 * 60.0, 24.0 * 60.0))
	minutes -= minutes % 10 # Nhảy 10 phút một cho dễ nhìn.
	var hour := minutes / 60
	_time_label.text = "%02d:%02d" % [hour, minutes % 60]
	_phase_label.text = _part_of_day(hour)


## Giờ (6..29) -> progress của đồng hồ mặt trời.
static func _at(hour: float) -> float:
	return (hour - 6.0) / 12.0


static func _part_of_day(hour: int) -> String:
	if hour >= 5 and hour < 11:
		return "Sáng"
	if hour >= 11 and hour < 13:
		return "Trưa"
	if hour >= 13 and hour < 18:
		return "Chiều"
	if hour >= 18 and hour < 22:
		return "Tối"
	return "Đêm"


## 1.250.000đ -> "1,25tr", 300.000đ -> "300k" để thanh KPI gọn.
func _short_money(value: int) -> String:
	if absi(value) >= 1_000_000:
		var m := value / 1_000_000.0
		var text := ("%.2f" % m).rstrip("0").rstrip(".")
		return text.replace(".", ",") + "tr"
	if absi(value) >= 1000:
		return "%dk" % (value / 1000)
	return str(value)


# --- Dựng giao diện ---------------------------------------------------------

## Một ô trên thanh: icon bên trái, tiêu đề + giá trị bên phải.
func _section(icon: Control, title: String, content: Control, ratio: float) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.add_child(icon)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.add_child(_title_label(title))
	box.add_child(content)
	line.add_child(box)
	return _panel(line, ratio)


func _panel(content: Control, ratio: float) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	return panel


func _title_label(title: String) -> Label:
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", TITLE_COLOR)
	t.add_theme_color_override("font_outline_color", OUTLINE)
	t.add_theme_constant_override("outline_size", 4)
	return t


## Icon động: chạy hết các khung rồi nghỉ `pause` giây (đứng ở khung cuối), lặp lại.
func _icon(icon: String, frames: int, fps: float, pause: float, frame_size := ICON_FRAME, scale := ICON_SCALE) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(ICON_DIR + icon + ".png")
	atlas.region = Rect2(0, 0, frame_size, frame_size)
	var rect := TextureRect.new()
	rect.texture = atlas
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.custom_minimum_size = Vector2.ONE * frame_size * scale
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Lệch pha để các icon không chạy cùng lúc.
	_icons.append({"atlas": atlas, "frames": frames, "fps": fps, "pause": pause, "size": frame_size, "t": -0.6 * _icons.size()})
	return rect


func _value_label(color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", color)
	return l


func _value_box(content: Control) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _value_style())
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(content)
	return box


func _kpi_widget() -> Control:
	_kpi_bar = ProgressBar.new()
	_kpi_bar.show_percentage = false
	_kpi_bar.custom_minimum_size = Vector2(140, 30)
	_kpi_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kpi_bar.add_theme_stylebox_override("background", _value_style())
	var fill := StyleBoxFlat.new()
	fill.bg_color = BAR_FILL
	fill.set_border_width_all(2)
	fill.border_color = VALUE_BORDER
	_kpi_bar.add_theme_stylebox_override("fill", fill)
	_kpi_label = Label.new()
	_kpi_label.add_theme_font_size_override("font_size", 18)
	_kpi_label.add_theme_color_override("font_color", TEXT_COLOR)
	_kpi_label.add_theme_color_override("font_outline_color", OUTLINE)
	_kpi_label.add_theme_constant_override("outline_size", 5)
	_kpi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kpi_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_kpi_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_kpi_bar.add_child(_kpi_label)
	return _kpi_bar


func _stars_section() -> Control:
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 2)
	var tex: Texture2D = load(ICON_DIR + "hud_star.png")
	for i in MAX_STARS:
		var r := _star_rect(tex, STAR_SCALE)
		stars.add_child(r)
		_stars.append(r)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2.ONE * ICON_FRAME * ICON_SCALE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sao lớn có vệt sáng lướt qua; phóng đúng số nguyên để pixel không méo.
	holder.add_child(_icon("hud_star_shine", 8, 16.0, 2.0, STAR_FRAME, 3))
	return _section(holder, "ĐÁNH GIÁ", stars, 1.25)


func _star_rect(tex: Texture2D, scale: int) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(0, 0, STAR_FRAME, STAR_FRAME)
	var r := TextureRect.new()
	r.texture = atlas
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = Vector2.ONE * STAR_FRAME * scale
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _time_section() -> Control:
	_sun = HudSunDial.new()
	_sun.custom_minimum_size = Vector2(150, 60)
	_sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_label = _title_label("")
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 24)
	_time_label.add_theme_color_override("font_color", TEXT_COLOR)
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.custom_minimum_size = Vector2(70, 0)
	info.add_theme_constant_override("separation", 0)
	info.add_child(_phase_label)
	info.add_child(_time_label)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.add_child(_sun)
	line.add_child(info)
	return _panel(line, 1.1)


## Nút Kho: mở bảng kho (nguyên liệu, nước cốt, hạn sử dụng).
func _storage_section() -> Control:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(96, 0)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var st := _panel_style()
		if state == "pressed":
			st.bg_color = PANEL_BG.lightened(0.15)
		button.add_theme_stylebox_override(state, st)
	button.pressed.connect(func(): add_child(StoragePopup.new()))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var atlas := AtlasTexture.new()
	atlas.atlas = load(ICON_DIR + "hud_storage.png")
	atlas.region = Rect2(0, 0, ICON_FRAME, ICON_FRAME)
	var icon := TextureRect.new()
	icon.texture = atlas
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2.ONE * ICON_FRAME * 1.5
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var t := _title_label("KHO")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(t)
	button.add_child(box)
	_storage_alert = Label.new()
	_storage_alert.text = "!"
	_storage_alert.add_theme_font_size_override("font_size", 26)
	_storage_alert.add_theme_color_override("font_color", Color("ff5252"))
	_storage_alert.add_theme_color_override("font_outline_color", OUTLINE)
	_storage_alert.add_theme_constant_override("outline_size", 6)
	_storage_alert.position = Vector2(70, -2)
	_storage_alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(_storage_alert)
	return button


## Có lô nào đang ở ngày cuối hoặc đã hết hạn thì nhấp nháy dấu "!".
func _update_storage_alert() -> void:
	var warn := false
	for store in [GameState.item_batches, GameState.broth_batches]:
		for id in store:
			for batch in store[id]:
				if batch["expired"] or GameState.days_left(batch) <= 1:
					warn = true
	_storage_alert.visible = warn
	if warn:
		_storage_alert.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 180.0)


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG
	s.border_color = PANEL_BORDER
	s.set_border_width_all(3)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(7) # Viền 3px + 4px hở để nội dung không đè lên viền.
	return s


func _value_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = VALUE_BG
	s.border_color = VALUE_BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	s.content_margin_left = 8
	s.content_margin_right = 8
	return s


# --- Hoạt ảnh icon ----------------------------------------------------------

func _animate_icons(delta: float) -> void:
	for icon in _icons:
		var frames: int = icon["frames"]
		var fps: float = icon["fps"]
		var size: int = icon["size"]
		icon["t"] = float(icon["t"]) + delta
		var t: float = icon["t"]
		var run := frames / fps
		var cycle := run + float(icon["pause"])
		var frame := 0
		if t >= 0.0:
			var local := fmod(t, cycle)
			frame = mini(int(local * fps), frames - 1)
		(icon["atlas"] as AtlasTexture).region = Rect2(frame * size, 0, size, size)


## Phát lại icon (lịch lật khi sang ngày, xu xoay khi tiền đổi).
func _play_icon(index: int) -> void:
	if index < _icons.size():
		_icons[index]["t"] = 0.0
