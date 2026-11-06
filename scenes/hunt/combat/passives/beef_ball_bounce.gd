extends Passive
## Bò viên nảy: dai và nảy, phản lại 20% sát thương nhận từ đòn đánh lên kẻ tấn công.
## Sát thương phản là sát thương hiệu ứng (attacker = null) nên không bị phản ngược lại vô hạn.

const REFLECT_RATIO := 0.2


func on_damaged(holder: Combatant, battle: Battle, attacker: Combatant, amount: int) -> void:
	if attacker == null or amount <= 0 or not attacker.is_alive():
		return
	var reflected := maxi(1, roundi(amount * REFLECT_RATIO))
	var lost := attacker.take_damage(battle, null, reflected)
	battle.add_log("%s nảy bật lại: %s -%d máu" % [holder.display_name, attacker.display_name, lost])
