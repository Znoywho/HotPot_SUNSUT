# Kế hoạch: Kho lạnh – Sơ chế – Nấu ăn

**Dành cho:** Hạo (logic, dữ liệu, cửa hàng) và Hải (giao diện, art, hiệu ứng).
**Phần bán (Tuấn):** chỉ cần dùng thêm "chất lượng nồi" khi tính giá (mục 3.4).
**Trạng thái:** bản nháp để cả nhóm góp ý, chưa có code.

## 0. Cần chốt trước khi làm

1. `scenes/cook/` và `data/broths/` hiện thuộc Tuấn (theo `.claude/CLAUDE.md`). Nếu giao cho Hạo và Hải thì Tuấn cần đồng ý bàn giao, rồi sửa lại mục phân công.
2. Không ai sửa chung một file scene. Tách scene nhỏ (mục 5), mỗi người sở hữu file riêng.
3. Năm câu hỏi mở ở cuối file (mục 8).

## 1. Vòng chơi buổi trưa (75 giây)

```
Kho lạnh  ->  Sơ chế (thớt)  ->  Nấu (bếp)  ->  Nồi chín vào kho nồi  ->  Mở quán
```

Sơ chế mẻ sau trong lúc mẻ trước đang nấu, nên người chơi luôn có việc làm. Nút "Mở quán sớm" vẫn giữ.

## 2. Thiết kế

### 2.1 Kho lạnh
- Hiện nay: mọi nguyên liệu và nồi giữ được 3 ngày (`GameState.SHELF_DAYS`).
- Mới: nâng cấp **Kho lạnh** cấp 0 đến 3, mỗi cấp thêm 1 ngày hạn (3 → 6 ngày), áp dụng cho cả nguyên liệu và nồi. Hạn tính theo cấp hiện tại.
- Trong màn nấu: bấm cửa kho lạnh thì mở bảng Kho (`StoragePopup` đã có), cửa có hoạt ảnh mở và đóng.
- Bản sau: kho có sức chứa, đồ vượt sức chứa chỉ giữ 3 ngày.

### 2.2 Sơ chế
- Mỗi nguyên liệu có 2 trạng thái: **thô** và **đã sơ chế** (kèm chất lượng 0–100%).
- Thao tác (cảm ứng được):
  1. Chạm nguyên liệu trong kho để đặt lên thớt.
  2. Mini-game "nhịp dao": thanh trượt chạy qua lại, chạm khi vào vùng xanh. Mỗi phần cần 3 nhát, mỗi nhát được Hoàn hảo, Tốt hoặc Trượt. Chất lượng phần là trung bình 3 nhát.
- Nút **Sơ chế nhanh**: tự động, chất lượng cố định 60%, tốn thời gian gấp đôi. Dành cho ai không muốn chơi mini-game (cũng an toàn cho điện thoại).
- Số thớt = 1 + cấp nâng cấp **Thớt** (tối đa 3 thớt), sơ chế song song.
- Dùng nguyên liệu **thô** vẫn nấu được (không chặn người chơi), nhưng chất lượng tính là 50%.

### 2.3 Nấu
- Số bếp = 1 + cấp nâng cấp **Bếp** (tối đa 4). Mỗi bếp một nồi.
- Chọn món, trừ nguyên liệu (lô cũ nhất trước, ưu tiên đã sơ chế). Thanh tiến độ, lửa, hơi nước, chín thì chạm để thu nồi (hoặc tự thu).
- **Mẻ:** một lần nấu ra nhiều phần, `pots_per_batch = 5 + cấp Nồi`. Thời gian nấu = `cook_time × hệ số bếp` (đã có).
- **Chất lượng nồi** = trung bình chất lượng nguyên liệu. Hệ số giá = `0,7 + 0,45 × chất lượng`, tức từ ×0,7 (toàn đồ thô) đến ×1,15 (hoàn hảo).
- Nấu từ nguyên liệu quá hạn: nồi vẫn mang cờ `expired` như hiện nay.
- Bản sau: "canh lửa" (giữ lửa trong vùng an toàn để khỏi cháy).

### 2.4 Phần bán (Tuấn)
- Giá thu = `price × hệ số chất lượng`. Chất lượng ≥ 90% thì tăng tỷ lệ tip.
- Đồ nhúng: đĩa nhúng cũng sơ chế được (giai đoạn 3, nếu còn thời gian).

## 3. Dữ liệu và API (Hạo)

| Việc | Chi tiết |
|---|---|
| Lô kho có chất lượng | `item_batches` và `broth_batches` thêm trường `quality` (0 = thô). Gộp lô theo ngày, trạng thái hết hạn và mức chất lượng làm tròn 10%. |
| API mới | `prep_items(id, count, quality)` chuyển thô sang đã sơ chế (giữ ngày nhập). `consume_items_info(req, prefer_prepped)` trả thêm `avg_quality`. `take_broth_info` trả thêm `quality`. `shelf_days()` thay hằng số. |
| Giữ tương thích | Giữ nguyên tên hàm cũ, chỉ thêm tham số tùy chọn (như lần làm kho theo lô). Save cũ: mọi lô coi như `quality = 0`. |
| `BrothData` | Thêm `pots_per_batch`. File này là foundation (`data/classes/`), cần báo cả nhóm trước khi sửa. |
| Nâng cấp | `cold_storage`, `prep_board` trong `data/upgrades/` + `database.gd`, hiện trong cửa hàng. `stove` và `pot` dùng lại. |
| Cân bằng | Công thức nguyên liệu mỗi mẻ, số liệu ở mục 6, mô phỏng lại như lần cân bằng săn. |

## 4. Giao diện và art (Hải)

**Cấu trúc scene mới** (mỗi file một chủ):
- `cook_phase.gd` / `.tscn`: khung và điều phối. Hạo giữ.
- `prep_station.gd` / `.tscn`: thớt, thanh nhịp dao, danh sách nguyên liệu. Hải.
- `stove_view.gd` / `.tscn`: bếp, nồi, lửa, hơi nước, thanh tiến độ. Hải.
- `cold_storage.gd` / `.tscn`: cửa kho lạnh. Hải.

**Bố cục:** theo bản mẫu bếp (`kitchen_v2.png`): kho lạnh bên trái, thớt và bếp dọc tường, xe đẩy bên phải. Nút ≥ 56px, chữ ≥ 18px, không hover.

**Asset cần vẽ:**
- Nền bếp, cửa kho lạnh (đóng, mở), thớt có dao.
- Bếp 3 trạng thái (trống, đang nấu, chín) cho 5 loại nước cốt, lửa, hơi nước, bong bóng.
- Icon nguyên liệu thô và đã sơ chế (huy hiệu), thanh chất lượng.
- Âm thanh: băm thớt, nước sôi, tiếng "ting" khi chín (nguồn CC0, ghi vào CREDITS).

## 5. Thứ tự làm

| ID | Việc | Ai | Phụ thuộc |
|---|---|---|---|
| M0 | Chốt câu hỏi mở, chốt API (mục 3) | cả nhóm | không |
| S30 | `GameState`: lô có chất lượng, API mới, migrate save, test logic | Hạo | M0 |
| S31 | Nâng cấp Kho lạnh, Thớt trong cửa hàng; `shelf_days()` | Hạo | S30 |
| S32 | `BrothData` + 5 file `.tres`, công thức theo mẻ | Hạo | M0, Tuấn đồng ý |
| S33 | `prep_station` (thanh nhịp, thớt, trạng thái) | Hải | M0 (chạy bằng API giả trước) |
| S34 | `stove_view` (nồi, lửa, hơi, thu nồi) | Hải | M0 |
| S35 | Nền bếp và sprite (AI vẽ + ép về bảng màu game) | Hải | không |
| S36 | Ghép `cook_phase` mới | Hạo + Hải | S30, S33, S34 |
| S37 | Cân bằng bằng mô phỏng | Hạo | S36 |
| S38 | Test cảm ứng, bản web, sửa lỗi | cả nhóm | S37 |

Để Hải làm UI song song: Hạo viết sẵn bản API giả (trả số cứng) trong buổi đầu, rồi thay bằng bản thật ở S30.

**Bản sau (nếu dư thời gian):** canh lửa, đĩa nhúng sơ chế, nhân viên sơ chế tự động (gắn với S07), kho lạnh có sức chứa.

## 6. Số liệu khởi điểm (đặt trong `.tres`)

| Mục | Giá trị |
|---|---|
| Nhát cho 1 phần | 3 nhát, khoảng 1 giây mỗi nhát |
| Sơ chế nhanh | chất lượng 60%, thời gian ×2 |
| Thớt | 1 → 3 |
| Bếp | 1 → 4 |
| Phần mỗi mẻ | 5 + cấp Nồi |
| Thời gian nấu | 8–15 giây (như hiện nay) |
| Hệ số giá theo chất lượng | ×0,7 đến ×1,15 |
| Kho lạnh | +1 ngày hạn mỗi cấp, tối đa +3 |

**Tính thử:** một thớt và một bếp. Sơ chế 3 nguyên liệu mất khoảng 10 giây, nấu 10 giây chạy song song, nên khoảng 6 mẻ trong 75 giây, tức khoảng 30 phần. Buổi bán 195 giây có khoảng 32 khách, nên vừa khớp.

**Rủi ro cân bằng:** hiện công thức mỗi mẻ chỉ cần khoảng 3 nguyên liệu và săn được khoảng 45, nên nguyên liệu sẽ dư. Cần tăng công thức lên khoảng 6 nguyên liệu mỗi mẻ hoặc giảm lượng rơi (đang ×3). Chỉnh bằng mô phỏng ở S37.

## 7. Rủi ro và cách kiểm tra

- **Quá nhiều thao tác trong 75 giây:** có nút Sơ chế nhanh và tự thu nồi.
- **Đổi API `GameState` làm hỏng phần bán và save:** giữ tên hàm cũ, thêm tham số tùy chọn, test save cũ.
- **Hai người sửa cùng một scene:** tách scene như mục 4.
- **Cách test:** test logic không giao diện (FIFO kèm chất lượng, `shelf_days`, migrate save), mô phỏng 5 ngày, thử cảm ứng, bản web.

## 8. Câu hỏi mở

1. Giao phần nấu cho Hạo và Hải, Tuấn giữ phần bán có được không?
2. Một mẻ ra bao nhiêu phần (đề xuất 5 + cấp Nồi)?
3. Nguyên liệu thô có được nấu không (đề xuất có, chất lượng 50%)?
4. Kho lạnh bản đầu chỉ tăng hạn, hay phải có sức chứa ngay?
5. Mini-game nhịp dao bắt buộc hay tùy chọn (đề xuất có nút Sơ chế nhanh)?
