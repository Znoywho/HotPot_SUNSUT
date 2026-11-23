class_name GameMusic
extends Node
## Nhạc nền chạy xuyên các màn (nằm dưới root, không phải autoload): tự chọn bài theo buổi của DayManager,
## đổi bài thì bài cũ nhỏ dần, bài mới to dần. Trận đánh gọi GameMusic.set_battle(true/false) để đổi sang
## nhạc đánh nhau. Phát qua bus "Music" (tự tạo nếu chưa có) để sau này bảng Cài đặt chỉnh riêng được.
## Gọi GameMusic.ensure(get_tree()) một lần lúc mở game (DayManager._ready).

const DIR := "res://assets/audio/music/"
const MUSIC_DB := -12.0 ## Nhạc nền nhỏ hơn SFX để không át tiếng thao tác.
const SILENT_DB := -40.0
const FADE := 0.7
const BUS := "Music"

static var _instance: GameMusic = null

var _battle := false
var _track := ""
var _player: AudioStreamPlayer = null


static func ensure(tree: SceneTree) -> void:
	# Chạy headless (kiểm tra script, build) không có âm thanh: không bật nhạc, khỏi báo tài nguyên còn giữ lúc thoát.
	if is_instance_valid(_instance) or DisplayServer.get_name() == "headless":
		return
	_instance = GameMusic.new()
	_instance.name = "GameMusic"
	tree.root.add_child.call_deferred(_instance)


## Trận đánh bắt đầu / kết thúc: đổi sang nhạc đánh nhau và trở lại nhạc buổi săn.
static func set_battle(on: bool) -> void:
	if is_instance_valid(_instance):
		_instance._battle = on


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Menu tạm dừng / sổ tổng kết vẫn có nhạc.
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, "Master")


func _process(_delta: float) -> void:
	var want := _wanted_track()
	if want != _track:
		_switch(want)


func _wanted_track() -> String:
	match DayManager.current_phase:
		DayManager.Phase.HUNT:
			return "battle" if _battle else "hunt"
		DayManager.Phase.COOK:
			return "cook"
		DayManager.Phase.SELL:
			return "sell"
		DayManager.Phase.GAME_OVER:
			return ""
	return "menu" # Menu chính, cửa hàng, sổ tổng kết.


func _switch(track: String) -> void:
	_track = track
	_battle = _battle and DayManager.current_phase == DayManager.Phase.HUNT
	if _player != null:
		var old := _player
		var t := old.create_tween()
		t.tween_property(old, "volume_db", SILENT_DB, FADE)
		t.tween_callback(old.queue_free)
		_player = null
	var path := DIR + track + ".ogg"
	if track == "" or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.bus = BUS
	_player.volume_db = SILENT_DB
	add_child(_player)
	_player.play()
	_player.create_tween().tween_property(_player, "volume_db", MUSIC_DB, FADE)


func _exit_tree() -> void:
	# Tắt game: dừng và nhả nhạc để Godot không báo tài nguyên còn bị giữ.
	for c in get_children():
		if c is AudioStreamPlayer:
			(c as AudioStreamPlayer).stop()
			(c as AudioStreamPlayer).stream = null
	if _instance == self:
		_instance = null
