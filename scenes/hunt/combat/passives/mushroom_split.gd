extends Passive
## Nấm mỡ sinh sôi: khi bị hạ thì tách ra 1 nấm con (50% chỉ số, không có nội tại, rơi ít đồ hơn).

const CHILD_STAT_RATIO := 0.5
const CHILD_DROPS := {"mushroom": 1}


func on_death(holder: Combatant, battle: Battle) -> bool:
	var child_data: CombatantData = holder.data.duplicate()
	child_data.display_name = "%s con" % holder.data.display_name
	child_data.passive = null # Nấm con không tách tiếp.
	child_data.drops = CHILD_DROPS.duplicate()
	var child := Combatant.from_data(child_data, holder.is_ally, 1.0)
	# Chỉ số theo bản thân holder (đã nhân hệ số mốc ngày), không theo data gốc.
	child.max_hp = maxi(1, roundi(holder.max_hp * CHILD_STAT_RATIO))
	child.hp = child.max_hp
	child.damage = maxi(1, roundi(holder.damage * CHILD_STAT_RATIO))
	if holder.is_ally:
		battle.allies.append(child)
	else:
		battle.enemies.append(child)
	battle.add_log("%s tách ra %s!" % [holder.display_name, child.display_name])
	return false
