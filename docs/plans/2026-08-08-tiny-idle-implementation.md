# Tiny Idle Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a complete minimal idle garden loop for Game 6.

**Architecture:** Use one independent Godot 4 project under `games/06-tiny-idle`. `Main` owns the entire one-screen idle loop: currency, plots, upgrades, timer-based production, UI, visuals, win state, and restart.

**Tech Stack:** Godot 4 stable, GDScript, primitive 2D nodes, no addons.

---

### Task 1: Scaffold Game 6 Project

**Files:**
- Create: `games/06-tiny-idle/README.md`
- Create: `games/06-tiny-idle/project.godot`
- Create: `games/06-tiny-idle/icon.svg`
- Create directory: `games/06-tiny-idle/scenes/`
- Create directory: `games/06-tiny-idle/scripts/`
- Modify: `README.md`
- Modify: `games/README.md`

**Steps:**

1. Create the independent project folder and starter README from the AGENTS template.
2. Fill the five-line concept for Tiny Garden Idle.
3. Add no more than ten checklist tasks to the README.
4. Add project settings for main scene, 960x720 viewport, stretch, renderer, and `restart` input.
5. Reuse the simple placeholder icon.
6. Add Game 6 to the root and games README lists.
7. Validate project file presence with `rg --files games/06-tiny-idle`.

### Task 2: Add Main Scene UI And Visuals

**Files:**
- Create: `games/06-tiny-idle/scenes/Main.tscn`

**Steps:**

1. Create a `Node2D` root with script placeholder reference to `res://scripts/main.gd`.
2. Add a background, six plot visuals, labels for title, coins, total earned, production, plots, watering, and status.
3. Add buttons named `TendButton`, `BuyPlotButton`, and `WaterButton`.
4. Add an `IncomeTimer` with `wait_time = 1.0` and `autostart = true`.
5. Validate required node names with `rg "TendButton|BuyPlotButton|WaterButton|IncomeTimer|Plot" games/06-tiny-idle/scenes/Main.tscn`.

### Task 3: Add Idle Economy Script

**Files:**
- Create: `games/06-tiny-idle/scripts/main.gd`

**Steps:**

1. Add typed constants for maximum plots, win target, manual coins, base production, plot base cost, and watering base cost.
2. Track `coins`, `total_earned`, `plots_owned`, `watering_level`, and `game_won`.
3. Connect buttons and timer in `_ready()`.
4. Implement tending for manual coins.
5. Implement buying plots with increasing cost and a six-plot cap.
6. Implement watering upgrades with increasing cost.
7. Implement passive income once per second.
8. Update labels, button disabled states, and plot colors.
9. Win at 500 total coins and allow `restart` to reload after win.
10. Validate required behavior references with `rg "WIN_TOTAL|_on_tend_pressed|_on_buy_plot_pressed|_on_income_timer_timeout|reload_current_scene" games/06-tiny-idle/scripts/main.gd`.

### Task 4: Verify And Commit

**Files:**
- Modify: `games/06-tiny-idle/README.md`

**Steps:**

1. Run `git diff --check`.
2. Run `godot --version` if available.
3. Run `godot --headless --path games/06-tiny-idle --editor --quit` if available.
4. Run `godot --headless --path games/06-tiny-idle --quit-after 2` if practical.
5. Manually test the loop when practical.
6. Mark completed README tasks based on implementation and leave manual test unchecked unless performed.
7. Commit with `feat: build tiny idle loop`.
