class_name DecorArt
extends RefCounted
## Vẽ pixel các món đồ trang trí mua ở tab Trang trí (DecorData): quán (RoomDecor) và thẻ xem trước ở cửa hàng
## dùng chung các hàm này nên luôn ra đúng một hình.
## Mỗi món vẽ trong một khung riêng (BOX, đơn vị = 1 điểm ảnh nền), góc trái trên tại `origin` (px màn hình),
## 1 điểm ảnh = `px` px màn hình (quán dùng 4, thẻ cửa hàng tự chọn cho vừa ô).

## Cỡ khung (điểm ảnh) của từng chỗ đặt đồ.
const BOX := {
	"clock": Vector2i(11, 11),
	"painting": Vector2i(17, 14),
	"shelf": Vector2i(32, 13),
	"cat": Vector2i(10, 15),
	"corner": Vector2i(16, 18),
	"door": Vector2i(11, 11),
}
## Tên chỗ đặt hiện trên thẻ cửa hàng.
const SLOT_NAMES := {
	"clock": "Đồng hồ", "painting": "Tranh treo", "shelf": "Kệ treo tường",
	"cat": "Mèo thần tài", "corner": "Góc quán", "door": "Trên cửa",
}

const INK := Color("2e1a10")
const WOOD := Color("8a5a2c")
const WOOD_DARK := Color("5a3418")
const RED := Color("c4342b")
const RED_DARK := Color("8c201c")
const GOLD := Color("f2c14e")
const GOLD_DARK := Color("b8862a")
const CREAM := Color("f5ecd6")
const PAPER := Color("d9c8a8")


## Vẽ món `style` của chỗ `slot` với góc trái trên khung ở `origin`.
static func draw(ci: CanvasItem, slot: String, style: String, origin: Vector2, px: float) -> void:
	var d := Pen.new(ci, origin, px)
	match slot:
		"clock":
			_clock(d, style)
		"painting":
			_painting(d, style)
		"shelf":
			_shelf(d, style)
		"cat":
			_cat(d, style)
		"corner":
			_corner(d, style)
		"door":
			_door(d, style)


## Bút vẽ ô vuông theo lưới điểm ảnh: p(x, y, w, h, màu) với toạ độ tính từ góc khung.
class Pen:
	var ci: CanvasItem
	var origin: Vector2
	var px: float

	func _init(canvas: CanvasItem, at: Vector2, pixel: float) -> void:
		ci = canvas
		origin = at
		px = pixel

	func p(x: float, y: float, w: float, h: float, c: Color) -> void:
		ci.draw_rect(Rect2(origin + Vector2(x, y) * px, Vector2(w, h) * px), c)


# --- Đồng hồ (11x11): viền theo kiểu "wood" / "red" / "gold" ---------------------

static func _clock(d: Pen, style: String) -> void:
	var frame: Color = {"red": RED, "gold": GOLD}.get(style, WOOD)
	var hand := RED if style == "gold" else INK
	d.p(3, 0, 5, 11, INK)
	d.p(0, 3, 11, 5, INK)
	d.p(1, 1, 9, 9, INK)
	d.p(1, 2, 9, 7, frame)
	d.p(2, 1, 7, 9, frame)
	d.p(2, 2, 7, 7, CREAM)
	for t in [Vector2i(5, 2), Vector2i(8, 5), Vector2i(5, 8), Vector2i(2, 5)]:
		d.p(t.x, t.y, 1, 1, frame.darkened(0.2))
	d.p(5, 3, 1, 3, hand) # kim phút
	d.p(5, 5, 2, 1, RED if style != "gold" else INK) # kim giờ


# --- Tranh (17x14): "mountain" núi / "sea" biển có thuyền / "lotus" hoa sen khung vàng ---

static func _painting(d: Pen, style: String) -> void:
	var gold := style == "lotus"
	d.p(0, 0, 17, 14, GOLD_DARK if gold else INK)
	d.p(1, 1, 15, 12, GOLD if gold else Color("6b3f1f"))
	var x := 2
	var y := 2
	var w := 13
	var h := 10
	match style:
		"sea":
			d.p(x, y, w, h, Color("bfe6f5"))
			d.p(x, y + 5, w, 5, Color("3d8fc4"))
			for i in 4:
				d.p(x + 1 + i * 3, y + 6 + (i % 2), 2, 1, Color("e8f6fb"))
			d.p(x + 5, y + 4, 4, 1, WOOD) # thân thuyền
			d.p(x + 6, y + 5, 2, 1, WOOD_DARK)
			d.p(x + 7, y, 1, 4, INK) # cột buồm
			d.p(x + 5, y + 1, 2, 3, RED) # buồm
		"lotus":
			d.p(x, y, w, h, Color("dcefd2"))
			d.p(x, y + 7, w, 3, Color("6fb3c9"))
			d.p(x + 1, y + 6, 4, 2, Color("4f9a3a")) # lá sen
			d.p(x + 8, y + 7, 4, 2, Color("4f9a3a"))
			d.p(x + 6, y + 4, 1, 4, Color("3c7a2c")) # cuống
			d.p(x + 4, y + 2, 5, 2, Color("f08aa0")) # bông sen
			d.p(x + 5, y + 1, 3, 1, Color("f8b9c6"))
			d.p(x + 6, y + 0, 1, 1, Color("f8b9c6"))
			d.p(x + 5, y + 3, 3, 1, Color("c8566e"))
		_:
			d.p(x, y, w, h, Color("9fd3ea"))
			d.p(x + w - 4, y + 1, 2, 2, Color("ffe08a"))
			d.p(x, y + h - 4, w, 4, Color("4f9a3a"))
			for i in 4:
				d.p(x + 2 + i, y + h - 5 - i, 7 - 2 * i, 1, Color("6a8fa0"))
			d.p(x + 1, y + h - 1, w - 2, 1, Color("3c7a2c"))


# --- Kệ treo tường (32x13): mặt kệ ở hàng 9-10; "spice" gia vị / "wine" rượu / "bowls" bát đĩa ---

static func _shelf(d: Pen, style: String) -> void:
	d.p(0, 9, 32, 2, WOOD)
	d.p(0, 11, 32, 1, INK)
	d.p(2, 12, 2, 1, INK)
	d.p(28, 12, 2, 1, INK)
	match style:
		"wine":
			var bottles := [Color("2e6b2a"), Color("5a2a12"), Color("cfe3e8"), Color("2e6b2a"), Color("7a1f2b")]
			for i in bottles.size():
				var bx := 2 + i * 5
				d.p(bx, 2, 3, 7, bottles[i])
				d.p(bx + 1, 0, 1, 2, bottles[i].darkened(0.2))
				d.p(bx + 1, 0, 1, 1, RED if i % 2 == 0 else GOLD)
				d.p(bx, 4, 3, 2, PAPER) # nhãn
			for i in 2: # chén rượu
				d.p(27 + i * 2, 7, 1, 2, CREAM)
		"bowls":
			for stack in 2:
				var bx := 2 + stack * 9
				for i in 3:
					d.p(bx, 6 - i * 2, 7, 2, CREAM)
					d.p(bx, 6 - i * 2, 7, 1, Color("3d6fb5")) # viền xanh
			d.p(21, 4, 7, 5, Color("b5562c")) # ấm trà
			d.p(22, 3, 5, 1, Color("d0703c"))
			d.p(24, 2, 1, 1, Color("d0703c"))
			d.p(28, 5, 2, 1, Color("b5562c")) # vòi ấm
		_:
			d.p(2, 4, 5, 5, RED_DARK) # hũ ớt
			d.p(3, 5, 3, 3, RED)
			d.p(2, 3, 5, 1, PAPER)
			for i in 2: # chai nước chấm
				var bx := 10 + i * 4
				d.p(bx, 2, 2, 7, Color("5a2a12") if i == 0 else Color("2e6b2a"))
				d.p(bx, 0, 2, 2, PAPER)
			d.p(20, 5, 4, 4, Color("e8e2d0")) # lọ tỏi
			d.p(20, 4, 4, 1, GOLD_DARK)
			d.p(26, 6, 4, 3, Color("f2c14e")) # hũ mật ong
			d.p(26, 5, 4, 1, WOOD)


# --- Mèo thần tài (10x15) trên bục đỏ nhỏ: "white" / "black" / "gold" ---------------

static func _cat(d: Pen, style: String) -> void:
	var body: Color = {"gold": GOLD, "black": Color("2b2b33")}.get(style, Color("f5f1e6"))
	var shade: Color = {"gold": GOLD_DARK, "black": Color("15151a")}.get(style, Color("d0c8b8"))
	var eye := GOLD if style == "black" else INK
	d.p(0, 12, 10, 3, RED_DARK) # bục
	d.p(1, 12, 8, 1, RED)
	d.p(1, 5, 7, 7, body) # thân
	d.p(1, 1, 7, 5, body) # đầu
	d.p(1, 0, 2, 1, body) # tai
	d.p(6, 0, 2, 1, body)
	d.p(8, 0, 2, 4, body) # tay vẫy
	d.p(2, 3, 1, 1, eye)
	d.p(6, 3, 1, 1, eye)
	d.p(1, 6, 7, 1, RED) # vòng cổ
	d.p(4, 7, 1, 1, GOLD if style != "gold" else RED) # chuông
	d.p(2, 9, 5, 2, shade)


# --- Góc quán (16x18), đứng trên sàn: "crates" két bia / "barrel" chum rượu / "aquarium" bể cá ---

static func _corner(d: Pen, style: String) -> void:
	match style:
		"barrel":
			var clay := Color("8a4a22")
			d.p(3, 16, 10, 2, clay.darkened(0.3))
			d.p(2, 7, 12, 9, clay)
			d.p(3, 5, 10, 2, clay)
			d.p(4, 8, 1, 6, clay.lightened(0.2))
			d.p(4, 3, 8, 2, RED) # nắp vải
			d.p(4, 5, 8, 1, PAPER) # dây buộc
			d.p(5, 9, 6, 4, Color("f1e3c4")) # giấy dán
			d.p(7, 10, 2, 2, RED)
		"aquarium":
			d.p(0, 14, 16, 4, WOOD) # chân kệ
			d.p(1, 17, 2, 1, INK)
			d.p(13, 17, 2, 1, INK)
			d.p(0, 3, 16, 11, INK) # khung kính
			d.p(1, 4, 14, 9, Color("6fc3e0"))
			d.p(1, 4, 14, 2, Color("a8e0f0"))
			d.p(1, 11, 14, 2, Color("e0c890")) # cát
			d.p(3, 7, 1, 4, Color("4f9a3a")) # rong
			d.p(4, 8, 1, 3, Color("6cb24a"))
			d.p(8, 7, 3, 2, Color("ff8a3d")) # cá
			d.p(7, 7, 1, 2, Color("e0602a"))
			d.p(11, 9, 2, 1, Color("ffd54a"))
			d.p(12, 5, 1, 1, CREAM) # bọt
			d.p(13, 4, 1, 1, CREAM)
		_:
			var colors := [Color("2e7d32"), Color("c99a1a"), Color("2e7d32")]
			var spots := [Vector2i(0, 12), Vector2i(8, 12), Vector2i(4, 6)]
			for i in 3:
				var o: Vector2i = spots[i]
				var c: Color = colors[i]
				d.p(o.x, o.y, 8, 6, c.darkened(0.35))
				d.p(o.x + 1, o.y + 1, 6, 4, c)
				for b in 3:
					d.p(o.x + 1 + b * 2, o.y, 1, 1, PAPER)
				d.p(o.x + 2, o.y + 2, 4, 1, c.darkened(0.2))


# --- Trên cửa (11x11): "phuc" chữ Phúc hình thoi / "wreath" vòng hoa nơ đỏ ------------

static func _door(d: Pen, style: String) -> void:
	if style == "wreath":
		var leaf := Color("3f8a3a")
		d.p(3, 0, 5, 2, leaf)
		d.p(1, 1, 2, 3, leaf)
		d.p(8, 1, 2, 3, leaf)
		d.p(0, 3, 2, 5, leaf)
		d.p(9, 3, 2, 5, leaf)
		d.p(1, 7, 2, 3, leaf)
		d.p(8, 7, 2, 3, leaf)
		d.p(3, 9, 5, 2, leaf)
		for b in [Vector2i(2, 2), Vector2i(8, 6), Vector2i(1, 6), Vector2i(6, 0)]:
			d.p(b.x, b.y, 1, 1, RED) # quả đỏ
		d.p(3, 8, 2, 2, RED) # nơ
		d.p(6, 8, 2, 2, RED)
		d.p(5, 9, 1, 1, RED_DARK)
		return
	for i in 6: # hình thoi viền vàng, ruột đỏ
		d.p(5 - i, i, 1 + i * 2, 1, GOLD)
		d.p(5 - i, 10 - i, 1 + i * 2, 1, GOLD)
	for i in 5:
		d.p(5 - i, i + 1, 1 + i * 2, 1, RED)
		d.p(5 - i, 9 - i, 1 + i * 2, 1, RED)
	d.p(4, 3, 3, 1, GOLD)
	d.p(5, 4, 1, 3, GOLD)
	d.p(3, 6, 5, 1, GOLD)
