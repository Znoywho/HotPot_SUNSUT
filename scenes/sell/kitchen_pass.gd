class_name KitchenPass
extends Control
## Ô cửa bếp trên tường nhà hàng: đầu bếp đứng sau quầy, các nồi lẩu đã nấu (kho nước cốt) bày trên quầy
## kèm số phần còn lại. Chạm một nồi để bưng lên khay. Nồi dùng chung hình với màn bếp (pot_<món>.png).
## Toạ độ theo sân khấu 1280x720 của màn bán (1 điểm ảnh nền = 4 px).

signal pot_tapped(broth_id: String)

const KIT := "res://assets/sprites/kitchen/"
const FRONT_TEXTURE := "res://assets/sprites/restaurant/restaurant_pass_front.png"
const CHAR_DIR := "res://assets/sprites/characters/"
const STAGE := Vector2(1280, 720)
const CHEF_X := 806.0
const CHEF_FEET := 252.0
const LEDGE_Y := 204.0 ## Mặt quầy (đáy nồi đặt ở đây).
const POT_X0 := 878.0
const POT_STEP := 76.0
const POT_SIZE := Vector2(64, 56) ## Nồi 32x28 phóng x2.
const SOUS_X := 880.0
const SOUS_POT_X0 := 934.0
const SOUS_POT_STEP := 66.0

var chef: KitchenActor
var sous: KitchenActor = null
var _pots: Dictionary = {} ## broth id -> {rect: TextureRect, count: Label}


func _init() -> void:
	size = STAGE
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	chef = KitchenActor.new()
	add_child(chef)
	chef.setup(load(CHAR_DIR + "player.png"), CHEF_X, CHEF_FEET, "Đầu bếp", true)
	# Bếp phó Minh (cấp Nhân viên bếp 3, cùng người ở màn bếp) đứng cạnh đầu bếp; nồi dồn sang phải.
	var pot_x0 := POT_X0
	var pot_step := POT_STEP
	if RestaurantDecor.has_sous():
		sous = KitchenActor.new()
		add_child(sous)
		sous.setup(load(CHAR_DIR + "staff_minh.png"), SOUS_X, CHEF_FEET, "Minh", true)
		pot_x0 = SOUS_POT_X0
		pot_step = SOUS_POT_STEP

	var front := TextureRect.new()
	front.texture = load(FRONT_TEXTURE)
	front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	front.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	front.stretch_mode = TextureRect.STRETCH_SCALE
	front.size = STAGE
	front.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(front)

	var i := 0
	for broth in Database.broths_for_day(GameState.day):
		_add_pot(broth, Vector2(pot_x0 + i * pot_step, LEDGE_Y - POT_SIZE.y))
		i += 1


static func pot_texture(broth_id: String) -> Texture2D:
	var path := KIT + "pot_" + broth_id.trim_suffix("_broth") + ".png"
	return load(path) if ResourceLoader.exists(path) else load(KIT + "pot_tomato.png")


func _add_pot(broth: BrothData, pos: Vector2) -> void:
	var rect := TextureRect.new()
	rect.texture = pot_texture(broth.id)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.position = pos
	rect.size = POT_SIZE
	rect.pivot_offset = Vector2(POT_SIZE.x / 2.0, POT_SIZE.y)
	rect.mouse_filter = MOUSE_FILTER_STOP
	rect.gui_input.connect(_on_pot_input.bind(broth.id))
	add_child(rect)
	var count := HuntUI.outlined_label("", 18, Color.WHITE)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.custom_minimum_size = Vector2(POT_SIZE.x, 0)
	count.position = Vector2(pos.x, LEDGE_Y + 2.0)
	count.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(count)
	_pots[broth.id] = {"rect": rect, "count": count}


func _on_pot_input(event: InputEvent, broth_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pot_tapped.emit(broth_id)
		accept_event()


## Cập nhật số phần trên quầy; nồi đang nằm trên khay thì nhấc lên khỏi quầy.
func refresh(carrying_id: String) -> void:
	for id in _pots:
		var ui: Dictionary = _pots[id]
		var n := GameState.get_broth_count(id)
		var rect: TextureRect = ui["rect"]
		var count: Label = ui["count"]
		count.text = "x%d" % n
		count.add_theme_color_override("font_color", Color.WHITE if n > 0 else Color("ff8a80"))
		rect.modulate = Color.WHITE if n > 0 else Color(0.35, 0.3, 0.3, 0.75)
		rect.position.y = LEDGE_Y - POT_SIZE.y - (10.0 if id == carrying_id else 0.0)


## Tâm nồi (toạ độ global) để bay nồi từ quầy ra bàn.
func pot_global_center(broth_id: String) -> Vector2:
	if not _pots.has(broth_id):
		return global_position + Vector2(CHEF_X, LEDGE_Y)
	var rect: TextureRect = _pots[broth_id]["rect"]
	return rect.get_global_rect().get_center()


## Nảy nồi khi bị chạm mà hết hàng / khi lấy lên khay.
func bounce(broth_id: String) -> void:
	if not _pots.has(broth_id):
		return
	var rect: TextureRect = _pots[broth_id]["rect"]
	var t := rect.create_tween()
	t.tween_property(rect, "scale", Vector2(1.15, 0.85), 0.07)
	t.tween_property(rect, "scale", Vector2.ONE, 0.12)
