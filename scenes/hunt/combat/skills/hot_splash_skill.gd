class_name HotSplashSkill
extends ChefSkill
## Hất lẩu nóng: sát thương lên toàn bộ kẻ địch và gây Đốt.

var damage := 8
var burn_turns := 2


func _init(config: HuntConfig) -> void:
	id = "splash"
	display_name = "Hất lẩu nóng"
	damage = config.splash_damage
	burn_turns = config.splash_burn_turns
	cooldown = config.splash_cooldown
	needs_target = false
	description = "%d dame cả đám + Đốt" % damage


func _use(controller: BattleController, user: Combatant, _target: Combatant) -> void:
	var battle := controller.battle
	battle.add_log("%s hất nồi lẩu sôi sùng sục!" % user.display_name)
	for enemy in battle.opponents_of(user):
		var lost := enemy.take_damage(battle, user, damage)
		battle.add_log("  %s -%d máu (còn %d/%d)" % [enemy.display_name, lost, enemy.hp, enemy.max_hp])
		if enemy.is_alive() and lost > 0:
			BattleController.apply_burn(enemy, burn_turns)
	battle.flush_deaths()
