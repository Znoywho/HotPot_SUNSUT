class_name PoisonEffect
extends StatusEffect
## Độc: mất 2% máu tối đa mỗi lượt (ít nhất 1 máu).

const MAX_HP_RATIO := 0.02


func on_turn_start(target: Combatant, battle: Battle) -> void:
	var amount := maxi(1, roundi(target.max_hp * MAX_HP_RATIO))
	var lost := target.take_damage(battle, null, amount)
	battle.add_log("%s trúng độc: -%d máu (còn %d/%d)" % [target.display_name, lost, target.hp, target.max_hp])
