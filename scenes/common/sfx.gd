class_name Sfx
## Phát một tiếng hiệu ứng ngắn (one-shot), tự xoá khi phát xong; kêu được cả lúc game tạm dừng.
## Dùng: Sfx.play(self, Sfx.LOOT)

const LOOT := "res://assets/audio/sfx/loot.ogg" ## Tiếng "ting": mua đồ, đạt KPI.
const HIT := "res://assets/audio/sfx/hit.ogg" ## Tiếng đập: con dấu sổ tổng kết.


## Phát tiếng `path` gắn vào `parent`; file chưa có thì bỏ qua để màn không lỗi.
static func play(parent: Node, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
