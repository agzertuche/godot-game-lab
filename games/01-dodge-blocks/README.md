# Dodge the Blocks

Player: A simple player character moved by keyboard input on one screen.
Objective: Survive for 30 seconds.
Main obstacle: Falling blocks that spawn during play.
Win condition: The player avoids every block until the 30-second timer ends.
Lose condition: The player collides with a falling block.

## Scope

Build the smallest complete Godot 4 2D project that teaches movement, spawning, collision, timers, labels, and restarting. Use primitive shapes or generated placeholders only.

Do not add art polish, sound, power-ups, levels, menus beyond what the loop needs, scoring, difficulty modes, settings, or reusable framework code.

## Tasks

- [x] Create the Godot project for Game 1.
- [x] Configure movement input actions.
- [x] Create the main scene.
- [x] Add a controllable player.
- [x] Spawn falling blocks.
- [x] Detect player-block collision.
- [x] Add a 30-second survival timer.
- [x] Display basic win and loss state.
- [x] Add restart behavior.
- [x] Manually test the full loop.

## Lessons

- Direct local scenes and scripts were enough for the first complete loop.
- Godot rewrites scene and input-map metadata after editor use, so final commits should include the editor-normalized project files after manual testing.
- The smallest playable version was easier to verify than a more abstract setup: movement, spawning, collision, win, loss, and restart are all visible in one short run.
