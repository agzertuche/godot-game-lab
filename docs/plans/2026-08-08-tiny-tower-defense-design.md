# Tiny Tower Defense Design

## Goal

Build Game 5 as a separate Godot project where the player places one tower type beside one fixed enemy path, survives three waves, wins when all waves are cleared, loses when base health reaches zero, and can restart.

## Approaches Considered

Recommended approach: use direct local scenes with Godot path nodes. `Main` owns wave sequencing, currency, placement, UI, win/loss state, and restart. Enemies use `PathFollow2D` so the project teaches the intended path mechanic directly. Towers are one simple scene that finds the nearest enemy in range and deals damage on a cooldown.

Alternative approach: move enemies through hard-coded waypoints. This would be simpler to script, but it skips the explicit `Path2D` and `PathFollow2D` learning goal.

Alternative approach: create separate manager scripts for waves, placement, targeting, and economy. This could suit a larger tower-defense game, but it adds unnecessary structure for the fifth small learning project.

## Architecture

`Main.tscn` owns the complete gameplay loop: path, base health, currency, build spots, wave timer, UI, win/loss state, and restart. It spawns enemies under a `Path2D`, registers placed towers, and exposes the current list of enemies so towers can choose targets.

`Enemy.tscn` is a `PathFollow2D` scene that moves along the fixed path. It has health, emits a signal when killed, and emits a signal when it reaches the end of the path so `Main` can damage the base.

`Tower.tscn` is one placeable `Node2D` with attack range, cooldown, target selection, and damage. Towers use primitive shapes only and do not support upgrades, variants, selling, rotation, or manual targeting.

Input uses mouse clicks for tower placement and `R` for restart after win or loss. Placement is limited to visible build spots beside the path. A tower can only be placed if the spot is empty and the player has enough currency.

## Components

- `games/05-tiny-tower-defense/project.godot`: independent Godot project with main scene, display settings, and restart input.
- `games/05-tiny-tower-defense/README.md`: required game concept, scope, task list, and later lessons.
- `games/05-tiny-tower-defense/scenes/Main.tscn`: root scene with path, build spots, timers, UI, and spawn containers.
- `games/05-tiny-tower-defense/scenes/Enemy.tscn`: one enemy type driven by `PathFollow2D`.
- `games/05-tiny-tower-defense/scenes/Tower.tscn`: one tower type with range and cooldown.
- `games/05-tiny-tower-defense/scripts/main.gd`: game state, wave sequencing, placement, enemy tracking, UI, win/loss, and restart.
- `games/05-tiny-tower-defense/scripts/enemy.gd`: path movement, health, death, and base-entry signal.
- `games/05-tiny-tower-defense/scripts/tower.gd`: target selection, cooldown, and damage.

## Testing

Use Godot command-line validation when available:

- `godot --headless --path games/05-tiny-tower-defense --editor --quit`
- `godot --headless --path games/05-tiny-tower-defense --quit-after 2`

Manual verification is required: launch the project, confirm enemies follow the path, confirm clicking valid spots places towers and spends currency, confirm invalid or unaffordable placements are rejected, confirm towers attack enemies in range, confirm enemies damage the base at the path end, confirm three waves can be cleared for a win, confirm base health reaching zero loses, and confirm restart reloads the loop.
