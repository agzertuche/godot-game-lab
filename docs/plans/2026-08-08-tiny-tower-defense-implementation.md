# Tiny Tower Defense Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a complete minimal tower defense loop for Game 5.

**Architecture:** Use one independent Godot 4 project under `games/05-tiny-tower-defense`. `Main` owns game state, wave sequencing, currency, placement, UI, win/loss, and restart. `Enemy` follows a `Path2D` through `PathFollow2D`, and `Tower` handles one local attack behavior against tracked enemies.

**Tech Stack:** Godot 4 stable, GDScript, primitive 2D nodes, no addons.

---

### Task 1: Scaffold Game 5 Project

**Files:**
- Create: `games/05-tiny-tower-defense/README.md`
- Create: `games/05-tiny-tower-defense/project.godot`
- Create: `games/05-tiny-tower-defense/icon.svg`
- Create directory: `games/05-tiny-tower-defense/scenes/`
- Create directory: `games/05-tiny-tower-defense/scripts/`
- Modify: `README.md`
- Modify: `games/README.md`

**Steps:**

1. Create the independent project folder and starter README from the required AGENTS template.
2. Fill the five-line concept:
   - Player: a defender who places towers with the mouse.
   - Objective: survive three waves.
   - Main obstacle: enemies following one path toward the base.
   - Win condition: all three waves are cleared.
   - Lose condition: base health reaches zero.
3. Add no more than ten checklist tasks to the game README.
4. Add project settings for the main scene, display size, display stretch, renderer, and `restart` input action.
5. Reuse the simple Godot placeholder icon.
6. Add Game 5 to the root and games README lists.
7. Validate that the project files are present with `rg --files games/05-tiny-tower-defense`.

### Task 2: Add Enemy Path Scene

**Files:**
- Create: `games/05-tiny-tower-defense/scenes/Enemy.tscn`
- Create: `games/05-tiny-tower-defense/scripts/enemy.gd`

**Steps:**

1. Create an `Enemy.tscn` scene with `PathFollow2D` as the root.
2. Add a visible primitive child and collision area child so the enemy can be seen and can be targeted by distance.
3. Attach a typed `enemy.gd` script.
4. Implement exported values for `speed`, `max_health`, `base_damage`, and `currency_reward`.
5. Move the enemy by increasing `progress` in `_process(delta)`.
6. Emit `reached_base(enemy)` when `progress_ratio >= 1.0`.
7. Add `take_damage(amount)` that reduces health and emits `died(enemy)` when health reaches zero.
8. Validate references with `rg "reached_base|take_damage|progress_ratio|currency_reward" games/05-tiny-tower-defense`.

### Task 3: Add Tower Scene

**Files:**
- Create: `games/05-tiny-tower-defense/scenes/Tower.tscn`
- Create: `games/05-tiny-tower-defense/scripts/tower.gd`

**Steps:**

1. Create a `Tower.tscn` scene with `Node2D` as the root.
2. Add a visible primitive base and a simple range indicator that can stay subtle or hidden.
3. Attach a typed `tower.gd` script.
4. Implement exported values for `range`, `damage`, and `fire_cooldown`.
5. Add `set_enemy_provider(provider: Callable)` so `Main` can give towers access to live enemies without global state.
6. In `_process(delta)`, reduce cooldown, find the nearest valid enemy within range, and call `take_damage(damage)` when ready.
7. Validate references with `rg "set_enemy_provider|fire_cooldown|take_damage|range" games/05-tiny-tower-defense`.

### Task 4: Add Main Scene And Placement

**Files:**
- Create: `games/05-tiny-tower-defense/scenes/Main.tscn`
- Create: `games/05-tiny-tower-defense/scripts/main.gd`

**Steps:**

1. Create `Main.tscn` with a root `Node2D`.
2. Add a `Path2D` with one fixed visible route from left to right.
3. Add child containers named `Enemies`, `Towers`, and `BuildSpots`.
4. Add six visible build spots beside the path using `Area2D` nodes or simple `Node2D` markers with positions.
5. Add labels for base health, currency, wave, remaining enemies, and status.
6. Attach `main.gd`.
7. Implement mouse placement:
   - Find the nearest build spot within a small click radius.
   - Reject clicks after game over.
   - Reject occupied spots.
   - Reject placement if currency is below tower cost.
   - Instance one `Tower.tscn`, place it on the spot, spend currency, and mark the spot occupied.
8. Validate references with `rg "BuildSpots|tower_cost|occupied|instantiate|set_enemy_provider" games/05-tiny-tower-defense`.

### Task 5: Add Waves, Economy, Win, Loss, And Restart

**Files:**
- Modify: `games/05-tiny-tower-defense/scripts/main.gd`
- Modify: `games/05-tiny-tower-defense/scenes/Main.tscn`

**Steps:**

1. Add a spawn timer to `Main.tscn`.
2. Define three small waves in `main.gd`, for example `[4, 6, 8]`.
3. Spawn enemies as children of the `Path2D` so their `PathFollow2D` root follows the route.
4. Track active enemies in an array and remove them when they die or reach the base.
5. Award currency when an enemy dies.
6. Damage base health when an enemy reaches the base.
7. Start the next wave after the current wave has spawned and no active enemies remain.
8. Win after wave 3 is cleared.
9. Lose when base health reaches zero.
10. Allow `restart` to reload the current scene after win or loss.
11. Validate references with `rg "reload_current_scene|base_health|waves|active_enemies|_on_enemy_died|_on_enemy_reached_base" games/05-tiny-tower-defense`.

### Task 6: Verify, Document, And Commit

**Files:**
- Modify: `games/05-tiny-tower-defense/README.md`

**Steps:**

1. Run `git diff --check`.
2. Run `godot --version` if available.
3. Run `godot --headless --path games/05-tiny-tower-defense --editor --quit` if the executable is available.
4. Run `godot --headless --path games/05-tiny-tower-defense --quit-after 2` if practical.
5. If `godot` is not available, try `/Applications/Godot.app/Contents/MacOS/Godot --version`.
6. Manually test in the editor or launched project when practical:
   - Enemies follow the path.
   - Towers can be placed on valid spots.
   - Invalid, occupied, and unaffordable placements are rejected.
   - Towers attack enemies in range.
   - Killed enemies award currency.
   - Enemies reaching the end damage the base.
   - Three cleared waves win.
   - Base health reaching zero loses.
   - Restart reloads the loop.
7. Mark completed README tasks based on verified implementation.
8. Fill in `## Lessons` only after the game has been tested enough to count as finished.
9. Commit with `feat: build tiny tower defense loop` after validation.
