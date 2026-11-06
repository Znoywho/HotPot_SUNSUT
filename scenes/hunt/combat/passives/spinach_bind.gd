extends Passive
## Rau muống quấn: đòn đánh có 25% quấn chặt mục tiêu, lùi thanh hành động (ATB) một nửa.

const BIND_CHANCE := 0.25
const ATB_LOSS := Battle.ATB_FULL * 0.5


func on_hit_dealt(holder: Combatant, battle: Battle, target: Combatant, damage: int) -> void:
	if damage <= 0 or not target.is_alive() or randf() >= BIND_CHANCE:
		return
	target.atb = maxf(0.0, target.atb - ATB_LOSS)
	battle.add_log("%s quấn chặt %s, làm chậm lượt kế tiếp" % [holder.display_name, target.display_name])
