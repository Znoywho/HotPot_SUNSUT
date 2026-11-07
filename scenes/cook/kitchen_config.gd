class_name KitchenConfig
extends Resource
## Số liệu cân bằng của khu bếp (sơ chế, nấu, nhân viên). Sửa trong data/broths/kitchen_config.tres.
## Số bếp = 1 + cấp "Bếp xịn"; số phần mỗi lần nấu = giá trị nâng cấp "Nồi";
## số nhân viên = giá trị nâng cấp "Nhân viên bếp"; ngày giữ đồ thêm = nâng cấp "Kho lạnh".

@export_group("Bếp nấu")
@export var max_stoves := 6 ## Bếp tối đa trong khu bếp.
@export var gas_stove_from := 2 ## Bếp thứ mấy trở đi là bếp ga inox (trước đó là bếp lò đá).
@export var keep_ratio_on_leave := 0.5 ## Hết giờ / mở quán sớm: nồi đã nấu được >= 50% coi như chín, còn lại hoàn nguyên liệu.

@export_group("Sơ chế")
@export var prep_session_max := 5 ## Mỗi lượt sơ chế làm tối đa bao nhiêu phần.
## Cách sơ chế theo nguyên liệu: chop = chạm liên tục để thái, wash = rửa rồi vuốt để cắt,
## sort = kéo vào rổ sạch, peel = giữ để bóc vỏ. Nguyên liệu không có trong bảng dùng "chop".
@export var prep_methods := {
	"beef": "chop",
	"chili": "chop",
	"tomato": "wash",
	"greens": "wash",
	"mushroom": "sort",
	"enoki": "sort",
	"shrimp": "peel",
}
@export var chop_taps_per_unit := 6 ## Số nhát dao cho 1 phần.
@export var wash_taps_per_unit := 2 ## Số lần chạm để rửa sạch 1 phần.
@export var swipe_min_distance := 70.0 ## Vuốt dài tối thiểu (px) mới tính là 1 nhát cắt.
@export var peel_hold_seconds := 0.9 ## Giữ bao lâu để bóc xong 1 con tôm.

@export_group("Nhân viên")
@export var staff_prep_interval := 3.5 ## Mỗi phụ bếp sơ chế 1 phần sau mỗi bấy nhiêu giây.
@export var prep_staff_max := 2 ## Số phụ bếp tối đa (cấp nhân viên lớn hơn thì thêm bếp phó).
@export var sous_chef_level := 3 ## Cấp nhân viên có bếp phó tự nấu khi bếp trống.
@export var sous_chef_delay := 1.5 ## Bếp phó đợi bấy nhiêu giây rồi mới tự nấu (để người chơi chọn trước).
@export var staff_target_batches := 2 ## Phụ bếp giữ sẵn đồ sơ chế đủ cho bấy nhiêu mẻ mỗi món.


func method_for(id: String) -> String:
	return str(prep_methods.get(id.trim_prefix(GameState.GOLDEN_PREFIX), "chop"))
