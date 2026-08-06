# Collect Everything Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a complete minimal Game 2 loop where the player collects ten objects before time expires.

**Architecture:** Use one independent Godot 4 project under `games/02-collect-everything`. `Main` owns state and UI, `Player` owns movement, and `Collectible` owns overlap detection through an `Area2D` signal.

**Tech Stack:** Godot 4 stable, GDScript, primitive 2D nodes, no addons.

---

### Task 1: Scaffold Game 2 Project

**Files:**
- Create: `games/02-collect-everything/README.md`
- Create: `games/02-collect-everything/project.godot`
- Create directory: `games/02-collect-everything/scenes/`
- Create directory: `games/02-collect-everything/scripts/`
- Create: `games/02-collect-everything/icon.svg`

**Steps:**

1. Create the independent project folder and starter README from the required AGENTS template.
2. Add project settings for the main scene, display stretch, renderer, and input actions.
3. Reuse the simple Godot placeholder icon.
4. Validate that the project files are present with `rg --files games/02-collect-everything`.

### Task 2: Add Player Movement

**Files:**
- Create: `games/02-collect-everything/scenes/Player.tscn`
- Create: `games/02-collect-everything/scripts/player.gd`

**Steps:**

1. Create a `CharacterBody2D` player with rectangle collision and a primitive visual.
2. Add typed movement using `Input.get_vector`.
3. Clamp the player to the viewport.
4. Validate file references with `rg "res://scripts/player.gd|move_left|move_right|move_up|move_down" games/02-collect-everything`.

### Task 3: Add Collectibles

**Files:**
- Create: `games/02-collect-everything/scenes/Collectible.tscn`
- Create: `games/02-collect-everything/scripts/collectible.gd`

**Steps:**

1. Create an `Area2D` collectible with rectangle collision and a primitive visual.
2. Add a `collected` signal.
3. Emit the signal and hide/disable the item once the player enters.
4. Validate file references with `rg "collected|body_entered|res://scripts/collectible.gd" games/02-collect-everything`.

### Task 4: Add Main Loop

**Files:**
- Create: `games/02-collect-everything/scenes/Main.tscn`
- Create: `games/02-collect-everything/scripts/main.gd`

**Steps:**

1. Add player instance, countdown timer, and UI labels.
2. Spawn one collectible at a random visible position.
3. Increment the counter when the item is collected, then spawn the next item until ten are collected.
4. Win at ten collected items.
5. Lose when the timer expires.
6. Restart the current scene with `restart` after win/loss.
7. Validate file references with `rg "target_collectibles|TimeLabel|CountLabel|StatusLabel|reload_current_scene" games/02-collect-everything`.

### Task 5: Verify And Commit

**Files:**
- Modify: `games/02-collect-everything/README.md`

**Steps:**

1. Run `git diff --check`.
2. Run Godot validation commands if the executable is available.
3. Mark implemented checklist items in the README, leaving manual test unchecked unless the game was manually tested.
4. Commit the Game 2 implementation.
