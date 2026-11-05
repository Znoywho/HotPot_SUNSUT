extends Passive
## Rau cải pháp sư: đánh trúng thì đốt 15 máu mỗi lượt, kéo dài 3 lượt.
## Không cộng dồn: nếu mục tiêu đang bị đốt thì làm mới lại số lượt.

const BURN_TURNS := 3


func on_hit_dealt(holder: Combatant, battle: Battle, target: Combatant, damage: int) -> void:
	if damage <= 0 or not target.is_alive():
		return
	for effect in target.statuses:
		if effect is BurnEffect:
			effect.turns_left = maxi(effect.turns_left, BURN_TURNS)
			return
	target.add_status(BurnEffect.new(BURN_TURNS))
	battle.add_log("%s đốt %s trong %d lượt" % [holder.display_name, target.display_name, BURN_TURNS])
