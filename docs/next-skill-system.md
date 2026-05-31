# Next Skill System

The next effective skill for WikiQuest is `game-studio:game-ui-frontend`.

Use it before more release work. The project now builds publicly; the weak part is player feel: the first launch, quest deck, HUD rhythm, photo reveal, and game screens.

## Why This Skill

WikiQuest should read as a playable Wikipedia system within a few seconds. The UI needs game discipline:

- one primary visual object per screen
- one compact HUD strip
- one bottom command area
- minimal persistent chrome
- strong photo use without spoiling answers
- motion only for state changes, reward, reveal, and completion

This is closer to game HUD/product design than standard app redesign.

## Skill Order

1. `game-studio:game-ui-frontend`
   Define the playable surfaces: Quest Deck, Mystery, Race, Map, App Clip, HUD strips, and command areas.
2. `design-consultation`
   Tighten the visual direction: photo treatment, Archive Compass usage, typography, color, and spacing.
3. `plan-design-review`
   Cut weak copy, excess panels, generic mobile patterns, and low-value motion before implementation.
4. `plan-eng-review`
   Split the work into safe SwiftUI changes with tests and no new runtime dependencies.
5. `ship`
   Run public CI, TestFlight archive, device screenshots, and release notes only after the visual pass exists.

Do not start with `ship`. Shipping a weak flow faster is not the right bottleneck.

## Next Implementation Target

Build **Quest Deck V2** as the center of the app.

First shipped slice:

- Home deck is image-first with HUD overlay.
- `Daily Mystery` is the primary deck action.
- Mystery/Race/Map moved into a compact command rail.
- Discovery photos remain secondary.
- Public CI remains the gate after each slice.

### First Launch

- boot tick: Archive Compass mark, `WikiQuest`, short system pulse
- playable preview: one blurred Wikipedia image clue, three choices, one reveal
- primary action after result: `Sign in with Apple`
- legal links visible before sign-in
- no dock while signed out

### Signed-In Today

- one large Daily Mystery deck card with image-safe clue state
- compact ticker strip: XP, streak, rank
- three mode entries: Mystery, Race, Map
- no marketing copy
- no stacked card grid

### Mystery

- large locked/revealed photo clue area
- clue ticks, guess count, time, score
- flat article input and suggestion rail
- result stamp and media credit after reveal
- shipped first V2 slice: photo clue now owns the HUD overlay, progress strip, and media credit

### Race

- current article hero image
- target tile
- blue-link choices with tiny thumbnails where available
- click/time HUD
- visual path trail
- shipped first V2 slice: current article now owns the playfield, target/XP moved into objective strip

### Map

- map-first header
- compact phase HUD
- pin pulse on placement
- reveal photo card only after guess
- distance ticker and source credit
- shipped first V2 slice: map owns phase/page/distance HUD, below-map copy is now command/status

### App Clip

- same visual language as onboarding preview
- one local Clip Quest round
- no account, purchases, XP, or full app shell
- install/open full app CTA after result

## Implementation Constraints

- SwiftUI only.
- No new animation libraries.
- Use existing `WikiTheme`, `WikiMotion`, `WikipediaClient`, `SessionStore`, `PurchaseStore`, and `WikiQuestSnapshotStore`.
- Add small UI-only types only when they simplify state.
- Keep media spoiler rules explicit in code and tests.
- Public CI must stay green after every step.

## Acceptance Criteria

- App feels playable before sign-in.
- Screenshots show Wikipedia/media first, not generic app panels.
- No tall dock active column.
- No floating form island.
- No repeated brand/logo clutter inside signed-in tabs.
- No blank image states; every media slot has a deliberate fallback.
- Text fits on small iPhone.
- Reduce Motion removes non-essential animation.
- Public CI passes.
- TestFlight screenshot review passes before release.
