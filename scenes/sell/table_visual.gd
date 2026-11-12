class_name TableVisual
extends Control
## Bàn tròn nhìn chéo từ trên (2.5D) có `seats` ghế xếp vòng quanh. Khách ngồi phía sau và hai bên quay mặt
## ra (nửa dưới khuất sau mặt bàn / mặt ghế), khách ngồi phía trước quay lưng lại (hình *_back.png, lưng ghế
## che nửa dưới). Ghế trống vẫn thấy rõ nên biết bàn còn chỗ. Nồi lẩu của món đã gọi đặt giữa bàn, khói bốc
## lên khi đang ăn. Bong bóng gọi món (nồi + số phần + đồ nhúng + thanh kiên nhẫn) nổi phía trên bàn, nằm ở
## lớp riêng để không bị tối theo giờ. Bàn ghế đổi theo cấp Nội thất (RestaurantDecor). Chạm bàn -> `tapped`.

signal tapped

const HEIGHT := 192.0
const CENTER_Y := 110.0 ## Tâm mặt bàn (toạ độ bàn).
const SIDE_ROOM := 56.0 ## Chỗ cho khách ngồi hai bên mép bàn.
const RADIUS := {2: 56.0, 4: 74.0, 6: 94.0} ## Bán trục ngang mặt bàn theo số ghế.
const SQUASH := 0.42 ## Mặt bàn nhìn chéo: trục dọc = trục ngang x SQUASH.
## Góc từng ghế (độ; 0 = bên phải, 90 = phía trước, 270 = phía sau).
const SEAT_ANGLES := {
	2: [180.0, 0.0],
	4: [215.0, 325.0, 145.0, 35.0],
	6: [180.0, 240.0, 300.0, 0.0, 120.0, 60.0],
}
const GUEST_SIZE := 96.0 ## Cỡ hình khách ở tỉ lệ 1 (32 x 3).
const POT_SIZE := Vector2(64, 56)
const SMOKE_TEXTURE := "res://assets/sprites/fx/smoke.png"
const SMOKE_FRAME := 48
const SMOKE_FPS := 10.0
const BAR_SIZE := Vector2(104, 12)
const SPRITE_PX := 32.0
const POT_PX := Vector2(32, 28)

var seats := 4
var number := 1
var guests: Array[TextureRect] = [] ## Một hình cho mỗi ghế.
var pot: TextureRect
var smoke: TextureRect
var bubble: PanelContainer
var _fur: Dictionary
var _rx := 74.0
var _ry := 31.0
var _angles: Array[float] = []
var _seat_order: Array[int] = [] ## Thứ tự ngồi: ghế phía sau trước (thấy mặt khách), phía trước sau cùng.
var _looks: Array = [] ## Hình mặt trước của khách ở từng ghế (để đi ra cửa).
var _base_y: Array[float] = [] ## Vị trí y gốc của hình khách từng ghế (trước khi nhún).
var _smoke_atlas: AtlasTexture
var _smoke_time := 0.0
var _top: Control
var _front_chairs: Control
var _number: Label
var _pot_wait := 0.0
var _eating := false
var _guest_px := 3.0
var _highlight := 0 ## 0 thường, 1 = vừa nhóm đang chờ (nhấp nháy), -1 = không vừa (mờ).
# Bong bóng
var _note: Label
var _bubble_pot: TextureRect
var _portions: Label
var _sides: HBoxContainer
var _bar_fill: ColorRect
var _pulse := 0.0
var _bubble_style: StyleBoxFlat
var _shown_order := ""
var _shown_sides: Array[String] = []


func _init(table_number := 1, seat_count := 4) -> void:
	number = table_number
	seats = seat_count if SEAT_ANGLES.has(seat_count) else 4
	_rx = RADIUS[seats]
	_ry = _rx * SQUASH
	for a in SEAT_ANGLES[seats]:
		_angles.append(deg_to_rad(a))
	_seat_order.assign(range(seats))
	_seat_order.sort_custom(func(a: int, b: int) -> bool: return sin(_angles[a]) < sin(_angles[b]))
	size = Vector2(width_for(seats), HEIGHT)
	custom_minimum_size = size
	mouse_filter = MOUSE_FILTER_STOP
	_fur = RestaurantDecor.furniture()
	_looks.resize(seats)

	var back := _BackLayer.new()
	back.owner_table = self
	add_child(back)
	for i in seats:
		guests.append(_make_guest())
		_base_y.append(0.0)
	# Khách phía sau + hai bên nằm dưới mặt bàn.
	for i in seats:
		if not is_front(i):
			add_child(guests[i])
	_top = _TableTop.new()
	_top.owner_table = self
	add_child(_top)

	pot = TextureRect.new()
	pot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pot.stretch_mode = TextureRect.STRETCH_SCALE
	pot.mouse_filter = MOUSE_FILTER_IGNORE
	pot.visible = false
	add_child(pot)
	_smoke_atlas = AtlasTexture.new()
	_smoke_atlas.atlas = load(SMOKE_TEXTURE)
	_smoke_atlas.region = Rect2(0, 0, SMOKE_FRAME, SMOKE_FRAME)
	smoke = TextureRect.new()
	smoke.texture = _smoke_atlas
	smoke.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	smoke.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	smoke.size = Vector2(48, 48)
	smoke.mouse_filter = MOUSE_FILTER_IGNORE
	smoke.visible = false
	add_child(smoke)

	# Khách phía trước (quay lưng) nằm trên mặt bàn, lưng ghế phía trước che nửa dưới họ.
	for i in seats:
		if is_front(i):
			add_child(guests[i])
	_front_chairs = _FrontChairs.new()
	_front_chairs.owner_table = self
	add_child(_front_chairs)

	_number = HuntUI.outlined_label("Bàn %d" % number, 18, HuntUI.GOLD)
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_number)

	_build_bubble()
	set_display_scale(1.0)


static func width_for(seat_count: int) -> float:
	var rx: float = RADIUS.get(seat_count, 74.0)
	return rx * 2.0 + SIDE_ROOM * 2.0


func center() -> Vector2:
	return Vector2(size.x / 2.0, CENTER_Y)


## Ghế phía trước bàn (khách quay lưng lại).
func is_front(i: int) -> bool:
	return sin(_angles[i]) > 0.2


## Ghế ở hai bên mép bàn.
func is_side(i: int) -> bool:
	return absf(sin(_angles[i])) <= 0.2


## Điểm đặt ghế i trên sàn quanh bàn (toạ độ bàn).
func seat_point(i: int) -> Vector2:
	return center() + Vector2(cos(_angles[i]) * (_rx + 22.0), sin(_angles[i]) * (_ry + 14.0))


## Đáy hình khách ngồi ở ghế i: phía sau thì lún sâu sau mặt bàn, phía trước thì lưng ghế che bớt.
func _guest_bottom(i: int) -> float:
	if is_front(i):
		return seat_point(i).y + 24.0
	if is_side(i):
		return seat_point(i).y + 26.0
	return seat_point(i).y + 34.0


func _make_guest() -> TextureRect:
	var g := TextureRect.new()
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_SCALE
	g.mouse_filter = MOUSE_FILTER_IGNORE
	g.visible = false
	return g


func _build_bubble() -> void:
	bubble = PanelContainer.new()
	bubble.mouse_filter = MOUSE_FILTER_IGNORE
	_bubble_style = StyleBoxFlat.new()
	_bubble_style.bg_color = Color("fcf8e8")
	_bubble_style.border_color = Color("a67c52")
	_bubble_style.set_border_width_all(3)
	_bubble_style.set_corner_radius_all(10)
	_bubble_style.content_margin_left = 8
	_bubble_style.content_margin_right = 8
	_bubble_style.content_margin_top = 4
	_bubble_style.content_margin_bottom = 6
	_bubble_style.shadow_color = Color(0, 0, 0, 0.3)
	_bubble_style.shadow_offset = Vector2(0, 3)
	_bubble_style.shadow_size = 2
	bubble.add_theme_stylebox_override("panel", _bubble_style)
	bubble.visible = false

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	bubble.add_child(box)
	_note = HuntUI.label("", 18, HuntUI.RUST)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(row)
	_bubble_pot = TextureRect.new()
	_bubble_pot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bubble_pot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bubble_pot.stretch_mode = TextureRect.STRETCH_SCALE
	_bubble_pot.custom_minimum_size = POT_PX * 2.0
	_bubble_pot.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(_bubble_pot)
	_portions = HuntUI.label("", 20, HuntUI.INK)
	_portions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_portions)
	_sides = HBoxContainer.new()
	_sides.add_theme_constant_override("separation", 0)
	_sides.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(_sides)
	var bar := Control.new()
	bar.custom_minimum_size = BAR_SIZE
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(bar)
	var back := ColorRect.new()
	back.color = Color("3b2416")
	back.size = BAR_SIZE
	back.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(back)
	_bar_fill = ColorRect.new()
	_bar_fill.position = Vector2(2, 2)
	_bar_fill.size = BAR_SIZE - Vector2(4, 4)
	_bar_fill.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(_bar_fill)


## Đưa bong bóng + chữ số bàn sang lớp riêng (trên lớp ánh sáng, không bị hàng bàn phía sau che).
func attach_bubble(layer: Control) -> void:
	layer.add_child(bubble)
	_number.get_parent().remove_child(_number)
	layer.add_child(_number)
	_number.remove_theme_font_size_override("font_size")
	_number.reset_size()


## Thu phóng cả bàn; chữ số bàn không nhỏ hơn 18px trên màn hình (đọc được trên điện thoại).
## Khách và nồi luôn phóng theo bội số nguyên của điểm ảnh gốc để hình pixel không bị nhòe.
func set_display_scale(sc: float) -> void:
	scale = Vector2(sc, sc)
	var gk := maxi(2, roundi(3.0 * sc))
	var gs := SPRITE_PX * gk / sc
	_guest_px = gs / SPRITE_PX
	for i in seats:
		var g := guests[i]
		g.size = Vector2(gs, gs)
		var p := seat_point(i)
		_base_y[i] = _guest_bottom(i) - gs
		g.position = Vector2(p.x - gs / 2.0, _base_y[i])
		# Khách hai bên quay mặt vào bàn.
		g.flip_h = is_side(i) and cos(_angles[i]) > 0.0
	var pk := maxi(1, roundi(2.0 * sc - 0.1))
	pot.size = POT_PX * pk / sc
	pot.position = Vector2(center().x - pot.size.x / 2.0, CENTER_Y + 8.0 - pot.size.y)
	smoke.position = Vector2(center().x - 24.0, pot.position.y - 40.0)


## Cho nhóm khách ngồi: ghế phía sau trước (thấy mặt), phía trước sau cùng (quay lưng).
func seat_group(looks: Array) -> void:
	for g in guests:
		g.visible = false
	_looks.fill(null)
	for k in mini(looks.size(), seats):
		var i := _seat_order[k]
		var tex: Texture2D = looks[k]
		_looks[i] = tex
		guests[i].texture = _back_texture(tex) if is_front(i) else tex
		guests[i].visible = true


static func _back_texture(front: Texture2D) -> Texture2D:
	var path := front.resource_path.trim_suffix(".png") + "_back.png"
	return load(path) if ResourceLoader.exists(path) else front


## Góc trên-trái (global) của các ghế mà nhóm `count` người sẽ ngồi (theo thứ tự ngồi).
func seat_globals(count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for k in mini(count, seats):
		var i := _seat_order[k]
		result.append(get_global_transform() * Vector2(guests[i].position.x, _base_y[i]))
	return result


## Khách đang ngồi: hình mặt trước + góc trên-trái global (để cho đi ra cửa).
func seated_guests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for k in seats:
		var i := _seat_order[k]
		if guests[i].visible and _looks[i] != null:
			result.append({"texture": _looks[i], "global": get_global_transform() * Vector2(guests[i].position.x, _base_y[i])})
	return result


## Cỡ hình khách ngồi trên màn hình (px).
func guest_screen_size() -> float:
	return guests[0].size.x * scale.x


## Tâm nồi trên bàn (toạ độ global).
func pot_global_center() -> Vector2:
	return get_global_transform() * Vector2(center().x, CENTER_Y - 20.0)


## Đánh dấu bàn trống: 1 = vừa nhóm đang chờ (nhấp nháy), -1 = không đủ ghế (mờ), 0 = thường.
func set_highlight(mode: int) -> void:
	_highlight = mode


## Nhóm khách đang chờ món: 1 nồi lẩu + các đĩa đồ nhúng, thanh kiên nhẫn, ghi chú (khách đặc biệt / hết món).
func show_waiting(broth_id: String, sides: Array[String], patience: float, note: String, note_color: Color, ready_to_serve: bool) -> void:
	_eating = false
	pot.visible = false
	smoke.visible = false
	bubble.visible = true
	_set_order(broth_id, sides)
	_portions.visible = false
	_bubble_pot.modulate = Color.WHITE
	_set_note(note, note_color)
	_set_bar(patience, _patience_color(patience))
	var glow := 0.5 + 0.5 * sin(_pulse * 6.0) if ready_to_serve else 0.0
	_bubble_style.border_color = Color("a67c52").lerp(Color("f2a33a"), glow)


## Nhóm đang ăn: nồi trên bàn sôi, bong bóng chỉ còn thanh tiến độ ăn.
func show_eating(broth_id: String, progress: float) -> void:
	_eating = true
	if not pot.visible and _pot_wait <= 0.0:
		pot.texture = KitchenPass.pot_texture(broth_id)
		pot.visible = true
		smoke.visible = true
	bubble.visible = true
	_set_order(broth_id, [])
	_portions.visible = false
	_bubble_pot.modulate = Color(1, 1, 1, 0.55)
	_set_note("", HuntUI.INK)
	_set_bar(progress, Color("4cc552"))
	_bubble_style.border_color = Color("a67c52")


## Giữ nồi chưa hiện trên bàn trong `seconds` giây (lúc nồi đang được bưng tới).
func delay_pot(seconds: float) -> void:
	_pot_wait = seconds
	pot.visible = false
	smoke.visible = false


func show_empty() -> void:
	_eating = false
	for g in guests:
		g.visible = false
	pot.visible = false
	smoke.visible = false
	bubble.visible = false
	_shown_order = ""


func _set_order(broth_id: String, sides: Array[String]) -> void:
	if broth_id == _shown_order and sides == _shown_sides:
		return
	_shown_order = broth_id
	_shown_sides = sides.duplicate()
	_bubble_pot.texture = KitchenPass.pot_texture(broth_id)
	for child in _sides.get_children():
		child.queue_free()
	# Đồ nhúng trùng gộp lại: hình món + "x2".
	var counts := {}
	for id in sides:
		counts[id] = int(counts.get(id, 0)) + 1
	for id in counts:
		var icon := HuntUI.texture_rect(HuntUI.ingredient_texture(id), 32)
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		_sides.add_child(icon)
		if int(counts[id]) > 1:
			var n := HuntUI.label("x%d" % int(counts[id]), 18, HuntUI.INK)
			n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_sides.add_child(n)


func _set_note(text: String, color: Color) -> void:
	_note.text = text
	_note.visible = text != ""
	_note.add_theme_color_override("font_color", color)


func _set_bar(ratio: float, color: Color) -> void:
	_bar_fill.size.x = (BAR_SIZE.x - 4.0) * clampf(ratio, 0.0, 1.0)
	_bar_fill.color = color


static func _patience_color(r: float) -> Color:
	if r > 0.5:
		return Color("4cc552")
	if r > 0.25:
		return Color("f2a33a")
	return Color("e53935")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit()
		accept_event()


func _process(delta: float) -> void:
	_pulse += delta
	_pot_wait = maxf(0.0, _pot_wait - delta)
	# Khách thở nhẹ khi chờ, ăn thì cúi gắp liên tục; mỗi người lệch nhịp. Nhích đúng 1 điểm ảnh để hình không nhòe.
	for i in seats:
		var g := guests[i]
		if not g.visible:
			continue
		var down := sin(_pulse * 9.0 + i * 1.9) > 0.2 if _eating and pot.visible else sin(_pulse * 2.6 + i * 1.3) > 0.5
		g.position.y = _base_y[i] + (_guest_px if down else 0.0)
	# Bàn trống vừa nhóm đang chờ: sáng nhấp nháy; không đủ ghế: mờ đi.
	match _highlight:
		1:
			var k := 0.5 + 0.5 * sin(_pulse * 6.0)
			_number.modulate = Color(1, 1, 1).lerp(Color(1.6, 1.6, 1.3), k)
			_top.modulate = Color(1, 1, 1).lerp(Color(1.2, 1.15, 1.0), k)
		-1:
			_number.modulate = Color(1, 1, 1, 0.45)
			_top.modulate = Color(0.8, 0.8, 0.8)
		_:
			_number.modulate = Color.WHITE
			_top.modulate = Color.WHITE
	var parent_origin := (bubble.get_parent() as Control).get_global_transform().origin if bubble.get_parent() is Control else Vector2.ZERO
	if bubble.visible:
		bubble.reset_size()
		var head := get_global_transform() * Vector2(center().x, CENTER_Y - _ry - 62.0)
		bubble.position = (head - parent_origin - Vector2(bubble.size.x * 0.5, bubble.size.y)).round()
	# Chữ số bàn ngay dưới mép trước mặt bàn (giữa hai ghế phía trước), cỡ 18px trên màn hình.
	var label_at := get_global_transform() * Vector2(center().x, CENTER_Y + _ry + 6.0)
	_number.position = (label_at - parent_origin - Vector2(_number.size.x * 0.5, 0)).round()
	if smoke.visible:
		_smoke_time += delta
		var frame_count := maxi(1, int(_smoke_atlas.atlas.get_width()) / SMOKE_FRAME)
		var frame := int(_smoke_time * SMOKE_FPS) % frame_count
		_smoke_atlas.region = Rect2(frame * SMOKE_FRAME, 0, SMOKE_FRAME, SMOKE_FRAME)


func _exit_tree() -> void:
	if is_instance_valid(bubble) and bubble.get_parent() != self:
		bubble.queue_free()
	if is_instance_valid(_number) and _number.get_parent() != self:
		_number.queue_free()


# --- Vẽ bàn ghế -----------------------------------------------------------------------

static func _ellipse(c: Vector2, rx: float, ry: float, steps := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for s in steps:
		var a := TAU * s / steps
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Ghế nhìn chéo: mặt ghế (elip nhỏ) + lưng ghế phía xa bàn.
static func draw_chair(ci: CanvasItem, p: Vector2, angle: float, fur: Dictionary, with_back: bool, with_seat: bool) -> void:
	var chair: Color = fur["chair"]
	var cushion: Color = fur["cushion"]
	if with_seat:
		ci.draw_colored_polygon(_ellipse(p + Vector2(0, 4), 18, 8), chair.darkened(0.3))
		ci.draw_colored_polygon(_ellipse(p, 18, 8), chair.lightened(0.1))
		if cushion.a > 0.0:
			ci.draw_colored_polygon(_ellipse(p, 13, 5.5), cushion)
		ci.draw_rect(Rect2(p.x - 2, p.y + 6, 4, 14), chair.darkened(0.35))
	if with_back and fur["back"]:
		# Lưng ghế nằm phía xa bàn (đối diện tâm bàn).
		var out := Vector2(cos(angle), sin(angle))
		var bp := p + Vector2(out.x * 12.0, out.y * 5.0)
		ci.draw_rect(Rect2(bp.x - 16, bp.y - 30, 32, 26), chair.darkened(0.12))
		ci.draw_rect(Rect2(bp.x - 13, bp.y - 27, 26, 4), chair.lightened(0.2))
		ci.draw_rect(Rect2(bp.x - 13, bp.y - 16, 26, 3), chair.darkened(0.3))


## Bóng sàn + ghế phía sau / hai bên (nằm dưới khách ngồi ở đó).
class _BackLayer extends Control:
	var owner_table: TableVisual

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		size = owner_table.size

	func _draw() -> void:
		var t := owner_table
		var c := t.center()
		draw_colored_polygon(TableVisual._ellipse(c + Vector2(0, 44), t._rx + 8.0, t._ry + 8.0), Color(0, 0, 0, 0.25))
		for i in t.seats:
			if not t.is_front(i):
				TableVisual.draw_chair(self, t.seat_point(i), t._angles[i], t._fur, not t.is_side(i), true)


## Mặt bàn tròn + chân bàn, khăn trải, viền vàng, bát đũa trước mỗi ghế.
class _TableTop extends Control:
	var owner_table: TableVisual

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		size = owner_table.size

	func _draw() -> void:
		var t := owner_table
		var fur := t._fur
		var top: Color = fur["top"]
		var edge: Color = fur["edge"]
		var cloth: Color = fur["cloth"]
		var trim: Color = fur["trim"]
		var c := t.center()
		var rx := t._rx
		var ry := t._ry
		# Chân bàn giữa + đế.
		draw_rect(Rect2(c.x - 7, c.y + ry * 0.4, 14, 44), edge.darkened(0.2))
		draw_colored_polygon(TableVisual._ellipse(c + Vector2(0, 44), 26, 8), edge.darkened(0.3))
		if cloth.a > 0.0:
			# Khăn phủ rủ xuống quanh mép bàn.
			draw_colored_polygon(TableVisual._ellipse(c + Vector2(0, 14), rx + 4.0, ry + 4.0), cloth.darkened(0.3))
			draw_colored_polygon(TableVisual._ellipse(c + Vector2(0, 8), rx + 4.0, ry + 4.0), cloth.darkened(0.12))
			draw_colored_polygon(TableVisual._ellipse(c, rx + 4.0, ry + 4.0), cloth)
			if trim.a > 0.0:
				draw_polyline(TableVisual._ellipse(c + Vector2(0, 13), rx + 4.0, ry + 4.0) + PackedVector2Array([c + Vector2(rx + 4.0, 13)]), trim, 3.0)
			draw_colored_polygon(TableVisual._ellipse(c, rx - 10.0, ry - 5.0), top.lightened(0.08))
		else:
			# Mép bàn dày (mặt cắt) rồi mặt bàn.
			draw_colored_polygon(TableVisual._ellipse(c + Vector2(0, 9), rx, ry), edge)
			draw_colored_polygon(TableVisual._ellipse(c, rx, ry), top)
			draw_colored_polygon(TableVisual._ellipse(c + Vector2(-rx * 0.15, -ry * 0.2), rx * 0.6, ry * 0.45), top.lightened(0.1))
			if trim.a > 0.0:
				draw_polyline(TableVisual._ellipse(c, rx - 8.0, ry - 4.0) + PackedVector2Array([c + Vector2(rx - 8.0, 0)]), trim, 2.0)
		# Bếp âm giữa bàn.
		draw_colored_polygon(TableVisual._ellipse(c, 22, 9), Color("2a1a12"))
		# Bát đũa trước mỗi ghế (từ cấp Nội thất 1).
		if int(fur["bowls"]) > 0:
			for i in t.seats:
				var a: float = t._angles[i]
				var b := c + Vector2(cos(a) * rx * 0.68, sin(a) * ry * 0.62)
				draw_colored_polygon(TableVisual._ellipse(b, 9, 4), Color("f7f1e3"))
				draw_colored_polygon(TableVisual._ellipse(b, 6, 2.5), Color("c9bba3"))


## Ghế phía trước: lưng ghế che nửa dưới khách ngồi quay lưng.
class _FrontChairs extends Control:
	var owner_table: TableVisual

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		size = owner_table.size

	func _draw() -> void:
		var t := owner_table
		for i in t.seats:
			if t.is_side(i):
				# Khách hai bên: mặt ghế + thân ghế che chân (trông như đang ngồi).
				var sp := t.seat_point(i)
				var sc: Color = t._fur["chair"]
				draw_rect(Rect2(sp.x - 18, sp.y + 2, 36, 18), sc.darkened(0.2))
				draw_rect(Rect2(sp.x - 18, sp.y + 2, 36, 4), sc.lightened(0.1))
				draw_rect(Rect2(sp.x - 16, sp.y + 20, 4, 12), sc.darkened(0.35))
				draw_rect(Rect2(sp.x + 12, sp.y + 20, 4, 12), sc.darkened(0.35))
			if t.is_front(i):
				var p := t.seat_point(i)
				var chair: Color = t._fur["chair"]
				# Mặt ghế (thấy khi trống) + lưng ghế quay về phía người chơi.
				TableVisual.draw_chair(self, p, t._angles[i], t._fur, false, true)
				var top := p.y - 6.0
				draw_rect(Rect2(p.x - 18, top, 36, 26), chair.darkened(0.12))
				draw_rect(Rect2(p.x - 15, top + 3, 30, 4), chair.lightened(0.2))
				draw_rect(Rect2(p.x - 15, top + 14, 30, 3), chair.darkened(0.3))
				draw_rect(Rect2(p.x - 16, top + 26, 4, 10), chair.darkened(0.35))
				draw_rect(Rect2(p.x + 12, top + 26, 4, 10), chair.darkened(0.35))
