extends Passive
## Bò tót điên: bị đánh thì tích nội năng như một quả bom. Khi chết thì phát nổ,
## gây sát thương lên toàn bộ kẻ địch = EXPLOSION_BASE + nội năng * ENERGY_RATIO.
## TODO(nhóm): cân bằng EXPLOSION_BASE và ENERGY_RATIO.

const EXPLOSION_BASE := 5
const ENERGY_RATIO := 0.1 ## 120 máu bị đánh hết -> +12 dame nổ.

var inner_energy := 0 ## Tổng máu đã mất trong trận.


func on_battle_start(_holder: Combatant, _battle: Battle) -> void:
	inner_energy = 0


func on_damaged(_holder: Combatant, _battle: Battle, _attacker: Combatant, amount: int) -> void:
	inner_energy += amount


func explosion_damage() -> int:
	return EXPLOSION_BASE + roundi(inner_energy * ENERGY_RATIO)


func on_death(holder: Combatant, battle: Battle) -> bool:
	var dmg := explosion_damage()
	battle.add_log("%s phát nổ (nội năng %d)! Gây %d dame lên toàn bộ kẻ địch" % [holder.display_name, inner_energy, dmg])
	# opponents_of() trả về mảng mới nên an toàn khi có người chết giữa chừng.
	for c in battle.opponents_of(holder):
		c.take_damage(battle, null, dmg)
	return false
