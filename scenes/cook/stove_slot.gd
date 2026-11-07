class_name StoveSlot
extends Control
## Một bếp trong khu bếp: bếp lò đá (có lửa trong lò) hoặc bếp ga (lửa xanh dưới nồi),
## nồi đổi theo món đang nấu, hơi nước bốc lên, thẻ nhỏ dưới chân bếp hiện tên món + tiến độ.
## Chạm vào bếp -> phát tín hiệu tapped (màn nấu tự xử lý).

signal tapped(slot: StoveSlot)

const KIT := "res://assets/sprites/kitchen/"
const PX := 4 ## 1 điểm ảnh sprite = 4 px màn hình (giống nền).
const STOVE_Y := 64.0 ## Bếp nằm dưới phần nồi + hơi nước.
const WIDTH := 136.0
const HEIGHT := 216.0
const POT_H := 28 ## Nồi gang 32x28 (điểm ảnh sprite).
const POT_Y := STOVE_Y + 6 * PX - 27 * PX ## Đáy nồi ngồi trên mặt bếp. ## Nồi (phía trên) + bếp + thẻ trạng thái.

var index := 0
var gas := false
var broth: BrothData = null
var total := 0.0
var remaining := 0.0
var servings := 0
var expired := false
var taken: Dictionary = {}
var cook_actor: KitchenActor = null ## Ai đang trông nồi này (để quay về khi xong).

var _stove: TextureRect
var _fire: TextureRect
var _fire_atlas: AtlasTexture
var _flame: TextureRect
var _flame_atlas: AtlasTexture
var _pot: TextureRect
var _steam: TextureRect
var _steam_atlas: AtlasTexture
var _chip: PanelContainer
var _chip_label: Label
var _bar: ProgressBar
var _anim := 0.0


func setup(i: int, is_gas: bool) -> void:
	index = i
	gas = is_gas
	size = Vector2(WIDTH, HEIGHT)
	mouse_filter = MOUSE_FILTER_STOP
	_stove = _sprite(load(KIT + ("stove_gas" if gas else "stove_stone") + ".png"), Vector2(34, 38), Vector2(0, STOVE_Y))
	_fire_atlas = _atlas("fire", 16, 12)
	_fire = _sprite(_fire_atlas, Vector2(16, 12), Vector2(36, STOVE_Y + 21 * PX))
	_pot = _sprite(load(KIT + "pot_empty.png"), Vector2(32, POT_H), Vector2((WIDTH - 128) / 2.0, POT_Y))
	# Lửa bếp ga liếm đáy nồi (vẽ đè lên mép dưới nồi).
	_flame_atlas = _atlas("gas_flame", 20, 5)
	_flame = _sprite(_flame_atlas, Vector2(20, 5), Vector2((WIDTH - 80) / 2.0, STOVE_Y + 3 * PX))
	_steam_atlas = _atlas("steam", 14, 18)
	_steam = _sprite(_steam_atlas, Vector2(14, 18), Vector2((WIDTH - 56) / 2.0, _pot.position.y - 62))
	_fire.visible = false
	_flame.visible = false
	_steam.visible = false

	_chip = PanelContainer.new()
	# Biển gỗ phẳng (không có chấm trang trí ở góc nên chữ không bị đè).
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color("f3e2c0")
	cs.border_color = Color("5a3820")
	cs.set_border_width_all(3)
	cs.set_corner_radius_all(5)
	cs.content_margin_left = 6
	cs.content_margin_right = 6
	cs.content_margin_top = 2
	cs.content_margin_bottom = 3
	cs.shadow_color = Color(0, 0, 0, 0.3)
	cs.shadow_offset = Vector2(0, 2)
	cs.shadow_size = 1
	_chip.add_theme_stylebox_override("panel", cs)
	_chip.position = Vector2(4, -50) # Biển nhỏ treo phía trên nồi (không bị nhân vật che).
	_chip.custom_minimum_size = Vector2(WIDTH - 8, 0)
	_chip.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_chip)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	_chip.add_child(box)
	_chip_label = HuntUI.label("", 14, HuntUI.INK)
	_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chip_label.clip_text = true
	_chip_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(_chip_label)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.max_value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("5d4037")
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ff9800")
	fill.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(_bar)
	_show_idle()


## Đưa thẻ trạng thái sang lớp khác (nằm trên nhân vật đứng trước bếp), giữ nguyên vị trí trên màn.
## Bếp có thể bị thu nhỏ (scale): biển giữ cỡ chữ gốc, nằm ngay trên miệng nồi, rộng bằng bếp.
func detach_chip(layer: Control) -> void:
	var at := position + Vector2(3, POT_Y * scale.y - 32)
	remove_child(_chip)
	layer.add_child(_chip)
	_chip.custom_minimum_size.x = WIDTH * scale.x - 6
	_chip.size = Vector2.ZERO # Co về đúng cỡ tối thiểu mới.
	_chip.position = at


func is_idle() -> bool:
	return broth == null


func progress() -> float:
	if broth == null or total <= 0.0:
		return 0.0
	return clampf(1.0 - remaining / total, 0.0, 1.0)


## Bắt đầu nấu 1 mẻ.
func start(b: BrothData, seconds: float, portions: int, from_expired: bool, taken_items: Dictionary) -> void:
	broth = b
	total = maxf(0.5, seconds)
	remaining = total
	servings = portions
	expired = from_expired
	taken = taken_items
	var pot_path := KIT + "pot_" + b.id.trim_suffix("_broth") + ".png"
	_pot.texture = load(pot_path) if ResourceLoader.exists(pot_path) else load(KIT + "pot_tomato.png")
	_fire.visible = not gas
	_flame.visible = gas
	_steam.visible = true
	_chip_label.text = b.display_name
	_bar.visible = true
	_bar.value = 0.0
	# Nồi được đặt lên bếp: nảy nhẹ.
	_pot.pivot_offset = Vector2(64, POT_H * PX - 4)
	_pot.scale = Vector2(1.12, 0.86)
	create_tween().tween_property(_pot, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Gọi mỗi khung hình; trả về true khi vừa chín.
func tick(delta: float) -> bool:
	if broth == null:
		return false
	remaining -= delta
	_bar.value = progress()
	_chip_label.text = "%ds · %s" % [ceili(maxf(remaining, 0.0)), _short_name()]
	return remaining <= 0.0


## Nhấc nồi ra (chín hoặc bỏ dở): trả bếp về trạng thái trống.
func clear() -> void:
	broth = null
	taken = {}
	cook_actor = null
	_show_idle()


## Nháy sáng khi vừa nấu xong.
func flash() -> void:
	modulate = Color(1.5, 1.4, 1.1)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.4)


func _show_idle() -> void:
	_pot.texture = load(KIT + "pot_empty.png")
	_fire.visible = false
	_flame.visible = false
	_steam.visible = false
	_chip_label.text = "Bếp %d" % (index + 1)
	_bar.visible = false


## Viền sáng khi bếp đang được chọn để nấu (bảng chọn món đang mở cho bếp này).
func set_selected(on: bool) -> void:
	_stove.modulate = Color(1.25, 1.18, 0.95) if on else Color.WHITE
	_chip.modulate = Color(1.1, 1.05, 0.8) if on else Color.WHITE
	if on and broth == null:
		_chip_label.text = "Chọn món..."
	elif broth == null:
		_chip_label.text = "Bếp %d" % (index + 1)


func _short_name() -> String:
	var n := broth.display_name.trim_prefix("Lẩu ")
	return n.left(1).to_upper() + n.substr(1)


func _process(delta: float) -> void:
	_anim += delta
	if _fire.visible:
		_fire_atlas.region = Rect2(16 * (int(_anim * 9.0) % 4), 0, 16, 12)
	if _flame.visible:
		_flame_atlas.region = Rect2(20 * (int(_anim * 8.0) % 3), 0, 20, 5)
	if _steam.visible:
		_steam_atlas.region = Rect2(14 * (int(_anim * 7.0) % 6), 0, 14, 18)
	if broth != null:
		# Nồi sôi: rung rất nhẹ.
		_pot.position.y = POT_Y + (1.0 if int(_anim * 6.0) % 2 == 0 else 0.0)


func _sprite(tex: Texture2D, px_size: Vector2, pos: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = px_size * PX
	r.position = pos
	r.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _atlas(name: String, w: int, h: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load(KIT + name + ".png")
	a.region = Rect2(0, 0, w, h)
	return a


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(self)
		accept_event()
