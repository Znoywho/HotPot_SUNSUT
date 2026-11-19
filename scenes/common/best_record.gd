class_name BestRecord
## Kỷ lục số ngày trụ được qua mọi lần chơi. Lưu chung file cài đặt (user://settings.cfg)
## nên không mất khi Game Over xoá save. Chỉ ghi ở màn Game Over (lần chơi đã kết thúc).

const SECTION := "record"
const KEY_DAYS := "best_days"


## Kỷ lục hiện tại (0 = chưa có lần chơi nào kết thúc).
static func best_days() -> int:
	var config := ConfigFile.new()
	config.load(SettingsPanel.SETTINGS_PATH) # chưa có file = chưa có kỷ lục
	return int(config.get_value(SECTION, KEY_DAYS, 0))


## Ghi `days` nếu vượt kỷ lục cũ (giữ nguyên các mục khác trong file). Trả về true nếu là kỷ lục mới.
static func submit_days(days: int) -> bool:
	if days <= best_days():
		return false
	var config := ConfigFile.new()
	config.load(SettingsPanel.SETTINGS_PATH)
	config.set_value(SECTION, KEY_DAYS, days)
	config.save(SettingsPanel.SETTINGS_PATH)
	return true
