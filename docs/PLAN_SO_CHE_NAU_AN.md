# Khu bếp: sơ chế, nấu, nhân viên, kho lạnh (đã làm)

**Dành cho:** Hạo và Tuấn, để đọc trước khi review và gộp.
**Trạng thái:** đã làm xong trên branch `hai`, chạy thử bằng demo. Chưa test trên bản web và điện thoại.

## Vòng chơi buổi trưa (75 giây)

```
Kho lạnh -> Sơ chế (trò chơi nhỏ) -> Nấu (bếp) -> Nồi chín vào kho nồi -> Mở quán
```

- Chỉ nấu được bằng nguyên liệu **đã sơ chế**.
- Mỗi lần nấu ra nhiều phần lẩu.
- Có thể sơ chế mẻ sau trong lúc mẻ trước đang nấu.

## Đã làm

| Phần | Cách chơi | File |
|---|---|---|
| Sơ chế | 4 trò. **Thái** (bò, ớt): chạm liên tục. **Rửa rồi cắt** (cà chua, rau): chạm để rửa, vuốt để cắt. **Nhặt** (nấm, kim châm): kéo sang rổ sạch. **Bóc vỏ** (tôm): nhấn giữ. Mỗi lượt làm tối đa 5 phần. | `scenes/cook/prep_*.gd`, `prep_panel.gd` |
| Bếp | Lúc đầu 1 bếp. Mỗi cấp **Bếp xịn** mở thêm 1 bếp, tối đa 6 (2 bếp lò đá, sau đó là bếp ga). Thời gian nấu = `cook_time × hệ số Bếp xịn`. | `stove_slot.gd`, `cook_phase.gd` |
| Số phần mỗi lần nấu | Bằng giá trị nâng cấp **Nồi**: 4 phần ở cấp 0, +1 mỗi cấp, cấp 5 ra 10 phần. | `data/upgrades/pot.tres` |
| Nhân viên | Nâng cấp mới **Nhân viên bếp**. Cấp 1–2: phụ bếp Lan, Tùng tự sơ chế 1 phần mỗi 3,5 giây. Cấp 3: bếp phó Minh tự nấu món đắt nhất khi có bếp trống. | `data/upgrades/staff.tres` |
| Kho lạnh | Chạm tủ để mở bảng Kho. Bảng Kho có thêm mục "Đã sơ chế". Nâng cấp mới **Kho lạnh**: mỗi cấp giữ đồ thêm 1 ngày (3 → 6 ngày). | `data/upgrades/cold_storage.tres` |
| Kết thúc buổi | Hết giờ hoặc mở quán sớm: nồi đã nấu từ 50% trở lên được tính là chín, còn lại trả đồ sơ chế về kho. Mở sớm thì hỏi xác nhận. | `cook_phase.gd` |
| Ánh sáng theo giờ | Bám đồng hồ HUD: sáng ban ngày, chiều ngả vàng, sau 18h tối dần, bật đèn. Dùng cho cả bếp và nhà hàng. | `scenes/cook/day_light.gd` |

Số liệu cân bằng đặt trong `data/broths/kitchen_config.tres` (số nhát dao, thời gian giữ, nhịp phụ bếp...), cùng các file `.tres` của nước cốt và nâng cấp.

## Thay đổi ở file của người khác

**Hạo:**
- `autoload/game_state.gd`: thêm kho đã sơ chế, có lô theo ngày và hạn sử dụng.
  - Hàm mới: `prep_items`, `consume_prepped_info`, `refund_prepped`, `add_prepped`, `get_prepped_count`, `has_prepped`, `shelf_days`.
  - Save cũ vẫn đọc được. Các hàm cũ giữ nguyên.
- `autoload/database.gd`: đăng ký 2 nâng cấp mới.
- `data/upgrades/pot.tres`: values đổi thành số phần mỗi lần nấu `[4, 5, 6, 7, 8, 10]`. Bản cũ ghi 15–70 nhưng không chỗ nào dùng.
- `data/upgrades/stove.tres`: sửa mô tả.

**Tuấn:**
- `scenes/cook/`: viết lại toàn bộ màn nấu.
- `data/broths/*.tres`: công thức nhiều hơn vì mỗi mẻ ra nhiều phần, khoảng 4–5 nguyên liệu mỗi mẻ.
- `scenes/sell/sell_phase.gd`: thêm vài dòng gắn ánh sáng theo giờ.

## Cần nhóm xem

1. **Doanh thu tăng khoảng 4 lần.** Mỗi mẻ ra 4 phần và nấu được khoảng 7 mẻ/ngày, tức khoảng 28 phần, gần bằng khoảng 32 khách ở buổi bán. Ước tính doanh thu ngày 1 khoảng 4 triệu (trước khoảng 900 nghìn). Giá nâng cấp và KPI có thể cần chỉnh theo.
2. **Sổ tổng kết chưa chạy tiếp được.** Trong `scenes/day_end/day_end.gd`, hàm `_on_continue_pressed()` vẫn để trống (TODO của Hạo), nên chưa sang được cửa hàng để mua nâng cấp.
3. **Chưa làm:** chất lượng sơ chế (ảnh hưởng giá bán) và khách gọi đồ nhúng. Hai phần này để sau.
