extends Control
## Chiều tối – bán hàng trong nhà hàng pixel, cùng phong cách và tỉ lệ với khu bếp (1 điểm ảnh nền = 4 px):
## - Nhóm khách 1-6 người vào cửa, xếp hàng chờ trước quầy lễ tân (có thanh kiên nhẫn, chờ lâu thì bỏ về).
## - Bàn tròn 6 ghế (nhìn chéo 2.5D). Chạm một bàn trống để xếp chỗ: nhóm chờ đầu tiên đi tới và ngồi vào ghế.
##   Có khách chờ thì bàn trống nhấp nháy.
## - Mỗi bàn gọi 1 nồi lẩu dù đi mấy người; nhóm càng đông thì gọi càng nhiều đĩa đồ nhúng (tính tiền theo đĩa).
## - Ô cửa bếp: các nồi lẩu đã nấu bày trên quầy kèm số phần; chạm nồi để lấy lên khay, chạm bàn để bưng ra
##   (khay trống thì tự lấy đúng món; không đủ phần thì thương lượng đổi món).
## Thanh HUD chung (tiền, ngày, KPI, sao, giờ) do DayManager hiện phía trên; màn này chừa sẵn chỗ cho thanh đó.

const TIP_MIN := 0.03
const TIP_MAX := 0.07
const BASE_EATING_TIME := 8.0
const SPAWN_INTERVAL := 6.0 ## Giây giữa hai nhóm khách (chia cho customer_multiplier).
const CUSTOMER_WAIT := 20.0 ## Kiên nhẫn chờ món sau khi đã ngồi.
const QUEUE_WAIT := 25.0 ## Kiên nhẫn chờ được xếp bàn ở quầy lễ tân.
const MAX_QUEUE := 2 ## Số nhóm đứng chờ tối đa (chỗ trước quầy + cạnh cửa).
const STAR_FAST_SERVE := 0.15
const STAR_SERVE := 0.05
const STAR_CUSTOMER_LEFT := 0.25
const NEGOTIATE_CHANCE := 0.5
const EXPIRED_DETECT_CHANCE := 0.25
const EXPIRED_COMPENSATION := 2.0
const EXPIRED_STAR_LOSS := 0.5
## Giá gốc mỗi đĩa đồ nhúng (mọi loại như nhau), nhân hệ số chất lượng sơ chế (PrepConfig.dipping_price_mult).
const DIPPING_PRICE := 10_000
const DIPPING_POOL := ["beef", "mushroom", "greens", "shrimp", "enoki", "tomato", "chili"]
## TODO(nhóm): cân bằng tỉ lệ số người mỗi nhóm (chỉ số = số người, giá trị = trọng số).
const GROUP_SIZE_WEIGHTS := [0, 15, 30, 15, 25, 8, 7]
const TABLE_SEATS := 6 ## Bàn tròn nào cũng 6 ghế (nhóm đông nhất 6 người).

const ART := "res://assets/sprites/restaurant/"
const STAGE := Vector2(1280, 720)
const PX := 4.0
const SIDE_WALL_PX := 160.0
const FLOOR_RECT := Rect2(16, 352, 1248, 290) ## Vùng xếp bàn trên sàn.
const BAR_Y := 650.0
const MAX_TABLE_SCALE := 1.25 ## Quán ít bàn (1 hàng) thì phóng bàn to cho cân với đầu bếp, lễ tân.
const ONE_ROW_BOTTOM := 0.86
const ROW_OVERLAP := 0.28 ## Hàng sau chồng lên hàng trước (phần trống trên đầu bàn); lớn hơn ~0.3 thì ghế hai hàng dính nhau.
const TABLE_GAP := 24.0 ## Khoảng hở giữa hai bàn (ở tỉ lệ 1).
const WAITER_HOME := Vector2(690, 300) ## Góc trên-trái chỗ Tùng đứng chờ dưới ô cửa bếp.
const WAITER_SIZE := 96.0
const WAITER_SPEED := 520.0 ## px/giây, Tùng chạy bàn nhanh.
const CHAR_DIR := "res://assets/sprites/characters/"
const NIGHT_STRENGTH := 0.5 ## Mức tối theo giờ trong quán (1 = tối như ngoài trời như màn bếp).
const LAMP_GLOW := 0.45 ## Độ sáng quầng đèn treo lúc tối.
const GUEST_LOOKS := ["customer_1", "customer_2", "customer_3", "customer_4", "customer_5", "customer_6"]
const SPECIAL_LOOKS := {"critic": "customer_critic", "michelin": "customer_michelin"}

var tables: Array[TableNode] = []
var cart := Cart.new()
var _spawn_timer := 2.0
var _negotiating: TableNode = null
var _stage: Control
var _pass: KitchenPass
var _reception: ReceptionDesk
var _floor: Control ## Sàn quán, nơi đặt các bàn.
var _visuals: Array[TableVisual] = []
var _seats: Array[int] = []
var _overlay: Control ## Lớp cho khách đang đi và nồi bay ra bàn.
var _bubbles: Control ## Bong bóng gọi món / nhóm chờ (trên lớp ánh sáng để luôn dễ đọc).
var _queue: Array[Dictionary] = [] ## Nhóm đang chờ xếp bàn: {size, looks, broth_id, sides, special, wait, walkers, bubble, bar}
var _reserved: Dictionary = {} ## Bàn đã nhận nhóm đang đi tới.
var _events = preload("res://scenes/sell/sell_events.gd").new()
var _leaving := false
var _waiter: TextureRect = null ## Tùng bưng lẩu (cấp Nhân viên bếp 2+).
var _waiter_legs: SpriteFrameLayer = null
var _waiter_pot: TextureRect = null
var _waiter_busy := false

var _tray_icon: TextureRect
var _tray_label: Label
var _notification_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	set_meta("reserves_hud", true) # Đã chừa sẵn chỗ cho thanh HUD phía trên.
	DayManager.phase_time_up.connect(_close_shop)
	add_child(cart)
	add_child(_events)
	_events.setup(self)
	_build_stage()
	_build_bar()
	_setup_tables()
	resized.connect(_center_stage)
	_center_stage()


func _process(delta: float) -> void:
	var spawn_interval := SPAWN_INTERVAL / maxf(0.2, GameState.customer_multiplier)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		_try_spawn_group()
	_tick_queue(delta)
	for table in tables:
		if table.state == TableNode.State.WAITING_ORDER and table.customer and table != _negotiating:
			if table.customer.remaining_time() <= 0.0:
				_customer_timeout(table)
		elif table.state == TableNode.State.EATING:
			if table.eating_remaining() <= 0.0:
				_finish_eating(table)
	_update_ui()


# --- Dựng nhà hàng -----------------------------------------------------------------

func _build_stage() -> void:
	var back := ColorRect.new()
	back.color = Color("2b1a14")
	back.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	back.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(back)
	_stage = Control.new()
	_stage.size = STAGE
	_stage.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_stage)
	_art("restaurant_bg", Vector2(320, 180), Vector2.ZERO)
	# Nối tường + sàn sang hai bên để màn rộng hơn 16:9 không bị dải trống.
	_art("restaurant_bg_side", Vector2(SIDE_WALL_PX, 180), Vector2(-SIDE_WALL_PX * PX, 0))
	_art("restaurant_bg_side", Vector2(SIDE_WALL_PX, 180), Vector2(STAGE.x, 0))

	_stage.add_child(RoomDecor.new())
	_pass = KitchenPass.new()
	_stage.add_child(_pass)
	_pass.pot_tapped.connect(_pick_to_cart)
	_stage.add_child(MenuBoard.new()) # Bảng phấn Thực đơn cạnh quầy, chạm để xem giá và công thức (vẽ dưới bong bóng của quầy).
	_reception = ReceptionDesk.new()
	_stage.add_child(_reception)

	_floor = Control.new()
	_floor.position = FLOOR_RECT.position
	_floor.size = FLOOR_RECT.size
	_floor.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.add_child(_floor)

	_overlay = Control.new()
	_overlay.size = STAGE
	_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.add_child(_overlay)
	if RestaurantDecor.has_waiter():
		_build_waiter()

	# Ánh sáng theo giờ phủ lên cảnh + nhân vật; đèn treo và ô cửa bếp sáng dần khi trời tối.
	# Trong quán đèn luôn bật nên tối nhẹ hơn ngoài trời (cửa sổ vẫn thấy trời đêm), quầng đèn dịu để không loá.
	var light := DayLight.new()
	light.strength = NIGHT_STRENGTH
	_stage.add_child(light)
	var gold := str(RestaurantDecor.furniture()["lamp"]) == "gold"
	for p in RoomDecor.lamp_centers():
		light.add_lamp(p, 220.0 if gold else 200.0, LAMP_GLOW * (1.15 if gold else 1.0), 1.2)
	light.add_lamp(Vector2(1010, 170), 300.0, LAMP_GLOW * 0.85, 0.6)
	var windows := RestaurantWindows.new()
	_stage.add_child(windows)
	windows.setup(light)
	if RestaurantDecor.furniture()["fairy"]:
		_stage.add_child(RoomDecor.FairyLights.new())

	_bubbles = Control.new()
	_bubbles.size = STAGE
	_bubbles.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.add_child(_bubbles)
	_reception.move_speech_to(_bubbles) # Lời Lan / Mai nằm trên cửa sổ và ánh sáng, không bị che.


func _art(name: String, px_size: Vector2, pos: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(ART + name + ".png")
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = px_size * PX
	r.position = pos
	r.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.add_child(r)
	return r


## Thanh dưới: khay đang bưng gì, thông báo, nút đóng cửa (cùng kiểu dải thông tin + nút cam của màn bếp).
func _build_bar() -> void:
	var strip := PanelContainer.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.17, 0.1, 0.07, 0.88)
	ss.border_color = Color("8a5a3c")
	ss.set_border_width_all(3)
	ss.set_corner_radius_all(6)
	ss.content_margin_left = 10
	ss.content_margin_right = 6
	ss.content_margin_top = 4
	ss.content_margin_bottom = 4
	strip.add_theme_stylebox_override("panel", ss)
	strip.position = Vector2(16, BAR_Y)
	strip.size = Vector2(1248, 64)
	_stage.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	strip.add_child(row)

	_tray_icon = TextureRect.new()
	_tray_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tray_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tray_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tray_icon.custom_minimum_size = Vector2(56, 48)
	_tray_icon.size_flags_vertical = SIZE_SHRINK_CENTER
	_tray_icon.texture = load("res://assets/sprites/kitchen/tray.png")
	row.add_child(_tray_icon)
	_tray_label = HuntUI.outlined_label("", 18, HuntUI.GOLD)
	_tray_label.custom_minimum_size = Vector2(250, 0)
	_tray_label.clip_text = true
	_tray_label.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(_tray_label)

	_notification_label = HuntUI.outlined_label("Quán mở cửa! Khách tới thì chạm bàn trống đủ ghế để xếp chỗ.", 18, Color("f3e2c0"))
	_notification_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_notification_label.size_flags_vertical = SIZE_SHRINK_CENTER
	_notification_label.clip_text = true
	row.add_child(_notification_label)

	var close := Button.new()
	close.text = "Đóng cửa, tổng kết  »"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(250, 56)
	close.add_theme_font_size_override("font_size", 20)
	_style_button(close, Color("f2a33a"), Color("8a5a3c"), HuntUI.INK)
	close.pressed.connect(_close_shop)
	row.add_child(close)


func _style_button(b: Button, bg: Color, border: Color, font: Color) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = bg.darkened(0.18) if state.ends_with("pressed") else (bg.darkened(0.4) if state == "disabled" else bg)
		s.border_color = border
		s.set_border_width_all(3)
		s.set_corner_radius_all(6)
		s.shadow_color = Color(0, 0, 0, 0.3)
		s.shadow_offset = Vector2(0, 3)
		s.shadow_size = 1
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, font)


func _center_stage() -> void:
	_stage.position = ((size - STAGE) / 2.0).floor()


func _setup_tables() -> void:
	# Số bàn theo nâng cấp "Thêm bàn" (tối đa GameState.MAX_TABLES_FLOOR1 = 10).
	var count := clampi(maxi(GameState.tables_floor1, int(Database.upgrade_value("tables"))), 1, GameState.MAX_TABLES_FLOOR1)
	for i in count:
		var table := TableNode.new()
		table.eating_time = BASE_EATING_TIME * Database.upgrade_value("stove")
		add_child(table)
		tables.append(table)
		table.eating_finished.connect(_on_eating_finished)
		var seats := TABLE_SEATS
		_seats.append(seats)
		var visual := TableVisual.new(i + 1, seats)
		_floor.add_child(visual)
		visual.attach_bubble(_bubbles)
		visual.tapped.connect(_on_table_tapped.bind(table))
		_visuals.append(visual)
	_layout_tables()


## Xếp bàn 1-3 hàng trên sàn, cân đối hai bên: chia đều số bàn cho các hàng (vd 14 -> 5/4/5), hàng nào
## cũng căn giữa. Các hàng chồng nhau một phần để vừa sàn. Đông bàn thì thu nhỏ bàn.
func _layout_tables() -> void:
	var n := _visuals.size()
	if n == 0:
		return
	var area := FLOOR_RECT.size
	var rows := 1 if n <= 5 else (2 if n <= 10 else 3)
	var counts := _row_counts(n, rows)
	# Bề rộng từng hàng (tỉ lệ 1) = tổng bề rộng bàn + khe giữa các bàn.
	var widths: Array[float] = []
	var i := 0
	for r in rows:
		var w := 0.0
		for c in counts[r]:
			w += _visuals[i].size.x
			i += 1
		widths.append(w + TABLE_GAP * (counts[r] - 1))
	var height_units := 1.0 + (rows - 1) * (1.0 - ROW_OVERLAP)
	var max_scale := MAX_TABLE_SCALE if rows == 1 else 1.0
	var sc := minf(max_scale, area.y / (TableVisual.HEIGHT * height_units))
	for w in widths:
		sc = minf(sc, area.x / w)
	var table_h := TableVisual.HEIGHT * sc
	var pitch := table_h * (1.0 - ROW_OVERLAP)
	# Đáy hàng cuối: quán 1 hàng chừa lối đi phía dưới; đông bàn thì dùng hết sàn.
	var bottom := area.y * (ONE_ROW_BOTTOM if rows == 1 else 1.0)
	var top := bottom - table_h - pitch * (rows - 1)
	i = 0
	for r in rows:
		var x := (area.x - widths[r] * sc) * 0.5
		for c in counts[r]:
			var v: TableVisual = _visuals[i]
			v.set_display_scale(sc)
			v.position = Vector2(x, top + r * pitch).floor()
			x += (v.size.x + TABLE_GAP) * sc
			i += 1


## Số bàn mỗi hàng, chênh nhau nhiều nhất 1 và đối xứng trên-dưới (vd 14 bàn 3 hàng -> 5/4/5, 13 -> 4/5/4).
static func _row_counts(n: int, rows: int) -> Array[int]:
	var base := n / rows
	var extra := n % rows
	var counts: Array[int] = []
	for r in rows:
		counts.append(base)
	if rows == 3 and extra == 1:
		counts[1] += 1
	elif rows == 3 and extra == 2:
		counts[0] += 1
		counts[2] += 1
	elif extra > 0:
		counts[0] += 1
	return counts


# --- Nhóm khách tới, xếp hàng chờ ---------------------------------------------------

func _try_spawn_group() -> void:
	if _queue.size() >= MAX_QUEUE or _seats.is_empty():
		return
	var broth := _random_unlocked_broth()
	if broth == null:
		return
	var special: String = _events.take_pending_special()
	var count := _random_group_size(_seats.max())
	if special != "":
		count = mini(count, 2) # Nhà phê bình / giám khảo đi 1-2 người.
	var looks: Array[Texture2D] = []
	for k in count:
		var look: String = GUEST_LOOKS[randi() % GUEST_LOOKS.size()]
		if k == 0 and special != "":
			look = SPECIAL_LOOKS[special]
		looks.append(load(CHAR_DIR + look + ".png"))
	var group := {
		"size": count, "looks": looks, "broth_id": broth.id, "sides": _random_side_items(count),
		"special": special, "wait": QUEUE_WAIT,
	}
	var slot := _queue.size()
	_queue.append(group)
	group["walkers"] = _reception.enter_group(looks, slot, _overlay)
	_make_queue_bubble(group)
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_inside_tree() and not _queue.is_empty() and _queue[0] == group:
			_reception.greet("Xin chào quý khách!"))
	if special == "critic":
		_notify("Nhà phê bình ẩm thực tới! Xếp bàn và phục vụ thật nhanh!", Color("e0b0ff"))
	elif special == "michelin":
		_notify("Có khách lạ vào quán, cứ lặng lẽ ghi chép...", HuntUI.GOLD)
	else:
		_notify("Nhóm %d khách vừa tới. Chạm bàn trống đủ %d ghế để xếp chỗ." % [count, count])


## Số người theo trọng số GROUP_SIZE_WEIGHTS, không quá số ghế của bàn lớn nhất.
static func _random_group_size(max_seats: int) -> int:
	var total := 0
	for s in range(1, mini(max_seats, GROUP_SIZE_WEIGHTS.size() - 1) + 1):
		total += int(GROUP_SIZE_WEIGHTS[s])
	var roll := randi() % maxi(total, 1)
	for s in range(1, mini(max_seats, GROUP_SIZE_WEIGHTS.size() - 1) + 1):
		roll -= int(GROUP_SIZE_WEIGHTS[s])
		if roll < 0:
			return s
	return 1


## Thanh kiên nhẫn mỏng dưới chân nhóm đang chờ (không còn bong bóng "Nhóm N người" để khỏi che quầy).
## Khách đặc biệt có thêm một dòng chữ nhỏ dưới thanh.
func _make_queue_bubble(group: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	var bar := Control.new()
	bar.custom_minimum_size = TableVisual.BAR_SIZE
	bar.size_flags_horizontal = SIZE_SHRINK_CENTER
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(bar)
	var back := ColorRect.new()
	back.color = Color("3b2416")
	back.size = TableVisual.BAR_SIZE
	back.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(back)
	var fill := ColorRect.new()
	fill.position = Vector2(2, 2)
	fill.size = TableVisual.BAR_SIZE - Vector2(4, 4)
	fill.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(fill)
	var special_text := ""
	if group["special"] == "critic":
		special_text = "Nhà phê bình"
	elif group["special"] == "michelin":
		special_text = "Khách lạ"
	if special_text != "":
		var title := HuntUI.outlined_label(special_text, 18, Color("fff59d"))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
	_bubbles.add_child(box)
	group["bubble"] = box
	group["bar"] = fill

## Đếm ngược kiên nhẫn của các nhóm đang chờ; hết thì cả nhóm bỏ về.
func _tick_queue(delta: float) -> void:
	for group in _queue.duplicate():
		group["wait"] = float(group["wait"]) - delta
		if float(group["wait"]) <= 0.0:
			_remove_from_queue(group)
			_reception.leave_queue(group["walkers"])
			GameState.lose_star(STAR_CUSTOMER_LEFT)
			if group["special"] != "":
				# Khách đặc biệt bỏ về ngay ở cửa vẫn tính là phục vụ kém.
				var dummy := TableNode.new()
				dummy.special = group["special"]
				_events.special_result(dummy, false, 0)
				dummy.free()
			_notify("Nhóm %d khách chờ lâu không có bàn nên bỏ về! Bị trừ sao." % int(group["size"]), Color("ff8a80"))


func _remove_from_queue(group: Dictionary) -> void:
	_queue.erase(group)
	var bubble: Control = group.get("bubble")
	if is_instance_valid(bubble):
		bubble.queue_free()
	# Nhóm phía sau tiến lên chỗ trước quầy.
	for i in _queue.size():
		_reception.move_group(_queue[i]["walkers"], i)


# --- Xếp bàn -----------------------------------------------------------------------

func _on_table_tapped(table: TableNode) -> void:
	if table.state == TableNode.State.EMPTY:
		if not _reserved.has(table):
			_seat_at(table)
	else:
		_serve_table(table)


## Xếp nhóm chờ đầu tiên vừa bàn này (đủ ghế) vào bàn.
func _seat_at(table: TableNode) -> void:
	var index := tables.find(table)
	var seats := _seats[index]
	if _queue.is_empty():
		_notify("Chưa có khách chờ. Bàn %d còn trống %d ghế." % [index + 1, seats])
		return
	var group: Dictionary = {}
	for g in _queue:
		if int(g["size"]) <= seats:
			group = g
			break
	if group.is_empty():
		_notify("Bàn %d chỉ có %d ghế, không đủ cho nhóm đang chờ!" % [index + 1, seats], Color("ffccbc"))
		return
	_remove_from_queue(group)
	_reserved[table] = true
	var visual := _visuals[index]
	var count: int = group["size"]
	_reception.greet("Mời vào Bàn %d!" % (index + 1))
	await _reception.seat_group(group["walkers"], visual.seat_globals(count), visual.guest_screen_size() / ReceptionDesk.GUEST_SIZE)
	_reserved.erase(table)
	if not is_inside_tree() or table.state != TableNode.State.EMPTY:
		return
	visual.seat_group(group["looks"])
	var customer := Customer.new()
	customer.group_size = count
	add_child(customer)
	customer.setup(group["broth_id"], group["sides"], CUSTOMER_WAIT)
	table.occupy(customer)
	table.place_order(group["broth_id"], group["sides"])
	table.special = group["special"]
	_notify("Bàn %d (%d người) gọi %s + %d đĩa đồ nhúng." % [index + 1, count, _broth_name(group["broth_id"]), (group["sides"] as Array).size()])


func _random_unlocked_broth() -> BrothData:
	var broths := Database.broths_for_day(GameState.day)
	if broths.is_empty():
		return null
	return broths[randi() % broths.size()]


## Đồ nhúng theo số người: 1 người gọi 1-2 đĩa, nhóm 6 người gọi 5-6 đĩa (tối đa 6).
## Chỉ gọi món kho đang có (đã sơ chế hoặc đồ thô), không gọi quá số lượng còn lại; kho hết thì chỉ gọi lẩu.
func _random_side_items(people: int) -> Array[String]:
	var count := clampi(people - 1 + randi() % 2 + (1 if people == 1 else 0), 1, 6)
	var left := {}
	for id in DIPPING_POOL:
		var n := GameState.get_prepped_count(id) + GameState.get_item_count(id)
		if n > 0:
			left[id] = n
	var result: Array[String] = []
	for i in count:
		if left.is_empty():
			break
		var ids := left.keys()
		var id: String = ids[randi() % ids.size()]
		result.append(id)
		left[id] = int(left[id]) - 1
		if int(left[id]) <= 0:
			left.erase(id)
	return result


## Lấy đồ nhúng của bàn từ kho khi bưng ra; trả về {total: tiền các đĩa đã bưng, served, missing, expired}.
func _take_dishes(table: TableNode) -> Dictionary:
	var total := 0
	var served := 0
	var expired := false
	for id in table.side_items:
		var r := GameState.take_dipping(id)
		if not bool(r["ok"]):
			continue
		served += 1
		total += roundi(DIPPING_PRICE * float(r["price_mult"]) / 1000.0) * 1000
		expired = expired or bool(r["expired"])
	return {"total": total, "served": served, "missing": table.side_items.size() - served, "expired": expired}


# --- Bưng món ----------------------------------------------------------------------

func _pick_to_cart(broth_id: String) -> void:
	if cart.carrying_broth_id == broth_id:
		return
	if cart.carrying_broth_id != "":
		_notify("Khay đang bưng %s, giao xong đã!" % _broth_name(cart.carrying_broth_id), Color("ffccbc"))
		_pass.bounce(cart.carrying_broth_id)
		return
	if not cart.pick_broth(broth_id):
		_notify("Hết %s rồi!" % _broth_name(broth_id), Color("ff8a80"))
		_pass.bounce(broth_id)
		return
	_pass.bounce(broth_id)
	_pass.chef.work(0.3, "stir")
	_notify("Đã lấy %s lên khay. Chạm bàn gọi món này để bưng ra." % _broth_name(broth_id))


func _serve_table(table: TableNode) -> void:
	if table.state != TableNode.State.WAITING_ORDER:
		return
	if _negotiating != null:
		return
	var id := table.order_broth_id
	if cart.carrying_broth_id == "":
		if not cart.pick_broth(id):
			_negotiate(table)
			return
	elif cart.carrying_broth_id != id:
		_notify("Khay đang bưng %s, bàn này gọi %s!" % [_broth_name(cart.carrying_broth_id), _broth_name(id)], Color("ffccbc"))
		return
	_deliver(table)


## Bưng nồi lẩu (1 nồi cho cả bàn) cùng các đĩa đồ nhúng ra bàn.
func _deliver(table: TableNode) -> void:
	var fast := table.customer != null and table.customer.remaining_time() > CUSTOMER_WAIT * 0.5
	var broth_id := cart.carrying_broth_id
	if cart.serve_to(table):
		table.served_fast = fast
		GameState.add_star(STAR_FAST_SERVE if fast else STAR_SERVE)
		# Đồ nhúng lấy từ kho lúc bưng ra; món đã hết (bàn khác dùng mất) thì không bưng, không tính tiền.
		var dishes := _take_dishes(table)
		table.set_meta("dish_total", dishes["total"])
		table.set_meta("dish_count", dishes["served"])
		table.served_expired = table.served_expired or bool(dishes["expired"])
		var visual := _visuals[tables.find(table)]
		visual.delay_pot(_carry_pot(broth_id, visual))
		var missing_text := " (thiếu %d đĩa, kho hết)" % int(dishes["missing"]) if int(dishes["missing"]) > 0 else ""
		_notify("Đã bưng %s + %d đĩa đồ nhúng ra bàn%s%s!" % [_broth_name(table.order_broth_id), int(dishes["served"]), missing_text, " (nhanh, +sao)" if fast else ""], Color("c8e6c9"))


func _build_waiter() -> void:
	_waiter = TextureRect.new()
	_waiter.texture = load(CHAR_DIR + "staff_tung.png")
	_waiter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_waiter.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_waiter.stretch_mode = TextureRect.STRETCH_SCALE
	_waiter.size = Vector2(WAITER_SIZE, WAITER_SIZE)
	_waiter.position = WAITER_HOME
	_waiter.mouse_filter = MOUSE_FILTER_IGNORE
	_overlay.add_child(_waiter)
	_waiter_legs = SpriteFrameLayer.attach_to(_waiter)
	_waiter_pot = TextureRect.new()
	_waiter_pot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_waiter_pot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_waiter_pot.size = KitchenPass.POT_SIZE
	_waiter_pot.position = Vector2(40, 34)
	_waiter_pot.mouse_filter = MOUSE_FILTER_IGNORE
	_waiter_pot.visible = false
	_waiter.add_child(_waiter_pot)


## Bưng nồi ra bàn: có Tùng (rảnh) thì Tùng chạy ra, không thì nồi bay ra. Trả về số giây tới bàn.
func _carry_pot(broth_id: String, visual: TableVisual) -> float:
	if _waiter == null or _waiter_busy:
		_fly_pot(broth_id, visual)
		return 0.4
	_waiter_busy = true
	var target := visual.pot_global_center() - _overlay.global_position - Vector2(WAITER_SIZE * 0.35, WAITER_SIZE * 0.6)
	var go := maxf(0.25, _waiter.position.distance_to(target) / WAITER_SPEED)
	var back := maxf(0.25, target.distance_to(WAITER_HOME) / WAITER_SPEED)
	_waiter_pot.texture = KitchenPass.pot_texture(broth_id)
	_waiter_pot.visible = true
	_waiter.flip_h = target.x < _waiter.position.x
	_waiter_pot.position.x = 0.0 if _waiter.flip_h else 40.0
	if _waiter_legs != null:
		_waiter_legs.play("run")
	var t := _waiter.create_tween()
	t.tween_property(_waiter, "position", target, go)
	t.tween_callback(func() -> void:
		_waiter_pot.visible = false
		_waiter.flip_h = WAITER_HOME.x < _waiter.position.x
		if _waiter_legs != null:
			_waiter_legs.play("run"))
	t.tween_property(_waiter, "position", WAITER_HOME, back)
	t.tween_callback(func() -> void:
		_waiter_busy = false
		_waiter.flip_h = false
		if _waiter_legs != null:
			_waiter_legs.stop())
	return go


## Cả nhóm rời bàn đi ra cửa (ăn xong vui vẻ / bỏ về đỏ mặt).
func _guests_leave(visual: TableVisual, happy: bool) -> void:
	var seat_scale := visual.guest_screen_size() / ReceptionDesk.GUEST_SIZE
	var k := 0
	for g in visual.seated_guests():
		_reception.walk_out(g["texture"], g["global"], seat_scale, happy, _overlay, k * 0.15)
		k += 1


## Nồi bay từ quầy bếp ra bàn (chỉ là hình ảnh, khi chưa có người bưng).
func _fly_pot(broth_id: String, visual: TableVisual) -> void:
	var r := TextureRect.new()
	r.texture = KitchenPass.pot_texture(broth_id)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = KitchenPass.POT_SIZE
	r.mouse_filter = MOUSE_FILTER_IGNORE
	_overlay.add_child(r)
	var from := _pass.pot_global_center(broth_id) - _overlay.global_position - r.size / 2.0
	var to := visual.pot_global_center() - _overlay.global_position - r.size / 2.0
	r.position = from
	var t := r.create_tween()
	t.tween_method(func(k: float) -> void:
		r.position = from.lerp(to, k) + Vector2(0, -120.0 * sin(k * PI)), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	t.tween_callback(r.queue_free)
	_sfx("splash", -14.0)


## Hết món đã gọi: đề nghị đổi sang món khác còn trong kho.
func _negotiate(table: TableNode) -> void:
	var missing := _broth_name(table.order_broth_id)
	var offer := _best_in_stock()
	if offer == null:
		_notify("Hết %s và kho cũng không còn loại lẩu nào khác!" % missing, Color("ff8a80"))
		return
	if table.customer != null and table.customer.has_meta("negotiated"):
		_notify("Khách bàn này đã từ chối đổi món rồi.", Color("ffccbc"))
		return
	_negotiating = table
	var wheel = preload("res://scenes/sell/negotiation_wheel.gd").new()
	add_child(wheel)
	wheel.open(missing, offer.display_name, NEGOTIATE_CHANCE)
	var accepted: bool = await wheel.decided
	_negotiating = null
	if table.state != TableNode.State.WAITING_ORDER:
		return
	if table.customer != null:
		table.customer.set_meta("negotiated", true)
	if accepted and cart.carrying_broth_id == "" and cart.pick_broth(offer.id):
		table.order_broth_id = offer.id
		if table.customer != null:
			table.customer.desired_broth_id = offer.id
		_notify("Khách đồng ý đổi sang %s!" % offer.display_name, Color("c8e6c9"))
		_deliver(table)
	else:
		_notify("Khách không đồng ý đổi món!", Color("ff8a80"))
		_customer_timeout(table)


## Món còn nhiều phần nhất trong kho, bằng nhau thì lấy món đắt hơn.
func _best_in_stock() -> BrothData:
	var best: BrothData = null
	for b in Database.broths:
		var n := GameState.get_broth_count(b.id)
		if n <= 0:
			continue
		if best == null or n > GameState.get_broth_count(best.id) or (n == GameState.get_broth_count(best.id) and b.price > best.price):
			best = b
	return best


func _broth_name(id: String) -> String:
	var broth := Database.get_broth(id)
	return broth.display_name if broth else id


# --- Ăn xong / bỏ về ---------------------------------------------------------------

func _finish_eating(table: TableNode) -> void:
	if table.state != TableNode.State.EATING:
		return
	var visual := _visuals[tables.find(table)]
	var broth := Database.get_broth(table.order_broth_id)
	var dishes := int(table.get_meta("dish_count", 0))
	var dish_total := int(table.get_meta("dish_total", 0))
	for key in ["dish_count", "dish_total"]:
		if table.has_meta(key):
			table.remove_meta(key)
	if broth and table.served_expired and (table.special != "" or randf() < EXPIRED_DETECT_CHANCE):
		var compensation := roundi(broth.price * EXPIRED_COMPENSATION / 1000.0) * 1000
		GameState.add_money(-compensation, false)
		GameState.lose_star(EXPIRED_STAR_LOSS)
		_notify("Khách phát hiện lẩu hết hạn! Bồi thường %s, trừ sao." % GameState.format_money(compensation), Color("ff8a80"))
		_float_text("-%s" % GameState.format_money(compensation), visual, Color("ff8a80"))
		if table.special != "":
			_events.special_result(table, false, broth.price)
		_guests_leave(visual, false)
		table.clear()
		return
	if broth:
		# Hoá đơn = 1 nồi lẩu + các đĩa đồ nhúng (nhóm đông gọi nhiều đĩa hơn).
		var bill := broth.price + dish_total
		var tip_rate := randf_range(TIP_MIN, TIP_MAX) + Database.upgrade_value("furniture")
		var tip := roundi(bill * tip_rate / 1000.0) * 1000
		# Phí phục vụ (nâng cấp mở khi đủ 10 bàn): cộng % vào hoá đơn.
		var service := roundi(bill * Database.upgrade_value("service") / 1000.0) * 1000
		GameState.add_money(bill + service + tip)
		var service_text := ", phí phục vụ %s" % GameState.format_money(service) if service > 0 else ""
		_notify("Bàn %d thanh toán lẩu + %d đĩa: %s%s, tip %s." % [tables.find(table) + 1, dishes, GameState.format_money(bill), service_text, GameState.format_money(tip)], Color("fff59d"))
		_float_text("+%s" % GameState.format_money(bill + service + tip), visual, HuntUI.GOLD)
		_reception.cash_in(bill + service + tip)
		_sfx("loot", -12.0)
		if table.special != "":
			_events.special_result(table, table.served_fast and not table.served_expired, bill)
	_guests_leave(visual, true)
	table.clear()


func _customer_timeout(table: TableNode) -> void:
	if table.state != TableNode.State.WAITING_ORDER:
		return
	GameState.lose_star(STAR_CUSTOMER_LEFT)
	_notify("Khách Bàn %d chờ món lâu quá nên bỏ về! Bị trừ sao." % (tables.find(table) + 1), Color("ff8a80"))
	_float_text("Bỏ về!", _visuals[tables.find(table)], Color("ff8a80"))
	if table.special != "":
		_events.special_result(table, false, 0)
	_guests_leave(_visuals[tables.find(table)], false)
	table.clear()


func _on_eating_finished(table: TableNode) -> void:
	_finish_eating(table)


func _close_shop() -> void:
	if _leaving:
		return
	_leaving = true
	DayManager.next_phase()


# --- Cập nhật hình -----------------------------------------------------------------

func _update_ui() -> void:
	_pass.refresh(cart.carrying_broth_id)
	if cart.carrying_broth_id == "":
		_tray_icon.texture = load("res://assets/sprites/kitchen/tray.png")
		_tray_label.text = "Khay: trống"
	else:
		_tray_icon.texture = KitchenPass.pot_texture(cart.carrying_broth_id)
		_tray_label.text = "Khay: %s" % _broth_name(cart.carrying_broth_id)

	# Thanh kiên nhẫn dưới chân nhóm đang chờ.
	var smallest := 99
	for i in _queue.size():
		var group := _queue[i]
		smallest = mini(smallest, int(group["size"]))
		var bubble: Control = group["bubble"]
		bubble.reset_size()
		var spot := _reception.queue_bar_spot(i, bubble.size) - _bubbles.global_position
		bubble.position = spot.round()
		var r := float(group["wait"]) / QUEUE_WAIT
		var fill: ColorRect = group["bar"]
		fill.size.x = (TableVisual.BAR_SIZE.x - 4.0) * clampf(r, 0.0, 1.0)
		fill.color = TableVisual._patience_color(r)

	for i in tables.size():
		var table := tables[i]
		var visual := _visuals[i]
		match table.state:
			TableNode.State.WAITING_ORDER:
				visual.set_highlight(0)
				var patience := (table.customer.remaining_time() / CUSTOMER_WAIT) if table.customer else 0.0
				var has_stock := GameState.get_broth_count(table.order_broth_id) > 0 or cart.carrying_broth_id == table.order_broth_id
				var note := ""
				var note_color := HuntUI.RUST
				if table.special == "critic":
					note = "Nhà phê bình"
					note_color = Color("6a3d9a")
				elif table.special == "michelin":
					note = "Khách lạ"
					note_color = HuntUI.GOLDEN_INK
				if not has_stock:
					note = "Hết món! Chạm để đổi" if table.customer and not table.customer.has_meta("negotiated") else "Hết món!"
					note_color = HuntUI.BAD
				visual.show_waiting(table.order_broth_id, table.side_items, patience, note, note_color, has_stock)
			TableNode.State.EATING:
				visual.set_highlight(0)
				visual.show_eating(table.order_broth_id, 1.0 - table.eating_remaining() / maxf(table.eating_time, 0.01))
			_:
				if not _reserved.has(table):
					visual.show_empty()
					# Có nhóm chờ: bàn đủ ghế cho ít nhất một nhóm thì nhấp nháy, không đủ thì mờ.
					visual.set_highlight(0 if _queue.is_empty() else (1 if _seats[i] >= smallest else -1))
				else:
					visual.set_highlight(0)


func _notify(text: String, color := Color("f3e2c0")) -> void:
	_notification_label.text = text
	_notification_label.add_theme_color_override("font_color", color)


func _float_text(text: String, visual: TableVisual, color: Color) -> void:
	var l := HuntUI.outlined_label(text, 22, color)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.custom_minimum_size = Vector2(240, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var at := visual.pot_global_center() - _bubbles.global_position
	l.position = at - Vector2(120, 20)
	_bubbles.add_child(l)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", at.y - 80, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.8)
	t.chain().tween_callback(l.queue_free)


func _sfx(name: String, db: float) -> void:
	var path := "res://assets/audio/sfx/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## SellEvents ghi nhật ký qua hàm này (không còn ô log, chỉ in ra console để dò lỗi).
func log_line(text: String) -> void:
	print(text)
