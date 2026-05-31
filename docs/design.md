# Design Principles

WikiQuest should feel like a game system built out of Wikipedia, not a generic mobile app.

## Identity

- Paper and ink first.
- Mode accents: Mystery amber, Race blue, Map green.
- Archive Compass mark.
- Compact OS rhythm.
- Real article media instead of stock visuals.

## Screen Shape

- One strong visual object.
- One status/HUD strip.
- One command area.
- Minimal chrome.
- No stacked card islands.

## Quest Deck V2

The signed-in Home screen is the game start, not an app dashboard.

- Lead with one large Wikipedia media surface.
- Put time/reset/state as a small HUD overlay, not a separate metric card.
- Use a three-command mode rail for Mystery, Race, and Map.
- Keep discovery photos secondary and horizontal.
- Keep reminders and account utility below the primary play loop.
- Do not add marketing hero copy, carousel framing, or a grid of equal-weight cards.

Design review score after this decision: 8/10. The remaining gap is real-device screenshot review for image cropping, dock spacing, and small-iPhone mode rail density.

## Mode Screens V2

Mystery, Race, and Map use the same game-screen grammar as the deck.

- **Mystery:** photo clue is the stage; hints, score, guesses, and progress attach to that stage.
- **Race:** current article is the stage; target, clicks, time, XP, and path read as HUD/objective data.
- **Map:** MapKit is the stage; phase, page count, distance, score, and reveal photo sit around the map, not above it as app copy.
- Keep long explanations below the play surface or remove them.
- Show media credits only when media is visible.
- Do not repeat full headers, generic panels, and equal-weight metrics if the HUD already carries the state.

Plan-eng review result: UI-only implementation. Reuse existing view models, API clients, media parsing, haptics, and motion; do not add dependencies, backend routes, or release workflow changes.

## Motion

Use motion to confirm state:

- photo blur/unblur
- ticker numbers
- row reveal
- button press
- pin pulse
- result stamp

Avoid long cinematic animation. Respect Reduce Motion.

## Copy

Use short product language:

- `WikiQuest`
- `Mystery`
- `Race`
- `Map`
- `Solved`
- `Revealed`
- `Save your trail`

Avoid startup copy, generic productivity language, and empty hype.
