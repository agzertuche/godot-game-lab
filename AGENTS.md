# AGENTS.md

## Repository purpose

`godot-game-lab` is a learning repository containing a progressive series of very small 2D games built with Godot and GDScript.

The objective is to learn Godot mechanics, 2D game-development fundamentals, and reliable AI-assisted development by repeatedly finishing small playable projects.

This repository is not currently intended for polished commercial games.

## Primary goals

1. Finish small games instead of expanding them indefinitely.
2. Learn one small group of Godot concepts per game.
3. Increase complexity gradually.
4. Build complete gameplay loops: start, play, win or lose, and restart.
5. Use Codex to accelerate implementation while keeping the developer involved in design, testing, and review.
6. Prefer simple, readable solutions over scalable architecture designed for hypothetical future needs.

## Current constraints

Until the learning plan is complete:

- Use Godot 4 stable.
- Use GDScript unless a project explicitly requires something else.
- Build only 2D games.
- Use primitive shapes, generated placeholders, labels, or basic temporary assets.
- Do not spend time on original art, music, visual polish, narrative, settings, localization, online features, achievements, or platform integrations.
- Sound effects are optional and should only be added when they teach or clarify a mechanic.
- Each game should normally take between 2 and 6 focused hours.
- No game may exceed one weekend unless the developer explicitly changes its scope.
- Each game must remain independently runnable.
- Do not introduce external addons unless they solve an immediate, demonstrated problem.

## Repository structure

Expected structure:

```text
godot-game-lab/
├── AGENTS.md
├── README.md
├── shared/
└── games/
    ├── 01-dodge-blocks/
    ├── 02-collect-everything/
    ├── 03-breakout/
    ├── 04-one-room-shooter/
    ├── 05-tiny-tower-defense/
    ├── 06-tiny-idle/
    ├── 07-mini-platformer/
    ├── 08-tiny-roguelite-arena/
    ├── 09-micro-strategy/
    └── 10-three-day-game-jam/
```

Each game should normally be its own Godot project with its own `project.godot`.

Do not create a shared framework prematurely. Add code to `shared/` only after at least two completed games contain substantially identical, proven code that is genuinely useful to reuse.

## Progressive learning plan

### Game 1: Dodge the Blocks

Concept: Move around one screen and avoid falling blocks for 30 seconds.

Learn:

- Godot editor basics
- Scenes and nodes
- `CharacterBody2D`
- Input actions
- Collision
- Timers
- Scene instantiation
- Basic labels
- Restarting a scene

Completion criteria:

- Player movement works.
- Blocks spawn.
- Collision causes a loss.
- Surviving 30 seconds causes a win.
- The game can restart.

### Game 2: Collect Everything

Concept: Collect ten objects before time runs out.

Learn:

- `Area2D`
- Signals
- Counters
- Random placement
- Removing collected objects
- Basic win and loss state management

Completion criteria:

- Objects can be collected.
- The counter updates.
- Collecting ten objects wins.
- The timer expiring loses.
- The game can restart.

### Game 3: Breakout

Concept: Control a paddle, bounce a ball, and destroy every block.

Learn:

- Physics movement
- Collision response
- Reusable scenes
- Groups
- Simple level layouts

Completion criteria:

- Paddle movement works.
- The ball bounces predictably.
- Blocks disappear on impact.
- Clearing the blocks wins.
- Losing the ball loses.
- The game can restart.

Do not add power-ups.

### Game 4: One-Room Shooter

Concept: Survive for one minute against enemies that move toward the player.

Learn:

- Projectiles
- Cooldowns
- Enemy movement
- Health and damage
- Spawning
- Basic reusable components

Completion criteria:

- The player shoots.
- Enemies chase the player.
- Enemies and the player can take damage.
- Surviving one minute wins.
- Player death loses.
- The game can restart.

Use one weapon and one enemy type.

### Game 5: Tiny Tower Defense

Concept: Place towers beside one fixed enemy path and survive three waves.

Learn:

- `Path2D` and `PathFollow2D`
- Mouse input
- Placement validation
- Target selection
- Attack range
- Currency
- Wave sequencing

Completion criteria:

- Enemies follow one path.
- One tower type can be placed.
- Towers attack automatically.
- Three waves are playable.
- A clear win and loss condition exists.

Do not add upgrades or branching paths.

### Game 6: Tiny Garden Idle

Concept: Tend a tiny garden, earn coins manually and passively, buy plots, and improve watering.

Learn:

- Timer-driven passive income
- Button-driven interaction
- Incremental costs
- Upgrade balancing
- UI state and disabled buttons
- Simple visual feedback
- Win detection without a lose condition

Completion criteria:

- The player can earn coins manually.
- Owned plots generate passive coins.
- Plots can be bought with increasing costs.
- Watering upgrades increase production.
- Reaching the target total wins.
- The game can restart after winning.

Do not add save data, offline progress, prestige, multiple currencies, inventories, or multiple screens.

### Game 7: Mini Platformer

Concept: Reach the exit of one short level.

Learn:

- Gravity
- Jumping
- Floor detection
- Moving platforms
- Hazards
- Checkpoints
- Camera movement

Completion criteria:

- Running and jumping work.
- One hazard exists.
- One moving platform exists.
- One checkpoint exists.
- Reaching the exit wins.

Do not add combat.

### Game 8: Tiny Roguelite Arena

Concept: Survive five minutes, gain experience, and choose simple upgrades.

Learn:

- Experience and leveling
- Upgrade choices
- Data-driven configuration
- Difficulty scaling
- Managing multiple entities
- Reusable gameplay components

Completion criteria:

- One weapon exists.
- Two enemy types exist.
- Three upgrade choices exist.
- Surviving five minutes wins.
- Player death loses.
- The game can restart.

Do not add procedural maps, shops, inventories, or permanent progression.

### Game 9: Micro Strategy

Concept: Capture three resource points while defending a base on one screen.

Learn:

- Unit selection
- Click-to-move
- Simple state machines
- Resource production
- Basic opposing behavior
- Coordinating multiple entities

Completion criteria:

- Units can be selected and moved.
- Resource points can be captured.
- The opponent sends units toward the player.
- Capturing all points wins.
- Losing the base loses.

### Game 10: Three-Day Game Jam

Concept: Create a new small game using previously learned mechanics.

Constraints:

- One core mechanic
- One screen or one short level
- At most two enemy types
- At most one upgrade system
- No online features
- No procedural world
- No complex narrative
- No custom-art requirement
- No music requirement

The game is complete when another person can launch it, understand the objective, play it, reach an ending, and restart without developer assistance.

## Required workflow for every game

Before implementation, create a short `README.md` inside the game folder containing:

```text
# Game title

Player:
Objective:
Main obstacle:
Win condition:
Lose condition:

## Scope

## Tasks

- [ ] Maximum of ten initial tasks

## Lessons

Complete this section after finishing the game.
```

Then follow this order:

1. Define the five-line game concept.
2. Create no more than ten initial implementation tasks.
3. Build the smallest ugly playable version.
4. Complete the full gameplay loop.
5. Test the game manually.
6. Fix blocking errors.
7. Export or produce a runnable build when practical.
8. Record lessons learned.
9. Mark the game finished and stop adding features.

## Definition of done

A game counts as finished when:

- Its central mechanic works.
- Its objective is clear.
- It has a reachable win condition, lose condition, or both as appropriate.
- It can restart without reopening the editor.
- It has no known blocking errors.
- Its game-specific README contains lessons learned.
- The final changes are committed.

The following are not required:

- Original art
- Music
- Polished animation
- Multiple levels
- Save data
- Settings
- Tutorials
- Controller support
- Steam integration
- Perfect architecture
- Full automated test coverage

## Instructions for Codex

### General behavior

- Inspect the relevant project and existing conventions before editing.
- Work on one small, testable feature at a time.
- Make reasonable assumptions when details are minor.
- Preserve the current game scope.
- Prefer the smallest implementation that produces a complete working behavior.
- Do not add features that were not requested.
- Do not refactor unrelated code.
- Do not create generalized systems for hypothetical future games.
- Do not introduce dependencies without explaining why the built-in Godot APIs are insufficient.
- Do not modify completed games unless explicitly asked.
- Never overwrite local user changes that are unrelated to the current task.
- Stop and report unexpected unrelated modifications before continuing.

### Godot implementation rules

- Follow the official GDScript style guide.
- Prefer typed GDScript where it improves clarity.
- Prefer composition through small nodes or resources over deep inheritance.
- Use signals to reduce unnecessary coupling.
- Keep scene responsibilities narrow and understandable.
- Use descriptive node names.
- Avoid hard-coded node paths when a local exported reference or clearly scoped lookup is more maintainable.
- Avoid global autoloads unless the behavior is genuinely global.
- Keep `_process()` and `_physics_process()` lightweight.
- Use `_physics_process()` for physics movement.
- Use `delta` for frame-rate-dependent movement.
- Configure gameplay inputs through Godot's Input Map.
- Use collision layers and masks intentionally.
- Avoid manually editing complex `.tscn` resources when the Godot editor or an established script is safer.
- Do not add shaders, complex particles, advanced animation systems, or asset pipelines during the early games unless the mechanic specifically requires them.

### Validation

For every implementation task:

1. Identify the affected Godot project.
2. Inspect `project.godot`, relevant scenes, scripts, and input configuration.
3. Make the smallest coherent change.
4. Validate GDScript parsing when the Godot executable is available.
5. Run the project or relevant scene when practical.
6. Report what was tested and what still requires manual verification.

Suggested commands, depending on the installed executable:

```bash
godot --version
godot --headless --path games/01-dodge-blocks --editor --quit
godot --headless --path games/01-dodge-blocks --quit-after 2
```

On macOS, the executable may instead be:

```bash
/Applications/Godot.app/Contents/MacOS/Godot
```

Do not claim a game works solely because the scripts parse. Gameplay behavior still requires running and manually checking the project.

### Git behavior

- Review `git status` before editing.
- Keep commits small and focused.
- Do not commit generated import data, editor caches, exports, or operating-system files.
- Do not rewrite history.
- Do not use destructive Git commands unless explicitly instructed.
- Suggested commit prefixes:
  - `feat:`
  - `fix:`
  - `refactor:`
  - `docs:`
  - `chore:`

## Scope control

When a requested change exceeds the current game's intended scope:

1. Point out the scope increase directly.
2. Propose the smallest version that still teaches the requested mechanic.
3. Implement only the reduced version unless the developer explicitly chooses the larger scope.

Examples of scope increases to challenge:

- Adding multiplayer
- Adding procedural generation
- Adding inventories
- Adding multiple upgrade trees
- Adding account systems
- Adding a reusable engine-wide framework
- Adding extensive art or audio pipelines
- Adding several levels before the first level is complete
- Adding multiple enemy or weapon types before one works end to end

## Architecture guidance

Architecture should mature progressively:

- Games 1–3: direct, local scripts are acceptable.
- Games 4–6: introduce small reusable scenes and components where repetition is visible.
- Games 7–9: use clearer state separation and data-driven configuration where it solves actual complexity.
- Game 10: reuse only patterns that proved useful in completed games.

Duplication is preferable to the wrong abstraction during early learning projects.

## References

### Codex

- Codex repository: https://github.com/openai/codex
- OpenAI introduction to Codex and `AGENTS.md`: https://openai.com/index/introducing-codex/
- Codex configuration documentation: https://github.com/openai/codex/blob/main/docs/config.md
- Example Codex `AGENTS.md`: https://github.com/openai/codex/blob/main/AGENTS.md

### Godot documentation

Use stable documentation unless the repository pins a specific Godot version.

- Godot stable documentation: https://docs.godotengine.org/en/stable/
- Getting started: https://docs.godotengine.org/en/stable/getting_started/introduction/index.html
- Step-by-step fundamentals: https://docs.godotengine.org/en/stable/getting_started/step_by_step/
- First 2D game: https://docs.godotengine.org/en/stable/getting_started/first_2d_game/index.html
- 2D documentation: https://docs.godotengine.org/en/stable/tutorials/2d/index.html
- GDScript documentation: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html
- GDScript style guide: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html
- Signals: https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html
- Input examples: https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html
- 2D movement overview: https://docs.godotengine.org/en/stable/tutorials/2d/2d_movement.html
- Command-line tutorial: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- Exporting projects: https://docs.godotengine.org/en/stable/tutorials/export/index.html
- Godot class reference: https://docs.godotengine.org/en/stable/classes/

## Optional Godot MCP integration

A Godot MCP server is not required for this learning plan. Codex can edit project files and invoke the Godot command-line executable without one.

MCP should be evaluated only after Game 1 works through the normal editor-and-CLI workflow. This makes it possible to distinguish Godot problems from MCP integration problems.

There is currently no official Godot-maintained MCP server established as the project standard. Community options exist and must be treated as third-party code with broad local access.

Candidate for evaluation:

- Repository: https://github.com/tugcantopaloglu/godot-mcp
- Requires Node.js 18 or later.
- Requires Godot 4.4 or later.
- Provides editor, project, runtime, scene, script, and validation tools.
- Review its source, permissions, open issues, and release notes before installing.
- Restrict it to the `godot-game-lab` directory when the server supports allowed-directory configuration.
- Do not expose secrets or unrelated directories.
- Pin a known release instead of automatically following the latest branch.

Possible Codex registration pattern after cloning and building the server:

```bash
codex mcp add godot -- node /ABSOLUTE/PATH/TO/godot-mcp/build/index.js
codex mcp list
```

The exact server entry point must be confirmed from the selected release's README after installation. Do not guess it from this file.

Alternative community implementation:

- https://github.com/mkdevkit/godot-mcp

Do not install multiple Godot MCP servers simultaneously. Start without MCP, evaluate one server, and keep it only if it makes scene inspection, runtime debugging, or validation measurably easier.

## Decision priority

When instructions conflict, prioritize:

1. A complete playable loop
2. The current game's explicit scope
3. Correct and understandable behavior
4. Learning value
5. Simple maintainable code
6. Reuse
7. Polish
