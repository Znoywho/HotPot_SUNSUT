class_name Battle
extends RefCounted
## Logic trận đánh theo lượt kiểu ATB, không có UI.
## Mỗi "tick" mọi đơn vị cộng speed vào thanh ATB; ai đầy trước thì hành động trước.
## -> tốc đánh cao thì đánh trước và đánh nhiều hơn.

const ATB_FULL := 100.0
const MAX_TURNS := 500

var allies: Array[Combatant] = []
var enemies: Array[Combatant] = []
var turn_count := 0
var log_lines: Array[String] = []
var pending_deaths: Array[Combatant] = [] ## Đơn vị vừa chết, chờ in log.


func _init(ally_list: Array[Combatant], enemy_list: Array[Combatant]) -> void:
	allies = ally_list
	enemies = enemy_list
	for c in all_combatants():
		for p in c.passives:
			p.on_battle_start(c, self)


func all_combatants() -> Array[Combatant]:
	var result: Array[Combatant] = []
	result.append_array(allies)
	result.append_array(enemies)
	return result


func alive(list: Array[Combatant]) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for c in list:
		if c.is_alive():
			result.append(c)
	return result


func opponents_of(c: Combatant) -> Array[Combatant]:
	if c.is_ally:
		return alive(enemies)
	return alive(allies)


func teammates_of(c: Combatant) -> Array[Combatant]:
	if c.is_ally:
		return alive(allies)
	return alive(enemies)


func is_over() -> bool:
	return alive(allies).is_empty() or alive(enemies).is_empty() or turn_count >= MAX_TURNS


func allies_won() -> bool:
	return not alive(allies).is_empty() and alive(enemies).is_empty()


## Tăng thanh ATB đến khi có người đầy, trả về người hành động tiếp theo.
func next_actor() -> Combatant:
	var living := alive(all_combatants())
	var total_speed := 0
	for c in living:
		total_speed += maxi(c.speed, 0)
	if total_speed == 0:
		return null
	while true:
		var best: Combatant = null
		for c in living:
			if c.atb >= ATB_FULL and (best == null or c.atb > best.atb):
				best = c
		if best != null:
			best.atb -= ATB_FULL
			return best
		for c in living:
			c.atb += maxi(c.speed, 0)
	return null


## Một lượt của actor: hiệu ứng đầu lượt -> đánh thường.
## Mục tiêu mặc định là kẻ địch còn sống đầu tiên trong danh sách
## (thú cưỡi đặt đầu danh sách allies sẽ chịu đòn trước).
## TODO(Hải): cho người chơi chọn mục tiêu / chiêu khi có UI.
func take_turn(actor: Combatant) -> void:
	turn_count += 1
	actor.process_turn_start(self)
	flush_deaths()
	if not actor.is_alive() or is_over():
		return
	var targets := opponents_of(actor)
	if targets.is_empty():
		return
	perform_basic_attack(actor, targets[0])


func perform_basic_attack(actor: Combatant, target: Combatant) -> int:
	var lost := target.take_damage(self, actor, actor.roll_attack_damage())
	add_log("%s đánh %s: -%d máu (còn %d/%d)" % [actor.display_name, target.display_name, lost, target.hp, target.max_hp])
	for p in actor.passives:
		p.on_hit_dealt(actor, self, target, lost)
	flush_deaths()
	return lost


func flush_deaths() -> void:
	for c in pending_deaths:
		add_log("%s bị hạ!" % c.display_name)
	pending_deaths.clear()


## Chạy tự động tới khi hết trận (dùng cho bản tạm / test cân bằng).
func auto_resolve() -> void:
	while not is_over():
		var actor := next_actor()
		if actor == null:
			break
		take_turn(actor)


## Gộp đồ rơi của mọi quái đã bị hạ.
## TODO(Hải): + tỷ lệ rơi từ Dao bén, + lượng rơi theo mốc ngày.
func collect_drops() -> Dictionary:
	var drops := {}
	for e in enemies:
		if e.is_alive() or e.data == null:
			continue
		for id in e.data.drops:
			drops[id] = int(drops.get(id, 0)) + int(e.data.drops[id])
	return drops


func add_log(text: String) -> void:
	log_lines.append(text)
