class_name KitchenConfig
extends Resource
## Số liệu cân bằng của khu bếp (nấu, nhân viên). Sửa trong data/broths/kitchen_config.tres.
## Số liệu sơ chế (chấm điểm, chất lượng, sơ chế nhanh) nằm ở data/prep/prep_config.tres.
## Số bếp = 1 + cấp "Bếp xịn"; số phần mỗi lần nấu = giá trị nâng cấp "Nồi";
## số nhân viên = giá trị nâng cấp "Nhân viên bếp"; ngày giữ đồ thêm = nâng cấp "Kho lạnh".

@export_group("Bếp nấu")
@export var max_stoves := 6 ## Bếp tối đa trong khu bếp.
@export var gas_stove_from := 99 ## Bếp thứ mấy trở đi là bếp ga inox (99 = mọi bếp đều là bếp lò đá giống nhau).
@export var keep_ratio_on_leave := 0.5 ## Hết giờ / mở quán sớm: nồi đã nấu được >= 50% coi như chín, còn lại hoàn nguyên liệu.

@export_group("Nhân viên")
@export var staff_prep_interval := 3.5 ## Mỗi phụ bếp sơ chế nhanh 1 phần (chất lượng PrepConfig.quick_quality) sau mỗi bấy nhiêu giây.
@export var prep_staff_max := 2 ## Số phụ bếp tối đa (cấp nhân viên lớn hơn thì thêm bếp phó).
@export var sous_chef_level := 3 ## Cấp nhân viên có bếp phó tự nấu khi bếp trống.
@export var sous_chef_delay := 1.5 ## Bếp phó đợi bấy nhiêu giây rồi mới tự nấu (để người chơi chọn trước).
@export var staff_target_batches := 1 ## Phụ bếp giữ sẵn đồ sơ chế đủ cho bấy nhiêu mẻ mỗi món.
