# One-Room Shooter Design

## Goal

Build Game 4 as a separate Godot project where the player moves around one room, fires one projectile type on a cooldown, survives enemies that chase and damage the player, wins after 60 seconds, loses when health reaches zero, and can restart.

## Approaches Considered

Recommended approach: use direct local scenes with a small health/damage signal flow. This introduces projectiles, cooldowns, enemy movement, spawning, and basic reusable components without a shared framework.

Alternative approach: add mouse aiming. This feels natural for a shooter, but increases input and aim-state complexity before the core loop is proven.

Alternative approach: use automatic nearest-enemy shooting. This reduces controls, but it teaches less about projectile direction, cooldown input, and explicit combat timing.

## Architecture

`Main.tscn` owns the 60-second survival timer, enemy spawn timer, UI, win/loss state, and restart. `Player.tscn` is a `CharacterBody2D` with movement, health, a shoot cooldown, and a projectile spawn signal. `Projectile.tscn` is an `Area2D` that travels in a direction, damages one enemy, and frees itself. `Enemy.tscn` is one `CharacterBody2D` type that chases the player and damages on contact with a short cooldown.

Input uses WASD/arrow keys for movement, directional arrow/IJKL-style shooting actions for firing, and `R` for restart. The game uses primitive visuals only. There is one weapon, one enemy type, no upgrades, no pickups, no score, and no level progression.

## Components

- `games/04-one-room-shooter/project.godot`: independent Godot project with input map and main scene.
- `games/04-one-room-shooter/scenes/Main.tscn`: root scene, player instance, timers, UI labels, and spawned enemies/projectiles.
- `games/04-one-room-shooter/scenes/Player.tscn`: movement, health, shoot cooldown, and projectile request signal.
- `games/04-one-room-shooter/scenes/Projectile.tscn`: simple projectile area and hit behavior.
- `games/04-one-room-shooter/scenes/Enemy.tscn`: chasing enemy body and touch damage behavior.
- `games/04-one-room-shooter/scripts/main.gd`: state, spawn loop, survival timer, UI, restart.
- `games/04-one-room-shooter/scripts/player.gd`: movement, shooting input, damage, health signals.
- `games/04-one-room-shooter/scripts/projectile.gd`: projectile movement, hit detection, cleanup.
- `games/04-one-room-shooter/scripts/enemy.gd`: chase movement, health, damage cooldown, death signal.

## Testing

Use Godot headless validation when available:

- `godot --headless --path games/04-one-room-shooter --editor --quit`
- `godot --headless --path games/04-one-room-shooter --quit-after 2`

Manual verification is required: launch the project, move the player, shoot projectiles, confirm enemies chase, confirm enemies die when shot, confirm player health drops on contact, confirm survival wins, confirm player death loses, and confirm restart reloads the loop.
