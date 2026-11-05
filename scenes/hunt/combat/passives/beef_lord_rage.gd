extends Passive
## Boss Lão Bò Lẩu – Cuồng nộ: lần đầu xuống dưới 50% máu thì hồi 10% máu tối đa,
## dame x1.5 và tốc đánh +50% (1 lần/trận).

const HP_THRESHOLD := 0.5
const HEAL_RATIO := 0.1
const DAMAGE_MULTIPLIER := 1.5
const SPEED_MULTIPLIER := 1.5

var _enraged := false


func on_battle_start(_holder: Combatant, _battle: Battle) -> void:
	_enraged = false


func on_damaged(holder: Combatant, battle: Battle, _attacker: Combatant, _amount: int) -> void:
	if _enraged or not holder.is_alive() or holder.hp >= holder.max_hp * HP_THRESHOLD:
		return
	_enraged = true
	holder.heal(roundi(holder.max_hp * HEAL_RATIO))
	holder.damage = roundi(holder.damage * DAMAGE_MULTIPLIER)
	holder.speed = roundi(holder.speed * SPEED_MULTIPLIER)
	battle.add_log("%s nổi cơn cuồng nộ! Hồi máu (còn %d/%d), dame và tốc đánh tăng mạnh" % [holder.display_name, holder.hp, holder.max_hp])
