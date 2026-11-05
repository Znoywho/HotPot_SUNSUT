class_name BattleController
extends RefCounted
## Điều khiển một trận theo từng lượt cho UI (không sửa Battle).
## UI gọi begin_turn() -> nếu là lượt đầu bếp thì chờ người chơi chọn rồi gọi player_action(),
## còn lại gọi ai_action(). Trước/sau mỗi bước, UI so snapshot() để vẽ số sát thương.

enum Result { NONE, WIN, LOSE, FLED, TIMEOUT }

var battle: Battle
var player: Combatant
var skills: Array[ChefSkill] = []
var result := Result.NONE
var crits: Array[Combatant] = [] ## Những đơn vị vừa ăn đòn chí mạng ở bước gần nhất.


func _init(ally_list: Array[Combatant], enemy_list: Array[Combatant], chef: Combatant, config: HuntConfig) -> void:
	player = chef
	# Phe ta đi qua nhiều trận trong buổi sáng: máu giữ nguyên, nhưng độc/đốt và giáp tạm thì xóa.
	for c in ally_list:
		c.atb = 0.0
		c.statuses.clear()
		c.armor = 0
	battle = Battle.new(ally_list, enemy_list)
	skills = [BasicAttackSkill.new(), SliceSkill.new(config), HotSplashSkill.new(config)]


## Sang lượt kế tiếp: tăng ATB, chạy hiệu ứng đầu lượt (độc, đốt, nội tại).
## Trả về người hành động, hoặc null nếu trận đã kết thúc.
func begin_turn() -> Combatant:
	crits.clear()
	if _check_over():
		return null
	var actor := battle.next_actor()
	if actor == null:
		_check_over()
		return null
	battle.turn_count += 1
	actor.process_turn_start(battle)
	battle.flush_deaths()
	if actor == player:
		for s in skills:
			s.tick()
	return actor


## Người hành động còn đánh được không (có thể vừa chết vì độc/đốt).
func can_act(actor: Combatant) -> bool:
	return actor != null and actor.is_alive() and not _check_over()


func is_player(actor: Combatant) -> bool:
	return actor == player


func player_action(skill: ChefSkill, target: Combatant) -> void:
	crits.clear()
	if target == null or not target.is_alive():
		target = default_target()
	skill.execute(self, player, target)
	_check_over()


## Lượt tự động: quái và thú cưỡi đánh mục tiêu đầu tiên còn sống
## (thú cưỡi đứng đầu danh sách đồng minh nên chịu đòn trước).
## Đầu bếp ở chế độ Tự đánh: dùng chiêu khi sẵn sàng, nhắm quái ít máu nhất.
func ai_action(actor: Combatant) -> void:
	crits.clear()
	if actor == player:
		var target := weakest_enemy()
		var skill := auto_skill()
		skill.execute(self, player, target)
	else:
		var targets := battle.opponents_of(actor)
		if not targets.is_empty():
			attack(actor, targets[0])
	_check_over()


func auto_skill() -> ChefSkill:
	var enemies := battle.alive(battle.enemies)
	var splash := skills[2]
	if splash.is_ready() and enemies.size() >= 2:
		return splash
	if skills[1].is_ready():
		return skills[1]
	return skills[0]


func default_target() -> Combatant:
	var enemies := battle.alive(battle.enemies)
	return null if enemies.is_empty() else enemies[0]


func weakest_enemy() -> Combatant:
	var best: Combatant = null
	for e in battle.alive(battle.enemies):
		if best == null or e.hp < best.hp:
			best = e
	return best


func flee() -> void:
	result = Result.FLED
	battle.add_log("Đầu bếp bỏ chạy khỏi trận!")


func time_out() -> void:
	result = Result.TIMEOUT
	battle.add_log("Hết giờ săn! Phải về bếp ngay.")


func is_finished() -> bool:
	return result != Result.NONE or _check_over()


## Một đòn đánh (giống Battle.perform_basic_attack nhưng biết có chí mạng không).
func attack(actor: Combatant, target: Combatant, ratio := 1.0) -> int:
	var crit := randf() < actor.crit_chance
	var amount := roundi(actor.damage * ratio * (actor.crit_multiplier if crit else 1.0))
	var lost := target.take_damage(battle, actor, maxi(amount, 1))
	if crit and lost > 0:
		crits.append(target)
	battle.add_log("%s đánh %s%s: -%d máu (còn %d/%d)" % [
		actor.display_name, target.display_name, " (CHÍ MẠNG!)" if crit and lost > 0 else "",
		lost, target.hp, target.max_hp])
	for p in actor.passives:
		p.on_hit_dealt(actor, battle, target, lost)
	battle.flush_deaths()
	return lost


## Dự đoán n người hành động tiếp theo (không làm thay đổi trận).
func predict_order(n: int) -> Array[Combatant]:
	var order: Array[Combatant] = []
	var living := battle.alive(battle.all_combatants())
	var atb := {}
	var total_speed := 0
	for c in living:
		atb[c] = c.atb
		total_speed += maxi(c.speed, 0)
	if total_speed == 0:
		return order
	var guard := 0
	while order.size() < n and guard < 10000:
		guard += 1
		var best: Combatant = null
		for c in living:
			if atb[c] >= Battle.ATB_FULL and (best == null or atb[c] > atb[best]):
				best = c
		if best != null:
			atb[best] -= Battle.ATB_FULL
			order.append(best)
		else:
			for c in living:
				atb[c] += maxi(c.speed, 0)
	return order


## Chụp trạng thái để UI so sánh trước/sau một bước.
func snapshot() -> Dictionary:
	var snap := {}
	for c in battle.all_combatants():
		snap[c] = {"hp": c.hp, "armor": c.armor, "alive": c.is_alive()}
	return snap


## Gây Đốt, không cộng dồn: đang bị đốt thì làm mới số lượt.
static func apply_burn(target: Combatant, turns: int) -> void:
	for effect in target.statuses:
		if effect is BurnEffect:
			effect.turns_left = maxi(effect.turns_left, turns)
			return
	target.add_status(BurnEffect.new(turns))


func _check_over() -> bool:
	if result != Result.NONE:
		return true
	if not player.is_alive() or battle.alive(battle.allies).is_empty():
		result = Result.LOSE
		return true
	if battle.alive(battle.enemies).is_empty():
		result = Result.WIN
		return true
	if battle.turn_count >= Battle.MAX_TURNS:
		result = Result.LOSE
		return true
	return false
