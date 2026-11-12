class_name ReceptionDesk
extends Control
## Quầy lễ tân cạnh cửa ra vào (cửa đã vẽ trong nền nhà hàng). Nhóm khách (1-6 người) bước vào cửa,
## xếp hàng chờ trước quầy (lễ tân Lan chào nếu đã thuê nhân viên), người chơi chọn bàn thì cả nhóm đi tới
## và ngồi vào từng ghế. Ăn xong / bỏ về thì từng người đi ra cửa.
## Toạ độ theo sân khấu 1280x720 của màn bán. Màu quầy theo cấp Nội thất (RestaurantDecor).

const CHAR_DIR := "res://assets/sprites/characters/"
const STAGE := Vector2(1280, 720)
const DOOR_FEET := Vector2(74, 318) ## Chân khách khi vừa bước qua cửa.
const DESK := Rect2(140, 292, 196, 56) ## Mặt trước quầy (mặt quầy ở cạnh trên).
const HOST_X := 238.0
const HOST_FEET := 330.0
## Chỗ đứng chờ (giữa chân nhóm): chỗ 0 trước quầy, chỗ 1 cạnh cửa.
const QUEUE_FEET := [Vector2(262, 404), Vector2(92, 404)]
const MEMBER_DX := 34.0 ## Khoảng cách giữa người trong nhóm đứng chờ.
const MEMBER_DY := 16.0 ## Hàng sau đứng cao hơn hàng trước.
const GUEST_SIZE := 96.0
const WALK_SPEED := 280.0 ## px/giây

var host: KitchenActor
var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_until := 0.0


func _init() -> void:
	size = STAGE
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	# Lan chỉ đứng quầy khi đã thuê nhân viên (cùng người làm phụ bếp ở màn bếp); chưa có thì quầy trống.
	if RestaurantDecor.has_host():
		host = KitchenActor.new()
		add_child(host)
		host.setup(load(CHAR_DIR + "staff_lan.png"), HOST_X, HOST_FEET, "Lan", false)

	var front := _DeskFront.new()
	front.desk = DESK
	add_child(front)

	_bubble = PanelContainer.new()
	_bubble.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fcf8e8")
	style.border_color = Color("a67c52")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_bubble.add_theme_stylebox_override("panel", style)
	_bubble_label = HuntUI.label("", 18, HuntUI.INK)
	_bubble.add_child(_bubble_label)
	_bubble.visible = false
	add_child(_bubble)


func _process(_delta: float) -> void:
	if _bubble.visible and Time.get_ticks_msec() / 1000.0 > _bubble_until:
		_bubble.visible = false


## Lễ tân nói một câu (không có lễ tân thì thôi).
func greet(text: String) -> void:
	if host == null:
		return
	_bubble_label.text = text
	_bubble.visible = true
	_bubble.reset_size()
	_bubble.position = Vector2(HOST_X - _bubble.size.x / 2.0, HOST_FEET - KitchenActor.SIZE - _bubble.size.y + 18.0)
	_bubble_until = Time.get_ticks_msec() / 1000.0 + 1.4
	host.work(0.4, "stir")


## Vị trí (global, góc trên-trái hình) của người thứ k trong nhóm `count` người đứng ở chỗ chờ `slot`.
func queue_spot(slot: int, k: int, count: int) -> Vector2:
	var feet: Vector2 = QUEUE_FEET[clampi(slot, 0, QUEUE_FEET.size() - 1)]
	var per_row := mini(count, 3)
	var row := k / 3
	var col := k % 3
	var in_row := mini(per_row, count - row * 3)
	var x := feet.x + (col - (in_row - 1) / 2.0) * MEMBER_DX + row * MEMBER_DX * 0.5
	var y := feet.y - row * MEMBER_DY
	return global_position + Vector2(x, y) - Vector2(GUEST_SIZE / 2.0, GUEST_SIZE)


## Đỉnh đầu (global) của nhóm đang đứng ở chỗ chờ `slot` (để đặt bong bóng "Nhóm N người").
func queue_head(slot: int, count: int) -> Vector2:
	var feet: Vector2 = QUEUE_FEET[clampi(slot, 0, QUEUE_FEET.size() - 1)]
	var rows := 1 if count <= 3 else 2
	return global_position + Vector2(feet.x, feet.y - GUEST_SIZE - (rows - 1) * MEMBER_DY + 8.0)


## Nhóm bước vào cửa rồi tới chỗ chờ `slot`. Trả về danh sách người đi bộ {rect, legs}.
func enter_group(looks: Array, slot: int, overlay: Control) -> Array[Dictionary]:
	var walkers: Array[Dictionary] = []
	# Người hàng sau thêm vào trước để vẽ phía sau.
	var order: Array[int] = []
	for k in range(looks.size() - 1, -1, -1):
		order.append(k)
	var made := {}
	for k in order:
		var w := _make_walker(looks[k], overlay)
		w["rect"].global_position = global_position + DOOR_FEET - Vector2(GUEST_SIZE / 2.0, GUEST_SIZE)
		w["rect"].create_tween().tween_property(w["rect"], "modulate:a", 1.0, 0.25)
		made[k] = w
	for k in looks.size():
		walkers.append(made[k])
	move_group(walkers, slot, 0.18)
	return walkers


## Cả nhóm đi tới chỗ chờ `slot` (người sau đi trễ hơn một chút cho tự nhiên).
func move_group(walkers: Array[Dictionary], slot: int, stagger := 0.1) -> void:
	for k in walkers.size():
		var target := queue_spot(slot, k, walkers.size())
		_walk_to(walkers[k], target, k * stagger)


## Cả nhóm đi từ chỗ chờ tới các ghế (`seats` là góc trên-trái global của từng ghế), thu về cỡ ghế
## rồi biến mất (hình khách ngồi ở bàn hiện thay). Dùng với await.
func seat_group(walkers: Array[Dictionary], seats: Array[Vector2], seat_scale: float) -> void:
	var longest := 0.0
	for k in walkers.size():
		var w: Dictionary = walkers[k]
		if not is_instance_valid(w["rect"]):
			continue
		# Hình ngồi nhỏ hơn hình đi: căn để chân/đầu khớp chỗ ngồi sau khi thu nhỏ quanh đáy hình.
		var target: Vector2 = seats[mini(k, seats.size() - 1)] - Vector2(GUEST_SIZE / 2.0, GUEST_SIZE) * (1.0 - seat_scale)
		longest = maxf(longest, _walk_to(w, target, k * 0.08))
	await get_tree().create_timer(longest + 0.05).timeout
	for w in walkers:
		var rect: TextureRect = w["rect"]
		if is_instance_valid(rect):
			var t := rect.create_tween()
			t.tween_property(rect, "scale", Vector2.ONE * seat_scale, 0.08)
			t.tween_callback(rect.queue_free)
	await get_tree().create_timer(0.09).timeout


## Cả nhóm bỏ về từ chỗ chờ (đỏ mặt).
func leave_queue(walkers: Array[Dictionary]) -> void:
	for k in walkers.size():
		var w: Dictionary = walkers[k]
		var rect: TextureRect = w["rect"]
		if not is_instance_valid(rect):
			continue
		rect.modulate = Color("ffb0a0")
		var d := _walk_to(w, global_position + DOOR_FEET - Vector2(GUEST_SIZE / 2.0, GUEST_SIZE), k * 0.08)
		var t := rect.create_tween()
		t.tween_interval(d)
		t.tween_property(rect, "modulate:a", 0.0, 0.25)
		t.tween_callback(rect.queue_free)


## Một khách rời bàn đi ra cửa rồi biến mất. `happy` = ăn xong vui vẻ, không thì đỏ mặt bỏ về.
func walk_out(guest_texture: Texture2D, seat_global: Vector2, seat_scale: float, happy: bool, overlay: Control, delay := 0.0) -> void:
	var w := _make_walker(guest_texture, overlay)
	var rect: TextureRect = w["rect"]
	rect.modulate = Color.WHITE if happy else Color("ffb0a0")
	rect.scale = Vector2.ONE * seat_scale
	rect.global_position = seat_global - Vector2(GUEST_SIZE / 2.0, GUEST_SIZE) * (1.0 - seat_scale)
	rect.create_tween().tween_property(rect, "scale", Vector2.ONE, 0.15)
	var d := _walk_to(w, global_position + DOOR_FEET - Vector2(GUEST_SIZE / 2.0, GUEST_SIZE), delay)
	var t := rect.create_tween()
	t.tween_interval(d)
	t.tween_property(rect, "modulate:a", 0.0, 0.25)
	t.tween_callback(rect.queue_free)


func _make_walker(tex: Texture2D, overlay: Control) -> Dictionary:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = Vector2(GUEST_SIZE, GUEST_SIZE)
	rect.pivot_offset = Vector2(GUEST_SIZE / 2.0, GUEST_SIZE)
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	rect.modulate = Color(1, 1, 1, 0)
	overlay.add_child(rect)
	return {"rect": rect, "legs": SpriteFrameLayer.attach_to(rect)}


## Đi thẳng tới `target` (góc trên-trái, global) sau `delay` giây, chân chạy theo sheet nếu có.
## Trả về tổng số giây (kể cả delay).
func _walk_to(w: Dictionary, target: Vector2, delay := 0.0) -> float:
	var rect: TextureRect = w["rect"]
	if not is_instance_valid(rect):
		return 0.0
	var legs: SpriteFrameLayer = w["legs"]
	var from := rect.global_position
	var duration := maxf(0.2, from.distance_to(target) / WALK_SPEED)
	var parent_origin := (rect.get_parent() as Control).global_position
	if w.has("tween") and (w["tween"] as Tween).is_valid():
		(w["tween"] as Tween).kill()
	var t := rect.create_tween()
	w["tween"] = t
	t.tween_interval(delay)
	t.tween_callback(func() -> void:
		rect.flip_h = target.x < rect.global_position.x - 2.0
		if legs != null:
			legs.play("run"))
	t.tween_property(rect, "position", target - parent_origin, duration)
	t.tween_callback(func() -> void:
		rect.flip_h = false
		if legs != null:
			legs.stop())
	return delay + duration


## Mặt trước quầy lễ tân, vẽ đè lên người lễ tân (che nửa dưới).
class _DeskFront extends Control:
	var desk: Rect2

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		size = Vector2(1280, 720)

	func _draw() -> void:
		var fur := RestaurantDecor.furniture()
		var top: Color = fur["top"]
		var edge: Color = fur["edge"]
		var cloth: Color = fur["cloth"]
		var trim: Color = fur["trim"]
		# Bóng dưới chân quầy.
		draw_rect(Rect2(desk.position.x + 8, desk.end.y, desk.size.x - 8, 8), Color(0, 0, 0, 0.25))
		# Mặt quầy (nhìn chéo từ trên) + thân quầy.
		draw_rect(Rect2(desk.position.x - 8, desk.position.y - 12, desk.size.x + 16, 16), edge)
		draw_rect(Rect2(desk.position.x - 4, desk.position.y - 12, desk.size.x + 8, 12), top.lightened(0.15))
		draw_rect(desk, edge)
		draw_rect(Rect2(desk.position + Vector2(4, 4), desk.size - Vector2(8, 8)), top)
		for i in 3:
			var x := desk.position.x + 16 + i * (desk.size.x - 32) / 2.0
			draw_rect(Rect2(x - 2, desk.position.y + 8, 4, desk.size.y - 16), edge)
		if cloth.a > 0.0:
			draw_rect(Rect2(desk.position.x, desk.position.y, desk.size.x, 12), cloth)
			if trim.a > 0.0:
				draw_rect(Rect2(desk.position.x, desk.position.y + 12, desk.size.x, 4), trim)
		# Chuông + sổ đặt bàn trên mặt quầy.
		draw_rect(Rect2(desk.position.x + 14, desk.position.y - 20, 16, 8), Color("f2c14e"))
		draw_rect(Rect2(desk.position.x + 20, desk.position.y - 24, 4, 4), Color("f2c14e"))
		draw_rect(Rect2(desk.end.x - 52, desk.position.y - 16, 36, 6), Color("f7f1e3"))
		draw_rect(Rect2(desk.end.x - 52, desk.position.y - 10, 36, 2), Color("a67c52"))
