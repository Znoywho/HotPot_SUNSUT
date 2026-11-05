class_name SliceSkill
extends ChefSkill
## Thái lát: chém nhiều nhát nhanh, mỗi nhát yếu hơn đánh thường (mỗi nhát có thể chí mạng).

var hits := 2
var ratio := 0.6


func _init(config: HuntConfig) -> void:
	id = "slice"
	display_name = "Thái lát"
	hits = config.slice_hits
	ratio = config.slice_damage_ratio
	cooldown = config.slice_cooldown
	description = "Chém %d nhát x%d%%" % [hits, roundi(ratio * 100)]


func _use(controller: BattleController, user: Combatant, target: Combatant) -> void:
	for i in hits:
		if not target.is_alive() or not user.is_alive():
			break
		controller.attack(user, target, ratio)
