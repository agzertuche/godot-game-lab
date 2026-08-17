# Elevator Rush Setup Controls Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the cramped Elevator Rush V2 setup table with three persistent, high-contrast touch-friendly elevator strategy cards.

**Architecture:** Keep `Main.gd` as the existing strategy-binding authority and preserve the live queuing semantics. Restructure only `Main.tscn` presentation nodes into larger per-elevator cards, then add a small UI-state helper in `Main.gd` so every card clearly reports its effective or queued configuration.

**Tech Stack:** Godot 4.7, Godot Control nodes, typed GDScript, Compatibility renderer.

---

### Task 1: Record the current control bindings and define card state copy

**Files:**
- Modify: `prototypes/elevator-rush/v2/scripts/main.gd`
- Test: Manual Godot scene check

**Step 1: Inspect the existing bindings**

Confirm `E1Min`, `E1Max`, `E1Stage`, `E1Mode`, and `E1Apply` (and E2/E3 equivalents) are resolved and connected by the existing setup code. Preserve node names so strategy semantics do not change.

**Step 2: Add a small display helper**

Add a helper that formats one status line from the controller/elevator state, for example:

```gdscript
func _strategy_summary(elevator: RushElevator) -> String:
    return "Serving floors %d–%d  •  Staging at %d" % [
        elevator.controller.min_floor,
        elevator.controller.max_floor,
        elevator.controller.staging_floor,
    ]
```

Use the existing queued-change information during a running wave so each card says either `ACTIVE NOW` or `QUEUED FOR NEXT IDLE`.

**Step 3: Keep behavior unchanged**

Do not change range validation, staging logic, modes, cooldowns, routing, dispatcher scoring, or button callbacks.

**Step 4: Static validation**

Run:

```bash
git diff --check
```

When Godot is available, run:

```bash
godot --headless --path prototypes/elevator-rush/v2 --editor --quit
```

**Step 5: Commit**

```bash
git add prototypes/elevator-rush/v2/scripts/main.gd
git commit -m "feat: clarify elevator strategy status"
```

### Task 2: Replace the compressed table with three elevator cards

**Files:**
- Modify: `prototypes/elevator-rush/v2/scenes/Main.tscn`

**Step 1: Expand the preparation panel**

Move the top of `PreparationPanel` high enough to contain three cards, while keeping it clear of the building HUD. Retain the portrait 600×960 viewport.

**Step 2: Create one visual card pattern per elevator**

For E1, E2, and E3, use a dark opaque `ColorRect` card with:

- A high-contrast elevator heading in a distinct accent color.
- A status/summary label immediately below it.
- Local labels `SERVE FROM`, `TO`, `STAGE AT`, and `MODE` placed above or beside their inputs.
- Existing SpinBox/OptionButton nodes resized to at least 44px tall.
- Existing apply action renamed to `APPLY TO ELEVATOR N`, resized to at least 44px tall, and given a saturated accent fill with white text.

Preserve the existing control node names and paths so `Main.gd` bindings continue to work.

**Step 3: Remove ambiguous table labels**

Delete or hide the dense shared `Header` and old plain `E#Status` rows only after their per-card replacement labels/status text are present.

**Step 4: Separate global actions**

Place the full-width Start button below the final card with a distinct green/high-contrast treatment. Keep the live Restart button in the header area, separate from setup controls.

**Step 5: Static validation**

Run:

```bash
git diff --check
```

**Step 6: Commit**

```bash
git add prototypes/elevator-rush/v2/scenes/Main.tscn
git commit -m "feat: improve elevator setup controls"
```

### Task 3: Apply high-contrast control styling and preparation/running state cues

**Files:**
- Modify: `prototypes/elevator-rush/v2/scenes/Main.tscn`
- Modify: `prototypes/elevator-rush/v2/scripts/main.gd`

**Step 1: Style all readable values**

Give SpinBoxes and OptionButtons opaque, light input surfaces with dark text. Ensure label text is bright white/pale blue on navy backgrounds. Maintain distinct E1/E2/E3 accent colors without using color as the only identifier.

**Step 2: Update card helper copy by phase**

During preparation, state that settings apply when the level starts. During a wave, state that Apply queues the requested strategy until the next idle moment; retain the existing 8-second cooldown behavior.

**Step 3: Verify no direct movement affordances were introduced**

There must be no move-up, move-down, go-to-floor, pickup, or drop-off control.

**Step 4: Static validation**

Run:

```bash
git diff --check
```

When Godot is available, run:

```bash
godot --headless --path prototypes/elevator-rush/v2 --quit-after 2
```

**Step 5: Commit**

```bash
git add prototypes/elevator-rush/v2/scenes/Main.tscn prototypes/elevator-rush/v2/scripts/main.gd
git commit -m "fix: improve setup control contrast"
```

### Task 4: Manually verify portrait usability

**Files:**
- Review: `prototypes/elevator-rush/v2/scenes/Main.tscn`
- Review: `prototypes/elevator-rush/v2/scripts/main.gd`

**Step 1: Preparation check**

Run V2 at 600×960. Confirm every E1/E2/E3 range, staging, mode, and Apply control is readable and individually tappable without overlap. Confirm Start is separated from Apply actions.

**Step 2: Running check**

Start a level. Confirm the same three cards remain usable, Apply queues the existing strategy change, and the status text makes the deferred activation clear.

**Step 3: Regression check**

Confirm no manual movement control exists and the autonomous simulation still starts/restarts normally.

**Step 4: Final static check**

```bash
git diff --check
git status --short
```

**Step 5: Commit any focused correction**

```bash
git add prototypes/elevator-rush/v2/scenes/Main.tscn prototypes/elevator-rush/v2/scripts/main.gd
git commit -m "fix: refine elevator setup layout"
```
