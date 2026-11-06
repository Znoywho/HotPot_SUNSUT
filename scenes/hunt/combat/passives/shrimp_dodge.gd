extends Passive
## Tôm nhảy: 5% né đòn đánh thường (không né được sát thương hiệu ứng).

const DODGE_CHANCE := 0.05


func modify_incoming_damage(holder: Combatant, battle: Battle, attacker: Combatant, amount: int) -> int:
	# attacker == null là sát thương từ hiệu ứng (độc, đốt, nổ...): không né được.
	if attacker != null and amount > 0 and randf() < DODGE_CHANCE:
		battle.add_log("%s nhảy né đòn của %s!" % [holder.display_name, attacker.display_name])
		return 0
	return amount
