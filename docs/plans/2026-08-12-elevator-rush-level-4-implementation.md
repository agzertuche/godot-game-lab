# Elevator Rush Level 4 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a randomized-but-replayable fourth Elevator Rush V2 wave named Adaptive Chaos.

**Architecture:** Extend the existing level data with a Level 4 entry and add one stored Level 4 schedule in `main.gd`. The normal fixed-seed schedule builder continues to serve Levels 1–3; Level 4 generates its mixed traffic schedule exactly once when unlocked and reuses it for restarts/retries until the player requests a new challenge.

**Tech Stack:** Godot 4.7, GDScript, existing `Main.tscn` UI.

---

### Task 1: Add Level 4 data and schedule ownership

**Files:**
- Modify: `prototypes/elevator-rush/v2/scripts/main.gd:6-15`
- Modify: `prototypes/elevator-rush/v2/scripts/main.gd:140-175`
- Test: Manual Godot validation checklist in `prototypes/elevator-rush/v2/README.md`

**Step 1: Define the Level 4 requirement in code comments/data**

Add an `ADAPTIVE CHAOS` level entry with 60 passengers and a non-revealing forecast. Add a `generated_level_four_schedule` array field that survives retries.

**Step 2: Verify the pre-change behavior manually**

Run Level 3 in Godot and confirm there is no Level 4 unlock path.

**Step 3: Implement schedule selection**

Add a helper that returns the fixed-seed schedule for Levels 1–3, but generates and caches a mixed Level 4 schedule when that level has no stored schedule.

**Step 4: Verify the schedule logic statically**

Run:

```bash
git diff --check
rg -n 'ADAPTIVE CHAOS|generated_level_four_schedule' prototypes/elevator-rush/v2/scripts/main.gd
```

Expected: no whitespace errors and exactly one cached-schedule owner.

**Step 5: Commit**

```bash
git add prototypes/elevator-rush/v2/scripts/main.gd
git commit -m "feat: add adaptive chaos wave"
```

### Task 2: Generate mixed Level 4 demand

**Files:**
- Modify: `prototypes/elevator-rush/v2/scripts/main.gd:170-210`
- Test: Manual Godot validation checklist in `prototypes/elevator-rush/v2/README.md`

**Step 1: Describe the required generated demand**

The generated schedule must contain 60 passengers across the 60-second wave, mixing lobby-to-upper, upper-to-lobby, and cross-floor trips. Origin and destination must never match.

**Step 2: Implement the mixed-demand builder**

Use a fresh `RandomNumberGenerator` seed when creating a new Adaptive Chaos challenge. Divide requests across the three traffic types; use the existing schedule sort-by-time behavior.

**Step 3: Verify the generated schedule shape**

Add temporary, non-committed instrumentation only if Godot is available; otherwise inspect the builder for all three demand branches and non-equal origin/destination guard.

**Step 4: Run static validation**

```bash
git diff --check
rg -n 'adaptive|chaos|randi_range|destination == origin' prototypes/elevator-rush/v2/scripts/main.gd
```

Expected: all three traffic branches are represented and the existing non-equal-floor guard remains.

**Step 5: Commit**

```bash
git add prototypes/elevator-rush/v2/scripts/main.gd
git commit -m "feat: randomize adaptive chaos demand"
```

### Task 3: Add final-level replay choices

**Files:**
- Modify: `prototypes/elevator-rush/v2/scenes/Main.tscn:ResultsPanel`
- Modify: `prototypes/elevator-rush/v2/scripts/main.gd:320-370`
- Test: Manual Godot validation checklist in `prototypes/elevator-rush/v2/README.md`

**Step 1: Establish the desired result behavior**

Passing Level 4 shows `CONGRATULATIONS!` with two visible actions: `REPLAY SAME CHALLENGE` and `NEW CHALLENGE`.

**Step 2: Implement the second result button and handlers**

Reuse the existing results panel. The same-challenge handler returns to Level 4 preparation without clearing the stored schedule. The new-challenge handler clears/rebuilds the stored schedule, then returns to Level 4 preparation.

**Step 3: Verify UI node references**

```bash
rg -n 'SameChallenge|NewChallenge|REPLAY SAME|NEW CHALLENGE' prototypes/elevator-rush/v2
```

Expected: scene nodes and script bindings match exactly.

**Step 4: Run static validation**

```bash
git diff --check
```

Expected: exit 0.

**Step 5: Commit**

```bash
git add prototypes/elevator-rush/v2/scenes/Main.tscn prototypes/elevator-rush/v2/scripts/main.gd
git commit -m "feat: add adaptive challenge replay options"
```

### Task 4: Update documentation and validate the complete flow

**Files:**
- Modify: `prototypes/elevator-rush/v2/README.md`
- Modify: `prototypes/elevator-rush/v2/CONTEXT.md`
- Test: `prototypes/elevator-rush/v2` Godot project

**Step 1: Update prototype documentation**

Document Level 4, its generated-on-entry schedule, fair retry behavior, and the two final result choices. Add the term `Adaptive Challenge` to the glossary if the user-facing language uses it.

**Step 2: Run available automated validation**

```bash
git diff --check
godot --headless --path prototypes/elevator-rush/v2 --editor --quit
godot --headless --path prototypes/elevator-rush/v2 --quit-after 2
```

If `godot` is unavailable, record that the CLI could not be found; do not claim runtime validation.

**Step 3: Perform manual Godot validation**

1. Pass Level 3 and confirm Level 4 unlocks.
2. Start Level 4, restart it, and confirm passenger timing/origin/destination repeat.
3. Pass Level 4, choose replay-same, and confirm the schedule still repeats.
4. Pass Level 4, choose new-challenge, and confirm a different demand pattern appears.
5. Confirm the live strategy controls, cooldown, and 8.0 pass threshold still work.

**Step 4: Commit**

```bash
git add prototypes/elevator-rush/v2/README.md prototypes/elevator-rush/v2/CONTEXT.md
git commit -m "docs: explain adaptive chaos challenge"
```
