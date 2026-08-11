# Tiny Kitchen Rush Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a complete minimal time-management cooking loop for Game 7.

**Architecture:** Use one independent Godot 4 project under `games/07-tiny-kitchen-rush`. `Main` owns the entire one-screen loop: orders, plate contents, timers, scoring, misses, UI, win/loss, and restart.

**Tech Stack:** Godot 4 stable, GDScript, primitive 2D nodes, no addons.

---

### Task 1: Scaffold Game 7 Project

**Files:**
- Create: `games/07-tiny-kitchen-rush/README.md`
- Create: `games/07-tiny-kitchen-rush/project.godot`
- Create: `games/07-tiny-kitchen-rush/icon.svg`
- Create directory: `games/07-tiny-kitchen-rush/scenes/`
- Create directory: `games/07-tiny-kitchen-rush/scripts/`
- Modify: `README.md`
- Modify: `games/README.md`
- Modify: `AGENTS.md`

**Steps:**

1. Create the independent project folder and starter README from the AGENTS template.
2. Fill the five-line concept for Tiny Kitchen Rush.
3. Add no more than ten checklist tasks to the README.
4. Add project settings for main scene, 960x720 viewport, stretch, renderer, and `restart` input.
5. Reuse the simple placeholder icon.
6. Add Game 7 to the root and games README lists.
7. Update the AGENTS learning plan so Game 7 matches the cooking game.

### Task 2: Add Main Scene UI And Visuals

**Files:**
- Create: `games/07-tiny-kitchen-rush/scenes/Main.tscn`

**Steps:**

1. Create a `Node2D` root with `res://scripts/main.gd`.
2. Add a background, counter, plate, labels for order, plate, served, misses, shift time, patience, and status.
3. Add buttons named `BunButton`, `PattyButton`, `LettuceButton`, `ServeButton`, and `ClearButton`.
4. Keep everything on one screen with primitive shapes and labels.

### Task 3: Add Cooking Loop Script

**Files:**
- Create: `games/07-tiny-kitchen-rush/scripts/main.gd`

**Steps:**

1. Add constants for ingredients, win served count, max misses, shift duration, and order patience.
2. Track active order, current plate, served count, misses, remaining shift time, remaining patience, and game over state.
3. Connect all buttons in `_ready()`.
4. Generate one active order at a time.
5. Add ingredient button handlers.
6. Add clear plate behavior.
7. Add serve behavior that compares plate and order.
8. Count incorrect plates as misses.
9. Count expired patience as misses and generate a new order.
10. Win at 8 served orders, lose at 3 misses or shift timeout, and allow `restart` after ending.

### Task 4: Verify And Commit

**Files:**
- Modify: `games/07-tiny-kitchen-rush/README.md`

**Steps:**

1. Run `git diff --check`.
2. Run `godot --version` if available.
3. Run `godot --headless --path games/07-tiny-kitchen-rush --editor --quit` if available.
4. Run `godot --headless --path games/07-tiny-kitchen-rush --quit-after 2` if practical.
5. Manually test the loop when practical.
6. Mark completed README tasks based on implementation and leave manual test unchecked unless performed.
7. Commit with `feat: build tiny kitchen rush loop`.
