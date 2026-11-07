extends Control
## Chiều tối – bán hàng: Giao diện quán ăn 2D trực quan (Bàn ăn gỗ, khách ngồi, quầy bếp).

const TIP_MIN := 0.03
const TIP_MAX := 0.07
const BASE_EATING_TIME := 8.0
const SPAWN_INTERVAL := 6.0
const CUSTOMER_WAIT := 20.0
const STAR_FAST_SERVE := 0.15
const STAR_SERVE := 0.05
const STAR_CUSTOMER_LEFT := 0.25
const NEGOTIATE_CHANCE := 0.5
const EXPIRED_DETECT_CHANCE := 0.25
const EXPIRED_COMPENSATION := 2.0
const EXPIRED_STAR_LOSS := 0.5

const INGREDIENT_DIR := "res://assets/sprites/ingredients/"

var tables: Array[TableNode] = []
var cart := Cart.new()
var _spawn_timer := 3.0
var _table_ui: Array[Dictionary] = []
var _negotiating: TableNode = null
var _events = preload("res://scenes/sell/sell_events.gd").new()

var _revenue_label: Label
var _stars_label: Label
var _cart_label: Label
var _inventory_box: HBoxContainer
var _notification_label: Label
var _inventory_buttons: Array[Button] = []
var _inventory_ids: Array[String] = []


func _ready() -> void:
	add_child(cart)
	add_child(_events)
	_events.setup(self)
	_build_ui()
	_setup()


func _process(delta: float) -> void:
	var spawn_interval := SPAWN_INTERVAL / maxf(0.2, GameState.customer_multiplier)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		_try_spawn_customer()
	for table in tables:
		if table.state == TableNode.State.WAITING_ORDER and table.customer and table != _negotiating:
			if table.customer.remaining_time() <= 0.0:
				_customer_timeout(table)
		elif table.state == TableNode.State.EATING:
			if table.eating_remaining() <= 0.0:
				_finish_eating(table)
	_update_ui()


func _build_ui() -> void:
	# 1. NỀN NHÀ HÀNG ẤM CÚNG (Tường ốp gỗ trên + Sàn gỗ phía dưới)
	var bg_container := Control.new()
	bg_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_container)

	# Tường gỗ trên
	var wall := ColorRect.new()
	wall.color = Color("#2d180e")
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_container.add_child(wall)

	# Sàn gỗ ấm bên dưới (bắt đầu từ y = 140px)
	var floor_panel := Panel.new()
	floor_panel.anchor_top = 0.22
	floor_panel.anchor_bottom = 1.0
	floor_panel.anchor_left = 0.0
	floor_panel.anchor_right = 1.0
	floor_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var floor_style := StyleBoxFlat.new()
	floor_style.bg_color = Color("#754324")
	floor_style.border_width_top = 6
	floor_style.border_color = Color("#4a2612")
	floor_style.shadow_color = Color(0, 0, 0, 0.35)
	floor_style.shadow_size = 12
	floor_panel.add_theme_stylebox_override("panel", floor_style)
	bg_container.add_child(floor_panel)

	# 2. KHÔNG GIAN CHÍNH (Chừa 92px phía trên cho HUD chung của Hạo)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 96)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	# Khu vực giữa: Bàn ăn (Trái 72%) + Quầy bếp (Phải 28%)
	var center_row := HBoxContainer.new()
	center_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_row.add_theme_constant_override("separation", 20)
	main_vbox.add_child(center_row)

	# --- KHU VỰC PHÒNG ĂN (LEFT) ---
	var dining_area := VBoxContainer.new()
	dining_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dining_area.size_flags_stretch_ratio = 2.4
	center_row.add_child(dining_area)

	var dining_title := HuntUI.outlined_label("Khu Vực Bàn Ăn Nhà Hàng", 22, HuntUI.GOLD)
	dining_area.add_child(dining_title)

	var table_grid := GridContainer.new()
	table_grid.columns = 2
	table_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_grid.add_theme_constant_override("h_separation", 20)
	table_grid.add_theme_constant_override("v_separation", 16)
	dining_area.add_child(table_grid)
	set_meta("table_grid", table_grid)

	# --- KHU VỰC QUẦY BẾP (RIGHT) ---
	var kitchen_panel := PanelContainer.new()
	kitchen_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kitchen_panel.size_flags_stretch_ratio = 1.0
	kitchen_panel.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_panel"))
	center_row.add_child(kitchen_panel)

	var kitchen_vbox := VBoxContainer.new()
	kitchen_vbox.add_theme_constant_override("separation", 10)
	kitchen_panel.add_child(kitchen_vbox)

	var kitchen_title := HuntUI.label("QUẦY BẾP TRƯỞNG", 20, HuntUI.RUST)
	kitchen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kitchen_vbox.add_child(kitchen_title)

	# Hình ảnh đầu bếp và bếp lò đỏ
	var kitchen_stage := HBoxContainer.new()
	kitchen_stage.alignment = BoxContainer.ALIGNMENT_CENTER
	kitchen_stage.add_theme_constant_override("separation", 12)
	kitchen_vbox.add_child(kitchen_stage)

	var chef_tex = load("res://assets/sprites/characters/player.png")
	var chef_rect := TextureRect.new()
	chef_rect.texture = chef_tex
	chef_rect.custom_minimum_size = Vector2(56, 56)
	chef_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	kitchen_stage.add_child(chef_rect)

	var flame_tex = load("res://assets/sprites/fx/flame.png")
	var flame_rect := TextureRect.new()
	flame_rect.texture = flame_tex
	flame_rect.custom_minimum_size = Vector2(40, 40)
	flame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	kitchen_stage.add_child(flame_rect)

	var pot_tex = load("res://assets/sprites/ui/broth_pot.png")
	var pot_stage := TextureRect.new()
	pot_stage.texture = pot_tex
	pot_stage.custom_minimum_size = Vector2(40, 40)
	pot_stage.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	kitchen_stage.add_child(pot_stage)

	var sep := HSeparator.new()
	kitchen_vbox.add_child(sep)

	_revenue_label = HuntUI.label("Doanh thu: 0đ", 18, HuntUI.INK)
	kitchen_vbox.add_child(_revenue_label)

	_stars_label = HuntUI.label("Đánh giá: 5.0 ★", 18, HuntUI.GOLD)
	kitchen_vbox.add_child(_stars_label)

	var hint_lbl := HuntUI.label("Quy tắc phục vụ:\n• Chạm vào Bàn/Bong bóng để bưng món.\n• Giao nhanh còn >50% giờ: +0.15★.\n• Hết món: bấm Thương lượng đổi món.", 14, HuntUI.INK_SOFT)
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kitchen_vbox.add_child(hint_lbl)

	_notification_label = HuntUI.label("Quán bắt đầu mở cửa đón khách!", 16, HuntUI.RUST)
	_notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notification_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kitchen_vbox.add_child(_notification_label)

	# --- 3. THANH KHAY ĐÁY (CARRIER & KHO NƯỚC CỐT) ---
	var bottom_panel := PanelContainer.new()
	bottom_panel.custom_minimum_size = Vector2(0, 64)
	bottom_panel.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_card"))
	main_vbox.add_child(bottom_panel)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 16)
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_panel.add_child(bottom_row)

	var inv_title := HuntUI.label("Kho nước cốt:", 18, HuntUI.INK)
	bottom_row.add_child(inv_title)

	_inventory_box = HBoxContainer.new()
	_inventory_box.add_theme_constant_override("separation", 8)
	bottom_row.add_child(_inventory_box)

	var vsep := VSeparator.new()
	bottom_row.add_child(vsep)

	_cart_label = HuntUI.outlined_label("Xe đẩy: [Trống]", 18, HuntUI.GOLD)
	bottom_row.add_child(_cart_label)

	var spacer_end := Control.new()
	spacer_end.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(spacer_end)

	var close_btn := HuntUI.button("Đóng cửa, tổng kết »")
	close_btn.custom_minimum_size = Vector2(180, 48)
	close_btn.pressed.connect(DayManager.next_phase)
	bottom_row.add_child(close_btn)


func _setup() -> void:
	var table_grid := get_meta("table_grid") as GridContainer
	var char_tex = load("res://assets/sprites/characters/player.png")
	var pot_tex = load("res://assets/sprites/ui/broth_pot.png")
	var smoke_tex = load("res://assets/sprites/fx/smoke.png")

	for i in GameState.tables_floor1:
		var table := TableNode.new()
		table.eating_time = BASE_EATING_TIME * Database.upgrade_value("stove")
		add_child(table)
		tables.append(table)
		table.customer_left.connect(_on_table_cleared)
		table.eating_finished.connect(_on_eating_finished)

		# KHUNG TRẠM BÀN ĂN 2D
		var station := PanelContainer.new()
		station.custom_minimum_size = Vector2(370, 200)
		station.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		station.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Style nền bàn ăn nhẹ nhàng, không còn viền hộp thô kệch
		var st_style := StyleBoxFlat.new()
		st_style.bg_color = Color(0.2, 0.12, 0.08, 0.45)
		st_style.border_color = Color(0.5, 0.35, 0.22, 0.6)
		st_style.border_width_left = 2
		st_style.border_width_right = 2
		st_style.border_width_top = 2
		st_style.border_width_bottom = 2
		st_style.corner_radius_top_left = 12
		st_style.corner_radius_top_right = 12
		st_style.corner_radius_bottom_left = 12
		st_style.corner_radius_bottom_right = 12
		st_style.content_margin_left = 10
		st_style.content_margin_right = 10
		st_style.content_margin_top = 8
		st_style.content_margin_bottom = 8
		station.add_theme_stylebox_override("panel", st_style)
		table_grid.add_child(station)

		var st_row := HBoxContainer.new()
		st_row.add_theme_constant_override("separation", 12)
		station.add_child(st_row)

		# --- CỘT TRÁI: BÀN ĂN GỖ TRÒN & KHÁCH & NỒI LẨU ---
		var visual_col := Control.new()
		visual_col.custom_minimum_size = Vector2(130, 180)
		visual_col.mouse_filter = Control.MOUSE_FILTER_PASS
		st_row.add_child(visual_col)

		# Ghế bên trái (khách ngồi)
		var chair_left := Panel.new()
		chair_left.position = Vector2(4, 70)
		chair_left.size = Vector2(26, 40)
		var chair_style := StyleBoxFlat.new()
		chair_style.bg_color = Color("#593016")
		chair_style.corner_radius_top_left = 6
		chair_style.corner_radius_bottom_left = 6
		chair_left.add_theme_stylebox_override("panel", chair_style)
		visual_col.add_child(chair_left)

		# Mặt bàn gỗ tròn Oval
		var wood_table := Panel.new()
		wood_table.position = Vector2(25, 45)
		wood_table.size = Vector2(85, 85)
		var tbl_style := StyleBoxFlat.new()
		tbl_style.bg_color = Color("#9c572b") # Mặt gỗ nâu đỏ ấm
		tbl_style.border_color = Color("#4a230d")
		tbl_style.border_width_left = 4
		tbl_style.border_width_top = 4
		tbl_style.border_width_right = 4
		tbl_style.border_width_bottom = 4
		tbl_style.corner_radius_top_left = 42
		tbl_style.corner_radius_top_right = 42
		tbl_style.corner_radius_bottom_left = 42
		tbl_style.corner_radius_bottom_right = 42
		tbl_style.shadow_color = Color(0, 0, 0, 0.4)
		tbl_style.shadow_size = 6
		wood_table.add_theme_stylebox_override("panel", tbl_style)
		visual_col.add_child(wood_table)

		# Bếp âm ở giữa bàn
		var burner := Panel.new()
		burner.position = Vector2(24, 24)
		burner.size = Vector2(37, 37)
		var burner_style := StyleBoxFlat.new()
		burner_style.bg_color = Color("#382318")
		burner_style.corner_radius_top_left = 18
		burner_style.corner_radius_top_right = 18
		burner_style.corner_radius_bottom_left = 18
		burner_style.corner_radius_bottom_right = 18
		burner.add_theme_stylebox_override("panel", burner_style)
		wood_table.add_child(burner)

		# Ghế bên phải
		var chair_right := Panel.new()
		chair_right.position = Vector2(104, 70)
		chair_right.size = Vector2(24, 40)
		var chair_r_style := StyleBoxFlat.new()
		chair_r_style.bg_color = Color("#593016")
		chair_r_style.corner_radius_top_right = 6
		chair_r_style.corner_radius_bottom_right = 6
		chair_right.add_theme_stylebox_override("panel", chair_r_style)
		visual_col.add_child(chair_right)

		# Sprite Nhân vật khách ngồi ở ghế
		var char_rect := TextureRect.new()
		char_rect.texture = char_tex
		char_rect.position = Vector2(-2, 55)
		char_rect.custom_minimum_size = Vector2(46, 46)
		char_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		char_rect.visible = false
		visual_col.add_child(char_rect)

		# Sprite Nồi lẩu sôi trên bàn
		var pot_rect := TextureRect.new()
		pot_rect.texture = pot_tex
		pot_rect.position = Vector2(46, 62)
		pot_rect.custom_minimum_size = Vector2(42, 42)
		pot_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pot_rect.visible = false
		visual_col.add_child(pot_rect)

		# Sprite Khói bốc lên
		var smoke_rect := TextureRect.new()
		smoke_rect.texture = smoke_tex
		smoke_rect.position = Vector2(50, 36)
		smoke_rect.custom_minimum_size = Vector2(34, 34)
		smoke_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		smoke_rect.visible = false
		visual_col.add_child(smoke_rect)

		# Nhãn số bàn dưới chân bàn
		var table_num_lbl := HuntUI.label("Bàn %d" % (i + 1), 16, HuntUI.GOLD)
		table_num_lbl.position = Vector2(45, 138)
		visual_col.add_child(table_num_lbl)

		# --- CỘT PHẢI: BONG BÓNG GỌI MÓN / ĐẾM GIỜ / NÚT PHỤC VỤ ---
		var info_col := VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.add_theme_constant_override("separation", 6)
		st_row.add_child(info_col)

		var status_lbl := HuntUI.label("Trống - Đang chờ khách", 16, HuntUI.INK_SOFT)
		info_col.add_child(status_lbl)

		# Bong bóng gọi món
		var bubble_panel := PanelContainer.new()
		bubble_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var bub_style := StyleBoxFlat.new()
		bub_style.bg_color = Color("#fcf8e8")
		bub_style.border_color = Color("#a67c52")
		bub_style.border_width_left = 2
		bub_style.border_width_top = 2
		bub_style.border_width_right = 2
		bub_style.border_width_bottom = 2
		bub_style.corner_radius_top_left = 10
		bub_style.corner_radius_top_right = 10
		bub_style.corner_radius_bottom_left = 10
		bub_style.corner_radius_bottom_right = 10
		bub_style.content_margin_left = 8
		bub_style.content_margin_right = 8
		bub_style.content_margin_top = 6
		bub_style.content_margin_bottom = 6
		bubble_panel.add_theme_stylebox_override("panel", bub_style)
		info_col.add_child(bubble_panel)

		var bub_vbox := VBoxContainer.new()
		bub_vbox.add_theme_constant_override("separation", 4)
		bubble_panel.add_child(bub_vbox)

		var vip_badge := HuntUI.label("", 15, HuntUI.GOLD)
		bub_vbox.add_child(vip_badge)

		var order_lbl := HuntUI.label("", 16, HuntUI.INK)
		order_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bub_vbox.add_child(order_lbl)

		# Hàng icon nguyên liệu nhúng kèm
		var sides_row := HBoxContainer.new()
		sides_row.add_theme_constant_override("separation", 4)
		bub_vbox.add_child(sides_row)

		var wait_bar := ProgressBar.new()
		wait_bar.custom_minimum_size = Vector2(0, 14)
		bub_vbox.add_child(wait_bar)

		var wait_time_lbl := HuntUI.label("", 14, HuntUI.INK_SOFT)
		bub_vbox.add_child(wait_time_lbl)

		var eat_bar := ProgressBar.new()
		eat_bar.custom_minimum_size = Vector2(0, 14)
		bub_vbox.add_child(eat_bar)

		var eat_time_lbl := HuntUI.label("", 14, HuntUI.INK_SOFT)
		bub_vbox.add_child(eat_time_lbl)

		# Nút phục vụ bàn / thương lượng
		var serve_btn := HuntUI.button("Giao món đến bàn")
		serve_btn.custom_minimum_size = Vector2(0, 44)
		serve_btn.pressed.connect(_serve_table.bind(table))
		info_col.add_child(serve_btn)

		_table_ui.append({
			"table": table,
			"status": status_lbl,
			"order": order_lbl,
			"sides_row": sides_row,
			"wait_bar": wait_bar,
			"wait_time": wait_time_lbl,
			"eat_bar": eat_bar,
			"eat_time": eat_time_lbl,
			"serve": serve_btn,
			"char": char_rect,
			"pot": pot_rect,
			"smoke": smoke_rect,
			"vip": vip_badge,
			"bubble": bubble_panel,
		})

	for broth in Database.broths_for_day(GameState.day):
		var btn := HuntUI.button(broth.display_name)
		btn.custom_minimum_size = Vector2(130, 44)
		btn.pressed.connect(_pick_to_cart.bind(broth.id))
		_inventory_box.add_child(btn)
		_inventory_buttons.append(btn)
		_inventory_ids.append(broth.id)


func _try_spawn_customer() -> void:
	var empty_table := _first_empty_table()
	if empty_table == null:
		return
	var broth := _random_unlocked_broth()
	if broth == null:
		return
	var sides := _random_side_items()
	var customer := Customer.new()
	add_child(customer)
	customer.setup(broth.id, sides, CUSTOMER_WAIT)
	empty_table.occupy(customer)
	empty_table.place_order(broth.id, sides)
	empty_table.special = _events.take_pending_special()
	if empty_table.special == "critic":
		log_line_safe("[color=#6a3d9a]Nhà phê bình vào Bàn, gọi %s.[/color]" % broth.display_name)
		_notification_label.text = "Nhà phê bình ẩm thực vừa vào! Hãy phục vụ thật nhanh!"
	elif empty_table.special == "michelin":
		log_line_safe("[color=gold]Giám khảo Michelin ẩn danh vào Bàn, gọi %s.[/color]" % broth.display_name)
		_notification_label.text = "Có khách lạ vào quán ghi chép... (Nghi là Giám khảo Michelin!)"
	else:
		log_line_safe("Khách vào Bàn, gọi %s." % broth.display_name)


func _first_empty_table() -> TableNode:
	for table in tables:
		if table.state == TableNode.State.EMPTY:
			return table
	return null


func _random_unlocked_broth() -> BrothData:
	var broths := Database.broths_for_day(GameState.day)
	if broths.is_empty():
		return null
	return broths[randi() % broths.size()]


func _random_side_items() -> Array[String]:
	var pool := ["beef", "mushroom", "greens", "shrimp", "enoki", "tomato", "chili"]
	var count := 1 + randi() % 2
	var result: Array[String] = []
	for i in count:
		result.append(pool[randi() % pool.size()])
	return result


func _pick_to_cart(broth_id: String) -> void:
	if cart.carrying_broth_id != "":
		_notification_label.text = "Xe đẩy đang chở món khác, hãy giao trước!"
		return
	if not cart.pick_broth(broth_id):
		var broth := Database.get_broth(broth_id)
		_notification_label.text = "Kho chưa có món %s!" % (broth.display_name if broth else broth_id)
		return
	_notification_label.text = "Đã lấy 1 nồi %s lên xe đẩy." % _broth_name(broth_id)


func _serve_table(table: TableNode) -> void:
	if table.state != TableNode.State.WAITING_ORDER:
		return
	if _negotiating != null:
		return
	if cart.carrying_broth_id == "":
		if not cart.pick_broth(table.order_broth_id):
			_negotiate(table)
			return
	elif cart.carrying_broth_id != table.order_broth_id:
		_notification_label.text = "Xe đẩy đang chở %s, bàn này gọi %s!" % [_broth_name(cart.carrying_broth_id), _broth_name(table.order_broth_id)]
		return
	_deliver(table)


func _deliver(table: TableNode) -> void:
	var fast := table.customer != null and table.customer.remaining_time() > CUSTOMER_WAIT * 0.5
	if cart.serve_to(table):
		table.served_fast = fast
		GameState.add_star(STAR_FAST_SERVE if fast else STAR_SERVE)
		log_line_safe("Đã giao %s đến bàn%s." % [_broth_name(table.order_broth_id), " (nhanh, +sao)" if fast else ""])
		_notification_label.text = "Đã giao %s ra bàn thành công%s!" % [_broth_name(table.order_broth_id), " (Giao nhanh +Sao)" if fast else ""]


func _negotiate(table: TableNode) -> void:
	var missing := _broth_name(table.order_broth_id)
	var offer := _best_in_stock()
	if offer == null:
		_notification_label.text = "Hết %s và kho cũng không còn loại lẩu nào khác!" % missing
		return
	if table.customer != null and table.customer.has_meta("negotiated"):
		_notification_label.text = "Khách bàn này đã từ chối đổi món rồi."
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
	if accepted and cart.pick_broth(offer.id):
		table.order_broth_id = offer.id
		if table.customer != null:
			table.customer.desired_broth_id = offer.id
		log_line_safe("[color=#4caf50]Khách đồng ý đổi sang %s.[/color]" % offer.display_name)
		_notification_label.text = "Khách đồng ý đổi sang %s!" % offer.display_name
		_deliver(table)
	else:
		_notification_label.text = "Khách không đồng ý đổi món!"
		_customer_timeout(table)


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


func _finish_eating(table: TableNode) -> void:
	if table.state != TableNode.State.EATING:
		return
	var broth := Database.get_broth(table.order_broth_id)
	if broth and table.served_expired and (table.special != "" or randf() < EXPIRED_DETECT_CHANCE):
		var compensation := roundi(broth.price * EXPIRED_COMPENSATION / 1000.0) * 1000
		GameState.add_money(-compensation, false)
		GameState.lose_star(EXPIRED_STAR_LOSS)
		log_line_safe("[color=red]Khách phát hiện %s đã hết hạn! Bồi thường %s, trừ sao.[/color]" % [broth.display_name, GameState.format_money(compensation)])
		_notification_label.text = "Khách phát hiện lẩu hết hạn! Phạt bồi thường %s và trừ sao!" % GameState.format_money(compensation)
		if table.special != "":
			_events.special_result(table, false, broth.price)
		table.clear()
		return
	if broth:
		var tip_rate := randf_range(TIP_MIN, TIP_MAX) + Database.upgrade_value("furniture")
		var tip := roundi(broth.price * tip_rate / 1000.0) * 1000
		GameState.add_money(broth.price + tip)
		log_line_safe("Khách thanh toán %s: %s + tip %s" % [broth.display_name, GameState.format_money(broth.price), GameState.format_money(tip)])
		_notification_label.text = "Bàn thanh toán %s: +%s (Tip: +%s)!" % [broth.display_name, GameState.format_money(broth.price), GameState.format_money(tip)]
		if table.special != "":
			_events.special_result(table, table.served_fast and not table.served_expired, broth.price)
	table.clear()


func _customer_timeout(table: TableNode) -> void:
	if table.state != TableNode.State.WAITING_ORDER:
		return
	GameState.lose_star(STAR_CUSTOMER_LEFT)
	log_line_safe("[color=red]Khách bỏ về, quán bị trừ sao.[/color]")
	_notification_label.text = "Khách chờ quá lâu nên bỏ về! Quán bị trừ 1 sao."
	if table.special != "":
		_events.special_result(table, false, 0)
	table.clear()


func _on_table_cleared(_table: TableNode) -> void:
	pass


func _on_eating_finished(table: TableNode) -> void:
	_finish_eating(table)


func _update_ui() -> void:
	_revenue_label.text = "Doanh thu: %s" % GameState.format_money(GameState.today_revenue)
	_stars_label.text = "Đánh giá: %.1f ★" % GameState.stars
	if cart.carrying_broth_id == "":
		_cart_label.text = "Xe đẩy: [Trống]"
	else:
		_cart_label.text = "Xe đẩy: [%s]" % _broth_name(cart.carrying_broth_id)

	for i in _inventory_ids.size():
		var id := _inventory_ids[i]
		var btn := _inventory_buttons[i]
		var broth := Database.get_broth(id)
		btn.text = "%s: x%d" % [broth.display_name if broth else id, GameState.get_broth_count(id)]

	var customer_colors := [Color("5fa8d3"), Color("f28482"), Color("84a59d"), Color("f6bd60")]

	for i in _table_ui.size():
		var ui = _table_ui[i]
		var table: TableNode = ui["table"]
		var status_lbl: Label = ui["status"]
		var order_lbl: Label = ui["order"]
		var sides_row: HBoxContainer = ui["sides_row"]
		var wait_bar: ProgressBar = ui["wait_bar"]
		var wait_time_lbl: Label = ui["wait_time"]
		var eat_bar: ProgressBar = ui["eat_bar"]
		var eat_time_lbl: Label = ui["eat_time"]
		var serve_btn: Button = ui["serve"]
		var char_rect: TextureRect = ui["char"]
		var pot_rect: TextureRect = ui["pot"]
		var smoke_rect: TextureRect = ui["smoke"]
		var vip: Label = ui["vip"]
		var bubble: Control = ui["bubble"]

		if table.state == TableNode.State.EMPTY:
			status_lbl.text = "Bàn %d: Trống - Chờ khách" % (i + 1)
			bubble.visible = false
			serve_btn.visible = false
			char_rect.visible = false
			pot_rect.visible = false
			smoke_rect.visible = false
		elif table.state == TableNode.State.WAITING_ORDER:
			bubble.visible = true
			serve_btn.visible = true
			var broth := Database.get_broth(table.order_broth_id)
			status_lbl.text = "Bàn %d: Khách gọi món" % (i + 1)
			order_lbl.text = "Thèm: %s" % (broth.display_name if broth else table.order_broth_id)

			# Cập nhật icon đồ nhúng
			for child in sides_row.get_children():
				child.queue_free()
			for sid in table.side_items:
				var icon_path := "%s%s.png" % [INGREDIENT_DIR, sid]
				if ResourceLoader.exists(icon_path):
					var side_icon := TextureRect.new()
					side_icon.texture = load(icon_path)
					side_icon.custom_minimum_size = Vector2(24, 24)
					side_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					side_icon.tooltip_text = GameState.item_display_name(sid)
					sides_row.add_child(side_icon)

			var rem := table.customer.remaining_time() if table.customer else 0.0
			wait_bar.visible = true
			wait_bar.value = 100.0 * (1.0 - rem / CUSTOMER_WAIT)
			wait_time_lbl.visible = true
			wait_time_lbl.text = "Chờ: %.0fs" % rem
			eat_bar.visible = false
			eat_time_lbl.visible = false

			# Nút phục vụ hoặc thương lượng
			var has_stock := GameState.get_broth_count(table.order_broth_id) > 0 or cart.carrying_broth_id == table.order_broth_id
			if not has_stock and table.customer and not table.customer.has_meta("negotiated"):
				serve_btn.text = "Thương lượng đổi món 🎲"
			else:
				serve_btn.text = "Bưng ra Bàn %d" % (i + 1)

			char_rect.visible = true
			if table.special == "critic":
				char_rect.modulate = Color("c77dff")
				vip.text = "[★ Nhà phê bình ẩm thực]"
			elif table.special == "michelin":
				char_rect.modulate = Color("ffd166")
				vip.text = "[★ Giám khảo Michelin]"
			else:
				char_rect.modulate = customer_colors[i % customer_colors.size()]
				vip.text = ""

			pot_rect.visible = false
			smoke_rect.visible = false
		elif table.state == TableNode.State.EATING:
			bubble.visible = true
			serve_btn.visible = false
			var broth := Database.get_broth(table.order_broth_id)
			status_lbl.text = "Bàn %d: Đang ăn lẩu" % (i + 1)
			order_lbl.text = "Đang ăn: %s" % (broth.display_name if broth else table.order_broth_id)
			for child in sides_row.get_children():
				child.queue_free()

			wait_bar.visible = false
			wait_time_lbl.visible = false
			eat_bar.visible = true
			var erem := table.eating_remaining()
			eat_bar.value = 100.0 * (1.0 - erem / table.eating_time)
			eat_time_lbl.visible = true
			eat_time_lbl.text = "Nồi lẩu sôi: %.0fs" % erem

			char_rect.visible = true
			pot_rect.visible = true
			smoke_rect.visible = true
			vip.text = ""


func log_line_safe(text: String) -> void:
	print(text)
