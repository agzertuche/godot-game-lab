# Elevator Rush Setup Controls Design

## Goal

Make Elevator Rush V2's strategy controls easy to read and operate on a portrait touch screen before and during a wave, without changing the autonomous request-dispatch simulation.

## Approved approach: persistent elevator cards

Replace the compressed table layout with three vertically stacked, color-coded elevator cards. Each card keeps all strategy controls visible:

- Elevator identity and current effective strategy summary.
- Large, labeled Floor Range controls: `MIN` and `MAX`.
- Large, labeled `STAGE AT` floor control.
- A readable `SERVICE MODE` selector.
- A full-width per-card `APPLY TO ELEVATOR` action.

Cards remain visible during the automatic simulation. While running, their helper copy explains that an applied configuration queues for the next idle moment; this preserves the existing live-strategy behavior rather than adding direct movement controls.

## Layout and contrast

- Expand the preparation/control panel upward so each card has distinct visual boundaries and 44px-or-larger touch targets.
- Use a dark navy panel surface, bright white primary text, pale-blue secondary text, and a distinct high-contrast accent color for each elevator.
- Give input fields an opaque lighter surface with dark text, and apply buttons a saturated accent fill with white text.
- Replace the dense column header and status rows with clear local field labels and a short strategy summary per card.
- Keep the start action separated beneath the cards and visually dominant during preparation.
- Keep the running phase's restart action separate from strategy controls.

## Scope and validation

This is a presentation-only change to the existing setup controls. It will not alter passenger demand, controller routing, dispatcher scoring, strategy semantics, or level rules.

Manual validation will confirm that each control is legible at the default 600x960 portrait size, can be clicked/tapped without overlap, and continues to apply or queue the existing strategy behavior correctly in preparation and during a wave.
