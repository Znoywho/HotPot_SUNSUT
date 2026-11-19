<div align="center">

<img src="docs/screenshots/logo.png" alt="Sôi Sùng Sục" width="560">

**Săn nguyên liệu bằng đánh theo lượt · Nấu lẩu · Bán cho khách · Đạt KPI mỗi ngày**

[![Chơi trên itch.io](https://img.shields.io/badge/Ch%C6%A1i%20ngay-itch.io-FA5C5C?style=for-the-badge&logo=itchdotio&logoColor=white)](https://znoywho.itch.io/soi-sung-suc)
<br>
![Godot 4.7.2](https://img.shields.io/badge/Godot-4.7.2-478CBF?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-355570)
![Web](https://img.shields.io/badge/N%E1%BB%81n%20t%E1%BA%A3ng-Web%20%C2%B7%20Desktop%20%C2%B7%20Mobile-2ea44f)

<img src="docs/screenshots/main_menu.png" alt="Menu chính" width="100%">

</div>

## Giới thiệu

**Sôi Sùng Sục** là game 2D pixel về một quán lẩu trên đỉnh núi. Mỗi ngày gồm 3 buổi:

| Buổi | Việc cần làm |
|---|---|
| **Sáng · Đi săn** (2:30) | Chọn bụi cỏ, đánh quái rau củ theo lượt để lấy nguyên liệu; đủ trận thì mở Boss |
| **Trưa · Nấu** (2:30) | Sơ chế nguyên liệu bằng mini-game, nấu nước cốt trên nhiều bếp |
| **Chiều tối · Bán** (3:15) | Xếp khách vào bàn, bưng lẩu, dọn bàn và sàn, giữ sao đánh giá |

Cuối ngày tổng kết **KPI**: không đạt là thua, đạt thì vào **cửa hàng nâng cấp** (Bếp · Chiến đấu · Quán) rồi sang ngày mới — KPI tăng dần theo doanh thu.
Chơi được bằng chuột trên máy tính và **cảm ứng trên điện thoại** (màn ngang).

## Ảnh chụp

<table>
  <tr>
    <td width="50%"><img src="docs/screenshots/hunt_map.png" alt="Chọn bụi cỏ để săn"><p align="center"><b>Sáng:</b> chọn bụi cỏ để săn</p></td>
    <td width="50%"><img src="docs/screenshots/battle.png" alt="Trận đánh theo lượt"><p align="center"><b>Đánh theo lượt</b> với quái rau củ</p></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/cook.png" alt="Bếp"><p align="center"><b>Trưa:</b> sơ chế và nấu nước cốt</p></td>
    <td><img src="docs/screenshots/sell.png" alt="Quán lẩu"><p align="center"><b>Chiều tối:</b> phục vụ 10 bàn khách</p></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/clean_panel.png" alt="Dọn dẹp"><p align="center"><b>Dọn dẹp</b> bàn, rác, vũng nước</p></td>
    <td><img src="docs/screenshots/shop.png" alt="Cửa hàng nâng cấp"><p align="center"><b>Cửa hàng nâng cấp</b> sau mỗi ngày</p></td>
  </tr>
</table>

<sub>Ảnh chụp ở Ngày 8, đã nâng cấp bàn, bếp và nhân viên.</sub>

**Nhóm:** Lê Thiên Hạo · Đỗ Hoàng Hải · Nguyễn Ngọc Minh Tuấn

## Cài đặt

- **Godot 4.7.2** (bản thường, không phải .NET). Cả nhóm dùng **cùng phiên bản**.
- Mở Godot → Import → chọn `project.godot` → F5 để chạy.

## Chơi trên web / đẩy lên itch.io

```bash
./tools/build_web.sh          # export ra build/web và build/soi-sung-suc-web.zip
./tools/build_web.sh serve    # thử trên trình duyệt: http://localhost:8000
./tools/build_web.sh push     # đẩy lên itch.io (cần butler login + ITCH_TARGET)
```

Cần cài export templates 4.7.2. Chi tiết xem mục "Phát hành lên itch.io" trong [`docs/PLAN.md`](docs/PLAN.md).
Asset bên ngoài phải ghi vào [`CREDITS.md`](CREDITS.md).

## Vòng lặp game

```
Menu → [Sáng: Săn 2:30] → [Trưa: Nấu] → [Chiều tối: Bán 4:00] → Tổng kết KPI
                ↑                                                   │
                └──────────── Cửa hàng nâng cấp ←── đạt ────────────┤
                                                    không đạt → Game Over
```

## Cấu trúc

| Thư mục | Nội dung |
|---|---|
| `autoload/` | `GameState` (tiền, ngày, KPI, kho, nâng cấp), `DayManager` (chuyển phase, đồng hồ), `SaveManager`, `Database` (danh sách dữ liệu) |
| `data/classes/` | Class Resource: `CombatantData`, `BrothData`, `UpgradeData` |
| `data/combatants/`, `broths/`, `upgrades/` | File `.tres` chứa **số liệu cân bằng**. Chỉnh trong Inspector, không cần sửa code |
| `scenes/hunt/combat/` | `Battle` (ATB theo tốc đánh), `Combatant`, `Passive`, `StatusEffect` |
| `scenes/hunt/combat/passives/` | Nội tại từng quái |
| `scenes/common/screen_base.gd` | Khung UI tạm |
| `assets/` | Hình, âm thanh, font (Be Vietnam Pro: có dấu tiếng Việt, dùng làm font mặc định) |
| `tools/build_web.sh` | Export bản Web và push lên itch.io |

**Thêm dữ liệu mới:** tạo `.tres` (chuột phải → New Resource → chọn class), rồi thêm vào `autoload/database.gd`.

**Thêm nội tại mới:** tạo script `extends Passive`, override hook cần dùng (`on_damaged`, `on_death`, ...), rồi kéo vào ô `passive` của quái.

## Phân công

| Người | Mảng | Tìm `TODO(...)` |
|---|---|---|
| Hạo | Core loop, KPI, cửa hàng nâng cấp, save/load, tích hợp | `TODO(Hạo)` |
| Hải | Săn nguyên liệu: combat UI, nội tại, boss, đồ rơi | `TODO(Hải)` |
| Tuấn | Nấu và bán hàng: bếp, khách, bàn, xe đẩy, tip, sao | `TODO(Tuấn)` |
| Cả nhóm | Các con số cần chốt | `TODO(nhóm)` |

Kế hoạch 3 tuần: [`docs/PLAN.md`](docs/PLAN.md)

## Dùng Claude Code

Phân công và quy tắc cho Claude nằm trong [`.claude/CLAUDE.md`](.claude/CLAUDE.md) (mã task S01–S25).
Mỗi người tạo file `CLAUDE.local.md` ở thư mục gốc (đã nằm trong `.gitignore`) để Claude biết mình là ai.
Claude chỉ sửa code trong phần của bạn, thấy lỗi ở phần người khác thì báo lại chứ không tự sửa.

**Hải:**
```markdown
# Current user
- I am Member 2 — Đỗ Hoàng Hải, responsible for hunting/combat and art assets.
- My area: `scenes/hunt/`, `data/combatants/`, `assets/sprites/`, `CREDITS.md` entries (see task list in `.claude/CLAUDE.md`).
- Everything else belongs to Member 1 (Hạo) or Member 3 (Tuấn): report issues there, do not edit.
```

**Tuấn:**
```markdown
# Current user
- I am Member 3 — Nguyễn Ngọc Minh Tuấn, responsible for the kitchen and restaurant (cook & sell).
- My area: `scenes/cook/`, `scenes/sell/`, `data/broths/` (see task list in `.claude/CLAUDE.md`).
- Everything else belongs to Member 1 (Hạo) or Member 2 (Hải): report issues there, do not edit.
```

## Quy ước

- Tên file/thư mục `snake_case`, class `PascalCase`, thụt lề bằng **tab**.
- **Không để 2 người cùng sửa một file `.tscn`**, vì file scene rất dễ conflict khi merge.
- Mỗi tính năng làm trên một branch riêng (`feat/hunt-ui`, ...), merge vào `main` khi đã chạy được.
- Không commit thư mục `.godot/` (đã có trong `.gitignore`).
- **Game phải chơi được bằng cảm ứng trên điện thoại** (màn ngang): nút to, không dùng hover/tooltip, chuột phải hay bàn phím. Chi tiết trong `docs/PLAN.md`.
