# Breakout Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a complete minimal Breakout loop for Game 3.

**Architecture:** Use one independent Godot 4 project under `games/03-breakout`. `Main` owns game state and level setup, `Paddle` owns horizontal movement, `Ball` owns collision response, and `Block` owns break behavior.

**Tech Stack:** Godot 4 stable, GDScript, primitive 2D nodes, no addons.

---

### Task 1: Scaffold Game 3 Project

**Files:**
- Create: `games/03-breakout/README.md`
- Create: `games/03-breakout/project.godot`
- Create: `games/03-breakout/icon.svg`
- Create directory: `games/03-breakout/scenes/`
- Create directory: `games/03-breakout/scripts/`

**Steps:**

1. Create the independent project folder and starter README from the required AGENTS template.
2. Add project settings for the main scene, display stretch, renderer, and input actions.
3. Reuse the simple Godot placeholder icon.
4. Validate that the project files are present with `rg --files games/03-breakout`.

### Task 2: Add Paddle, Ball, And Block Scenes

**Files:**
- Create: `games/03-breakout/scenes/Paddle.tscn`
- Create: `games/03-breakout/scenes/Ball.tscn`
- Create: `games/03-breakout/scenes/Block.tscn`
- Create: `games/03-breakout/scripts/paddle.gd`
- Create: `games/03-breakout/scripts/ball.gd`
- Create: `games/03-breakout/scripts/block.gd`

**Steps:**

1. Create a `CharacterBody2D` paddle with rectangle collision and primitive visual.
2. Create a `CharacterBody2D` ball with square collision and primitive visual.
3. Create a reusable `StaticBody2D` block with rectangle collision and primitive visual.
4. Add typed scripts for movement, bouncing, and block hit signaling.
5. Validate file references with `rg "res://scripts/paddle.gd|res://scripts/ball.gd|res://scripts/block.gd|blocks" games/03-breakout`.

### Task 3: Add Main Breakout Loop

**Files:**
- Create: `games/03-breakout/scenes/Main.tscn`
- Create: `games/03-breakout/scripts/main.gd`

**Steps:**

1. Add paddle and ball instances.
2. Generate one small block grid from the reusable block scene.
3. Track remaining blocks.
4. Win when no blocks remain.
5. Lose when the ball exits the bottom of the screen.
6. Restart the current scene with `restart` after win/loss.
7. Validate references with `rg "remaining_blocks|StatusLabel|BlockRoot|reload_current_scene|ball_lost" games/03-breakout`.

### Task 4: Verify And Commit

**Files:**
- Modify: `README.md`
- Modify: `games/README.md`
- Modify: `games/03-breakout/README.md`

**Steps:**

1. Run `git diff --check`.
2. Run Godot validation commands if the executable is available.
3. Mark implemented checklist items in the README, leaving manual test unchecked unless the game was manually tested.
4. Commit the Game 3 implementation.
