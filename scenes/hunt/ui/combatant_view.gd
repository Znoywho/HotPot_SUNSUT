class_name CombatantView
extends PanelContainer
## Một đơn vị trong trận: tên, sprite (có animation), thanh máu, giáp và trạng thái.
## Animation: đứng thở + chớp mắt; đánh = lấy đà (co người) rồi phóng tới (giãn người, bụi chân, bóng mờ), trả về
## ĐÚNG LÚC CHẠM để BattleView hiện đòn; trúng đòn = nháy trắng (đứng hình cùng hitstop) rồi đỏ, giật lùi, bẹp người;
## quái báo trước đòn (chớp đỏ + "!"); quái gục thì ngã rồi vỡ thành hạt pixel bốc hơi; độc / đốt có hạt bay liên tục.
## Chạm vào (ngón tay hoặc chuột) để chọn làm mục tiêu.

signal tapped(view: CombatantView)

const SPRITE_SIZE := 128.0
const SMALL_SPRITE_SIZE := 88.0 ## Đơn vị sinh ra giữa trận (vd nấm con).
const EYE_PUPIL := Color("1a1010")
const HIT_FLASH := preload("res://scenes/hunt/ui/hit_flash.gdshader")
const WINDUP_ALLY := 0.06 ## Giây lấy đà của đầu bếp / thú cưỡi: người chơi vừa bấm nên phải nhanh.
const WINDUP_ENEMY := 0.12 ## Quái lấy đà lâu hơn (cùng với báo trước đòn) để kịp đọc đòn.
const DASH := 0.07 ## Giây phóng tới mục tiêu.
const RETURN := 0.2 ## Giây lui về chỗ sau khi chạm.
const LUNGE := 46.0 ## px phóng tới.
const GHOSTS := 3 ## Số bóng mờ lúc phóng tới.
const ALLY_GHOST := Color(0.55, 0.85, 1.0, 0.55)
const ENEMY_GHOST := Color(1.0, 0.45, 0.4, 0.55)
const HURT_WHITE_SEC := 0.04 ## Nháy trắng ~2 khung (kéo dài suốt hitstop) rồi mới sang đỏ.
const HURT_RED := Color("ff4a3a")
const WARN_RED := Color("ff2a1a")
const REVIVE_GOLD := Color("ffd36b")

static var _blink_cache := {} ## Texture gốc -> texture mắt nhắm.
static var _color_cache := {} ## Texture gốc -> màu chủ đạo (màu "nước ép" khi trúng đòn).

var fx_layer: Control ## Lớp hiệu ứng của BattleView (bụi, vỡ hạt, "!"); BattleView gán khi tạo.
var speed := 1.0 ## 2 khi bật Tốc độ x2.

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
var _flash_mat: ShaderMaterial ## hit_flash.gdshader của sprite (lớp animation con dùng chung).
var _flash_tween: Tween
var _squash_tween: Tween
var _ambient := {} ## "poison" / "burn" -> CPUParticles2D đang chạy.


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
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = HIT_FLASH
	sprite.material = _flash_mat
	_frames = SpriteFrameLayer.attach_to(sprite)
	if _frames != null:
		_frames.use_parent_material = true # động tác tung chiêu cũng nháy theo sprite

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
	var burning := false
	var poisoned := false
	for effect in combatant.statuses:
		if effect is BurnEffect:
			parts.append("Đốt %d" % effect.turns_left)
			burning = true
		elif effect is PoisonEffect:
			parts.append("Độc %d" % effect.turns_left)
			poisoned = true
	status_label.text = " · ".join(parts)
	if not combatant.is_alive() and not _dead:
		play_death()
	elif combatant.is_alive() and _dead:
		play_revive() # Linh hồn đầu bếp.
	_set_ambient("burn", burning and not _dead)
	_set_ambient("poison", poisoned and not _dead)


## Bật / tắt hạt chạy liên tục quanh sprite (than hồng khi bị đốt, bọt xanh khi trúng độc).
func _set_ambient(kind: String, on: bool) -> void:
	if on and not _ambient.has(kind):
		var p := FxParticles.ambient(kind, Vector2(_stage.size.x * 0.55, _stage.size.y * 0.4))
		_stage.add_child(p)
		p.position = Vector2(_stage.size.x / 2.0, _stage.size.y * 0.55)
		_ambient[kind] = p
	elif not on and _ambient.has(kind):
		var p: CPUParticles2D = _ambient[kind]
		_ambient.erase(kind)
		p.emitting = false
		get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free) # hạt đang bay bay nốt rồi mới xoá


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


## Tung đòn: lấy đà (co người, lùi) rồi phóng tới (giãn người, bụi dưới chân, bóng mờ); đầu bếp phát thêm động tác
## của chiêu. Coroutine TRẢ VỀ ĐÚNG LÚC CHẠM để BattleView tính + hiện đòn ngay khoảnh khắc đó; phần lui về chạy
## tiếp phía sau. Chờ bằng timer chứ không chờ tween: tween bị huỷ giữa chừng (vd bị phản đòn) cũng không kẹt trận.
## windup < 0: dùng mặc định theo phe.
func play_attack(direction: float, animation_name := "attack", windup := -1.0) -> void:
	if _dead:
		return
	if windup < 0.0:
		windup = WINDUP_ALLY if combatant.is_ally else WINDUP_ENEMY
	var k := 1.0 / maxf(speed, 0.1)
	_kill_action()
	if _frames != null:
		_frames.play(animation_name)
	_stage.pivot_offset = Vector2(_stage.size.x / 2.0, _stage.size.y)
	var wind := create_tween().set_parallel(true)
	wind.tween_property(sprite, "position", _home + Vector2(-10 * direction, 2), windup * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	wind.tween_property(_stage, "scale", Vector2(0.86, 1.14), windup * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_action_tween = wind
	await get_tree().create_timer(windup * k, false).timeout
	if not is_inside_tree() or _dead:
		return
	_spawn_dust(direction)
	var dash := create_tween().set_parallel(true)
	dash.tween_property(sprite, "position", _home + Vector2(LUNGE * direction, -6), DASH * k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dash.tween_property(_stage, "scale", Vector2(1.2, 0.86), DASH * k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween = dash
	for i in GHOSTS:
		get_tree().create_timer(DASH * k * i / GHOSTS, false).timeout.connect(_spawn_ghost)
	await get_tree().create_timer(DASH * k, false).timeout
	if not is_inside_tree() or _dead:
		return
	var back := create_tween().set_parallel(true)
	back.tween_property(sprite, "position", _home, RETURN * k).set_delay(0.03 * k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(_stage, "scale", Vector2.ONE, 0.18 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_action_tween = back


## Quái báo trước đòn trong `seconds` giây (bài học từ Expedition 33: đòn phải đọc được): chớp đỏ + dấu "!" trên đầu.
func telegraph(seconds: float) -> void:
	if _dead:
		return
	flash(WARN_RED, 0.75, seconds * 0.9 / maxf(speed, 0.1))
	if fx_layer != null:
		var r := sprite.get_global_rect()
		DamageNumber.spawn(fx_layer, Vector2(r.get_center().x, r.position.y + 6.0), "!", DamageNumber.Kind.WARN, 0, 1.0, speed)


## Nháy màu sprite qua shader: hiện `color` ở mức `amount`, giữ `hold` giây rồi tắt dần trong `fade` giây.
func flash(color: Color, amount := 1.0, fade := 0.25, hold := 0.0) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_mat.set_shader_parameter("flash_color", color)
	_set_flash(amount)
	_flash_tween = create_tween()
	if hold > 0.0:
		_flash_tween.tween_interval(hold)
	_flash_tween.tween_method(_set_flash, amount, 0.0, fade)


func _set_flash(value: float) -> void:
	_flash_mat.set_shader_parameter("flash", value)


## Trúng đòn: nháy trắng ~2 khung (đứng hình cùng hitstop) rồi đỏ tắt dần, giật lùi, bẹp người rồi đàn hồi.
## heavy = chí mạng (giật xa hơn, bẹp hơn); bonk = bị muôi gõ lên đầu (bẹp dẹt xuống).
func play_hurt(heavy := false, bonk := false) -> void:
	if _dead:
		return
	var away := -1.0 if combatant.is_ally else 1.0
	var k := 1.0 / maxf(speed, 0.1)
	_kill_action()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_mat.set_shader_parameter("flash_color", Color.WHITE)
	_set_flash(1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_interval(HURT_WHITE_SEC)
	_flash_tween.tween_callback(func() -> void: _flash_mat.set_shader_parameter("flash_color", HURT_RED))
	_flash_tween.tween_method(_set_flash, 0.65, 0.0, 0.28 * k)
	var push := 22.0 if heavy else 12.0
	_action_tween = create_tween()
	_action_tween.tween_property(sprite, "position", _home + Vector2(push * away, 0), 0.06 * k)
	_action_tween.tween_property(sprite, "position", _home, 0.2 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stage.pivot_offset = Vector2(_stage.size.x / 2.0, _stage.size.y)
	_stage.scale = Vector2(1.4, 0.62) if bonk else (Vector2(1.32, 0.7) if heavy else Vector2(1.2, 0.82))
	_squash_tween = create_tween()
	_squash_tween.tween_property(_stage, "scale", Vector2.ONE, 0.2 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Né đòn: nhảy lùi sang bên để lại bóng mờ rồi về chỗ.
func play_dodge() -> void:
	if _dead:
		return
	var away := -1.0 if combatant.is_ally else 1.0
	var k := 1.0 / maxf(speed, 0.1)
	_kill_action()
	_spawn_ghost()
	_action_tween = create_tween()
	_action_tween.tween_property(sprite, "position", _home + Vector2(28 * away, -10), 0.08 * k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_callback(_spawn_ghost)
	_action_tween.tween_property(sprite, "position", _home, 0.22 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Ngã xuống: đổ nghiêng về phía sau, xám và mờ dần.
## Quái: ngã xong thì vỡ thành hạt pixel cùng màu rồi bốc hơi (giữ chỗ để đội hình không xô lệch, không chọn được nữa).
## Phe mình vẫn nằm lại (đầu bếp có thể hồi sinh).
func play_death() -> void:
	_dead = true
	if _idle_tween != null:
		_idle_tween.kill()
	_kill_action()
	_set_ambient("burn", false)
	_set_ambient("poison", false)
	sprite.texture = _blink_texture if _blink_texture != null else _open_texture
	var away := -1.0 if combatant.is_ally else 1.0
	_action_tween = create_tween().set_parallel(true)
	_action_tween.tween_property(sprite, "rotation", deg_to_rad(80) * away, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(sprite, "position", _home + Vector2(16 * away, 14), 0.35)
	_action_tween.tween_property(self, "modulate", Color(0.6, 0.6, 0.6, 0.55), 0.5).set_delay(0.2)
	if not combatant.is_ally:
		mouse_filter = MOUSE_FILTER_IGNORE
		get_tree().create_timer(0.4 / maxf(speed, 0.1), false).timeout.connect(_disintegrate)


## Quái vỡ thành hạt pixel bốc hơi, ô của nó mờ hẳn đi.
func _disintegrate() -> void:
	if not is_inside_tree():
		return
	if fx_layer != null:
		FxParticles.disintegrate(fx_layer, sprite)
	sprite.visible = false
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.3)


## Đứng dậy (Linh hồn đầu bếp hồi sinh): nháy vàng rực.
func play_revive() -> void:
	_dead = false
	_kill_action()
	sprite.texture = _open_texture
	sprite.visible = true
	flash(REVIVE_GOLD, 1.0, 0.5, 0.1)
	_action_tween = create_tween().set_parallel(true)
	_action_tween.tween_property(sprite, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(sprite, "position", _home, 0.3)
	_action_tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	_action_tween.chain().tween_callback(_start_idle)


func _kill_action() -> void:
	if _action_tween != null and _action_tween.is_running():
		_action_tween.kill()
	if _squash_tween != null and _squash_tween.is_running():
		_squash_tween.kill()
	if _frames != null:
		_frames.stop()
	sprite.position = _home
	sprite.modulate = Color.WHITE
	_stage.scale = Vector2.ONE


## Bóng mờ (afterimage) đúng hình đang hiện (kể cả khung động tác tung chiêu), đứng sau sprite rồi tắt dần.
func _spawn_ghost() -> void:
	if not is_inside_tree() or _dead:
		return
	var src: TextureRect = _frames if (_frames != null and _frames.visible) else sprite
	var tex := src.texture
	if tex == null:
		return
	if tex is AtlasTexture:
		tex = tex.duplicate() # giữ đúng khung lúc này
	var ghost := TextureRect.new()
	ghost.texture = tex
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = src.stretch_mode
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.flip_h = src.flip_h
	ghost.mouse_filter = MOUSE_FILTER_IGNORE
	ghost.size = src.size
	ghost.modulate = ALLY_GHOST if combatant.is_ally else ENEMY_GHOST
	_stage.add_child(ghost)
	_stage.move_child(ghost, 0) # đứng sau sprite
	ghost.position = sprite.position + (src.position if src != sprite else Vector2.ZERO)
	var t := ghost.create_tween()
	t.tween_property(ghost, "modulate:a", 0.0, 0.18 / maxf(speed, 0.1))
	t.tween_callback(ghost.queue_free)


## Bụi tung dưới chân, phía sau lưng, lúc bật người lao tới.
func _spawn_dust(direction: float) -> void:
	if fx_layer == null:
		return
	var r := sprite.get_global_rect()
	var at := Vector2(r.get_center().x - direction * r.size.x * 0.22, r.end.y - 14.0)
	HuntFX.play(fx_layer, "dust", at, 2.5, Color.WHITE, speed, 0.0, direction < 0.0)


## Màu chủ đạo của sprite (màu rực xuất hiện nhiều nhất, bỏ viền tối / màu xám), cache theo texture.
## Dùng làm màu "nước ép" bắn ra khi trúng đòn: cà chua đỏ, nấm nâu, cải xanh...
func dominant_color() -> Color:
	var tex := _open_texture
	if tex == null:
		return Color.WHITE
	if _color_cache.has(tex):
		return _color_cache[tex]
	var result := Color("fff4d6")
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var counts := {}
		var best := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a < 0.5 or c.s < 0.3 or c.v < 0.35:
					continue
				var key := Color(snappedf(c.r, 0.125), snappedf(c.g, 0.125), snappedf(c.b, 0.125))
				counts[key] = int(counts.get(key, 0)) + 1
				if counts[key] > best:
					best = counts[key]
					result = c
	_color_cache[tex] = result
	return result


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
