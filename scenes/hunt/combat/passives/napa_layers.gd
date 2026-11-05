extends Passive
## Cải thảo nhiều lớp: vào trận có 1 lớp lá (giáp). Lá bị đánh rụng hết thì đầu lượt sau
## mọc lớp mới, tối đa thêm 2 lần.

const LAYER_ARMOR := 10
const EXTRA_LAYERS := 2

var _layers_left := 0


func on_battle_start(holder: Combatant, _battle: Battle) -> void:
	holder.armor += LAYER_ARMOR
	_layers_left = EXTRA_LAYERS


func on_turn_start(holder: Combatant, battle: Battle) -> void:
	if holder.armor <= 0 and _layers_left > 0:
		_layers_left -= 1
		holder.armor += LAYER_ARMOR
		battle.add_log("%s mọc lớp lá mới: +%d giáp (còn %d lớp)" % [holder.display_name, LAYER_ARMOR, _layers_left])
