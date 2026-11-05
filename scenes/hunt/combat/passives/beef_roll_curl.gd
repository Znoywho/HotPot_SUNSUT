extends Passive
## Bò cuộn kim châm: lần đầu xuống dưới 50% máu thì cuộn chặt lại, hồi 25% máu tối đa (1 lần/trận).

const HP_THRESHOLD := 0.5
const HEAL_RATIO := 0.25

var _used := false


func on_battle_start(_holder: Combatant, _battle: Battle) -> void:
	_used = false


func on_damaged(holder: Combatant, battle: Battle, _attacker: Combatant, _amount: int) -> void:
	if _used or not holder.is_alive() or holder.hp >= holder.max_hp * HP_THRESHOLD:
		return
	_used = true
	var before := holder.hp
	holder.heal(roundi(holder.max_hp * HEAL_RATIO))
	battle.add_log("%s cuộn chặt lại: +%d máu (còn %d/%d)" % [holder.display_name, holder.hp - before, holder.hp, holder.max_hp])
