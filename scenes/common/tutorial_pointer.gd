class_name TutorialPointer
extends Control
## Mũi tên pixel vàng nhún nhảy trỏ vào một Control (kèm bong bóng chữ ngắn nếu có), dùng cho:
## - Ngày 0 hướng dẫn: TutorialPointer.hint(...) trỏ vào đồ thật trong màn (bụi cỏ, bếp, bàn, rác...), mỗi gợi ý 1 lần.
## - Thẻ trong bảng Cách chơi: trỏ vào khung chỉ trên ảnh minh hoạ.
## Không chặn chạm. Tự biến mất khi người chơi chạm vào đồ được trỏ, hoặc đồ đó bị ẩn / bị xoá.
## Mũi tên vẽ bằng _draw (font không có glyph mũi tên).

const PIXEL := 4.0 ## Một ô pixel của mũi tên = 4 px.
## Mũi tên chỉ xuống: X = viền tối, o = ruột vàng.
const ARROW := [
	"..XXXXX..",
	"..XoooX..",
	"..XoooX..",
	"..XoooX..",
	"XXXoooXXX",
	"XoooooooX",
	".XoooooX.",
	"..XoooX..",
	"...XoX...",
	"....X....",
]
const FILL := Color("ffd36b")
const OUTLINE := Color("1a0f0a")
const BOB_HEIGHT := 10.0 ## Nhún lên xuống bao nhiêu px.
const BOB_SPEED := 6.0
const GAP := 6.0 ## Khoảng hở giữa mũi tên và đồ được trỏ.
const BUBBLE_FONT := 20
const BUBBLE_BG := Color("4a2e20")
const BUBBLE_BORDER := Color("a8764a")
const TEXT_COLOR := Color("f5f1e6")

static var _shown := {} ## Khoá gợi ý Ngày 0 đã hiện (mỗi gợi ý chỉ hiện một lần mỗi lần chơi Ngày 0).

var target: Control
var below := false ## Đứng dưới node, chĩa lên (vd bàn quán: phía trên là bong bóng gọi món).
var area: Control ## Mũi tên phải nằm trong node này (null = cả màn); đụng mép trên thì lật xuống dưới node được trỏ.
var _time := 0.0
var _bubble: PanelContainer
var _dismiss_on_tap := true


## Gợi ý trong Ngày 0: trỏ vào `node` với câu `text`. Chỉ hiện khi đang chơi Ngày 0 và khoá `key` chưa hiện lần nào.
## `from_below` = mũi tên đứng dưới node. Trả về mũi tên (hoặc null nếu không hiện).
static func hint(key: String, node: Control, text: String, from_below := false) -> TutorialPointer:
	if not GameState.in_tutorial or _shown.has(key) or node == null or not node.is_inside_tree():
		return null
	_shown[key] = true
	var pointer := point_at(node, text)
	pointer.below = from_below
	return pointer


## Trỏ vào `node` (luôn hiện). Mũi tên gắn vào cùng lớp vẽ với node để toạ độ khớp nhau.
static func point_at(node: Control, text := "", dismiss_on_tap := true, inside: Control = null) -> TutorialPointer:
	var pointer := TutorialPointer.new()
	pointer.target = node
	pointer.area = inside
	pointer._dismiss_on_tap = dismiss_on_tap
	pointer._build_bubble(text)
	_host_for(node).add_child(pointer)
	return pointer


## Bắt đầu lại Ngày 0: các gợi ý được hiện lại từ đầu.
static func reset_hints() -> void:
	_shown.clear()


## Nơi gắn mũi tên: CanvasLayer gần nhất chứa node (HUD, bảng Cách chơi), không thì màn hiện tại.
## Không gắn thẳng vào node để không bị khung cuộn / clip_contents của node cha cắt mất.
static func _host_for(node: Control) -> Node:
	var parent := node.get_parent()
	while parent != null:
		if parent is CanvasLayer:
			return parent
		parent = parent.get_parent()
	return node.get_tree().current_scene


## Mũi tên nằm trên cùng, không theo biến đổi của node cha, không chặn chạm.
func _ready() -> void:
	top_level = true
	z_index = 100
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(ARROW[0].length(), ARROW.size()) * PIXEL
	_follow()


## Mỗi khung: nhún và bám theo node; node đã mất / bị ẩn thì tự xoá.
func _process(delta: float) -> void:
	if not is_instance_valid(target) or not target.is_visible_in_tree():
		queue_free()
		return
	_time += delta
	_follow()


## Chạm vào trong vùng node được trỏ thì mũi tên tắt (không nuốt chạm: node vẫn nhận như thường).
func _input(event: InputEvent) -> void:
	if not _dismiss_on_tap or not is_instance_valid(target):
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	var local_pos: Vector2 = target.make_input_local(event).get("position") # chuột và chạm đều có `position`
	if Rect2(Vector2.ZERO, target.size).has_point(local_pos):
		queue_free()


## Đặt mũi tên trên đầu node, đầu nhọn chĩa xuống; node sát mép trên màn thì đặt bên dưới, chĩa lên.
## Vị trí nhún: y = y0 ± BOB_HEIGHT × |sin(BOB_SPEED × t)| (nhún ra xa node rồi trở lại).
func _follow() -> void:
	var rect := target.get_global_rect()
	var bob := BOB_HEIGHT * absf(sin(BOB_SPEED * _time))
	var bubble_h := _bubble.get_combined_minimum_size().y + GAP if _bubble != null else 0.0
	var top_limit := area.get_global_rect().position.y if is_instance_valid(area) else 0.0
	var flip := below or rect.position.y - size.y - GAP - bubble_h < top_limit
	var x := rect.get_center().x - size.x / 2.0
	var y := rect.end.y + GAP + bob if flip else rect.position.y - size.y - GAP - bob
	global_position = Vector2(x, y).round()
	pivot_offset = size / 2.0
	rotation = PI if flip else 0.0
	if _bubble != null:
		var bsize := _bubble.get_combined_minimum_size()
		_bubble.size = bsize
		var by := y + size.y + GAP if flip else y - bsize.y - GAP
		var bx := clampf(rect.get_center().x - bsize.x / 2.0, GAP, get_viewport_rect().size.x - bsize.x - GAP)
		_bubble.global_position = Vector2(bx, by).round()


## Vẽ mũi tên theo bảng ô ARROW.
func _draw() -> void:
	for row in ARROW.size():
		var line: String = ARROW[row]
		for col in line.length():
			var ch := line[col]
			if ch == ".":
				continue
			draw_rect(Rect2(Vector2(col, row) * PIXEL, Vector2.ONE * PIXEL), OUTLINE if ch == "X" else FILL)


## Bong bóng chữ ngắn cạnh mũi tên (top_level riêng để không xoay theo mũi tên khi lật).
func _build_bubble(text: String) -> void:
	if text == "":
		return
	_bubble = PanelContainer.new()
	_bubble.top_level = true
	_bubble.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = BUBBLE_BG
	style.border_color = BUBBLE_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_bubble.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", BUBBLE_FONT)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	_bubble.add_child(label)
	add_child(_bubble)
