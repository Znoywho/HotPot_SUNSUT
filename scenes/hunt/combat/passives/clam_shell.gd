extends Passive
## Nghêu khép vỏ: cứ mỗi 3 lượt của mình thì khép vỏ, nhận giáp.

const EVERY_TURNS := 3
const ARMOR_GAIN := 12

var _turns := 0


func on_battle_start(_holder: Combatant, _battle: Battle) -> void:
	_turns = 0


func on_turn_start(holder: Combatant, battle: Battle) -> void:
	_turns += 1
	if _turns % EVERY_TURNS == 0:
		holder.armor += ARMOR_GAIN
		battle.add_log("%s khép vỏ: +%d giáp" % [holder.display_name, ARMOR_GAIN])
