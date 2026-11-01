extends ScreenBase
## Sáng – đi săn nguyên liệu.
## BẢN TẠM: trận đánh tự chạy và in log.
## TODO(Hải): làm battle_view.tscn có sprite, thanh máu, chọn mục tiêu; nối Battle vào đó.

var _player: Combatant


func _get_title() -> String:
	return "Sáng – Đi săn nguyên liệu"


func _setup() -> void:
	_player = _create_player()
	add_action("Đánh quái thường (1–2 con)", _fight.bind(false))
	add_action("Đánh Boss", _fight.bind(true))
	add_action("Về bếp nấu lẩu »", DayManager.next_phase)
	log_line("Đầu bếp: %d máu, %d dame, %d tốc đánh." % [_player.hp, _player.damage, _player.speed])
	log_line("[i]Bản tạm: trận đánh tự chạy. Máu không hồi giữa các trận trong buổi sáng.[/i]")


func _create_player() -> Combatant:
	var player := Combatant.from_data(Database.player, true)
	player.max_hp += roundi(Database.upgrade_value("armor"))
	player.hp = player.max_hp
	player.damage += roundi(Database.upgrade_value("knife"))
	# TODO(Hải): chí mạng (Trí tuệ minh mẫn, Mắt diều hâu), thú cưỡi đứng trước người chơi.
	return player


func _fight(boss: bool) -> void:
	if not _player.is_alive():
		log_line("[color=red]Đầu bếp đã kiệt sức, hãy về bếp.[/color]")
		return
	var pool := Database.monsters_for_day(GameState.day, boss)
	if pool.is_empty():
		log_line("Không có quái phù hợp.")
		return

	var multiplier := GameState.monster_stat_multiplier()
	var enemy_list: Array[Combatant] = []
	for i in (1 if boss else randi_range(1, 2)):
		enemy_list.append(Combatant.from_data(pool.pick_random(), false, multiplier))
	var ally_list: Array[Combatant] = [_player]
	_player.atb = 0.0

	var names: Array[String] = []
	for e in enemy_list:
		names.append(e.display_name)
	log_line("\n[b]Gặp: %s[/b]" % ", ".join(names))

	var battle := Battle.new(ally_list, enemy_list)
	battle.auto_resolve()
	for line in battle.log_lines:
		log_line(line)

	if battle.allies_won():
		var drops := battle.collect_drops()
		for id in drops:
			GameState.add_item(id, drops[id])
		log_line("[color=green]Thắng! Nhận: %s[/color]" % GameState.describe_items(drops))
	else:
		log_line("[color=red]Thua... phải về bếp.[/color]")
