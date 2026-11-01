class_name Combatant
extends RefCounted
## Một đơn vị đang ở trong trận (bản sao runtime của CombatantData).

var data: CombatantData
var display_name: String
var max_hp: int
var hp: int
var damage: int
var speed: int
var armor := 0 ## Giáp tạm: hấp thụ sát thương trước khi trừ máu.
var crit_chance := 0.0 ## 0..1
var crit_multiplier := 1.5
var atb := 0.0 ## Thanh hành động, đầy (Battle.ATB_FULL) thì được đánh.
var is_ally := false
var passives: Array[Passive] = []
var statuses: Array[StatusEffect] = []


static func from_data(source: CombatantData, ally := false, stat_multiplier := 1.0) -> Combatant:
	var c := Combatant.new()
	c.data = source
	c.display_name = source.display_name
	c.max_hp = roundi(source.max_hp * stat_multiplier)
	c.hp = c.max_hp
	c.damage = roundi(source.damage * stat_multiplier)
	c.speed = source.speed
	c.is_ally = ally
	if source.passive:
		c.passives.append(source.passive.new())
	return c


func is_alive() -> bool:
	return hp > 0


func roll_attack_damage() -> int:
	if randf() < crit_chance:
		return roundi(damage * crit_multiplier)
	return damage


## Nhận sát thương: qua nội tại (vd né đòn) -> trừ giáp -> trừ máu.
## attacker = null nghĩa là sát thương từ hiệu ứng (độc, đốt, nổ...).
## Trả về lượng máu thực sự bị mất.
func take_damage(battle: Battle, attacker: Combatant, amount: int) -> int:
	for p in passives:
		amount = p.modify_incoming_damage(self, battle, attacker, amount)
	if amount <= 0:
		return 0
	var absorbed := mini(armor, amount)
	armor -= absorbed
	var lost := amount - absorbed
	hp = maxi(0, hp - lost)
	for p in passives:
		p.on_damaged(self, battle, attacker, lost)
	if hp <= 0:
		_handle_death(battle)
	return lost


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)


func add_status(effect: StatusEffect) -> void:
	statuses.append(effect)


## Gọi đầu lượt của đơn vị này: nội tại + hiệu ứng trạng thái (độc, đốt...).
func process_turn_start(battle: Battle) -> void:
	for p in passives:
		p.on_turn_start(self, battle)
	for effect in statuses.duplicate():
		if not is_alive():
			break
		effect.on_turn_start(self, battle)
		effect.turns_left -= 1
		if effect.turns_left <= 0:
			statuses.erase(effect)


func _handle_death(battle: Battle) -> void:
	for p in passives:
		if p.on_death(self, battle):
			return # Được nội tại cứu (vd Linh hồn đầu bếp).
	battle.pending_deaths.append(self)
