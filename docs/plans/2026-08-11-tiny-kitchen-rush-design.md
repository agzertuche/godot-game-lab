# Tiny Kitchen Rush Design

## Goal

Build Game 7 as a separate Godot project where the player assembles simple food orders under time pressure, serves correct plates, misses impatient orders, wins by serving enough orders, and can restart.

## Scope Change

This replaces the original Game 7 mini-platformer slot with a small time-management cooking game. The project still follows the repository constraints: one screen, primitive visuals, one focused mechanic group, a complete loop, no save data, no multiple levels, and no polished art or audio.

## Approaches Considered

Recommended approach: Tiny Kitchen Rush. The player clicks ingredient buttons to build a plate, serves it against the current order, and manages order patience. This teaches UI buttons, recipe matching, timers, queue state, scoring, mistakes, win/loss, and restart without needing physics or art.

Alternative approach: drag ingredients onto a plate. This feels more tactile, but adds input complexity before the core time-management loop is proven.

Alternative approach: multiple cooking stations. This is closer to full cooking games, but it would introduce too many simultaneous systems for a tiny tutorial project.

## Architecture

`Main.tscn` owns the full loop: active order, plate contents, shift timer, patience timer, served count, misses, UI labels, buttons, win/loss state, and restart. One script, `main.gd`, is enough because this game has one screen, one order at a time, and no moving entities.

Orders are generated from three ingredients: bun, patty, and lettuce. The player clicks ingredient buttons to add items to the plate, clicks `Serve` to compare the plate with the active order, and clicks `Clear` to reset the plate. A patience timer counts down every frame. Serving 8 correct orders wins. Missing 3 orders or letting the 60-second shift expire before 8 serves loses.

## Components

- `games/07-tiny-kitchen-rush/project.godot`: independent Godot project with main scene, display settings, and restart input.
- `games/07-tiny-kitchen-rush/README.md`: required concept, scope, task list, and lessons placeholder.
- `games/07-tiny-kitchen-rush/scenes/Main.tscn`: root scene, UI, ingredient buttons, and primitive counter visuals.
- `games/07-tiny-kitchen-rush/scripts/main.gd`: order generation, recipe matching, timers, UI state, win/loss, and restart.
- `games/07-tiny-kitchen-rush/icon.svg`: placeholder icon.

## Testing

Use available command-line validation:

- `godot --headless --path games/07-tiny-kitchen-rush --editor --quit`
- `godot --headless --path games/07-tiny-kitchen-rush --quit-after 2`

Manual verification is required: launch the project, add ingredients, clear the plate, serve correct and incorrect plates, confirm patience misses orders, confirm 8 correct orders wins, confirm 3 misses loses, confirm shift timeout loses before 8 serves, and confirm `R` restarts after win/loss.
