class_name RestaurantDecor
extends RefCounted
## Diện mạo nhà hàng theo nâng cấp — một bảng chung để bàn ghế, quầy lễ tân, rèm, đèn, cây, thảm
## cùng đổi theo MỘT cấp "Nội thất" (cả quán lên đời cùng lúc, không lệch nhau).
## Nhân viên trong quán khớp với nhân viên ở bếp (cùng cấp "Nhân viên bếp", cùng người):
##   cấp 1 Lan (đón khách), cấp 2 Tùng (bưng lẩu ra bàn), cấp 3 Minh (bếp phó, đứng cùng đầu bếp ở ô cửa bếp).
## Nồi lẩu giữ đúng hình ở bếp (nâng cấp "Nồi" là nấu ra nhiều phần hơn, không đổi hình nồi).
## Chỉ là hình ảnh; số liệu hiệu ứng vẫn nằm trong data/upgrades/*.tres.

## Cấp 0..5 của Nội thất.
## top/edge = mặt/khung gỗ bàn + quầy, chair = ghế, back = ghế có lưng tựa, cushion = đệm ghế,
## cloth = khăn trải (TRANSPARENT = không), trim = viền vàng, bowls = bát đũa bày sẵn,
## lamp = "bulb" (bóng trần) / "lantern" (đèn lồng đỏ) / "gold" (đèn lồng vàng),
## curtain = rèm cửa sổ, plants = chậu cây, carpet = thảm lối đi, fairy = dây đèn trang trí trên tường.
const FURNITURE_TIERS := [
	{"name": "Quán bình dân", "top": Color("9c572b"), "edge": Color("4a230d"), "chair": Color("6b4a2a"),
		"back": false, "cushion": Color.TRANSPARENT, "cloth": Color.TRANSPARENT, "trim": Color.TRANSPARENT, "bowls": 0,
		"lamp": "bulb", "curtain": Color.TRANSPARENT, "plants": false, "carpet": Color.TRANSPARENT, "fairy": false},
	{"name": "Gỗ sơn bóng", "top": Color("8a4a22"), "edge": Color("3b1c0a"), "chair": Color("5a2e14"),
		"back": true, "cushion": Color.TRANSPARENT, "cloth": Color.TRANSPARENT, "trim": Color.TRANSPARENT, "bowls": 1,
		"lamp": "lantern", "curtain": Color.TRANSPARENT, "plants": false, "carpet": Color.TRANSPARENT, "fairy": false},
	{"name": "Khăn đỏ, rèm đỏ", "top": Color("8a4a22"), "edge": Color("3b1c0a"), "chair": Color("5a2e14"),
		"back": true, "cushion": Color.TRANSPARENT, "cloth": Color("b3342b"), "trim": Color.TRANSPARENT, "bowls": 2,
		"lamp": "lantern", "curtain": Color("b3342b"), "plants": false, "carpet": Color.TRANSPARENT, "fairy": false},
	{"name": "Viền vàng, cây cảnh", "top": Color("7a3f1c"), "edge": Color("3b1c0a"), "chair": Color("4a2812"),
		"back": true, "cushion": Color("c0392b"), "cloth": Color("b3342b"), "trim": Color("e0b040"), "bowls": 2,
		"lamp": "lantern", "curtain": Color("b3342b"), "plants": true, "carpet": Color.TRANSPARENT, "fairy": false},
	{"name": "Nhung đỏ, thảm đỏ", "top": Color("6b3517"), "edge": Color("2a1306"), "chair": Color("3b1c0a"),
		"back": true, "cushion": Color("e0b040"), "cloth": Color("7a1f2b"), "trim": Color("f2c14e"), "bowls": 2,
		"lamp": "lantern", "curtain": Color("7a1f2b"), "plants": true, "carpet": Color("9a2430"), "fairy": true},
	{"name": "Gỗ quý khảm vàng", "top": Color("4a2412"), "edge": Color("f2c14e"), "chair": Color("2a1306"),
		"back": true, "cushion": Color("f2c14e"), "cloth": Color.TRANSPARENT, "trim": Color("f2c14e"), "bowls": 2,
		"lamp": "gold", "curtain": Color("7a1f2b"), "plants": true, "carpet": Color("9a2430"), "fairy": true},
]

const HOST_STAFF_LEVEL := 1 ## Lan đón khách ở quầy (ở bếp: phụ bếp thứ nhất).
const WAITER_STAFF_LEVEL := 2 ## Tùng bưng lẩu ra bàn (ở bếp: phụ bếp thứ hai).
const SOUS_STAFF_LEVEL := 3 ## Minh đứng cùng đầu bếp (ở bếp: bếp phó).


static func furniture_tier() -> int:
	return clampi(GameState.get_upgrade_level("furniture"), 0, FURNITURE_TIERS.size() - 1)


static func furniture() -> Dictionary:
	return FURNITURE_TIERS[furniture_tier()]


static func staff_level() -> int:
	return int(Database.upgrade_value("staff"))


static func has_host() -> bool:
	return staff_level() >= HOST_STAFF_LEVEL


static func has_waiter() -> bool:
	return staff_level() >= WAITER_STAFF_LEVEL


static func has_sous() -> bool:
	return staff_level() >= SOUS_STAFF_LEVEL
