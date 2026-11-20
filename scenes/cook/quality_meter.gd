class_name QualityMeter
extends HBoxContainer
## Đồng hồ chất lượng của bảng Sơ chế, thay cho thanh tiến độ có chữ:
## mỗi bước là một ô; chấm xong ô đổi màu theo điểm (Hỏng đỏ / Ổn cam / Hoàn hảo vàng) và nảy lên một cái.
## Bên phải là chất lượng đang đạt, đổi màu theo (Kém / Thường / Thượng hạng) để người chơi thấy mình làm tốt tới đâu.
## Sơ chế nhanh dùng light_up() để các ô sáng dần theo thời gian.

const PIP_HEIGHT := 30.0
const PIP_GAP := 6
const VERDICT_WIDTH := 220.0
const PENDING := {"fill": Color("d9c7a5"), "border": Color("a98a63")}
## Theo điểm bước: 0 Hỏng, 1 Ổn, 2 Hoàn hảo.
const GRADE_STYLE := [
	{"fill": Color("e0483f"), "border": Color("7a1712")},
	{"fill": Color("f2a33a"), "border": Color("8a5a3c")},
	{"fill": Color("ffd54f"), "border": Color("a3461a")},
]

var _pips: Array[Panel] = []
var _row: HBoxContainer
var _verdict: Label


## Dựng khung: hàng ô bên trái chiếm hết chỗ, chữ chất lượng bên phải.
func _init() -> void:
	add_theme_constant_override("separation", 14)
	custom_minimum_size = Vector2(0, PIP_HEIGHT + 4.0)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", PIP_GAP)
	_row.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(_row)
	_verdict = HuntUI.label("", 22, HuntUI.INK)
	_verdict.custom_minimum_size = Vector2(VERDICT_WIDTH, 0)
	_verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_verdict.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_verdict)


## Xoá hết ô cũ, dựng `step_count` ô trống (0 thì để trống hẳn, bảng vẫn giữ nguyên chiều cao).
func setup(step_count: int) -> void:
	for pip in _pips:
		pip.queue_free()
	_pips.clear()
	set_verdict("", HuntUI.INK)
	for i in step_count:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(0, PIP_HEIGHT)
		pip.size_flags_horizontal = SIZE_EXPAND_FILL
		pip.size_flags_vertical = SIZE_SHRINK_CENTER
		pip.add_theme_stylebox_override("panel", _pip_style(PENDING))
		_row.add_child(pip)
		_pips.append(pip)


## Ô số `index` chấm xong với điểm `grade` (0 Hỏng / 1 Ổn / 2 Hoàn hảo): đổi màu và nảy lên.
func set_grade(index: int, grade: int) -> void:
	if index < 0 or index >= _pips.size():
		return
	var pip := _pips[index]
	pip.add_theme_stylebox_override("panel", _pip_style(GRADE_STYLE[clampi(grade, 0, 2)]))
	pip.pivot_offset = pip.size / 2.0
	var t := pip.create_tween()
	t.tween_property(pip, "scale", Vector2(1.18, 1.35), 0.09)
	t.tween_property(pip, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Chữ chất lượng bên phải (rỗng thì ẩn).
func set_verdict(text: String, color: Color) -> void:
	_verdict.text = text
	_verdict.add_theme_color_override("font_color", color)


## Sáng `ratio` (0..1) số ô bằng màu của `grade`, dùng cho sơ chế nhanh.
func light_up(ratio: float, grade: int) -> void:
	var lit := int(floor(clampf(ratio, 0.0, 1.0) * _pips.size() + 0.0001))
	for i in _pips.size():
		var style: Dictionary = GRADE_STYLE[clampi(grade, 0, 2)] if i < lit else PENDING
		_pips[i].add_theme_stylebox_override("panel", _pip_style(style))


## Ô bo góc nhẹ, viền đậm hơn màu ô, nửa trên sáng hơn một chút cho có khối.
func _pip_style(colors: Dictionary) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = colors["fill"]
	s.border_color = colors["border"]
	s.set_border_width_all(3)
	s.border_width_bottom = 5
	s.set_corner_radius_all(5)
	return s
