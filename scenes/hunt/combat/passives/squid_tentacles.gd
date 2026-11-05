extends Passive
## Mực tám xúc tu: đánh trúng thì quất thêm 1 xúc tu bằng 40% dame.

const EXTRA_RATIO := 0.4

var _chaining := false


func on_hit_dealt(holder: Combatant, battle: Battle, target: Combatant, damage: int) -> void:
	if _chaining or damage <= 0 or not target.is_alive() or not holder.is_alive():
		return
	_chaining = true
	var lost := target.take_damage(battle, holder, maxi(1, roundi(holder.damage * EXTRA_RATIO)))
	battle.add_log("  %s quất thêm xúc tu: %s -%d máu (còn %d/%d)" % [holder.display_name, target.display_name, lost, target.hp, target.max_hp])
	_chaining = false
