# Prompt: Quy trình sơ chế nguyên liệu (Sôi Sùng Sục)

> Dán toàn bộ khối bên dưới vào AI (Claude Code, ChatGPT...) khi cần sửa, mở rộng hoặc cân bằng phần sơ chế.
> Phần trong `<...>` là chỗ bạn điền yêu cầu cụ thể.

---

```
Bạn đang làm việc trên game Godot 4.7.2 (GDScript, GL Compatibility, xuất Web cho itch.io,
chơi được trên điện thoại cầm ngang bằng cảm ứng). Tên game: "Sôi Sùng Sục" — đi săn nguyên liệu
buổi sáng, nấu lẩu buổi trưa, bán buổi tối, đạt KPI để sang ngày mới.

## Bối cảnh: quy trình chế biến nguyên liệu (buổi trưa, 75 giây, giờ vẫn chạy)

Luồng: Kho lạnh (đồ thô) -> Sơ chế (trò chơi nhỏ) -> Kho đã sơ chế -> Nấu trên bếp -> Nồi chín vào kho nồi -> Mở quán.

Quy tắc:
1. Chỉ nấu được bằng nguyên liệu ĐÃ SƠ CHẾ. Đồ thô nằm trong kho lạnh, giữ được `GameState.shelf_days()`
   ngày (3 ngày, +1 mỗi cấp nâng cấp "Kho lạnh", tối đa 6). Đồ đã sơ chế chỉ dùng trong ngày.
2. Mỗi phần sơ chế xong gọi `GameState.prep_items(id, 1)`: trừ 1 phần kho thô, cộng 1 phần kho đã sơ chế.
3. Mỗi lượt sơ chế làm tối đa `prep_session_max` = 5 phần. Có thể sơ chế mẻ sau trong lúc mẻ trước đang nấu.
4. Bảng sơ chế (`prep_panel.gd`) đè lên khu bếp: bên trái là danh sách nguyên liệu cần cho các món hôm nay
   (thô / đã sơ chế / còn thiếu), bên phải là trò sơ chế đang chơi. Làm xong tự gợi ý nguyên liệu đang thiếu tiếp theo.
5. Nấu: lấy đồ bằng `GameState.consume_prepped_info(recipe)`; nếu hủy thì `GameState.refund_prepped(taken)`.
   Thời gian nấu = `cook_time × hệ số "Bếp xịn"`. Số phần mỗi nồi = giá trị nâng cấp "Nồi" (4 -> 10).
6. Hết giờ hoặc mở quán sớm: nồi đã nấu >= 50% (`keep_ratio_on_leave`) tính là chín, còn lại trả đồ sơ chế về kho.
7. Nhân viên bếp (nâng cấp "Nhân viên bếp"): cấp 1–2 có phụ bếp tự sơ chế 1 phần mỗi 3,5 giây,
   giữ sẵn đủ đồ cho `staff_target_batches` mẻ mỗi món; cấp 3 có bếp phó tự nấu món đắt nhất khi có bếp trống
   (đợi 1,5 giây để người chơi chọn trước).
8. Nguyên liệu vàng (id có tiền tố `GameState.GOLDEN_PREFIX`) dùng chung cách sơ chế với nguyên liệu thường.

## 4 trò sơ chế (mỗi trò là 1 lớp con của `PrepGame` trong `scenes/cook/prep_game.gd`)

| Cách | Nguyên liệu | Thao tác | Số liệu |
|---|---|---|---|
| chop  (Thái)          | beef, chili      | Chạm liên tục vào thớt / nút THÁI!                 | `chop_taps_per_unit` = 6 nhát / phần |
| wash  (Rửa rồi cắt)   | tomato, greens   | Chạm từng quả trong bồn để rửa, rồi vuốt ngang trên thớt để cắt | `wash_taps_per_unit` = 2, `swipe_min_distance` = 70 px |
| sort  (Nhặt)          | mushroom, enoki  | Kéo từng cây từ rổ bẩn sang rổ sạch                | 1 lần kéo / phần |
| peel  (Bóc vỏ)        | shrimp           | Nhấn và giữ vào con tôm đến khi vòng tròn đầy      | `peel_hold_seconds` = 0,9 giây |

Nguyên liệu không có trong `prep_methods` mặc định dùng "chop".
Mỗi phần xong phát signal `unit_done`; xong hết phát `all_done`. Lớp con override:
`title()`, `hint()`, `partial()` (tiến độ phần đang làm, 0..1), `status_text()`, `_build()`, `_gui_input()`.

Công thức lẩu hiện tại (`data/broths/*.tres`, mỗi mẻ):
- Lẩu nấm: enoki 2, mushroom 2 — nấu 8 s
- Lẩu Mala: beef 1, chili 1, greens 2 — 9 s
- Lẩu cà chua bò: beef 2, tomato 2 — 10 s
- Lẩu Thái: shrimp 2, enoki 1, chili 1 — 12 s
- Lẩu hoàng gia: beef 2, shrimp 2, mushroom 1 — 15 s

## File liên quan
- `scenes/cook/prep_game.gd` (khung chung), `prep_chop.gd`, `prep_wash.gd`, `prep_sort.gd`, `prep_peel.gd`
- `scenes/cook/prep_panel.gd` (bảng sơ chế), `cook_phase.gd`, `stove_slot.gd`, `kitchen_actor.gd`
- `scenes/cook/kitchen_config.gd` + `data/broths/kitchen_config.tres` (MỌI số cân bằng nằm ở đây)
- `autoload/game_state.gd`: `prep_items`, `add_prepped`, `get_prepped_count`, `has_prepped`,
  `consume_prepped_info`, `refund_prepped`, `shelf_days`
- Sprite: `assets/sprites/kitchen/` (pixel art 32×32, phóng to bằng scale, texture filter Nearest)

## Ràng buộc bắt buộc
- Cảm ứng: nút cao >= 56 px, chữ >= 18 px; không dùng hover, tooltip, chuột phải, phím tắt là thao tác chính;
  kéo thả phải làm được bằng ngón tay (dùng sự kiện chuột trái, Godot giả lập chạm thành chuột).
- Font Be Vietnam Pro KHÔNG có glyph `→ ▶ ★` và emoji — dùng `» ›` hoặc icon ảnh.
- Web đơn luồng: không dùng thread. Âm thanh `.ogg`. Asset nhỏ.
- Số cân bằng để trong `.tres`, không hardcode trong script.
- Không đổi public API của autoload / `data/classes/*.gd` / `scenes/common/screen_base.gd`
  khi chưa báo người phụ trách. Định danh code bằng tiếng Anh, comment tiếng Việt.
- Sau khi sửa chạy: `godot --headless --path . --quit-after 60` (không in gì = không lỗi script).

## Nhiệm vụ
<Mô tả việc cần làm. Ví dụ:
 - Thêm cách sơ chế mới "slice" (vuốt chéo) cho nguyên liệu squid, dùng cho món Lẩu hải sản mới.
 - Thêm chất lượng sơ chế: làm nhanh/chính xác -> phần "ngon" bán giá cao hơn 10%.
 - Cân bằng lại: người chơi nấu được khoảng 6–7 mẻ trong 75 giây ở ngày 1.>

Trước khi viết code: đọc các file liên quan ở trên, tóm tắt ngắn cách bạn sẽ làm và file nào sẽ sửa.
Sau khi xong: liệt kê thay đổi, số liệu mới đã thêm vào `.tres`, và cách thử trong game.
```
