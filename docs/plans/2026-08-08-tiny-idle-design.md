# Tiny Idle Design

## Goal

Build Game 6 as a separate Godot project where the player grows a tiny garden, earns coins manually and passively, buys plots and watering upgrades, wins by reaching a target coin total, and can restart.

## Scope Change

This replaces the original Game 6 Sokoban plan with a small idle game. The project still follows the repository constraints: one screen, primitive visuals, one focused mechanic group, a complete loop, no save data, no offline progress, no prestige system, no multiple currencies, and no polished art or audio.

## Approaches Considered

Recommended approach: Tiny Garden Idle. The player clicks to tend the garden, buys plots, upgrades watering, and watches passive income increase. This teaches timers, incremental values, UI state, button-driven interaction, simple balancing, and restartable win state.

Alternative approach: Tiny Mine Idle. This has the same structure with ore and miners, but it reads more abstractly with primitive shapes.

Alternative approach: Tiny Bakery Idle. This is friendly, but the theme invites more item types than the game needs.

## Architecture

`Main.tscn` owns the full loop: coins, total earned coins, plots, watering level, passive income timer, UI labels, buttons, garden visuals, win state, and restart. One script, `main.gd`, is enough because this game has one screen and no moving entities.

The player can click a `Tend` button for manual coins, buy up to six plots, and buy watering upgrades that increase output. Each owned plot produces coins every second. The game wins when total earned coins reaches 500. Pressing `R` after winning restarts the scene.

## Components

- `games/06-tiny-idle/project.godot`: independent Godot project with main scene, display settings, and restart input.
- `games/06-tiny-idle/README.md`: required concept, scope, task list, and lessons placeholder.
- `games/06-tiny-idle/scenes/Main.tscn`: root scene, UI, buttons, timer, and primitive garden visuals.
- `games/06-tiny-idle/scripts/main.gd`: idle economy, button handlers, passive production, visual updates, win state, and restart.
- `games/06-tiny-idle/icon.svg`: placeholder icon.

## Testing

Use available command-line validation:

- `godot --headless --path games/06-tiny-idle --editor --quit`
- `godot --headless --path games/06-tiny-idle --quit-after 2`

Manual verification is required: launch the project, click `Tend`, buy plots, buy watering upgrades, confirm passive coins increase every second, confirm buttons disable when unaffordable or capped, confirm reaching 500 total coins wins, and confirm `R` restarts after win.
