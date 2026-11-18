# Kế hoạch 3 tuần

## Phạm vi

| Mức | Nội dung |
|---|---|
| **MVP (bắt buộc)** | Vòng lặp ngày + KPI, săn theo lượt (6 quái + nội tại người chơi), nấu 2–3 nước cốt, bán hàng (khách, bàn, xe đẩy, tip, sao), shop cơ bản (Nồi, Bếp, Dao, Giáp, Nội thất, bàn tầng 1), Game Over |
| **Nên có** | Boss + nguyên liệu hoàng kim, chí mạng, Thú cưỡi, Lầu 2, mốc ngày 5/10/15, save/load |
| **Nếu dư thời gian** | Bản tiến hóa max cấp, nhân viên, phòng riêng + lẩu 4 ngăn, nhiệm vụ, dọn bếp buổi tối (đoạn ngắn sau khi bán xong để thấy cửa sổ bếp đổi màu đêm; thêm một giai đoạn vào `DayManager` nên cần cả nhóm đồng ý) |

## Tiến độ (cập nhật 18/11, ngày 18/21)

Đã gộp vào `main` tới PR #14. Chờ review: #15 (cuộn cửa hàng trên điện thoại), #16 (Game Over + `PixelBar`), #17 (menu cài đặt, cần #16 trước), #18 (nguồn icon HUD). Kiểm tra headless: không lỗi script.

| Việc | Trạng thái | Còn thiếu |
|---|---|---|
| S01 HUD chung | Xong | |
| S02 Sổ tổng kết + Game Over | Xong (PR #16) | KPI ngày 1 chốt 300.000đ |
| S03 Shop chia tab | Xong | Cân bằng giá |
| S04 Nối hiệu ứng nâng cấp | Gần xong | Nồi, Bếp, Dao, Giáp, Nội thất, Thêm bàn, Phí phục vụ đã chạy |
| S05 Save/load, cài đặt | Xong (PR #17) | Tự lưu đầu ngày; menu cài đặt có âm lượng chung. Khi có nhạc thì tách Nhạc / Hiệu ứng |
| S06 Mốc ngày 5/10/15 | Gần xong | Quái mạnh dần, thêm quái/trận, mở nước cốt theo ngày đã có; chưa có thông báo khi tới mốc |
| S07 Lầu 2, phòng riêng | Chưa làm | Nhân viên bếp đã có (`staff.tres`) |
| S08 Build web, itch.io | Đang làm | Đã sửa cuộn cửa hàng trên điện thoại (PR #15); còn làm trang itch |
| S10–S12 Nội tại, battle view, nhiều quái | Xong | Chốt tỷ lệ độc Nấm, số nổ Bò tót |
| S13 Nâng cấp chiến đấu | **Thiếu data** | Code đọc `sharp_mind`, `hawk_eye`, `mount`, `battle_robe`, `dragon_blade` nhưng chưa có file `.tres` nên shop không bán được |
| S14 Boss, hoàng kim | Xong | Chốt chỉ số boss |
| S15 Asset | Gần xong | **Chưa có nhạc nền**; nguồn icon HUD đã ghi (PR #18) |
| S20–S24 Bếp, khách, xe đẩy, tip, sao | Xong | Test cảm ứng trên điện thoại |
| S25 Thêm nước cốt | Xong | 5 nước cốt |
| S16 Chuyển cảnh giữa các buổi (Hải) | Chưa làm | Màn chuyển sáng » trưa » tối » tổng kết |
| Thanh tiến độ thống nhất | Một phần | `PixelBar` (PR #16) dùng cho HUD, Game Over, Cài đặt; Hải đổi thanh máu, Tuấn đổi thanh nấu/sơ chế |
| Tutorial | Chưa làm | |

**Việc giao tiếp (18–19/11):**

| Người | Việc |
|---|---|
| Hải | (1) Tạo 5 file `.tres` nâng cấp chiến đấu: `sharp_mind`, `hawk_eye`, `mount`, `battle_robe`, `dragon_blade` (báo Hạo đăng ký vào `database.gd`). (2) **S16 Chuyển cảnh giữa các buổi**: sáng săn » trưa nấu » tối bán » sổ tổng kết, ví dụ màn tối dần/sáng dần hoặc trượt, kèm chữ "Buổi trưa", "Buổi tối". Làm thành scene riêng (vd `scenes/common/phase_transition.tscn`), gọi được từ `DayManager.go_to()`; phần sửa `DayManager` thì báo Hạo. Phải chạy mượt trên web, không chặn bấm sau khi chuyển xong. (3) Chốt tỷ lệ độc Nấm, số nổ Bò tót, chỉ số boss. (4) Nhạc nền `.ogg` 2–3 bài, ghi `CREDITS.md`. |
| Tuấn | (1) Test bếp và màn bán bằng cảm ứng (kéo thả, xe đẩy) trên điện thoại. (2) Chốt tỉ lệ số người mỗi nhóm khách (`sell_phase.gd:28`). (3) Cân bằng doanh thu cùng Hạo (doanh thu tăng khoảng 4 lần sau khi làm lại bếp). |
| Hạo | ~~Game Over UI thật~~, ~~menu cài đặt~~, ~~chốt KPI ngày 1~~, ~~nguồn icon HUD~~ (xong). Còn: trang itch, review/merge PR. |

**Ưu tiên còn lại:** (1) thêm `.tres` cho 5 nâng cấp chiến đấu, (2) chốt số `TODO(nhóm)` còn lại + cân bằng (ngày 19), (3) nhạc nền, (4) chuyển cảnh S16, (5) test web trên điện thoại, trang itch. Lầu 2/phòng riêng: cắt nếu không kịp.

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
