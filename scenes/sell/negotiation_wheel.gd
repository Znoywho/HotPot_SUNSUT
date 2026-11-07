class_name NegotiationWheel
extends Control
## Bảng thương lượng khi hết món khách gọi: vòng quay 2 ô "Có" / "Không".
## Có -> khách đồng ý đổi sang món khác, Không -> khách bỏ về.
## Dùng: var w := NegotiationWheel.new(); add_child(w); w.open(tên món hết, tên món thay, tỷ lệ Có)
## rồi chờ tín hiệu `decided(accepted)`. Bảng tự xóa sau khi báo kết quả.

signal decided(accepted: bool)

const SPIN_TIME := 2.2 ## Thời gian quay (giây).
const SPIN_TURNS := 4 ## Số vòng quay đủ trước khi dừng.
const RESULT_HOLD := 0.9 ## Dừng lại cho người chơi xem kết quả.

const YES_COLOR := Color("4caf50")
const NO_COLOR := Color("d9534f")
const RIM := Color("3a2416")
const PAPER := Color("f3e6c4")

var yes_chance := 0.5
var _wheel: _Wheel
var _spin_button: Button
var _result_label: Label
var _spinning := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP # Chặn bấm xuống màn bên dưới.


## missing: món đã hết, offer: món đề nghị đổi, chance: tỷ lệ ô "Có" (0..1).
func open(missing: String, offer: String, chance: float) -> void:
	yes_chance = clampf(chance, 0.05, 0.95)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = RIM
	style.set_border_width_all(4)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	box.add_child(_label("Hết %s!" % missing, 26, RIM))
	box.add_child(_label("Thương lượng mời khách đổi sang %s?" % offer, 20, RIM))
	box.add_child(_label("Ô xanh: khách đồng ý (%d%%)" % roundi(yes_chance * 100), 18, Color("6b4a33")))
	_wheel = _Wheel.new()
	_wheel.yes_chance = yes_chance
	_wheel.custom_minimum_size = Vector2(240, 240)
	_wheel.size_flags_horizontal = SIZE_SHRINK_CENTER
	box.add_child(_wheel)
	_result_label = _label("", 24, RIM)
	box.add_child(_result_label)
	_spin_button = Button.new()
	_spin_button.text = "Quay!"
	_spin_button.custom_minimum_size = Vector2(220, 56)
	_spin_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	_spin_button.add_theme_font_size_override("font_size", 22)
	_spin_button.pressed.connect(_spin)
	box.add_child(_spin_button)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func _spin() -> void:
	if _spinning:
		return
	_spinning = true
	_spin_button.disabled = true
	var accepted := randf() < yes_chance
	# Ô "Có" chiếm góc [0, yes*TAU) tính từ kim (đỉnh) theo chiều kim đồng hồ.
	var yes_arc := yes_chance * TAU
	var land := randf_range(0.08, 0.92) * (yes_arc if accepted else TAU - yes_arc) + (0.0 if accepted else yes_arc)
	# Bánh xe quay sao cho điểm `land` nằm dưới kim.
	var final_rot := SPIN_TURNS * TAU + (TAU - land)
	var t := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(_wheel, "rotation_value", final_rot, SPIN_TIME).from(0.0)
	await t.finished
	_result_label.text = "Khách đồng ý đổi món!" if accepted else "Khách không chịu, bỏ về..."
	_result_label.add_theme_color_override("font_color", YES_COLOR.darkened(0.3) if accepted else NO_COLOR.darkened(0.2))
	await get_tree().create_timer(RESULT_HOLD).timeout
	decided.emit(accepted)
	queue_free()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(380, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Bánh xe 2 ô + kim chỉ ở đỉnh.
class _Wheel extends Control:
	var yes_chance := 0.5
	var rotation_value := 0.0:
		set(v):
			rotation_value = v
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 10.0
		draw_circle(c, r + 6.0, RIM)
		var yes_arc := yes_chance * TAU
		# Góc 0 của bánh xe = đỉnh (-PI/2), quay theo chiều kim đồng hồ.
		var start := -PI / 2.0 + rotation_value
		_sector(c, r, start, start + yes_arc, YES_COLOR)
		_sector(c, r, start + yes_arc, start + TAU, NO_COLOR)
		_text_at(c, r * 0.58, start + yes_arc / 2.0, "CÓ")
		_text_at(c, r * 0.58, start + yes_arc + (TAU - yes_arc) / 2.0, "KHÔNG")
		draw_circle(c, 14.0, RIM)
		draw_circle(c, 8.0, PAPER)
		# Kim chỉ ở đỉnh, đứng yên.
		var tip := Vector2(c.x, c.y - r + 14.0)
		draw_colored_polygon(PackedVector2Array([tip, Vector2(c.x - 14, c.y - r - 14), Vector2(c.x + 14, c.y - r - 14)]), Color.WHITE)
		draw_polyline(PackedVector2Array([tip, Vector2(c.x - 14, c.y - r - 14), Vector2(c.x + 14, c.y - r - 14), tip]), RIM, 3.0)

	func _sector(c: Vector2, r: float, a0: float, a1: float, col: Color) -> void:
		var pts := PackedVector2Array([c])
		var steps := maxi(4, int((a1 - a0) / TAU * 64.0))
		for i in steps + 1:
			var a := lerpf(a0, a1, i / float(steps))
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, col)
		draw_line(c, c + Vector2(cos(a0), sin(a0)) * r, RIM, 3.0)

	func _text_at(c: Vector2, dist: float, a: float, text: String) -> void:
		var font := get_theme_default_font()
		var fs := 22
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := c + Vector2(cos(a), sin(a)) * dist + Vector2(-w / 2.0, fs * 0.35)
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, RIM)
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
