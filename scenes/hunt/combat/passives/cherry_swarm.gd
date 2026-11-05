extends Passive
## Cà chua bi bầy đàn: mỗi đồng đội khác còn sống thì +25% dame (tính lại đầu mỗi lượt).

const BONUS_PER_ALLY := 0.25

var _base_damage := -1


func on_battle_start(holder: Combatant, _battle: Battle) -> void:
	_base_damage = holder.damage


func on_turn_start(holder: Combatant, battle: Battle) -> void:
	if _base_damage < 0:
		_base_damage = holder.damage
	var others := battle.teammates_of(holder).size() - 1
	holder.damage = roundi(_base_damage * (1.0 + BONUS_PER_ALLY * maxi(others, 0)))
