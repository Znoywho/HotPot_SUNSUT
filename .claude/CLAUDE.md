# Sôi Sùng Sục (HotPot_SUNSUT)

## Project goals
- 2D game (school project, 3 weeks): run a hotpot restaurant + turn-based combat to hunt ingredients.
- Daily loop: Morning hunt (2:30, turn-based) → Noon cook broth → Evening sell (4:00) → KPI check. KPI fail = game over; pass = upgrade shop, next day. KPI = yesterday's revenue + 10%.
- Ships as a **Web build on itch.io** (https://znoywho.itch.io/soi-sung-suc) — must be playable on **desktop and mobile (landscape, touch)**.
- Design source: `docs/PLAN.md` (scope MVP / nice-to-have / stretch, weekly plan, open questions).

## Tech stack
- Godot **4.7.2** (standard, not .NET), GDScript, GL Compatibility renderer (WebGL 2).
- Autoloads (`autoload/`): `Database` (lists of .tres data), `GameState` (money, day, KPI, inventory, upgrades, save dict), `SaveManager` (user://save.json), `DayManager` (phase flow + phase timer).
- Data as Resources: classes in `data/classes/`, balance numbers in `data/combatants/`, `data/broths/`, `data/upgrades/` (.tres). New .tres must be registered in `autoload/database.gd`.
- Combat (`scenes/hunt/combat/`): `Battle` (ATB by speed), `Combatant`, `Passive` (hooks receive `holder`), `StatusEffect`.
- Placeholder UI: every screen currently `extends ScreenBase` (`scenes/common/screen_base.gd`). Replace per screen with real UI.
- Font: Be Vietnam Pro (`assets/fonts/`), project default font.

## Common commands
- Run game: `godot --path .` (or open `project.godot` in the editor, F5)
- Headless script check: `godot --headless --path . --quit-after 60` (no output = no script errors)
- Re-import assets: `godot --headless --path . --import`
- Web build: `./tools/build_web.sh` · local test: `./tools/build_web.sh serve` (http://localhost:8000)
- Publish to itch.io: `./tools/build_web.sh push` (butler; only Member 1 pushes)

## Team ownership
Task IDs (Sxx) map to `docs/PLAN.md`. Search code for `TODO(Hạo)`, `TODO(Hải)`, `TODO(Tuấn)`, `TODO(nhóm)`.

### Member 1 — Lê Thiên Hạo (GitHub: Znoywho): Core loop, shop, integration, release
Area: `autoload/`, `scenes/common/`, `scenes/main_menu/`, `scenes/day_end/`, `scenes/shop/`, `scenes/game_over/`, `data/upgrades/`, `tools/`, `export_presets.cfg`, `project.godot`
- S01 Shared HUD (money, day, KPI, timer, stars)
- S02 KPI result & Game Over screens (real UI), KPI formula tuning
- S03 Upgrade shop with tabs (Kitchen / Combat / Restaurant), descriptions visible without hover
- S04 Wire upgrade effects: Pot, Stove, Furniture (with Member 3); Knife, Armor (with Member 2)
- S05 Save/load complete, settings menu
- S06 Day milestones 5/10/15: unlock broths/ingredients, monster scaling
- S07 Floor 2 tables, private rooms, staff (stretch)
- S08 Merge & integration, web build, itch.io page and releases

### Member 2 — Đỗ Hoàng Hải: Hunting / combat + art assets
Area: `scenes/hunt/` (incl. `combat/`, `passives/`, `statuses/`), `data/combatants/`, `assets/sprites/` (combat & characters), `CREDITS.md` entries
- S10 Implement 7 passives (`passives/*.gd`) + Poison/Burn (`statuses/*.gd`)
- S11 `battle_view.tscn`: sprites, HP bars, target selection, turn feedback (touch-friendly)
- S12 Multi-enemy fights, Mad Bull death explosion (AoE)
- S13 Combat upgrades: Knife, Armor, Crit (Sharp Mind, Hawk Eye), Mount takes hits first
- S14 Boss + golden ingredients (x3 price), drop rates
- S15 Asset sourcing: pick art style (pixel 32×32), find monsters, chef, ingredients, restaurant, UI, audio; log every asset in `CREDITS.md`

### Member 3 — Nguyễn Ngọc Minh Tuấn: Kitchen + restaurant (cook & sell)
Area: `scenes/cook/`, `scenes/sell/`, `data/broths/`
- S20 Real kitchen scene: cook time = `cook_time × stove value`, pot count limited by stove level
- S21 Customers arrive, take tables, order broth + dipping items (count × `GameState.customer_multiplier`)
- S22 Cart: put dishes on cart, deliver to the right table (drag/tap must work on touch)
- S23 Wait timer: on-time → tip 3–7% (+ Furniture); too slow → customer leaves, `GameState.lose_star()`
- S24 Stove reduces customer eating time 5–10%
- S25 More broths for milestone days (with Member 1)

### Shared
- Whole team: decide open numbers (`TODO(nhóm)`, "Cần chốt" in `docs/PLAN.md`), playtest each milestone, balance (day 19), bug fixing (day 20), report + slides + demo video (day 21).

## Rules
- Only modify code within the area the current user owns (see `CLAUDE.local.md` for who the current user is). Do NOT edit other members' areas.
- If you find a bug in someone else's area, do not fix it. Report it instead: file, line, how to reproduce, suggested fix, and which member owns it.
- Foundation files — warn clearly and ask before changing: `project.godot`, `export_presets.cfg`, `autoload/*.gd`, `data/classes/*.gd`, `scenes/common/screen_base.gd`, `scenes/hunt/combat/{battle,combatant,passive,status_effect}.gd` (public API used by others), `.gitignore`, `tools/build_web.sh`.
- Changing a public API (autoload functions/signals, Resource fields, Passive hooks) affects other members: flag it for the whole team and update all call sites in the same PR only with the owner's agreement.
- `.tscn` files: never have two people edit the same scene; prefer building small scenes per feature.
- Keep `.uid` and `.import` files in git (Godot needs them); never commit `.godot/` or `build/`.
- Balance numbers belong in `.tres` files, not hardcoded in scripts.
- Never commit directly to `main`; use feature branches (`feat/hunt-ui`, `fix/...`) and PRs.
- Never add "Co-Authored-By: Claude" or any AI attribution to commits/PRs.

## Web & mobile constraints
- Every UI must work with **touch** in landscape: buttons ≥ 56px tall, text ≥ 18px; no hover/tooltips, right-click or keyboard-only actions; drag & drop must work with a finger.
- The font has **no glyphs** for `→ ▶ ★` or emoji (render as boxes) — use `» ›` or image icons.
- Web build is single-threaded (no SharedArrayBuffer); avoid threads. Audio: `.ogg`. Keep assets small.
- After changes, run the headless check; before a release, test the web build on a real phone.

## Language
- Always respond to the user in Vietnamese.
- Code identifiers in English; comments and docstrings may be Vietnamese (existing code uses Vietnamese comments). Commit messages: Vietnamese or English, short and clear.
