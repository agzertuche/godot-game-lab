# Collect Everything Design

## Goal

Build Game 2 as a separate Godot project where the player collects ten objects before a 30-second timer expires, then can restart after winning or losing.

## Approaches Considered

Recommended approach: copy the proven Game 1 project shape into a new independent project and keep direct local scripts. This preserves the learning value of scenes, nodes, `Area2D`, signals, counters, timers, and restart behavior without creating a shared framework.

Alternative approach: move player movement and restart helpers into `shared/`. This is premature because only one completed game has used that code so far, and `AGENTS.md` explicitly prefers waiting until duplication is proven across at least two games.

Alternative approach: use one large main script with programmatically created collectibles. This is fast, but it hides the scene/signal structure that Game 2 is meant to teach.

## Architecture

`Main.tscn` owns the gameplay loop, countdown timer, counter, random collectible placement, win/loss state, and restart. `Player.tscn` is a simple `CharacterBody2D` with movement. `Collectible.tscn` is an `Area2D` that emits a local `collected` signal when the player enters it.

The project uses primitive `ColorRect` visuals and rectangle collisions. Input actions are `move_left`, `move_right`, `move_up`, `move_down`, and `restart`. The player wins by collecting ten objects and loses if the 30-second timer reaches zero first.

## Components

- `games/02-collect-everything/project.godot`: independent Godot project with input map and main scene.
- `games/02-collect-everything/scenes/Main.tscn`: root scene, player instance, UI labels, and timer.
- `games/02-collect-everything/scenes/Player.tscn`: player body, collision, and placeholder visual.
- `games/02-collect-everything/scenes/Collectible.tscn`: collectable item area, collision, and placeholder visual.
- `games/02-collect-everything/scripts/main.gd`: counter, timer, random placement, win/loss, restart.
- `games/02-collect-everything/scripts/player.gd`: input-driven movement clamped to the viewport.
- `games/02-collect-everything/scripts/collectible.gd`: `Area2D` collection signal and cleanup guard.

## Testing

Use Godot headless validation when available:

- `godot --headless --path games/02-collect-everything --editor --quit`
- `godot --headless --path games/02-collect-everything --quit-after 2`

Manual verification is still required: launch the project, move the player, collect items, confirm the counter updates, confirm ten items wins, confirm timeout loses, and confirm restart reloads the loop.
