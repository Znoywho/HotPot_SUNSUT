extends Passive
## Boss Nồi Lẩu Thần – Sôi sùng sục: cứ mỗi 3 lượt của mình thì nồi sôi trào,
## gây sát thương lên toàn bộ kẻ địch và làm bỏng (Đốt).

const EVERY_TURNS := 3
const BOIL_DAMAGE := 12
const BURN_TURNS := 2

var _turns := 0


func on_battle_start(_holder: Combatant, _battle: Battle) -> void:
	_turns = 0


func on_turn_start(holder: Combatant, battle: Battle) -> void:
	_turns += 1
	if _turns % EVERY_TURNS != 0:
		return
	battle.add_log("%s sôi sùng sục, nước lẩu trào ra!" % holder.display_name)
	for c in battle.opponents_of(holder):
		var lost := c.take_damage(battle, null, BOIL_DAMAGE)
		battle.add_log("  %s bị bỏng: -%d máu (còn %d/%d)" % [c.display_name, lost, c.hp, c.max_hp])
		if c.is_alive():
			BattleController.apply_burn(c, BURN_TURNS)
	battle.flush_deaths()
