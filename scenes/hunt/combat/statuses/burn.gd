class_name BurnEffect
extends StatusEffect
## Đốt: mất 15 máu mỗi lượt, kéo dài 3 lượt (tạo bằng BurnEffect.new(3)).

const DAMAGE_PER_TURN := 15


func on_turn_start(target: Combatant, battle: Battle) -> void:
	var lost := target.take_damage(battle, null, DAMAGE_PER_TURN)
	battle.add_log("%s bị đốt: -%d máu (còn %d/%d)" % [target.display_name, lost, target.hp, target.max_hp])
