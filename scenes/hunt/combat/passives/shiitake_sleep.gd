extends Passive
## Nấm hương ru ngủ: hương thơm làm mục tiêu ngủ gật, 20% đòn đánh làm mất trắng thanh hành động.

const SLEEP_CHANCE := 0.2


func on_hit_dealt(holder: Combatant, battle: Battle, target: Combatant, damage: int) -> void:
	if damage <= 0 or not target.is_alive() or randf() >= SLEEP_CHANCE:
		return
	target.atb = minf(target.atb, 0.0)
	battle.add_log("%s tỏa hương: %s ngủ gật, chậm mất một nhịp!" % [holder.display_name, target.display_name])
