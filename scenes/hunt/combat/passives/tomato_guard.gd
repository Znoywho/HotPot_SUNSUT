extends Passive
## Chiến binh cà chua: dưới 25% máu thì nhận giáp bằng 10% máu tối đa (1 lần/trận).

const HP_THRESHOLD := 0.25
const ARMOR_RATIO := 0.1

var _triggered := false


func on_battle_start(_holder: Combatant, _battle: Battle) -> void:
	_triggered = false


func on_damaged(holder: Combatant, battle: Battle, _attacker: Combatant, _amount: int) -> void:
	if _triggered or not holder.is_alive():
		return
	if holder.hp < holder.max_hp * HP_THRESHOLD:
		_triggered = true
		var gained := roundi(holder.max_hp * ARMOR_RATIO)
		holder.armor += gained
		battle.add_log("%s dựng khiên cà chua: +%d giáp" % [holder.display_name, gained])
