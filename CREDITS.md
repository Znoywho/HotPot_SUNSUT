# Credits

**Sôi Sùng Sục**: Lê Thiên Hạo · Đỗ Hoàng Hải · Nguyễn Ngọc Minh Tuấn

Mọi asset bên ngoài **phải** được ghi vào đây trước khi commit. CC-BY bắt buộc ghi tác giả.
Giấy phép thường gặp: CC0 (tự do), CC-BY (ghi tác giả), OFL (font). Không dùng asset có ghi "NC" nếu sau này muốn bán game, và không dùng asset lấy từ game khác.

## Font

| Asset | Tác giả | Giấy phép | Link |
|---|---|---|---|
| Be Vietnam Pro | The Be Vietnam Pro Project Authors | SIL OFL 1.1 (`assets/fonts/OFL.txt`) | https://fonts.google.com/specimen/Be+Vietnam+Pro |
| Ark Pixel 12px (`assets/fonts/ArkPixel12-Vietnamese.ttf`, font chữ thường mặc định; nhóm cắt chỉ giữ chữ Latin + tiếng Việt và ghép thêm "› ‹" bằng `make_ark_pixel_vi.py`) | TakWolf | SIL OFL 1.1 (`assets/fonts/OFL-ArkPixel.txt`) | https://github.com/TakWolf/ark-pixel-font |
| `assets/fonts/pixel_title/*` (font tiêu đề pixel mập: chữ in hoa tiếng Việt đủ dấu + số, 5 bảng màu theo buổi / Game Over) | Nhóm tự làm (vẽ bằng code `make_pixel_title_font.py`, nét theo logo menu chính, không dùng font của ai) | Của nhóm | — |

## Hình ảnh

| Asset | Dùng cho | Tác giả | Giấy phép | Link |
|---|---|---|---|---|
| `assets/sprites/monsters/*.png` (17 quái + 3 boss, pixel 32×32, bản tạm) | Sprite toàn bộ quái và boss | Nhóm tự làm | Của nhóm | — |
| `assets/sprites/characters/player.png`, `mount_buffalo.png` (pixel 32×32, bản tạm) | Sprite đầu bếp, thú cưỡi Trâu nước | Nhóm tự làm | Của nhóm | — |
| `assets/sprites/characters/staff_lan.png`, `staff_tung.png`, `staff_minh.png` (pixel 32×32) | Nhân viên bếp: 2 phụ bếp + bếp phó | Nhóm tự làm | Của nhóm | — |
| `assets/sprites/kitchen/*.png` (nền bếp 320×180, kho lạnh, bàn sơ chế, bếp lò đá, bếp ga, lửa, nồi lẩu theo món, hơi nước, thớt, dao, bồn rửa, rổ, khay, đồ đã sơ chế) | Khu bếp và các trò sơ chế | Nhóm tự làm | Của nhóm | — |
| `assets/sprites/restaurant/*.png` (nền nhà hàng 320×180 ghép từ gạch nền bếp, cửa ra vào, đèn lồng, ô cửa bếp, lớp trời cửa sổ) | Màn bán hàng | Nhóm tự làm (`make_restaurant_bg.py`) | Của nhóm | — |
| `assets/sprites/characters/customer_*.png` (6 khách thường, nhà phê bình, giám khảo Michelin, sheet chạy) | Khách nhà hàng | Nhóm tự làm (`make_customers.py`) | Của nhóm | — |
| `assets/sprites/ingredients/*.png` (14 nguyên liệu + bản hoàng kim, pixel 32×32) | Icon nguyên liệu, đồ nhúng, ớt | Nhóm tự làm | Của nhóm | — |
| `assets/sprites/ingredients/prepped/*.png` (14 món đã sơ chế + bản hoàng kim, pixel 32×32, bày trên đĩa) | Icon đồ nhúng đã sơ chế (bò thái lát, mực khoanh, nghêu mở vỏ...). Tự vẽ bằng code, chỉ tham khảo ý tưởng bày món, không dùng file của Magnific/Freepik | Nhóm tự làm | Của nhóm | — |
| `assets/sprites/ui/broth_pot.png`, `assets/sprites/ui/hud/hud_star.png`, `hud_star_shine.png`, `hud_storage.png` (pixel) | Icon nồi lẩu, ngôi sao đánh giá (vẽ lại theo phong cách sao pixel tròn, không dùng ảnh gốc), nút kho trên HUD | Nhóm tự làm | Của nhóm | — |
| `assets/sprites/ui/hud/hud_coin.png`, `hud_calendar.png`, `hud_target.png`, `hud_clock.png` | Icon động trên HUD (đồng xu, lịch, bia KPI, đồng hồ) | Nhóm tự làm (Hạo vẽ) | Của nhóm | — |
| `assets/sprites/Eris Esra's Character Template 4.1/` | Mẫu nhân vật pixel (template) | Eris Esra | Miễn phí dùng trong game; game miễn phí **bắt buộc** ghi tác giả + link | https://erisesra.itch.io/character-templates-pack |
| `assets/sprites/backgrounds/hunt_background.png` (pixel 320×180) | Nền khu săn | Nhóm tự làm | Của nhóm | — |
| `assets/sprites/fx/burst.png`, `explosion_fire.png`, `explosion_big.png`, `smoke.png`, `splash_broth.png` (đổi màu từ "water blob") | Hiệu ứng nổ, chí mạng, khói, nước lẩu trong trận | Ansimuz (Luis Zuno) | CC0 | https://ansimuz.itch.io/explosion-animations-pack |
| `assets/sprites/fx/impact_star.png`, `slash_arc.png`, `bonk_star.png`, `shockwave.png`, `dust.png`, `broth_blob.png` | Hiệu ứng chiến đấu: tia chạm, vệt chém smear, sao bị muôi gõ, vòng xung kích, bụi chân, giọt nước lẩu (vẽ bằng code `make_combat_fx.py`, học kỹ thuật "game feel" / smear frame, không dùng file của ai) | Nhóm tự làm | Của nhóm | — |
| `assets/sprites/fx/slash.png`, `flame.png`, `poison.png`, `heal.png`, `shield.png` (16×16) | Hiệu ứng chém, đốt, độc, hồi máu, giáp (tự vẽ, lấy cảm hứng phong cách từ "Free Effect and Bullet 16x16" của BDragon1727, không dùng file gốc) | Nhóm tự làm | Của nhóm | — |
| `assets/sprites/ui/paper_*.png` (khung, thẻ, nút kiểu sổ giấy da) | Giao diện màn săn (tự vẽ, lấy cảm hứng phong cách từ Pocket Inventory Series của Humble Pixel, không dùng file gốc) | Nhóm tự làm | Của nhóm | — |

## Âm thanh

| Asset | Dùng cho | Tác giả | Giấy phép | Link |
|---|---|---|---|---|
| RPG Audio: `knifeSlice.ogg` -> `sfx/slice.ogg`, `metalPot1.ogg` -> `sfx/splash.ogg`, `handleCoins.ogg` -> `sfx/loot.ogg` | Âm thanh chiến đấu | Kenney (kenney.nl) | CC0 | https://kenney.nl/assets/rpg-audio |
| Impact Sounds: `impactPunch_medium_000` -> `hit`, `impactPunch_heavy_000` -> `crit`, `impactSoft_heavy_000` -> `defeat`, `impactMining_000` -> `explosion` | Âm thanh chiến đấu | Kenney (kenney.nl) | CC0 | https://kenney.nl/assets/impact-sounds |
| Các SFX còn lại trong `assets/audio/sfx/` (38 file: click, good, wrong, bush, battle_start, swing, dodge, heal, shield, poison, burn, spawn, boss, victory, lose, flee, coin, water, chop, stove, bubble, ding, fridge, door_bell, seat, serve, cash, angry, sweep, mop, wipe, bowl, trash_in, critic, whistle, star_up, star_down, pop) | Thao tác săn, đánh, bếp, quán, dọn dẹp, sự kiện | Nhóm tự làm (tổng hợp 8-bit bằng `assets/audio/make_audio.py`, không dùng mẫu âm của ai) | Của nhóm | — |
| Nhạc nền `assets/audio/music/` (menu, hunt, battle, cook, sell) | Nhạc lặp theo buổi + lúc đánh nhau | Nhóm tự làm (chiptune tổng hợp bằng `assets/audio/make_audio.py`) | Của nhóm | — |

## Công cụ

- [Godot Engine](https://godotengine.org) 4.7.2 (MIT)
