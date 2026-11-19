# Kế hoạch 3 tuần

## Phạm vi

| Mức | Nội dung |
|---|---|
| **MVP (bắt buộc)** | Vòng lặp ngày + KPI, săn theo lượt (6 quái + nội tại người chơi), nấu 2–3 nước cốt, bán hàng (khách, bàn, xe đẩy, tip, sao), shop cơ bản (Nồi, Bếp, Dao, Giáp, Nội thất, bàn tầng 1), Game Over |
| **Nên có** | Boss + nguyên liệu hoàng kim, chí mạng, Thú cưỡi, Lầu 2, mốc ngày 5/10/15, save/load |
| **Nếu dư thời gian** | Bản tiến hóa max cấp, nhân viên, phòng riêng + lẩu 4 ngăn, nhiệm vụ, dọn bếp buổi tối (đoạn ngắn sau khi bán xong để thấy cửa sổ bếp đổi màu đêm; thêm một giai đoạn vào `DayManager` nên cần cả nhóm đồng ý) |

## Tiến độ (cập nhật 19/11 trưa, ngày 19/21)

Đã gộp vào `main` tới PR #28, không còn PR chờ (ngoài PR cập nhật tiến độ này). Kiểm tra headless: không lỗi script; export web chạy được. **Bản trên itch.io vẫn là bản cũ** (chưa push).

**Tổng:** 22 việc (không tính 3 mục đã cắt) → 18 xong, 2 đang làm (S08, S15), 2 chưa làm (lượng rơi, số người mỗi nhóm khách); tính việc dở là ½ ≈ **86%**. Vòng chơi chính (săn → nấu → bán → KPI → nâng cấp) đã đủ, phần còn lại chủ yếu là nhạc, test điện thoại và trang itch.

| Việc | Ai | Trạng thái | Còn thiếu |
|---|---|---|---|
| S01 HUD chung | Hạo | Xong | |
| S02 Sổ tổng kết + Game Over | Hạo | Xong (#16) | |
| S03 Shop chia tab | Hạo | Xong | |
| S04 Nối hiệu ứng nâng cấp | Hạo | Xong (#27) | Đủ cả 5 nâng cấp chiến đấu |
| S05 Save/load, cài đặt | Hạo | Xong (#17) | Khi có nhạc thì tách âm lượng Nhạc / Hiệu ứng |
| S06 Mốc ngày 5/10/15 | Hạo | Xong | Quái mạnh dần + lượng rơi tăng theo mốc; cửa hàng báo "Mốc ngày N" |
| S07 Lầu 2, phòng riêng | Hạo | **Cắt** | |
| S08 Build web, itch.io | Hạo | Đang làm | **Đẩy bản mới**, trang itch (ảnh bìa 630×500, ảnh chụp có sẵn trong `docs/screenshots/`, mô tả) |
| Cân bằng giá nâng cấp, quái, KPI | Hạo | Xong (#20) | Cả nhóm chơi thử |
| Logo pixel, menu không lệch khi đổi cỡ màn | Hạo | Xong (#21, #25) | |
| README: logo, badge, ảnh chụp | Hạo | Xong (#25, #26) | |
| `PixelBar` thanh tiến độ chung | Hạo | Xong (#16) | Hải, Tuấn chưa đổi thanh của mình sang (còn `ProgressBar` ở `hunt_ui.gd`, `prep_panel.gd`, `stove_slot.gd`, `clean_panel.gd`) |
| S10–S12 Nội tại, battle view, nhiều quái | Hải | Xong | Chốt tỷ lệ độc Nấm, số nổ Bò tót (`TODO(nhóm)`) |
| S13 Nâng cấp chiến đấu | Hạo (thay Hải) | Xong (#27) | Đầu óc sắc bén, Mắt diều hâu, Trâu chiến, Long đao (max Dao), Chiến bào (max Giáp). **Hải không cần làm nữa**, chỉ cần chơi thử |
| S14 Boss, hoàng kim | Hải | Xong | Chốt chỉ số boss |
| S15 Asset | Hải | Gần xong | **Chưa có nhạc nền** (mới có 7 hiệu ứng `.ogg`) |
| S16 Chuyển cảnh giữa các buổi | Hạo (thay Hải) | Xong (#28) | Mờ tối + thẻ tên buổi; đồng hồ chạy khi màn mới đã hiện. **Hải không cần làm nữa** |
| Lượng rơi, phạt khi thua | Hải | Chưa làm | `drop_amount_multiplier` vẫn 3.0 (`scenes/hunt/hunt_config.gd:32`), đề xuất 2.0; phạt mất nửa đồ có thể cắt |
| Menu chính mới (mèo, trâu Thần Tài) | Hải | Xong | |
| S20–S24 Bếp, khách, xe đẩy, tip, sao | Tuấn | Xong | **Test cảm ứng trên điện thoại** |
| Dọn bàn, quét rác, lau vũng nước | Hải, Hạo | Xong (#22, #24) | Giảm tần suất bẩn, sửa bố cục bảng Dọn dẹp. Phần của Tuấn: **Tuấn cần xem lại** |
| S25 Thêm nước cốt | Tuấn | Xong | 5 nước cốt |
| Chốt số người mỗi nhóm khách | Tuấn | Chưa làm | `TODO(nhóm)` ở `sell_phase.gd:32` |
| Số phần theo nguyên liệu (issue #19) | Tuấn | **Cắt** | Đổi luật nấu sát ngày đóng băng dễ sinh lỗi |
| Tutorial | Nhóm | **Cắt** | Thay bằng mục "Cách chơi" trong mô tả trang itch |

**Việc còn lại (19–20/11):**

| Người | Việc, theo thứ tự ưu tiên |
|---|---|
| Hạo | (1) Đẩy bản mới lên itch (`./tools/build_web.sh push`) để cả nhóm chơi thử. (2) Trang itch: ảnh bìa, ảnh chụp, mô tả + "Cách chơi". (3) Review/merge PR. |
| Hải | (1) Nhạc nền `.ogg` 2–3 bài, ghi `CREDITS.md`. (2) `drop_amount_multiplier` 3.0 » 2.0. (3) Chơi thử Trâu chiến + chí mạng (PR #27). (4) Thanh máu sang `PixelBar` nếu còn thời gian. |
| Tuấn | (1) Test bếp và màn bán bằng cảm ứng trên điện thoại. (2) Xem lại PR #22, #24 (đụng `scenes/sell/`). (3) Chốt tỉ lệ số người mỗi nhóm khách. (4) Thanh nấu / sơ chế sang `PixelBar` nếu còn thời gian. |
| Cả nhóm | Chơi thử 3–5 ngày bản mới, ghi lỗi và cảm giác khó/dễ, nhất là giá 5 nâng cấp chiến đấu mới. |

**Mốc cuối:** ngày 20 đóng băng tính năng, sửa bug, export bản cuối, đổi trang itch sang Public. Ngày 21 báo cáo, slide, video demo.

## Tuần 1: Bản chơi được (xấu cũng được)

Khung project và vòng lặp tạm đã xong.

| Ngày | Hạo | Hải | Tuấn |
|---|---|---|---|
| 1–2 | Đọc code khung, chốt các `TODO(nhóm)` | Cài 6 nội tại + độc/đốt (`passives/`, `statuses/`) | Thiết kế scene bếp thật |
| 3–4 | HUD chung (tiền, ngày, KPI, đồng hồ) | `battle_view.tscn`: sprite, thanh máu, chọn mục tiêu | Khách vào, nhận bàn, gọi món |
| 5–7 | Màn KPI và Game Over đẹp hơn, chỉnh công thức KPI | Nối `Battle` vào UI, Linh hồn đầu bếp | Nấu theo thời gian, đặt món lên xe đẩy |

**Mốc:** chơi trọn 1 ngày bằng UI thật.

## Tuần 2: Đủ MVP

| Ngày | Hạo | Hải | Tuấn |
|---|---|---|---|
| 8–9 | Shop chia tab, mô tả nâng cấp | Combat nhiều quái, bò tót nổ AoE | Giao đúng bàn, đếm giờ chờ, khách bỏ về |
| 10–11 | Nối hiệu ứng Nồi, Bếp, Nội thất | Dao, Giáp, chí mạng | Tip, trừ sao, lượng khách theo sao |
| 12–14 | Save/load hoàn chỉnh, menu cài đặt | Boss, nguyên liệu hoàng kim | Bếp ảnh hưởng tốc độ nấu và thời gian ăn |

**Mốc:** chơi liên tục 5 ngày, cả nhóm test và ghi lỗi.

## Tuần 3: Tính năng phụ, polish, nộp bài

| Ngày | Việc |
|---|---|
| 15–16 | Mốc ngày, Thú cưỡi, Lầu 2 |
| 17–18 | Asset, âm thanh, hiệu ứng, tutorial |
| 19 | Cân bằng số (KPI +10% tăng rất nhanh) |
| 20 | Đóng băng tính năng, sửa bug, export bản build |
| 21 | Báo cáo, slide, video demo |

Trễ tiến độ thì cắt ngày 15–16, **giữ nguyên ngày 20–21**.

## Asset (Hải phụ trách)

**Chốt phong cách trước khi tìm.** Đề xuất pixel art 32×32. Không trộn nhiều pack lệch phong cách.
Tối đa **2 ngày** để chốt bộ asset chính, phần còn lại dùng placeholder rồi thay sau.

| Nhóm | Cần gì | Ưu tiên |
|---|---|---|
| Chiến đấu | 6 quái, đầu bếp, 1 boss, nền khu săn | Cao |
| Nguyên liệu | 6 icon, thêm bản hoàng kim (đổi màu vàng) | Cao |
| Quán | Sàn, tường, bàn ghế (nhiều cấp), xe đẩy, nồi lẩu, bếp | Cao |
| Khách | 3–5 kiểu người, animation đi và ngồi | Trung bình |
| UI | Panel, nút, icon tiền, icon sao (font có dấu đã có: Be Vietnam Pro) | Cao |
| Âm thanh | Nhạc nền 2–3 bài, tiếng đánh, sôi lẩu, tiền, chuông khách | Thấp (tuần 3) |

**Nguồn:** Kenney.nl (CC0), itch.io → Game Assets → Free, OpenGameArt.org, Freesound.org.
**Bắt buộc:** ghi mọi asset vào [`CREDITS.md`](../CREDITS.md). Dùng asset do AI tạo thì phải khai báo trên itch.io.
**Lưu ý cho bản web:** nhạc dùng `.ogg`, ảnh giữ kích thước nhỏ để game tải nhanh.

## Phát hành lên itch.io (bản Web)

Mục tiêu: người khác **bấm link là chơi ngay trên trình duyệt**, không cần cài gì.

**Chuẩn bị một lần (Hạo):**
1. Cài Godot 4.7.2 và export templates 4.7.2 (Editor → Manage Export Templates → Download).
2. Tạo trang itch.io: Kind = **HTML**, Visibility = **Draft**.
3. Cài [butler](https://itch.io/docs/butler/), chạy `butler login` một lần.
4. Điền `ITCH_TARGET` trong `tools/build_web.sh` (vd `tenban/soi-sung-suc`).
5. Lần upload đầu: trên trang itch, tick **"This file will be played in the browser"**, viewport **1280×720**, bật **Fullscreen button**.

**Mỗi lần cập nhật:**
```bash
./tools/build_web.sh serve   # thử ở http://localhost:8000
./tools/build_web.sh push    # đẩy lên itch.io
```
Không có butler thì upload tay file `build/soi-sung-suc-web.zip`.

**Chơi trên điện thoại:** game chạy được trên Chrome Android và Safari iOS 15+ (WebGL 2), ở màn hình ngang.
Trên trang itch: tick **Mobile friendly** và chọn **Orientation: Landscape**.

Quy tắc UI cảm ứng cho cả nhóm:
- Nút cao tối thiểu khoảng 56px, chữ từ 18px trở lên.
- **Không dùng hover/tooltip**, chuột phải hay bàn phím. Thông tin cần đọc phải hiện sẵn.
- Kéo thả (món lên xe đẩy, xếp bàn) phải dùng được bằng ngón tay.
- Không đặt nút sát mép màn hình (dễ bấm nhầm thanh điều hướng của điện thoại).

**Checklist mỗi lần push:**
- [ ] `./tools/build_web.sh serve`, chơi thử 1 ngày trên máy tính
- [ ] Push lên itch, mở link trên **điện thoại thật** ở màn hình ngang và bấm thử mọi nút
- [ ] Cầm dọc thì phải hiện thông báo "Xoay ngang điện thoại"
- [ ] Chữ có dấu hiển thị đúng, không có ô vuông

> Font Be Vietnam Pro **không có** ký tự `→ ▶ ★` và emoji (hiện thành ô vuông). Dùng `» ›` hoặc icon hình ảnh.

**Theo tuần:**
| Khi nào | Việc |
|---|---|
| Tuần 1 | Đẩy bản khung hiện tại lên trang Draft, chơi thử trên trình duyệt để bắt lỗi web sớm |
| Cuối tuần 2 | Đổi sang **Restricted**, gửi link cho bạn bè test |
| Ngày 19 | Làm trang: ảnh bìa **630×500**, 3–5 ảnh chụp màn hình, 1 GIF chiến đấu, mô tả, cách chơi, credits, tag |
| Ngày 20 | Bản build cuối, đổi sang **Public** |
| Ngày 21 | Gắn link itch.io vào báo cáo và slide |

## Cần chốt

- ~~KPI ngày 1~~: đã chốt 300.000đ.
- ~~Nồi~~: đã chốt, số phần mỗi lần nấu `[4, 5, 6, 7, 8, 10]`.
- Linh hồn đầu bếp: "lần thua đầu tiên" tính theo trận, theo buổi sáng hay theo cả game?
- Bò tót: nội năng tích lũy dùng để làm gì?
- Tỷ lệ gây độc của Nấm dược sư.
- ~~Nước cốt thừa~~: đã chốt, giữ trong kho lạnh 3–6 ngày theo cấp Kho lạnh.
- Chỉ số boss.
