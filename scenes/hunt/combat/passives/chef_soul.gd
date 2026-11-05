extends Passive
## Người chơi – Linh hồn đầu bếp: lần thua đầu tiên được hồi 100 máu, nhân đôi dame và tốc đánh.
## Đã chốt: 1 lần mỗi ngày. Người chơi được tạo lại mỗi buổi sáng (hunt_phase.gd) nên
## biến _used tự reset sang ngày mới. Chỉ số x2 giữ đến hết buổi săn hôm đó.

const REVIVE_HP := 100
const DAMAGE_MULTIPLIER := 2
const SPEED_MULTIPLIER := 2

var _used := false


func on_death(holder: Combatant, battle: Battle) -> bool:
	if _used:
		return false
	_used = true
	holder.hp = mini(REVIVE_HP, holder.max_hp)
	holder.damage *= DAMAGE_MULTIPLIER
	holder.speed *= SPEED_MULTIPLIER
	battle.add_log("Linh hồn đầu bếp bừng cháy! %s hồi %d máu, x%d dame và tốc đánh" % [holder.display_name, holder.hp, DAMAGE_MULTIPLIER])
	return true
