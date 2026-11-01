# Sôi Sùng Sục

Game quản lý quán lẩu kết hợp chiến đấu theo lượt. Đồ án Godot.

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

Hiện tại mọi màn đều là **bản tạm**: nút bấm và log, kế thừa `ScreenBase`. Đủ để chơi thử trọn vòng lặp. Mỗi người thay màn của mình bằng UI thật.

## Cấu trúc

| Thư mục | Nội dung |
|---|---|
| `autoload/` | `GameState` (tiền, ngày, KPI, kho, nâng cấp), `DayManager` (chuyển phase, đồng hồ), `SaveManager`, `Database` (danh sách dữ liệu) |
| `data/classes/` | Class Resource: `CombatantData`, `BrothData`, `UpgradeData` |
| `data/combatants/`, `broths/`, `upgrades/` | File `.tres` chứa **số liệu cân bằng**. Chỉnh trong Inspector, không cần sửa code |
| `scenes/hunt/combat/` | `Battle` (ATB theo tốc đánh), `Combatant`, `Passive`, `StatusEffect` |
| `scenes/hunt/combat/passives/` | Nội tại từng quái (đang là TODO) |
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
