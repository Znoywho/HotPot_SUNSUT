class_name CombatantView
extends PanelContainer
## Một đơn vị trong trận: tên, sprite (có animation), thanh máu, giáp và trạng thái.
## Animation: đứng thở + chớp mắt, lao tới khi đánh, giật lùi khi trúng đòn, ngã khi chết.
## Chạm vào (ngón tay hoặc chuột) để chọn làm mục tiêu.

signal tapped(view: CombatantView)

const SPRITE_SIZE := 128.0
const SMALL_SPRITE_SIZE := 88.0 ## Đơn vị sinh ra giữa trận (vd nấm con).
const EYE_PUPIL := Color("1a1010")

static var _blink_cache := {} ## Texture gốc -> texture mắt nhắm.

var combatant: Combatant
var sprite: TextureRect ## Đặt tự do trong _stage (không bị container sắp lại) để tween vị trí.
var hp_bar: ProgressBar
var hp_label: Label
var status_label: Label
var name_label: Label
var _stage: Control
var _home := Vector2.ZERO
var _open_texture: Texture2D
var _blink_texture: Texture2D
var _idle_tween: Tween
var _action_tween: Tween
var _dead := false
var _selected := false
var _acting := false
var _frames: SpriteFrameLayer ## Động tác tung chiêu; null nếu nhân vật chưa có sheet.


func setup(c: Combatant) -> void:
	combatant = c
	custom_minimum_size = Vector2(150, 0)
	mouse_filter = MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.alignment = BoxContainer.ALIGNMENT_END
	add_child(box)

	name_label = HuntUI.outlined_label(c.display_name, HuntUI.FONT_SMALL)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)

	var spawned := c.data != null and c.data.resource_path.is_empty()
	var size := SMALL_SPRITE_SIZE if spawned else SPRITE_SIZE
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(size, size)
	box.add_child(_stage)
	_open_texture = HuntUI.combatant_texture(c.data)
	_blink_texture = _make_blink_texture(_open_texture)
	sprite = HuntUI.texture_rect(_open_texture, size)
	sprite.size = Vector2(size, size)
	sprite.pivot_offset = Vector2(size / 2.0, size * 0.9) # Chân nhân vật.
	_stage.add_child(sprite)
	_stage.resized.connect(_place_sprite)
	_frames = SpriteFrameLayer.attach_to(sprite)

	var bar_holder := Control.new()
	bar_holder.custom_minimum_size = Vector2(0, 24)
	box.add_child(bar_holder)
	hp_bar = HuntUI.hp_bar(c.is_ally)
	hp_bar.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bar_holder.add_child(hp_bar)
	hp_label = HuntUI.outlined_label("", 14)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bar_holder.add_child(hp_label)

	status_label = HuntUI.outlined_label("", 16, Color("ffe0b2"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size = Vector2(0, 22)
	box.add_child(status_label)

	HuntUI.ignore_mouse_recursive(self)
	_update_style()
	refresh()
	_start_idle()
	_schedule_blink()


func _place_sprite() -> void:
	_home = (_stage.size - sprite.size) / 2.0
	if _action_tween == null or not _action_tween.is_running():
		sprite.position = _home


func refresh() -> void:
	hp_bar.max_value = combatant.max_hp
	hp_bar.value = combatant.hp
	hp_label.text = "%d/%d" % [combatant.hp, combatant.max_hp]
	var parts: Array[String] = []
	if combatant.armor > 0:
		parts.append("Giáp %d" % combatant.armor)
	for effect in combatant.statuses:
		if effect is BurnEffect:
			parts.append("Đốt %d" % effect.turns_left)
		elif effect is PoisonEffect:
			parts.append("Độc %d" % effect.turns_left)
	status_label.text = " · ".join(parts)
	if not combatant.is_alive() and not _dead:
		play_death()
	elif combatant.is_alive() and _dead:
		play_revive() # Linh hồn đầu bếp.


func set_selected(value: bool) -> void:
	_selected = value
	_update_style()


func set_acting(value: bool) -> void:
	_acting = value
	_update_style()


func _update_style() -> void:
	var border := Color(0, 0, 0, 0)
	if _selected:
		border = Color("ffd54f")
	elif _acting:
		border = Color("ffffff")
	var bg := Color(0.1, 0.06, 0.04, 0.45) if (_selected or _acting) else Color(0, 0, 0, 0.0)
	add_theme_stylebox_override("panel", HuntUI.panel_style(bg, border, 12, 4))


# --- Animation --------------------------------------------------------------

## Đứng thở: co giãn nhẹ quanh chân, mỗi đơn vị lệch nhịp một chút.
func _start_idle() -> void:
	if _idle_tween != null:
		_idle_tween.kill()
	sprite.scale = Vector2.ONE
	var period := randf_range(0.55, 0.75)
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_interval(randf_range(0.0, 0.4))
	_idle_tween.tween_property(sprite, "scale", Vector2(1.04, 0.95), period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(sprite, "scale", Vector2.ONE, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _schedule_blink() -> void:
	if _blink_texture == null:
		return
	get_tree().create_timer(randf_range(2.0, 4.5)).timeout.connect(_blink)


func _blink() -> void:
	if not is_inside_tree():
		return
	if not _dead:
		sprite.texture = _blink_texture
		await get_tree().create_timer(0.12).timeout
		if is_inside_tree() and not _dead:
			sprite.texture = _open_texture
	_schedule_blink()


## Lao tới mục tiêu: lùi lấy đà rồi phóng lên trước; đầu bếp phát thêm động tác của chiêu.
func play_attack(direction: float, animation_name := "attack") -> void:
	if _dead:
		return
	_kill_action()
	if _frames != null:
		_frames.play(animation_name)
	_action_tween = create_tween()
	_action_tween.tween_property(sprite, "position", _home + Vector2(-10 * direction, 2), 0.08)
	_action_tween.tween_property(sprite, "position", _home + Vector2(46 * direction, -6), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(sprite, "position", _home, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## Trúng đòn: nháy đỏ, giật lùi, bẹp người rồi đàn hồi.
func play_hurt(heavy := false) -> void:
	if _dead:
		return
	var away := -1.0 if combatant.is_ally else 1.0
	_kill_action()
	sprite.modulate = Color(1, 0.3, 0.3)
	_action_tween = create_tween().set_parallel(true)
	_action_tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	var push := 22.0 if heavy else 12.0
	var back := create_tween()
	back.tween_property(sprite, "position", _home + Vector2(push * away, 0), 0.06)
	back.tween_property(sprite, "position", _home, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var squash := create_tween()
	squash.tween_property(_stage, "scale", Vector2(1.12, 0.86), 0.06)
	squash.tween_property(_stage, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_stage.pivot_offset = Vector2(_stage.size.x / 2.0, _stage.size.y)


## Ngã xuống: đổ nghiêng về phía sau, xám và mờ dần.
## Quái: sau khi ngã thì teo lại và biến mất hẳn (giữ chỗ để đội hình không xô lệch, không chọn được nữa).
## Phe mình vẫn nằm lại (đầu bếp có thể hồi sinh).
func play_death() -> void:
	_dead = true
	if _idle_tween != null:
		_idle_tween.kill()
	_kill_action()
	sprite.texture = _blink_texture if _blink_texture != null else _open_texture
	var away := -1.0 if combatant.is_ally else 1.0
	_action_tween = create_tween().set_parallel(true)
	_action_tween.tween_property(sprite, "rotation", deg_to_rad(80) * away, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(sprite, "position", _home + Vector2(16 * away, 14), 0.35)
	_action_tween.tween_property(self, "modulate", Color(0.6, 0.6, 0.6, 0.55), 0.5).set_delay(0.2)
	if not combatant.is_ally:
		mouse_filter = MOUSE_FILTER_IGNORE
		var vanish := create_tween()
		vanish.tween_interval(0.75)
		vanish.tween_property(_stage, "scale", Vector2(1.2, 0.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		vanish.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
		_stage.pivot_offset = Vector2(_stage.size.x / 2.0, _stage.size.y)


## Đứng dậy (Linh hồn đầu bếp hồi sinh).
func play_revive() -> void:
	_dead = false
	_kill_action()
	sprite.texture = _open_texture
	_action_tween = create_tween().set_parallel(true)
	_action_tween.tween_property(sprite, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(sprite, "position", _home, 0.3)
	_action_tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	_action_tween.chain().tween_callback(_start_idle)


func _kill_action() -> void:
	if _action_tween != null and _action_tween.is_running():
		_action_tween.kill()
	if _frames != null:
		_frames.stop()
	sprite.position = _home
	sprite.modulate = Color.WHITE


## Tạo khung mắt nhắm: tìm các ô trắng cạnh con ngươi (mắt), tô bằng màu da xung quanh
## và kẻ một vạch tối ở hàng dưới. Sprite không có mắt kiểu này thì trả về null.
static func _make_blink_texture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _blink_cache.has(tex):
		return _blink_cache[tex]
	var img := tex.get_image()
	if img == null or img.is_compressed():
		_blink_cache[tex] = null
		return null
	img = img.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var eye_pixels: Array[Vector2i] = []
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var is_eye := c.is_equal_approx(Color.WHITE) or c.is_equal_approx(EYE_PUPIL)
			if not is_eye:
				continue
			# Phải có cả trắng và con ngươi trong ô 3x3 quanh nó.
			var has_white := false
			var has_pupil := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var n := img.get_pixel(nx, ny)
					has_white = has_white or n.is_equal_approx(Color.WHITE)
					has_pupil = has_pupil or n.is_equal_approx(EYE_PUPIL)
			if has_white and has_pupil:
				eye_pixels.append(Vector2i(x, y))
	if eye_pixels.is_empty():
		_blink_cache[tex] = null
		return null
	var lowest := {}
	for p in eye_pixels:
		lowest[p.x] = maxi(int(lowest.get(p.x, -1)), p.y)
	var originals := {}
	for p in eye_pixels:
		originals[p] = true
	for p in eye_pixels:
		# Màu da: ô gần nhất phía trên không phải mắt.
		var skin := Color(0, 0, 0, 0)
		for k in range(1, 4):
			if p.y - k >= 0 and not originals.has(Vector2i(p.x, p.y - k)):
				skin = img.get_pixel(p.x, p.y - k)
				break
		img.set_pixel(p.x, p.y, skin)
	for x in lowest:
		img.set_pixel(x, lowest[x], EYE_PUPIL)
	var out := ImageTexture.create_from_image(img)
	_blink_cache[tex] = out
	return out


func _gui_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if pressed and combatant.is_alive():
		tapped.emit(self)
		accept_event()
