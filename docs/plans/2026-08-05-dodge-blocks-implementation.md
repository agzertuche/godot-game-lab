# Dodge Blocks Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the smallest complete playable Dodge the Blocks loop for Game 1.

**Architecture:** Use direct Godot 4 scenes and local typed GDScript. `Main` owns the loop and UI, `Player` owns movement, and `Block` owns falling/cleanup.

**Tech Stack:** Godot 4 stable, GDScript, primitive 2D nodes, no addons.

---

### Task 1: Configure Project Inputs And Main Scene

**Files:**
- Modify: `games/01-dodge-blocks/project.godot`
- Rename/replace: `games/01-dodge-blocks/node_2d.tscn`
- Create: `games/01-dodge-blocks/scenes/Main.tscn`

**Steps:**

1. Add input actions for `move_left`, `move_right`, `move_up`, `move_down`, and `restart`.
2. Point `run/main_scene` at `res://scenes/Main.tscn`.
3. Replace the temporary empty scene with the real main scene.
4. Validate with `godot --headless --path games/01-dodge-blocks --editor --quit` when available.

### Task 2: Add Player Movement

**Files:**
- Create: `games/01-dodge-blocks/scenes/Player.tscn`
- Create: `games/01-dodge-blocks/scripts/player.gd`
- Modify: `games/01-dodge-blocks/scenes/Main.tscn`

**Steps:**

1. Create a `CharacterBody2D` player with a rectangle collision shape and placeholder visual.
2. Add typed movement using the configured input actions.
3. Clamp the player to the viewport.
4. Validate parsing and run the scene briefly when Godot is available.

### Task 3: Add Falling Blocks

**Files:**
- Create: `games/01-dodge-blocks/scenes/Block.tscn`
- Create: `games/01-dodge-blocks/scripts/block.gd`
- Create: `games/01-dodge-blocks/scripts/main.gd`
- Modify: `games/01-dodge-blocks/scenes/Main.tscn`

**Steps:**

1. Create a block `Area2D` with rectangle collision and placeholder visual.
2. Move blocks downward every frame and free them after leaving the screen.
3. Spawn blocks from the top of the screen on a timer.
4. Validate parsing and run briefly when Godot is available.

### Task 4: Add Win/Loss/Restart Loop

**Files:**
- Modify: `games/01-dodge-blocks/scripts/main.gd`
- Modify: `games/01-dodge-blocks/scenes/Main.tscn`

**Steps:**

1. Track 30 seconds of survival time.
2. Show time/status labels.
3. End the game with a loss when a block touches the player.
4. End the game with a win when the timer reaches zero.
5. Restart the current scene when `restart` is pressed after win/loss.
6. Validate and manually verify the full loop when possible.

### Task 5: Update Documentation And Commit

**Files:**
- Modify: `games/01-dodge-blocks/README.md`

**Steps:**

1. Mark completed checklist tasks.
2. Add short lessons learned only after verification.
3. Commit the finished Game 1 implementation.
