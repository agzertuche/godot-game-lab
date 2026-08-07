# One Room Shooter Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a complete minimal one-room shooter loop for Game 4.

**Architecture:** Use one independent Godot 4 project under `games/04-one-room-shooter`. `Main` owns game state and spawning, `Player` owns movement/shooting/health, `Projectile` owns travel and enemy hits, and `Enemy` owns chasing/damage/death.

**Tech Stack:** Godot 4 stable, GDScript, primitive 2D nodes, no addons.

---

### Task 1: Scaffold Game 4 Project

**Files:**
- Create: `games/04-one-room-shooter/README.md`
- Create: `games/04-one-room-shooter/project.godot`
- Create: `games/04-one-room-shooter/icon.svg`
- Create directory: `games/04-one-room-shooter/scenes/`
- Create directory: `games/04-one-room-shooter/scripts/`

**Steps:**

1. Create the independent project folder and starter README from the required AGENTS template.
2. Add project settings for the main scene, display stretch, renderer, movement input, shooting input, and restart input.
3. Reuse the simple Godot placeholder icon.
4. Validate that the project files are present with `rg --files games/04-one-room-shooter`.

### Task 2: Add Player, Projectile, And Enemy Scenes

**Files:**
- Create: `games/04-one-room-shooter/scenes/Player.tscn`
- Create: `games/04-one-room-shooter/scenes/Projectile.tscn`
- Create: `games/04-one-room-shooter/scenes/Enemy.tscn`
- Create: `games/04-one-room-shooter/scripts/player.gd`
- Create: `games/04-one-room-shooter/scripts/projectile.gd`
- Create: `games/04-one-room-shooter/scripts/enemy.gd`

**Steps:**

1. Create a `CharacterBody2D` player with rectangle collision and primitive visual.
2. Create an `Area2D` projectile with rectangle collision and primitive visual.
3. Create a `CharacterBody2D` enemy with rectangle collision, primitive visual, and contact damage area.
4. Add typed scripts for movement, shooting, projectile movement, enemy chase, health, and damage signals.
5. Validate references with `rg "res://scripts/player.gd|res://scripts/projectile.gd|res://scripts/enemy.gd|projectile_requested|died" games/04-one-room-shooter`.

### Task 3: Add Main Survival Loop

**Files:**
- Create: `games/04-one-room-shooter/scenes/Main.tscn`
- Create: `games/04-one-room-shooter/scripts/main.gd`

**Steps:**

1. Add player instance, spawn timer, survival timer, and UI labels.
2. Spawn enemies at random screen edges.
3. Spawn projectiles when the player emits a projectile request.
4. Track health and remaining survival time.
5. Win after 60 seconds.
6. Lose when player health reaches zero.
7. Restart the current scene with `restart` after win/loss.
8. Validate references with `rg "SurvivalTimer|EnemySpawnTimer|HealthLabel|TimeLabel|StatusLabel|reload_current_scene" games/04-one-room-shooter`.

### Task 4: Verify And Commit

**Files:**
- Modify: `README.md`
- Modify: `games/README.md`
- Modify: `games/04-one-room-shooter/README.md`

**Steps:**

1. Run `git diff --check`.
2. Run Godot validation commands if the executable is available.
3. Mark implemented checklist items in the README, leaving manual test unchecked unless the game was manually tested.
4. Commit the Game 4 implementation.
