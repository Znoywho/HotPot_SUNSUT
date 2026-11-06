extends Passive
## Nấm dược sư: đòn đánh có thể gây độc, mất 2% máu tối đa mỗi lượt.
## Không cộng dồn: nếu mục tiêu đang trúng độc thì làm mới lại số lượt.
## TODO(nhóm): cân bằng sau – tỷ lệ gây độc (tạm 30%) và số lượt (tạm 3).

const POISON_CHANCE := 0.3
const POISON_TURNS := 3


func on_hit_dealt(holder: Combatant, battle: Battle, target: Combatant, damage: int) -> void:
	if damage <= 0 or not target.is_alive() or randf() >= POISON_CHANCE:
		return
	for effect in target.statuses:
		if effect is PoisonEffect:
			effect.turns_left = maxi(effect.turns_left, POISON_TURNS)
			return
	target.add_status(PoisonEffect.new(POISON_TURNS))
	battle.add_log("%s làm %s trúng độc trong %d lượt" % [holder.display_name, target.display_name, POISON_TURNS])
