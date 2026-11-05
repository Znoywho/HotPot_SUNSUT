extends Passive
## Ớt hiểm cuồng nộ: càng mất máu càng cay, dame tăng theo % máu đã mất (tối đa x2 khi sắp chết).

const MAX_BONUS := 1.0 ## +100% dame khi máu về gần 0.

var _base_damage := -1
var _announced := false


func on_battle_start(holder: Combatant, _battle: Battle) -> void:
	_base_damage = holder.damage
	_announced = false


func on_damaged(holder: Combatant, battle: Battle, _attacker: Combatant, _amount: int) -> void:
	if _base_damage < 0:
		_base_damage = holder.damage
	if not holder.is_alive():
		return
	var lost_ratio := 1.0 - float(holder.hp) / holder.max_hp
	holder.damage = roundi(_base_damage * (1.0 + MAX_BONUS * lost_ratio))
	if not _announced and lost_ratio >= 0.5:
		_announced = true
		battle.add_log("%s cay xé lưỡi, nổi cơn cuồng nộ! (dame %d)" % [holder.display_name, holder.damage])
