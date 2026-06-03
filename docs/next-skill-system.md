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
3. `design-shotgun`
   Explore a few concrete UI directions before code when a surface still feels weak; pick one restrained direction and do not turn every slice into a new style.
4. `plan-design-review`
   Cut weak copy, excess panels, generic mobile patterns, and low-value motion before implementation.
5. `plan-eng-review`
   Split the work into safe SwiftUI changes with tests and no new runtime dependencies.
6. `ship`
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
- first polish slice shipped: first-launch copy tightened and Today mode entries now use media-backed route tiles instead of utility boxes

### First Launch

- boot tick: simple blue `W`, `WikiQuest`, short system pulse
- playable preview: one blurred Wikipedia image clue, three choices, one reveal
- primary action after result: `Sign in with Apple`
- legal links visible before sign-in
- no dock while signed out
- preview HUD shipped: first launch now shows clue/choice/XP counters and numbered answer routes so the preview reads like a game round, not a static form
- preview HUD polish shipped: onboarding now uses the shared game HUD cluster, result-specific haptics, and stable preview choice identifiers
- signed-out dock gate verified: UI smoke tests keep the custom dock out of the onboarding flow
- reveal-loop polish shipped: the preview photo now shows `CLUE`/`REVEALED` state directly on the image, the HUD tracks photo state instead of a static choices count, and first-launch copy stays short beside the simple blue `W`
- boot-sequence polish shipped: the first-launch boot now advances through Mystery/Race/Map `READY` rows with mode accents instead of generic loading copy.
- boot-handoff polish shipped: the first boot now ends on a flat `Boot ready` / `Start preview` command with a rail tick instead of a generic `Continue` label.
- path-strip polish shipped: signed-out Mystery/Race/Map rows now use PATH metadata, command badges, and a small ticker rail, keeping onboarding game-like without adding another photo grid.

### Signed-In Today

- one large Daily Mystery deck card with image-safe clue state
- compact ticker strip: XP, streak, rank
- three mode entries: Mystery, Race, Map
- no marketing copy
- no stacked card grid
- shared fallback polish shipped: missing Daily/route/discovery media now uses a mode-aware archive surface instead of a generic dark placeholder
- deck HUD cleanup shipped: reset, streak, XP, and level now live on the photo card instead of a separate metric strip; mode tiles now use numbered route markers
- discovery rail cleanup shipped: random article photos now read as a secondary Wiki drift with numbered visual trail cards
- discovery rail density shipped: Today now pulls a broader concurrent random-page batch and shows a five-card Wiki drift rail with tighter reveal timing
- discovery scan polish shipped: Wiki drift now shows article/photo scan counts, per-card drift stamps, and photo/archive badges so the rail reads as a game-system scan instead of passive browsing.
- small-phone rail cleanup shipped: Mystery/Race/Map uses an adaptive grid so narrow phones get two readable columns instead of squeezed three-up tiles
- deck command motion shipped: the Daily card and mode tiles now use the shared command-lane pulse, matching the tactile feedback used inside Mystery, Race, and Map
- dock command feedback shipped: the custom dock now has per-tab QA identifiers and uses the same compact command pulse on tab changes
- smoke coverage shipped: signed-in UI tests now assert the Quest Deck card and Home mode rail exist
- shared HUD cleanup shipped: Quest Deck now uses the same compact game HUD cluster as the mode screens
- daily-state polish shipped: Today now drives the primary Daily card from `/api/daily-random/today`, using locked/clue/revealed media states instead of borrowing a random discovery photo.
- next-action polish shipped: Today now changes the Daily card command by state: load daily, reveal first clue, finish mystery, or review result.
- photo-stage signal shipped: the Daily card now carries a compact `PHOTO`/`CLUE`/`ARCHIVE`/`LOCKED` scan badge beside the WikiQuest label instead of adding another metric strip.
- reminder command polish shipped: the daily notification control now renders as a compact `Daily signal` command strip with arm/disarm states, removing the last generic reminder card from the Quest Deck flow.
- rail-motion polish shipped: the Daily card's top rail now ticks across markers instead of breathing on a fixed segment, matching the game rail motion used in Mystery, Race, and Map.
- mode-path polish shipped: signed-in Mystery/Race/Map tiles now cycle a compact path rail, so the mode picker reads as route selection rather than a static app menu.
- mode-rail review shipped: the signed-in mode rail now says `Path select` instead of generic choose-quest copy.

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
- verification cleanup shipped: photo stage, command deck, clue stack, guess field, hint action, refresh action, and suggestion rail now expose stable accessibility IDs for screenshot QA
- responsive HUD cleanup shipped: Mystery uses the shared game HUD cluster, so dense stage metrics collapse before crowding the photo
- fallback polish shipped: locked or missing Mystery media uses the clue fallback surface and keeps the answer hidden until reveal
- recovery cleanup shipped: Mystery errors now include a direct `Retry puzzle` command inside the command deck
- clue filmstrip shipped: opened Mystery hints now use type-specific symbols and locked slots instead of generic numbered boxes, making the reveal loop feel more like a game board
- stage-HUD polish shipped: Mystery photo stages now expose `LOCKED`/`CLUE`/`SOLVED`/`REVEALED` directly on the image, active rounds show hints/guesses/time, and score is reserved for result/reward surfaces
- command-lane polish shipped: Mystery now has a compact command status strip and article guess lane with submit feedback, keeping the solve action tactile without turning the input into a form island
- result-loop polish shipped: completed Daily Mystery now exposes a `Practice run` command and completed Practice exposes `New practice`, while share remains a compact utility action.
- photo-stage signal shipped: Mystery and preview photo clues now use the shared scan badge so clue/fallback/image states read as live stage instrumentation, not passive image labels.
- loading-strip polish shipped: Mystery puzzle loading now stays inside the command deck as a `SYNC` strip with clue/shot metadata and a tiny rail, replacing the generic loading glyph.
- empty-clue polish shipped: Mystery's unrevealed clue timeline now starts as a locked clue rail with a live `LOCKED` badge instead of a generic `READY` notice.
- solve-state review shipped: Mystery loading/status copy now uses clue-slot and solve language, failed results read `REVEALED`, and the empty clue rail says `SEALED` instead of `READY`.

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
- verification cleanup shipped: route photo stage, objective strip, trail, link choice list, per-link buttons, and completion panel now expose stable accessibility IDs for screenshot QA
- responsive HUD cleanup shipped: Race uses the shared game HUD cluster for click/time state
- trail motion cleanup shipped: Race path now reads as numbered route nodes with current-article emphasis, fresh connector feedback, sweep motion, and automatic scroll-to-latest behavior
- fallback polish shipped: current, target, and link-choice image failures now fall back to the article archive surface
- recovery cleanup shipped: Race route errors now include a `New race` command that also clears any live activity
- route-lane cleanup shipped: blue-link choices now use compact route connectors and TAKE/TRACE/SEEN badges so the next move feels like a route action instead of a generic row tap
- objective polish shipped: the Race photo stage now shows `START`/`ROUTE` on the current article image, and the target strip reports route state instead of showing active-round `0 XP`
- exit-command polish shipped: Race link choices now start with a compact command header showing ready exits, seen exits, and tracing state, so the next move reads as game instrumentation instead of a generic section header
- transition stability shipped: once the current article stage is visible, route tracing stays inside the exit header and selected exit lane instead of pushing a loading glyph above the playfield.
- photo-stage signal shipped: the current article stage now reports whether the route is using a real Wikipedia photo or archive fallback without crowding the target strip.
- boot-stage polish shipped: Race `READY` and initial `ROUTING` states now use a route boot stage with scan badge, HUD, and pulse rail instead of a generic loading glyph.
- exit-scan polish shipped: Race's blue-link command header now uses `Exit scan`, ready/seen/trace stats, and a tiny route rail instead of browser-like open-exit language.

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
- verification cleanup shipped: map stage, status, pin feedback, command sheet, action row, reveal panel, and city rail now expose stable accessibility IDs for screenshot QA
- responsive HUD cleanup shipped: Map uses the shared game HUD cluster for pages, score, and distance
- command/reveal polish shipped: Map now gives Reveal/Next the primary command width, demotes Locate to an icon utility, and shows distance/XP as a result strip before the revealed article photo
- fallback polish shipped: revealed targets without usable media now use the map fallback surface instead of a generic placeholder
- recovery cleanup shipped: Map API/location load errors now include a `Retry map` command that reloads the current center
- result-line cleanup shipped: revealed Map rounds now draw the guess-to-target line directly on the MapKit stage and label the summary as `Pin to target`
- survey-strip polish shipped: Map lower status now uses compact center/phase/pages/pin-distance chips with responsive stacking, keeping the command sheet from reading like explanatory app copy.
- reveal-grade polish shipped: Map reveal now grades the result with the same distance bands as scoring and shows a compact pin -> target -> XP rail before the article photo.
- playfield cleanup shipped: Map no longer places a bottom-left instruction panel over MapKit; the live stage keeps phase + HUD only, and instructions/commands stay in the lower command sheet.
- phase-signal polish shipped: the top-left Map phase chip now uses the shared scan badge for locating, loading, pin, reveal, and empty states, matching the live photo-stage language without covering the map.
- loading-strip polish shipped: Map locating/loading now renders as a lower command-sheet `LOCATE`/`SCAN` strip with page count and a tiny rail, replacing the generic loading glyph.
- city-scan polish shipped: sample-city controls now render as numbered `CITY` scan lanes with `SCAN`/`LIVE` badges and shared command feedback instead of utility jump chips.
- target-lock polish shipped: unplaced Map pins now read as `Aim on map` instead of a disabled set-pin command; placed pins show `Target lock`, a tiny lock rail, and `LOCKED` state, while empty/loading actions use scan language instead of generic choose/wait copy.

### Ranks / Me

- design-shotgun selection shipped: account and ranking failures use restrained OS command recovery, not modal alerts or red warning stacks
- recovery cleanup shipped: Ranks, Me, and Game Center errors now appear near the affected surface with one direct retry command
- empty-state cleanup shipped: Ranks only shows the empty board message after loading finishes and no API error is active
- reward polish shipped: connected Game Center reports now trigger one compact top-edge reward ribbon, and Daily Mystery fetches current streak before posting Daily/streak achievements

### App Clip

- same visual language as onboarding preview
- one local Clip Quest round
- no account, purchases, XP, or full app shell
- install/open full app CTA after result

### Brand

- simple blue `W` only
- paper tile background
- no compass ornament, mascot, SVG text, or font-rendered monogram
- let Wikipedia photos, map state, and game HUD motion provide the richness

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
- Manual `Screenshot Review` workflow produces PNG artifacts for icon, onboarding, Quest Deck, Mystery, Race, Map, Ranks, Me, and App Clip before final device review.
