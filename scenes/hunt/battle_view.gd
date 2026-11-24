class_name BattleView
extends Control
## Màn hình trận đánh (S11): sprite, thanh máu, chọn mục tiêu bằng chạm, thứ tự lượt,
## chiêu đầu bếp, số sát thương bay lên, Tự đánh và tốc độ x2.
## Dùng: add_child(view); view.start(session, encounter); chờ signal closed(result).

signal closed(result: BattleController.Result)
signal _action_chosen(choice: Dictionary)

const ORDER_PREVIEW := 7
const ORDER_SLOT := 56 ## Kích thước 1 ô trên thanh lượt.
const BG_SIZE := Vector2(320, 180) ## Kích thước ảnh nền khu săn (px ảnh).
const GROUND_FEET_Y := 110.0 ## Hàng px của ảnh nền nơi chân nhân vật đứng: giữa dải cỏ (cỏ nằm ở y 98-127).
const ORDER_BIG := 68 ## Ô của người đang đánh (to hơn).
const ORDER_GAP := 6
const ORDER_ARROW := 28 ## Chỗ cho dấu » sau ô đang đánh.
const ORDER_SLIDE := 0.28 ## Thời gian trượt 1 ô (giây).
const SFX_DIR := "res://assets/audio/sfx/"
const TELEGRAPH := 0.18 ## Giây quái báo trước đòn (lấy bớt từ action_delay nên nhịp trận không chậm đi).
const TELEGRAPH_BOSS := 0.26

## Cấp độ cú đánh (theo skill game-feel), thứ tự từ nhẹ tới nặng: một bước lấy cấp mạnh nhất.
enum Tier { NONE, DOT, LIGHT, MEDIUM, KILL, HEAVY, EPIC }
## Tier -> [hitstop (giây thật), trauma rung màn, số hạt nước ép / tia lửa]
const TIER_SPEC := {
	Tier.DOT: [0.0, 0.0, 4], ## Độc / đốt đầu lượt: không đứng hình, không rung.
	Tier.LIGHT: [0.04, 0.12, 6], ## Đánh thường.
	Tier.MEDIUM: [0.07, 0.3, 12], ## Cắt thái, Hất lẩu, trúng vụ nổ.
	Tier.KILL: [0.12, 0.45, 14], ## Hạ một quái.
	Tier.HEAVY: [0.12, 0.55, 20], ## Chí mạng (+ zoom vào mục tiêu).
	Tier.EPIC: [0.15, 1.0, 40], ## Boss gục / bò tót nổ (+ impact frame).
}

var session: HuntSession
var encounter: Encounter
var controller: BattleController
var views := {} ## Combatant -> CombatantView
var selected_target: Combatant
var auto_mode := false
var fast_mode := false
var _waiting_input := false
var _timed_out := false
var _log_index := 0

var _allies_box: HBoxContainer
var _enemies_box: HBoxContainer
var _order_box: Control ## Thanh lượt: các ô đặt tay để trượt mượt.
var _order_slots: Array[Dictionary] = [] ## {c: Combatant, node: PanelContainer}
var _order_arrow: Label
var _order_current: Combatant ## Người đang/vừa đánh, giữ ở ô đầu tới lượt sau.
var _turn_label: Label
var _skill_buttons: Array[Button] = []
var _flee_button: Button
var _auto_button: Button
var _fast_button: Button
var _float_layer: Control
var _juice: BattleJuice ## Hitstop, rung màn, zoom, impact frame của trận.
var _backdrop: TextureRect
var _arena: Control
var _arena_row: HBoxContainer ## Hàng phe ta - VS - quái, đặt sao cho chân đứng trên cỏ.
var timer_label: Label


func start(p_session: HuntSession, p_encounter: Encounter) -> void:
	session = p_session
	encounter = p_encounter
	controller = BattleController.new(session.allies(), encounter.create_enemies(), session.player, session.config)
	_build()
	for c in controller.battle.allies:
		_add_view(c)
	for c in controller.battle.enemies:
		_add_view(c)
	selected_target = controller.default_target()
	controller.battle.add_log("Trận bắt đầu! Thanh \"Lượt tiếp\" cho biết ai sẽ hành động trước.")
	GameMusic.set_battle(true)
	_sfx("boss" if encounter.is_boss else "battle_start")
	_refresh_all()
	_flush_log()
	_run()


func _process(_delta: float) -> void:
	if timer_label != null:
		timer_label.visible = DayManager.timer_running and get_tree().get_first_node_in_group("hud") == null
		timer_label.text = "Còn lại " + DayManager.time_left_text()


## Gọi khi hết giờ săn giữa trận.
func time_out() -> void:
	_timed_out = true
	if _waiting_input:
		_action_chosen.emit({"timeout": true})


# --- Vòng lặp lượt ----------------------------------------------------------

func _run() -> void:
	await _intro_banner()
	while not controller.is_finished() and not _timed_out:
		var before := controller.snapshot()
		var actor := controller.begin_turn()
		if actor == null:
			break
		await _show_changes(before) # độc / đốt đầu lượt
		if not controller.can_act(actor) or _timed_out:
			continue
		_set_acting(actor)
		_update_order(actor)
		var skill: ChefSkill = null
		var strike_secs := 0.0 ## Thời gian lấy đà + phóng tới (quy về tốc độ x1), trừ vào khoảng nghỉ sau đòn.
		# Mọi đòn: người đánh lấy đà + phóng tới, TỚI LÚC CHẠM mới tính đòn rồi hiện ngay (số, nháy, hitstop...).
		if controller.is_player(actor) and not auto_mode:
			var choice: Dictionary = await _wait_player()
			if choice.has("timeout"):
				break
			if choice.has("flee"):
				controller.flee()
				break
			skill = controller.auto_skill() if choice.has("auto") else choice.skill
			before = controller.snapshot()
			var t0 := Time.get_ticks_msec()
			await _strike(actor, skill)
			strike_secs = (Time.get_ticks_msec() - t0) / 1000.0 * _speed()
			if choice.has("auto"):
				controller.ai_action(actor)
			else:
				controller.player_action(skill, selected_target)
		else:
			# Quái báo trước đòn; thời gian báo lấy từ action_delay nên nhịp trận (và giờ săn) không chậm đi.
			var telegraph := 0.0
			if not actor.is_ally:
				telegraph = TELEGRAPH_BOSS if _is_boss(actor) else TELEGRAPH
			await _wait(maxf(0.0, session.config.action_delay - telegraph))
			if _timed_out:
				break
			if controller.is_player(actor):
				skill = controller.auto_skill()
			before = controller.snapshot()
			if telegraph > 0.0:
				await _telegraph(actor, telegraph)
			var t0 := Time.get_ticks_msec()
			await _strike(actor, skill)
			strike_secs = (Time.get_ticks_msec() - t0) / 1000.0 * _speed()
			controller.ai_action(actor)
		await _show_changes(before, actor, skill)
		# Nghỉ giữa 2 lượt: bớt đi thời gian vừa lấy đà / phóng tới để nhịp trận (và giờ săn) như trước khi có hiệu ứng.
		await _wait(maxf(0.05, session.config.action_delay * 0.5 - strike_secs))
	if _timed_out and controller.result == BattleController.Result.NONE:
		controller.time_out()
	_set_acting(null)
	_flush_log()
	_set_actions_enabled(false)
	_finish()


func _wait_player() -> Dictionary:
	_turn_label.text = "Lượt của bạn: chạm vào quái để chọn mục tiêu, rồi chọn chiêu"
	_ensure_target()
	_set_actions_enabled(true)
	_waiting_input = true
	var choice: Dictionary = await _action_chosen
	_waiting_input = false
	_set_actions_enabled(false)
	_turn_label.text = ""
	return choice


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds / (2.0 if fast_mode else 1.0), false).timeout


# --- Hiệu ứng ---------------------------------------------------------------

## So trạng thái trước / sau một bước, hiện mọi phản hồi cùng lúc (đúng khoảnh khắc chạm): số sát thương / hồi máu /
## giáp bằng chữ pixel, nháy + bẹp người, hiệu ứng theo chiêu, chữ báo nội tại; rồi "juice" theo cấp độ mạnh nhất
## của bước (hitstop, rung, zoom, impact frame, quay chậm cú kết liễu cuối). attacker = null: đầu lượt (độc / đốt).
func _show_changes(before: Dictionary, attacker: Combatant = null, skill: ChefSkill = null) -> void:
	var tier := Tier.NONE
	var hurt := false
	var crit_target: Combatant = null
	var died := false
	var epic := false
	var last_down: Combatant = null
	var stacks := {} ## Combatant -> số chữ đã hiện trên đầu trong bước này (để xếp chồng)
	var new_lines := controller.battle.log_lines.slice(_log_index)
	var all_text := "\n".join(new_lines)
	for c in controller.battle.all_combatants():
		if not views.has(c):
			_add_view(c) # Đơn vị mới sinh (nấm con).
			_sfx("spawn")
			_number(c, "XUẤT HIỆN!", DamageNumber.Kind.CALLOUT, stacks)
			_fx(c, "smoke", 1.2)
			continue
		var prev: Dictionary = before.get(c, {})
		if prev.is_empty():
			continue
		var view: CombatantView = views[c]
		var dhp: int = c.hp - int(prev.hp)
		var darmor: int = c.armor - int(prev.armor)
		if dhp < 0:
			var crit := c in controller.crits
			var opposing := attacker != null and attacker.is_ally != c.is_ally
			view.play_hurt(crit, opposing and skill is BasicAttackSkill)
			hurt = true
			tier = maxi(tier, _fx_for_damage(c, new_lines, all_text, attacker if opposing else null, skill, crit))
			if crit:
				crit_target = c
				_number(c, "-%d" % -dhp, DamageNumber.Kind.CRIT, stacks)
				_number(c, "CHÍ MẠNG!", DamageNumber.Kind.CALLOUT, stacks)
			else:
				_number(c, "-%d" % -dhp, DamageNumber.Kind.DAMAGE, stacks)
		elif dhp > 0:
			_number(c, "+%d" % dhp, DamageNumber.Kind.HEAL, stacks)
			_fx(c, "heal")
			_sfx("heal", -4.0)
		if darmor > 0:
			_number(c, "+%d GIÁP" % darmor, DamageNumber.Kind.ARMOR, stacks)
			_fx(c, "shield")
			_sfx("shield", -4.0)
		if prev.alive and not c.is_alive():
			died = true
			last_down = c
			tier = maxi(tier, Tier.KILL)
			if c.data != null and c.data.id == "mad_bull":
				epic = true
				_fx(c, "explosion_big")
				_number(c, "PHÁT NỔ!", DamageNumber.Kind.WARN, stacks)
			elif c.data != null and c.data.is_boss:
				epic = true
				_fx(c, "explosion_fire", 3.0)
			else:
				_fx(c, "smoke")
			if epic:
				_fx(c, "shockwave", 4.5)
	_callouts(new_lines, stacks)
	if epic:
		tier = Tier.EPIC
	# Độc / đốt đầu lượt có tiếng riêng.
	if " bị đốt:" in all_text:
		_sfx("burn", -4.0)
	if " trúng độc:" in all_text:
		_sfx("poison", -4.0)
	if epic:
		_sfx("explosion")
	elif died:
		_sfx("defeat")
	elif crit_target != null:
		_sfx("crit")
	elif hurt:
		_sfx("hit")
	_flush_log()
	_refresh_all()
	_apply_tier(tier, crit_target)
	# Cú kết liễu cuối trận: quay chậm + zoom vào quái vừa gục.
	if died and controller.is_finished() and controller.battle.allies_won() and views.has(last_down):
		_juice.slow_mo(0.3, 0.45)
		_juice.punch_zoom((views[last_down] as CombatantView).sprite.get_global_rect().get_center(), 1.08, 0.55)
	await _wait(0.25)


## "Juice" theo cấp độ mạnh nhất của bước (bảng TIER_SPEC): rung, impact frame, zoom vào mục tiêu chí mạng, hitstop.
## Hitstop gọi sau cùng để đứng hình đúng tư thế vừa chạm (nháy trắng, bẹp người).
func _apply_tier(tier: int, crit_target: Combatant) -> void:
	if not TIER_SPEC.has(tier):
		return
	var spec: Array = TIER_SPEC[tier]
	_juice.add_trauma(spec[1])
	if tier == Tier.EPIC:
		_juice.impact_frame()
	if crit_target != null and views.has(crit_target):
		_juice.punch_zoom((views[crit_target] as CombatantView).sprite.get_global_rect().get_center(), 1.06, 0.3)
	_juice.hit_stop(spec[0])


## Chữ báo nội tại đọc từ nhật ký trận: NÉ!, CUỒNG NỘ!, HỒI SINH!, NGỦ GẬT!
func _callouts(lines: Array, stacks: Dictionary) -> void:
	for line in lines:
		var l: String = line
		for c in controller.battle.all_combatants():
			var view: CombatantView = views.get(c)
			if view == null:
				continue
			var n := c.display_name
			if l.begins_with(n + " nhảy né"):
				_number(c, "NÉ!", DamageNumber.Kind.CALLOUT, stacks)
				view.play_dodge()
				_sfx("dodge")
			elif l.begins_with(n + " nổi cơn cuồng nộ") or l.begins_with(n + " cay xé lưỡi"):
				_number(c, "CUỒNG NỘ!", DamageNumber.Kind.WARN, stacks)
				view.flash(Color("ff3a2a"), 0.8, 0.45)
				FxParticles.burst(_float_layer, view.sprite.get_global_rect().get_center(), Color("ff4a3a"), 14, Vector2.UP, 80.0, Vector2(80, 200), -200.0, 0.6)
			elif l.begins_with("Linh hồn đầu bếp") and (n + " hồi") in l:
				_number(c, "HỒI SINH!", DamageNumber.Kind.CRIT, stacks)
				FxParticles.burst(_float_layer, view.sprite.get_global_rect().get_center(), Color("ffd36b"), 24, Vector2.UP, 70.0, Vector2(80, 240), -260.0, 0.8)
			elif (": " + n + " ngủ gật") in l:
				_number(c, "NGỦ GẬT!", DamageNumber.Kind.CALLOUT, stacks)


## Chọn hiệu ứng theo nguyên nhân mất máu (đọc từ nhật ký trận của bước vừa rồi) và trả về cấp độ cú đánh.
## attacker: người đánh phe đối diện (null = độc / đốt / phản đòn). Mọi đòn trực tiếp bắn "nước ép" cùng màu mục tiêu.
func _fx_for_damage(c: Combatant, lines: Array, all_text: String, attacker: Combatant, skill: ChefSkill, crit: bool) -> int:
	var name := c.display_name
	var center := (views[c] as CombatantView).sprite.get_global_rect().get_center()
	for line in lines:
		var l: String = line
		if l.begins_with(name + " bị đốt"):
			_fx(c, "flame")
			return Tier.DOT
		if l.begins_with(name + " trúng độc"):
			_fx(c, "poison")
			return Tier.DOT
		if l.strip_edges().begins_with(name + " bị bỏng"):
			_fx(c, "splash_broth")
			_steam(center)
			return Tier.LIGHT
	var tier := Tier.LIGHT
	var hit := _contact_point(c, attacker)
	if not c.is_ally and "hất nồi lẩu" in all_text:
		_fx(c, "splash_broth")
		_steam(center)
		tier = Tier.MEDIUM
	elif "phát nổ" in all_text and not (c.data != null and c.data.id == "mad_bull"):
		_fx(c, "burst", 2.0)
		tier = Tier.MEDIUM
	elif attacker != null and skill is SliceSkill:
		_slice_fx(center)
		tier = Tier.MEDIUM
	elif attacker != null and skill is BasicAttackSkill:
		HuntFX.play(_float_layer, "impact_star", hit, 3.0, Color.WHITE, _speed())
		_bonk_stars(c)
	elif attacker != null and not attacker.is_ally:
		var tint := (views[attacker] as CombatantView).dominant_color().lerp(Color.WHITE, 0.5) if views.has(attacker) else Color.WHITE
		HuntFX.play(_float_layer, "impact_star", hit, 3.0, tint, _speed())
	else:
		_fx(c, "slash")
	if crit:
		_fx(c, "burst")
		HuntFX.play(_float_layer, "shockwave", center, 3.0, Color.WHITE, _speed())
		tier = Tier.HEAVY
	var juice := Color("fff4d6") if c.is_ally else (views[c] as CombatantView).dominant_color()
	var away := 1.0 if attacker == null or attacker.is_ally else -1.0
	FxParticles.burst(_float_layer, hit, juice, int(TIER_SPEC[tier][2]), Vector2(away, -0.7), 55.0, Vector2(160, 320), 900.0, 0.45)
	return tier


## Điểm chạm: mép thân mục tiêu phía người đánh.
func _contact_point(c: Combatant, attacker: Combatant) -> Vector2:
	var r := (views[c] as CombatantView).sprite.get_global_rect()
	var side := 0.0 if attacker == null else (-1.0 if attacker.is_ally else 1.0)
	return r.get_center() + Vector2(side * r.size.x * 0.22, -r.size.y * 0.05)


## Cắt thái: 2 vệt smear chéo thành chữ X (cách nhau 0,05 s) + đường chém trắng vụt qua.
func _slice_fx(center: Vector2) -> void:
	HuntFX.play(_float_layer, "slash_arc", center, 3.2, Color.WHITE, _speed(), deg_to_rad(-35.0))
	get_tree().create_timer(0.05 / _speed(), false).timeout.connect(func() -> void:
		if is_inside_tree():
			HuntFX.play(_float_layer, "slash_arc", center, 3.2, Color.WHITE, _speed(), deg_to_rad(35.0), true))
	var line := Line2D.new()
	line.points = PackedVector2Array([center + Vector2(-80, -52), center + Vector2(80, 52)])
	line.width = 12.0
	line.default_color = Color.WHITE
	_float_layer.add_child(line)
	var t := line.create_tween()
	t.tween_property(line, "width", 0.0, 0.14 / _speed()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(line.queue_free)
	FxParticles.burst(_float_layer, center, Color("bff6ff"), 10, Vector2(1, 0.65), 25.0, Vector2(200, 380), 300.0, 0.35, Vector2(4, 4))


## Muôi gõ đầu: 3 ngôi sao lấp lánh xoay vòng elip quanh đầu mục tiêu.
func _bonk_stars(c: Combatant) -> void:
	var r := (views[c] as CombatantView).sprite.get_global_rect()
	var ring := Node2D.new()
	_float_layer.add_child(ring)
	ring.global_position = Vector2(r.get_center().x, r.position.y + r.size.y * 0.18)
	var stars: Array[Sprite2D] = []
	for i in 3:
		var s := HuntFX.sprite("bonk_star", 2.5)
		ring.add_child(s)
		stars.append(s)
	var t := ring.create_tween()
	t.tween_method(func(u: float) -> void:
		for i in stars.size():
			var a := u * TAU * 1.5 + TAU * i / stars.size()
			stars[i].position = Vector2(cos(a) * 34.0, sin(a) * 10.0).round()
			stars[i].frame = (int(u * 14.0) + i) % 4
			stars[i].z_index = 1 if sin(a) > 0.0 else -1, 0.0, 1.0, 0.55 / _speed())
	t.tween_callback(ring.queue_free)


## Hơi nước trắng bốc lên (nước lẩu nóng).
func _steam(at: Vector2) -> void:
	FxParticles.burst(_float_layer, at + Vector2(0, -20), Color(1, 1, 1, 0.85), 8, Vector2.UP, 35.0, Vector2(40, 100), -80.0, 0.8, Vector2(6, 10))


func _fx(c: Combatant, fx_name: String, scale := -1.0, tint := Color.WHITE) -> void:
	var view: CombatantView = views.get(c)
	if view == null:
		return
	var rect := view.sprite.get_global_rect()
	HuntFX.play(_float_layer, fx_name, rect.get_center(), scale, tint, 2.0 if fast_mode else 1.0)


## Số / chữ pixel bật ra trên đầu đơn vị; nhiều chữ trong cùng một bước thì xếp chồng lên nhau.
func _number(c: Combatant, text: String, kind: DamageNumber.Kind, stacks: Dictionary) -> void:
	var view: CombatantView = views.get(c)
	if view == null:
		return
	var r := view.sprite.get_global_rect()
	var index: int = stacks.get(c, 0)
	stacks[c] = index + 1
	DamageNumber.spawn(_float_layer, Vector2(r.get_center().x, r.position.y + r.size.y * 0.25), text, kind, index, -1.0 if c.is_ally else 1.0, _speed())


func _speed() -> float:
	return 2.0 if fast_mode else 1.0


func _is_boss(c: Combatant) -> bool:
	return c.data != null and c.data.is_boss


func _sfx(sound: String, db := 0.0) -> void:
	var path := SFX_DIR + sound + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = db
	player.pitch_scale = randf_range(0.92, 1.08)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _play_skill_sfx(skill: ChefSkill) -> void:
	if skill is HotSplashSkill:
		_sfx("splash")
	elif skill is SliceSkill:
		_sfx("slice")
	else:
		_sfx("swing") # Đánh thường: tiếng vung muôi.


## Người đánh lấy đà rồi phóng tới; trả về lúc chạm (đòn được tính và hiện ngay sau đó).
## Hất lẩu: chạm = lúc hất nồi, chờ thêm giọt lẩu bay tới quái rồi mới tính đòn.
func _strike(actor: Combatant, skill: ChefSkill) -> void:
	if controller.is_player(actor):
		_play_skill_sfx(skill)
	else:
		_sfx("swing", -6.0)
	var view: CombatantView = views.get(actor)
	if view == null:
		return
	var anim := _skill_animation(skill) if controller.is_player(actor) else "attack"
	await view.play_attack(1.0 if actor.is_ally else -1.0, anim)
	if skill is HotSplashSkill:
		await _throw_broth(actor)


## Quái báo trước đòn (chớp đỏ + "!"); boss tối viền màn.
func _telegraph(actor: Combatant, seconds: float) -> void:
	var view: CombatantView = views.get(actor)
	if view == null:
		return
	view.telegraph(seconds)
	if _is_boss(actor):
		_juice.vignette(0.6, seconds + 0.25)
	await _wait(seconds)


## Hất lẩu: mỗi quái một giọt nước lẩu bay vòng cung từ đầu bếp tới (lệch nhịp nhau), chờ tới giọt cuối.
func _throw_broth(actor: Combatant) -> void:
	var from_view: CombatantView = views.get(actor)
	if from_view == null:
		return
	var start := from_view.sprite.get_global_rect().get_center() + Vector2(30, -12)
	var flight := 0.2 / _speed()
	var gap := 0.04 / _speed()
	var count := 0
	for e in controller.battle.alive(controller.battle.enemies):
		var view: CombatantView = views.get(e)
		if view == null:
			continue
		var target := view.sprite.get_global_rect().get_center()
		var blob := HuntFX.sprite("broth_blob", 4.0)
		_float_layer.add_child(blob)
		blob.global_position = start
		var t := blob.create_tween()
		t.tween_interval(gap * count)
		t.tween_method(func(u: float) -> void:
			blob.global_position = start.lerp(target, u) + Vector2(0, -110.0 * 4.0 * u * (1.0 - u))
			blob.frame = int(u * 8.0) % 2, 0.0, 1.0, flight)
		t.tween_callback(blob.queue_free)
		count += 1
	if count > 0:
		await get_tree().create_timer(flight + gap * (count - 1), false).timeout


## Mở màn: dải chéo trượt ngang qua màn với "BẮT ĐẦU!" (boss: "BOSS!" + tên boss); chạm để bỏ qua.
func _intro_banner() -> void:
	var boss := encounter.is_boss
	var k := 1.0 / _speed()
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	holder.mouse_filter = MOUSE_FILTER_STOP
	add_child(holder)
	var band := ColorRect.new()
	band.color = Color(0.3, 0.03, 0.03, 0.88) if boss else Color(0.1, 0.05, 0.03, 0.85)
	band.size = Vector2(size.x * 1.6, 168.0 if boss else 128.0)
	band.pivot_offset = band.size / 2.0
	band.rotation = deg_to_rad(-4.0)
	band.mouse_filter = MOUSE_FILTER_IGNORE
	holder.add_child(band)
	for edge_y in [0.0, band.size.y - 6.0]: # viền trên / dưới của dải
		var edge := ColorRect.new()
		edge.color = HuntUI.BAD if boss else HuntUI.GOLD
		edge.size = Vector2(band.size.x, 6.0)
		edge.position = Vector2(0, edge_y)
		edge.mouse_filter = MOUSE_FILTER_IGNORE
		band.add_child(edge)
	var title := Label.new()
	title.text = "BOSS!" if boss else "BẮT ĐẦU!"
	PixelTitle.apply_label(title, "game_over" if boss else "noon", 5 if boss else 4)
	title.mouse_filter = MOUSE_FILTER_IGNORE
	holder.add_child(title)
	title.size = title.get_minimum_size()
	var sub: Label = null
	if boss:
		sub = Label.new()
		sub.text = encounter.names()
		PixelTitle.apply_label(sub, "white", 2)
		sub.mouse_filter = MOUSE_FILTER_IGNORE
		holder.add_child(sub)
		sub.size = sub.get_minimum_size()
	var cy := size.y * 0.42
	band.position = Vector2(-band.size.x, cy - band.size.y / 2.0)
	var title_y := cy - title.size.y / 2.0 - (22.0 if boss else 0.0)
	title.position = Vector2(-title.size.x, title_y)
	if sub != null:
		sub.position = Vector2(size.x, title_y + title.size.y - 8.0)
	var t := holder.create_tween()
	t.set_parallel(true)
	t.tween_property(band, "position:x", (size.x - band.size.x) / 2.0, 0.18 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(title, "position:x", (size.x - title.size.x) / 2.0, 0.24 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if sub != null:
		t.tween_property(sub, "position:x", (size.x - sub.size.x) / 2.0, 0.26 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval((0.45 if boss else 0.25) * k)
	t.chain().tween_property(band, "position:x", size.x, 0.18 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(title, "position:x", size.x + 40.0, 0.16 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if sub != null:
		t.parallel().tween_property(sub, "position:x", -sub.size.x - 40.0, 0.16 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(holder.queue_free)
	holder.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
			t.kill()
			holder.queue_free())
	while is_instance_valid(holder) and not holder.is_queued_for_deletion():
		await get_tree().process_frame


## Động tác của đầu bếp ứng với từng chiêu.
func _skill_animation(skill: ChefSkill) -> String:
	if skill is HotSplashSkill:
		return "splash"
	if skill is SliceSkill:
		return "slice"
	return "attack"


# --- Chọn mục tiêu / hành động ---------------------------------------------

func _on_view_tapped(view: CombatantView) -> void:
	if view.combatant.is_ally or not view.combatant.is_alive():
		return
	selected_target = view.combatant
	_refresh_selection()


func _ensure_target() -> void:
	if selected_target == null or not selected_target.is_alive():
		selected_target = controller.default_target()
	_refresh_selection()


func _on_skill_pressed(index: int) -> void:
	if _waiting_input:
		_action_chosen.emit({"skill": controller.skills[index]})


func _on_flee_pressed() -> void:
	if _waiting_input:
		_action_chosen.emit({"flee": true})


func _on_auto_toggled(on: bool) -> void:
	auto_mode = on
	_auto_button.text = "Tự đánh: Bật" if on else "Tự đánh: Tắt"
	if on and _waiting_input:
		_action_chosen.emit({"auto": true})


func _on_fast_toggled(on: bool) -> void:
	fast_mode = on
	_fast_button.text = "Tốc độ x2" if on else "Tốc độ x1"
	if _juice != null:
		_juice.speed = _speed()
	for v in views.values():
		(v as CombatantView).speed = _speed()


func _set_actions_enabled(enabled: bool) -> void:
	for i in _skill_buttons.size():
		var skill := controller.skills[i]
		var b := _skill_buttons[i]
		b.disabled = not enabled or not skill.is_ready()
		if skill.is_ready():
			b.text = "%s\n%s" % [skill.display_name, skill.description]
		else:
			b.text = "%s\n(chờ %d lượt)" % [skill.display_name, skill.cooldown_left]
	_flee_button.disabled = not enabled


# --- Kết thúc ---------------------------------------------------------------

func _finish() -> void:
	var drops := session.finish_battle(controller, encounter)
	var result := controller.result
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_panel", 8, Vector2(28, 22)))
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	HuntUI.book_open(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	var title := ""
	var palette := "noon" ## Bảng màu chữ pixel PixelTitle của tiêu đề.
	match result:
		BattleController.Result.WIN:
			title = "THẮNG!"
			palette = "noon"
		BattleController.Result.LOSE:
			title = "ĐẦU BẾP GỤC NGÃ..."
			palette = "game_over"
		BattleController.Result.FLED:
			title = "ĐÃ BỎ CHẠY"
			palette = "shop"
		BattleController.Result.TIMEOUT:
			title = "HẾT GIỜ SĂN!"
			palette = "morning"
	var t := Label.new()
	t.text = title
	PixelTitle.apply_label(t, palette, 3 if title.length() <= 10 else 2)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	match result:
		BattleController.Result.WIN:
			_sfx("victory", -2.0)
		BattleController.Result.LOSE:
			_sfx("lose")
		BattleController.Result.FLED:
			_sfx("flee")
		BattleController.Result.TIMEOUT:
			_sfx("wrong")
	if result == BattleController.Result.WIN:
		get_tree().create_timer(0.9).timeout.connect(func() -> void:
			if is_inside_tree():
				_sfx("loot"))
		box.add_child(HuntUI.label("Nhận được:", HuntUI.FONT))
		var row := HuntUI.items_row(drops, 48)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(row)
		var names := HuntUI.label(HuntUI.describe_items(drops), HuntUI.FONT_SMALL, HuntUI.INK_SOFT)
		names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		names.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(names)
		if session.streak >= 2:
			var s := HuntUI.label("Chuỗi thắng %d trận: +%d%% tỷ lệ rơi" % [session.streak, roundi(minf(session.config.streak_bonus_per_win * session.streak, session.config.streak_bonus_max) * 100)], HuntUI.FONT_SMALL, HuntUI.GOLDEN_INK)
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(s)
	elif result == BattleController.Result.LOSE:
		var l := HuntUI.label("Không còn sức săn tiếp. Hãy về bếp nấu lẩu.", HuntUI.FONT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	elif result == BattleController.Result.FLED:
		box.add_child(HuntUI.label("Không có đồ rơi, mất chuỗi thắng.", HuntUI.FONT))
	var next := HuntUI.button("Về bếp nấu lẩu »" if result == BattleController.Result.TIMEOUT else "Tiếp tục »", 280)
	next.pressed.connect(func(): closed.emit(result))
	box.add_child(next)


# --- Dựng UI ----------------------------------------------------------------

func _build() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_backdrop = HuntUI.background()
	add_child(_backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# Thanh trên: tên trận, đồng hồ, Tự đánh, x2.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var title := HuntUI.outlined_label(("BOSS: " if encounter.is_boss else "Gặp: ") + encounter.names(), 26, HuntUI.GOLD)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(title)
	timer_label = HuntUI.outlined_label("", 24, HuntUI.GOLD)
	top.add_child(timer_label)
	_auto_button = HuntUI.button("Tự đánh: Tắt", 190)
	_auto_button.toggle_mode = true
	_auto_button.toggled.connect(_on_auto_toggled)
	top.add_child(_auto_button)
	_fast_button = HuntUI.button("Tốc độ x1", 160)
	_fast_button.toggle_mode = true
	_fast_button.toggled.connect(_on_fast_toggled)
	top.add_child(_fast_button)

	# Đấu trường: phe ta bên trái, quái bên phải.
	_arena = Control.new()
	_arena.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(_arena)
	_arena_row = HBoxContainer.new()
	_arena_row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_arena_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_arena.add_child(_arena_row)
	resized.connect(_snap_arena_to_ground)
	_arena.resized.connect(_snap_arena_to_ground)
	_allies_box = HBoxContainer.new()
	_allies_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_allies_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_allies_box.add_theme_constant_override("separation", 8)
	_arena_row.add_child(_allies_box)
	var vs := HuntUI.outlined_label("VS", 36, Color(1, 1, 1, 0.7))
	vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs.size_flags_vertical = SIZE_SHRINK_END # nằm ngang tầm thân nhân vật, không trôi lên giữa đấu trường
	vs.custom_minimum_size.y = 190
	_arena_row.add_child(vs)
	_enemies_box = HBoxContainer.new()
	_enemies_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemies_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_enemies_box.add_theme_constant_override("separation", 8)
	_arena_row.add_child(_enemies_box)

	# Thứ tự lượt.
	var order_panel := PanelContainer.new()
	order_panel.add_theme_stylebox_override("panel", HuntUI.paper_style("paper_panel", 8, Vector2(18, 10)))
	root.add_child(order_panel)
	HuntUI.pop_in(order_panel, 0.1)
	var order_row := HBoxContainer.new()
	order_row.add_theme_constant_override("separation", 8)
	order_panel.add_child(order_row)
	order_row.add_child(HuntUI.label("Lượt tiếp:", HuntUI.FONT_SMALL))
	_order_box = Control.new()
	_order_box.custom_minimum_size = Vector2(ORDER_BIG + ORDER_ARROW + (ORDER_PREVIEW - 1) * (ORDER_SLOT + ORDER_GAP), ORDER_BIG)
	order_row.add_child(_order_box)
	_order_arrow = HuntUI.label("»", 24)
	_order_arrow.position = Vector2(ORDER_BIG + 3, (ORDER_BIG - 34) / 2.0)
	_order_box.add_child(_order_arrow)
	_turn_label = HuntUI.label("", HuntUI.FONT_SMALL, HuntUI.RUST)
	_turn_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	order_row.add_child(_turn_label)

	# Hành động: 1 hàng nút căn giữa dưới đấu trường (bỏ bảng nhật ký trận, hiệu ứng số máu đã đủ thông tin).
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	root.add_child(actions)
	HuntUI.pop_in(actions, 0.15)
	for i in controller.skills.size():
		var b := HuntUI.button(controller.skills[i].display_name, 230)
		b.custom_minimum_size.y = 70
		b.add_theme_font_size_override("font_size", HuntUI.FONT_SMALL)
		b.pressed.connect(_on_skill_pressed.bind(i))
		actions.add_child(b)
		_skill_buttons.append(b)
	_flee_button = HuntUI.button("Bỏ chạy\n(mất đồ rơi)", 230)
	_flee_button.custom_minimum_size.y = 70
	_flee_button.add_theme_font_size_override("font_size", HuntUI.FONT_SMALL)
	_flee_button.pressed.connect(_on_flee_pressed)
	actions.add_child(_flee_button)
	_set_actions_enabled(false)

	_float_layer = Control.new()
	_float_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_float_layer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_float_layer)

	_juice = BattleJuice.new()
	add_child(_juice)
	_juice.setup(_arena, _backdrop, self)
	_juice.speed = _speed()


## Đặt hàng nhân vật sao cho chân đứng trên mặt cỏ của ảnh nền, ở mọi tỉ lệ màn hình.
## Ảnh nền phủ kín màn kiểu "cover" (co theo cạnh dài hơn rồi cắt đều hai bên) nên:
## scale = max(rộng / 320, cao / 180); y_màn = y_ảnh × scale − phần cắt phía trên.
## Chân nằm ở đáy khung sprite; phần dưới đó (thanh máu...) đo trực tiếp. Không đủ chỗ thì chân dịch lên sát
## thanh lượt (vẫn trên cỏ vì thanh lượt nằm ngay dưới đấu trường).
func _snap_arena_to_ground() -> void:
	if views.is_empty() or _arena == null or not is_inside_tree():
		return
	var scale := maxf(size.x / BG_SIZE.x, size.y / BG_SIZE.y)
	var crop_top := (BG_SIZE.y * scale - size.y) / 2.0
	var feet_y := GROUND_FEET_Y * scale - crop_top - (_arena.global_position.y - global_position.y) # toạ độ trong đấu trường
	var view: CombatantView = views.values()[0]
	var feet_box := view.sprite.get_parent() as Control # khung sprite, đáy khung là chỗ chân đứng
	var below_feet := view.get_global_rect().end.y - feet_box.get_global_rect().end.y
	var row_bottom := minf(feet_y + below_feet, _arena.size.y)
	_arena_row.offset_bottom = row_bottom - _arena.size.y


func _add_view(c: Combatant) -> void:
	var view := CombatantView.new()
	view.fx_layer = _float_layer
	view.speed = _speed()
	view.size_flags_vertical = SIZE_SHRINK_END # căn đáy: tên 1 dòng hay 2 dòng thì chân vẫn thẳng hàng
	if c.is_ally:
		_allies_box.add_child(view)
	else:
		_enemies_box.add_child(view)
	view.setup(c)
	view.tapped.connect(_on_view_tapped)
	views[c] = view
	HuntUI.pop_in(view, 0.05 * views.size())
	_snap_arena_to_ground.call_deferred()


func _refresh_all() -> void:
	for c in views:
		views[c].refresh()
	_refresh_selection()
	# Thanh lượt chỉ trượt khi sang lượt mới; ở đây chỉ dựng lần đầu hoặc khi có ai bị hạ.
	var someone_down := false
	for slot in _order_slots:
		if not (slot["c"] as Combatant).is_alive():
			someone_down = true
	if _order_slots.is_empty() or someone_down:
		_update_order(_order_current)


func _refresh_selection() -> void:
	if selected_target != null and not selected_target.is_alive():
		selected_target = controller.default_target()
	for c in views:
		views[c].set_selected(c == selected_target)


func _set_acting(actor: Combatant) -> void:
	for c in views:
		views[c].set_acting(c == actor)


## Thanh thứ tự lượt: người đang hành động (viền trắng) rồi các lượt dự đoán.
## Qua lượt mới thì các ô trượt sang trái từng ô, ô vừa đánh trượt ra và mờ đi, lượt mới hiện dần ở cuối.
func _update_order(current: Combatant = null) -> void:
	_order_current = current
	var order: Array[Combatant] = []
	if current != null and current.is_alive():
		order.append(current)
	order.append_array(controller.predict_order(ORDER_PREVIEW - order.size()))
	var has_current := current != null and not order.is_empty() and order[0] == current
	_order_arrow.visible = has_current
	var duration := ORDER_SLIDE / (2.0 if fast_mode else 1.0)

	# Ghép ô cũ với lượt mới theo đúng thứ tự trái -> phải (không ô nào trượt chéo qua ô khác).
	var used: Array[bool] = []
	used.resize(_order_slots.size())
	used.fill(false)
	var new_slots: Array[Dictionary] = []
	var cursor := 0
	for i in order.size():
		var c := order[i]
		var pick := -1
		for j in range(cursor, _order_slots.size()):
			if _order_slots[j]["c"] == c:
				pick = j
				break
		if pick >= 0:
			cursor = pick + 1
		var slot: Dictionary
		if pick >= 0:
			used[pick] = true
			slot = _order_slots[pick]
		else:
			slot = _make_order_slot(c)
			var node: Control = slot["node"]
			node.modulate.a = 0.0
			if cursor >= _order_slots.size() or i == order.size() - 1:
				# Lượt mới ở cuối hàng: hiện dần, trượt nhẹ từ bên phải vào.
				node.position = _order_slot_rect(i + 1, has_current).position
			else:
				# Chen vào giữa hàng (vd được đẩy lượt lên): rơi từ trên xuống đúng chỗ, các ô khác dạt ra.
				node.position = _order_slot_rect(i, has_current).position + Vector2(0, -ORDER_SLOT * 0.8)
			_order_box.add_child(node)
		new_slots.append(slot)
		var is_current := i == 0 and has_current
		_style_order_slot(slot, is_current)
		var rect := _order_slot_rect(i, has_current)
		var n: Control = slot["node"]
		var t := n.create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(n, "position", rect.position, duration)
		t.tween_property(n, "size", rect.size, duration)
		t.tween_property(n, "modulate:a", 1.0, duration)
		var icon: Control = slot["icon"]
		t.tween_property(icon, "custom_minimum_size", Vector2.ONE * (52.0 if is_current else 40.0), duration)
	# Ô không còn trong hàng. Người vừa đánh: lóe trắng rồi trượt ra trái; ô khác: mờ dần tại chỗ.
	for j in _order_slots.size():
		if used[j]:
			continue
		var gone: Control = _order_slots[j]["node"]
		var t := gone.create_tween()
		if j == 0:
			t.tween_property(gone, "modulate", Color(2.0, 2.0, 2.0, 1.0), duration * 0.3)
			t.set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.chain().tween_property(gone, "position", gone.position + Vector2(-ORDER_SLOT * 0.6, -10), duration)
			t.tween_property(gone, "modulate", Color(2.0, 2.0, 2.0, 0.0), duration)
		else:
			t.tween_property(gone, "modulate:a", 0.0, duration)
		t.chain().tween_callback(gone.queue_free)
	_order_slots = new_slots


## Vị trí + kích thước ô thứ index. Ô đầu (người đang đánh) to hơn, sau nó là dấu ».
func _order_slot_rect(index: int, has_current: bool) -> Rect2:
	var small_y := (ORDER_BIG - ORDER_SLOT) / 2.0
	if not has_current:
		return Rect2(index * (ORDER_SLOT + ORDER_GAP), small_y, ORDER_SLOT, ORDER_SLOT)
	if index == 0:
		return Rect2(0, 0, ORDER_BIG, ORDER_BIG)
	var x := ORDER_BIG + ORDER_ARROW + (index - 1) * (ORDER_SLOT + ORDER_GAP)
	return Rect2(x, small_y, ORDER_SLOT, ORDER_SLOT)


func _make_order_slot(c: Combatant) -> Dictionary:
	var holder := PanelContainer.new()
	holder.size = Vector2(ORDER_SLOT, ORDER_SLOT)
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.mouse_filter = MOUSE_FILTER_IGNORE
	var icon := HuntUI.texture_rect(HuntUI.combatant_texture(c.data), 40)
	center.add_child(icon)
	holder.add_child(center)
	return {"c": c, "node": holder, "icon": icon}


func _style_order_slot(slot: Dictionary, is_current: bool) -> void:
	var c: Combatant = slot["c"]
	var border := Color(0, 0, 0, 0)
	if is_current:
		border = Color.WHITE
	elif c == controller.player:
		border = HuntUI.GOLD
	var style := HuntUI.panel_style(Color(0.2, 0.35, 0.2, 0.9) if c.is_ally else Color(0.4, 0.15, 0.12, 0.9), border, 6, 3 if is_current else 2)
	style.set_content_margin_all(0)
	var node: PanelContainer = slot["node"]
	node.add_theme_stylebox_override("panel", style)


## Đánh dấu đã đọc nhật ký trận (dùng để chọn hiệu ứng theo dòng mới; không còn hiện bảng nhật ký).
func _flush_log() -> void:
	_log_index = controller.battle.log_lines.size()


func _exit_tree() -> void:
	GameMusic.set_battle(false) # Về bản đồ săn: trở lại nhạc buổi săn.
	if _juice != null:
		_juice.reset() # luôn trả Engine.time_scale về 1
