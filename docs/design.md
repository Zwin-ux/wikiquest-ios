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

### Plan Design Review: Mode Screens

Status: cleared for the next implementation pass with focused cleanup.

Current score: 7.4/10. The direction is right: the modes now use real media, HUD pills, and playfield-first composition. The remaining design debt is old app layout competing with the game stage.

Priority fixes:

1. Make the stage first on Mystery and Race.
   - Remove or collapse the old `ScreenHeader` copy above the visual stage.
   - The first visible object should be the puzzle/photo/race state, not explanatory app text.
   - Keep the navigation title for system orientation, but do not repeat the same idea as a large page intro.

2. Remove duplicate metrics.
   - Mystery currently shows score in both the stage HUD and the status strip.
   - Race has route/title data above the stage and target data below it.
   - Each mode gets one HUD cluster for live state and one objective/status strip for context.

3. Tighten command placement.
   - Commands should read as game actions: `Reveal`, `Guess`, `Choose`, `Place pin`, `Next`.
   - Keep command rows close to the playfield state they affect.
   - Avoid sections that feel like settings panels or admin forms.

4. Keep photo hierarchy disciplined.
   - Mystery: hidden answer image stays locked until the thumbnail clue or result state.
   - Race: current page image is primary; target image is objective context.
   - Map: MapKit remains primary; article photo appears only on reveal.
   - Every media slot must have an intentional fallback, never a blank empty rectangle.

5. Reduce small-screen risk.
   - HUD pills should wrap into a compact cluster or hide labels before overlapping.
   - Long article titles should scale down or line-limit inside the stage.
   - Bottom command areas must remain tappable above the dock.

Pass scores:

- Information architecture: 7/10 -> target 8.5/10 after old headers are removed.
- Gameplay states: 7/10 -> target 8/10 after duplicate metrics are consolidated.
- User journey: 7.5/10 -> target 8.5/10 after commands sit closer to the playfield.
- AI slop resistance: 8.5/10 -> target 9/10 by cutting explanatory copy.
- Design system reuse: 8/10 -> target 8.5/10 with one shared stage/HUD rule.
- Responsive readiness: 6.5/10 -> target 8/10 after small-iPhone HUD rules are explicit.

Not in scope for this cleanup:

- New backend endpoints.
- New gameplay scoring rules.
- New animation libraries.
- Release workflow changes.
- Public App Store submission assets.

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
