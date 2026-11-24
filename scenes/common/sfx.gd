class_name Sfx
## Phát một tiếng hiệu ứng ngắn (one-shot), tự xoá khi phát xong; kêu được cả lúc game tạm dừng.
## Dùng: Sfx.play(self, Sfx.LOOT) hoặc Sfx.play(self, Sfx.POP, -8.0) (nhỏ hơn 8 dB).

const LOOT := "res://assets/audio/sfx/loot.ogg" ## Tiếng "ting": mua đồ, đạt KPI.
const HIT := "res://assets/audio/sfx/hit.ogg" ## Tiếng đập: con dấu sổ tổng kết.
const BUBBLE := "res://assets/audio/sfx/bubble.ogg" ## Tiếng sủi bọt: bọt chuyển cảnh phồng lên.
const POP := "res://assets/audio/sfx/pop.ogg" ## Tiếng "bụp": bọt chuyển cảnh vỡ.


## Phát tiếng `path` gắn vào `parent` (to / nhỏ hơn `volume_db` dB); file chưa có thì bỏ qua để màn không lỗi.
static func play(parent: Node, path: String, volume_db := 0.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = volume_db
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
