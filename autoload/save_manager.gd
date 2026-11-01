extends Node
## Lưu / tải game ra file JSON (autoload: SaveManager).
## Trên Linux file nằm ở ~/.local/share/godot/app_userdata/Sôi Sùng Sục/save.json

const SAVE_PATH := "user://save.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Không ghi được save: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary:
		push_error("File save bị hỏng: %s" % SAVE_PATH)
		return false
	GameState.load_from_dict(data)
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
