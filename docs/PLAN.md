# Kế hoạch 3 tuần

## Phạm vi

| Mức | Nội dung |
|---|---|
| **MVP (bắt buộc)** | Vòng lặp ngày + KPI, săn theo lượt (6 quái + nội tại người chơi), nấu 2–3 nước cốt, bán hàng (khách, bàn, xe đẩy, tip, sao), shop cơ bản (Nồi, Bếp, Dao, Giáp, Nội thất, bàn tầng 1), Game Over |
| **Nên có** | Boss + nguyên liệu hoàng kim, chí mạng, Thú cưỡi, Lầu 2, mốc ngày 5/10/15, save/load |
| **Nếu dư thời gian** | Bản tiến hóa max cấp, nhân viên, phòng riêng + lẩu 4 ngăn, nhiệm vụ |

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

- KPI ngày 1 (đang để tạm 300.000đ).
- Nồi: doc ghi "15 → 20 món" nhưng cũng ghi "mỗi bậc +10".
- Linh hồn đầu bếp: "lần thua đầu tiên" tính theo trận, theo buổi sáng hay theo cả game?
- Bò tót: nội năng tích lũy dùng để làm gì?
- Tỷ lệ gây độc của Nấm dược sư.
- Nước cốt thừa có giữ sang ngày sau không?
- Chỉ số boss.
