# Dodge Blocks Design

## Goal

Build the smallest complete Game 1 loop: move a player on one screen, avoid falling blocks, win after 30 seconds, lose on collision, and restart without reopening the editor.

## Approaches Considered

Recommended approach: one main scene with direct local scripts. This fits Games 1-3 guidance, keeps the node tree easy to inspect in Godot, and avoids premature reusable framework code.

Alternative approach: split every object into reusable packed scenes immediately. This is closer to later-game structure, but adds file and scene overhead before reuse is proven.

Alternative approach: implement the loop mostly in one script with programmatic nodes. This is fast to generate, but it teaches less about scenes and nodes, which are explicit Game 1 learning goals.

## Architecture

`Main.tscn` owns the game loop, timers, UI labels, block spawning, win/loss state, and restart input. `Player.tscn` is a `CharacterBody2D` with a simple typed movement script. `Block.tscn` is an `Area2D` with downward movement and a signal-friendly collision shape.

The scene uses primitive `ColorRect` visuals and rectangle collisions. Input actions live in `project.godot`: `move_left`, `move_right`, `move_up`, `move_down`, and `restart`.

## Components

- `scenes/Main.tscn`: root scene, camera-sized play area, player instance, spawn/survival timers, UI labels.
- `scenes/Player.tscn`: player body, visible rectangle, collision shape.
- `scenes/Block.tscn`: falling block area, visible rectangle, collision shape.
- `scripts/main.gd`: game state, spawn timing, survival countdown, collision result, restart.
- `scripts/player.gd`: input-driven movement clamped to the viewport.
- `scripts/block.gd`: downward movement and cleanup after leaving the screen.

## Testing

Use Godot headless commands when available:

- `godot --headless --path games/01-dodge-blocks --editor --quit`
- `godot --headless --path games/01-dodge-blocks --quit-after 2`

Manual verification still matters: launch the project, move the player, confirm blocks spawn, collision loses, 30 seconds wins, and restart reloads the loop.
