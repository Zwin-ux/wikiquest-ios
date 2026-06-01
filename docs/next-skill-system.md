# Next Skill System

The active goal is to execute the WikiQuest iOS photo-led native game overhaul with the right Codex/gstack skill at each phase.

Use this runbook before more release work. The project now builds publicly; the weak part is player feel: the first launch, quest deck, HUD rhythm, photo reveal, and game screens.

## Program Command Chain

Run these phases in order. Each phase has one primary skill, one job, and the concrete commands/functions that prove it is done.

| Phase | Primary skill | Job | Commands / functions |
| --- | --- | --- | --- |
| 1. Product taste lock | `design-consultation` | Keep the direction sharp: simple blue `W`, photo-led game surfaces, no SaaS/web landing patterns. | Read `docs/design.md`; update only if the visual contract changes. |
| 2. Game UI map | `game-studio:game-ui-frontend` | Convert WikiQuest into playable surfaces: preview, Quest Deck, Mystery, Race, Map, App Clip. | Update `docs/next-skill-system.md`; map one visual object, one HUD strip, one command area per screen. |
| 3. Design review | `plan-design-review` | Kill weak hierarchy, over-copy, fake OS labels, clutter, and motion that does not explain state. | Review planned screen changes before touching SwiftUI. |
| 4. Engineering review | `plan-eng-review` | Keep the SwiftUI changes safe, testable, and scoped to existing architecture. | Verify reuse of `WikiTheme`, `WikiMotion`, `WikipediaClient`, `SessionStore`, `PurchaseStore`, `WikiQuestSnapshotStore`. |
| 5. Implementation slice | Codex implementation | Build in thin vertical slices: onboarding/preview, Today deck, Mystery, Race, Map. | Edit Swift with `apply_patch`; add/update focused tests under `Tests/WikiQuestTests`. |
| 6. Local validation | `qa` where applicable | Run every check possible from Windows. | `corepack pnpm@10 run assets:wikiquest`; `corepack pnpm@10 run typecheck`; Railway smoke URLs; `git status --short`. |
| 7. Native CI | GitHub Actions | Validate Swift/Xcode on macOS. | `gh run list --repo Zwin-ux/wikiquest-ios --limit 8`; inspect latest `iOS CI`. |
| 8. Release gate | `ship` | Upload only after CI, backend, assets, and screenshots are ready. | Run TestFlight workflow with `confirm_backend_ready=true`; inspect IPA includes `WikiQuestClip.app`. |

Do not start with `ship`. Shipping a weak flow faster is not the right bottleneck.

## Current Command Function

The program is now locked to this loop until the core game screens feel good:

1. `game-studio:game-ui-frontend` decides the play surface budget.
2. `plan-design-review` removes weak hierarchy, extra copy, and non-game chrome.
3. `plan-eng-review` keeps the slice scoped to existing SwiftUI architecture.
4. Codex edits the smallest useful gameplay slice.
5. `qa` runs local script checks and inspects changed behavior.
6. GitHub `iOS CI` validates Swift/Xcode.
7. `ship` is only allowed after CI, backend smoke, and TestFlight screenshot review.

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
   Tighten the visual direction: photo treatment, blue `W` usage, typography, color, and spacing.
3. `plan-design-review`
   Cut weak copy, excess panels, generic mobile patterns, and low-value motion before implementation.
4. `plan-eng-review`
   Split the work into safe SwiftUI changes with tests and no new runtime dependencies.
5. `ship`
   Run public CI, TestFlight archive, device screenshots, and release notes only after the visual pass exists.

## Immediate Execution Target

Build **Quest Deck V2 + Mystery V2** first. This gives the whole product a new feel without touching every screen at once.

Implementation order:

1. Onboarding preview:
   - logo-first boot
   - blurred photo clue
   - three choices
   - result
   - Apple sign-in CTA
2. Today deck:
   - one large daily visual card
   - compact XP/streak/rank strip
   - Mystery/Race/Map command entries
3. Mystery:
   - photo stage owns the screen
   - HUD overlay handles hints/score/time
   - input/suggestions directly below stage
   - result stamp and media credit after reveal
4. Race:
   - current article stage first
   - target tile and path trail second
   - link rows subordinate to the route
5. Map:
   - MapKit first
   - bottom command sheet only
   - reveal photo after guess

## Next Implementation Target

Build **Quest Deck V2** as the center of the app.

First shipped slice:

- Home deck is image-first with HUD overlay.
- `Daily Mystery` is the primary deck action.
- Mystery/Race/Map moved into a compact command rail.
- Discovery photos remain secondary.
- Public CI remains the gate after each slice.
- next polish slice in progress: first-launch copy tightened and Today mode entries now use media-backed route tiles instead of utility boxes

### First Launch

- boot tick: simple blue `W`, `WikiQuest`, short system pulse
- playable preview: one blurred Wikipedia image clue, three choices, one reveal
- primary action after result: `Sign in with Apple`
- legal links visible before sign-in
- no dock while signed out
- preview HUD shipped: first launch now shows clue/choice/XP counters and numbered answer routes so the preview reads like a game round, not a static form

### Signed-In Today

- one large Daily Mystery deck card with image-safe clue state
- compact ticker strip: XP, streak, rank
- three mode entries: Mystery, Race, Map
- no marketing copy
- no stacked card grid
- deck HUD cleanup in progress: reset, streak, XP, and level now live on the photo card instead of a separate metric strip; mode tiles now use numbered route markers

### Mystery

- large locked/revealed photo clue area
- clue ticks, guess count, time, score
- flat article input and suggestion rail
- result stamp and media credit after reveal
- shipped first V2 slice: photo clue now owns the HUD overlay, progress strip, and media credit
- next design cleanup: make the photo stage the first object, remove duplicate score metrics, and keep the hint/guess commands directly under the playfield
- cleanup shipped: old intro header removed, mode switch moved under the stage, time joined the HUD, and the duplicate status strip was removed
- command cleanup shipped: guess field, reveal hint, refresh, suggestions, and result now sit directly under the photo stage before the clue log
- clue-stage polish shipped: linear progress bar replaced by numbered clue pips, photo stage gets a completion stamp, and revealed hints now read as a timeline

### Race

- current article hero image
- target tile
- blue-link choices with tiny thumbnails where available
- click/time HUD
- visual path trail
- shipped first V2 slice: current article now owns the playfield, target/XP moved into objective strip
- next design cleanup: remove old explanatory route header, move the trail closer to the objective strip, and keep link rows visually subordinate to the current article stage
- cleanup shipped: old route copy removed, unused route header components removed, and the trail now lives inside the route stage
- command cleanup shipped: next-link rows now read as a compact route command list with haptic tap feedback instead of a generic section
- finish cleanup shipped: completion now has a dedicated finish panel with clicks, time, XP, share, new race, and success haptic feedback
- route feedback shipped: link choices now have numbered lane markers, route-locked loading feedback, visited checks, and loading motion without adding another panel

### Map

- map-first header
- compact phase HUD
- pin pulse on placement
- reveal photo card only after guess
- distance ticker and source credit
- shipped first V2 slice: map owns phase/page/distance HUD, below-map copy is now command/status
- next design cleanup: remove redundant window/header chrome below the map and turn the lower area into one compact command sheet
- cleanup shipped: redundant lower window chrome removed, phase/status/actions now sit in one flat map command sheet
- command cleanup shipped: pin placement has tactile feedback, reveal/next inherits the phase tint, and map actions now appear before lower-priority city jumps
- reveal cleanup shipped: revealed target now reads as photo + distance/XP moment instead of duplicating title and description below the card
- pin feedback shipped: dropping a guess now arms the command sheet, updates the reveal action, and pulses once without duplicate haptic taps

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
