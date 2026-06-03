# Design Principles

WikiQuest should feel like a game system built out of Wikipedia, not a generic mobile app.

## Identity

- Paper and ink first.
- Mode accents: Mystery amber, Race blue, Map green.
- Simple blue `W` mark.
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
- Let the mode rail adapt to two columns on narrow phones instead of squeezing text and icons.
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

Status: cleanup slice implemented for Mystery, Race, and Map.

Current score: 7.4/10. The direction is right: the modes now use real media, HUD pills, and playfield-first composition. The remaining design debt is old app layout competing with the game stage.

Implemented cleanup:

- Deck, Mystery, and Race now hide the shared OS/window header so the first visible object is the play surface.
- Deck now opens directly on the Daily Mystery photo card, with stats and mode commands after the visual object.
- Mystery starts with the photo stage, moves mode switching below the stage, and removes the duplicate score/time status strip.
- Race starts with the current article stage, removes the old route explainer, and attaches the trail directly under the target objective strip.
- Map removes the extra lower window header and groups status, city jumps, reveal state, and map actions into one flat command sheet.

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
- Shared HUD cleanup: Quest Deck, Mystery, Race, and Map use one `GameHUDCluster` rule now. Dense clusters collapse labels before covering the playfield, while accessibility labels keep the metrics understandable.
- Onboarding preview cleanup: the first playable round uses the same HUD language and result-specific haptics as the signed-in game surfaces.
- Onboarding result cleanup: preview replay is now a compact utility icon and mode rows use signed-in game verbs, keeping Sign in with Apple as the only large first-launch command.
- Race trail cleanup: the path now reads as a moving route rail with numbered visited nodes, a current-article marker, fresh connector feedback, and automatic scroll-to-latest behavior.
- Map reveal cleanup: the command sheet now gives Reveal/Next priority, keeps Locate as a small utility control, and turns distance/XP into a clear result strip before the revealed article photo.
- Media fallback cleanup: every shared image surface now has a mode-aware archive fallback, so no-image and image-load failure states still look like WikiQuest rather than broken media.
- Discovery rail cleanup: Today pulls a wider random-page batch concurrently and shows more compact Wiki drift cards, giving the Deck more real Wikipedia texture without adding another panel.
- Discovery scan cleanup: Wiki drift now renders as a compact scan surface with article/photo counts, drift stamps, and photo/archive badges, making the rail feel like game instrumentation rather than passive browsing.
- Recovery cleanup: Mystery, Race, Map, Ranks, Me, and Game Center failures now show a direct retry command instead of passive error text, keeping both gameplay and account surfaces recoverable after API/network failures.
- Game Center reward cleanup: completed Daily, Race, Map, and Member events now emit one compact top-edge reward ribbon when Game Center is connected, keeping reward motion visible without covering the playfield.
- Mystery clue filmstrip cleanup: the stage progress strip now shows clue-type symbols for opened hints and locked slots for the rest, so the reveal loop reads more like a playable case board than a generic counter row.
- Race route-lane cleanup: blue-link choices now read as marker + lane + article thumbnail + compact action badge, improving the sense that each tap advances a route rather than opens a normal list item.
- Race route-verb cleanup: Link Race now uses `Pick next exit`, `Take`, `Trace`, and route-tracing loading states instead of browser-like `Choose`, `Open`, or `GO` labels.
- Race objective cleanup: the current article photo now carries a `START`/`ROUTE` badge and the target strip shows route state instead of active-round `0 XP`; XP stays reserved for finish/reward surfaces.
- Race exit-command cleanup: the blue-link list now has one compact command header with open/seen exit stats and tracing state, replacing the extra route-lock row with clearer next-action instrumentation.
- Race transition cleanup: active link taps no longer insert a full loading glyph above the current article stage; tracing feedback stays inside the route header and selected exit lane so the playfield does not jump.
- Map result-line cleanup: reveal now draws a red line between the guess pin and target pin on the MapKit stage, with the reveal summary using the same pin-to-target language.
- Map reveal-grade cleanup: the reveal panel now grades the pin distance using the existing scoring bands and shows a compact pin -> target -> XP rail before the revealed article photo.
- First-impression cleanup: onboarding now leads with a compact `WikiQuest` cartridge header, keeps the photo preview as the main object, and pins Sign in with Apple as a bottom command bar so small phones always expose the account action without turning the screen into a form.
- Onboarding boot pulse cleanup: the first-launch header uses a tiny live `READY` ticker beside the blue `W`, making the app feel like a playable system without adding copy or extra chrome.
- Onboarding answer-lane cleanup: preview answers now read as game lanes with `ANSWER 01` metadata and `PICK`, `HIT`, `MISS`, or `LOCKED` badges, so first launch feels playable before Apple sign-in.
- Onboarding reveal-loop cleanup: the preview photo now carries an explicit `CLUE`/`REVEALED` stage badge, the HUD tracks photo state instead of static choice count, and first-launch copy is shorter around the simple blue `W`.
- Onboarding boot-sequence cleanup: the one-time boot now wakes Mystery, Race, and Map as compact mode-coded `READY` rows instead of generic loading sentences.
- Quest Deck motion cleanup: the main deck card now has a tiny route pulse in the HUD corner, giving the signed-in start screen a live game-system feel while preserving the one-object layout.
- Quest Deck command cleanup: mode tiles now end with specific game verbs instead of a generic `Open` label, so Today reads like choosing the next quest rather than browsing app tabs.
- Quest Deck command-badge cleanup: mode verbs now render as compact colored action badges on the photo tile, making each quest choice read as a playable command instead of low-contrast metadata.
- Quest Deck daily-state cleanup: the primary Daily card now uses the actual daily puzzle state, staying locked before the thumbnail hint, switching to clue media only when revealed, and showing answer/source only after completion.
- Quest Deck next-action cleanup: the Daily card command now changes with puzzle state: load daily, reveal first clue, finish mystery, or review result. Today reads as a live game state instead of a static app shortcut.
- Mystery command cleanup: Reveal hint is now the dominant gameplay command, while Refresh is a compact utility icon. This keeps the command area closer to a game verb row and stops maintenance controls from competing with the solve loop.
- Mystery suggestion rail cleanup: title suggestions now use horizontal numbered `GUESS` chips, keeping the solve command deck compact and making suggestions feel like playable guesses instead of stacked app rows.
- Mystery stage-HUD cleanup: the photo stage now carries a `LOCKED`/`CLUE`/`SOLVED`/`REVEALED` badge, active rounds show hints/guesses/time instead of premature score, and score stays reserved for reward/result moments.
- Mystery command-lane cleanup: the solve area now uses a compact command status strip and purpose-built article guess lane, so typing, guessing, and suggestion selection read as game actions instead of a generic form.
- Mystery result-loop cleanup: completed Daily runs now offer `Practice run`, and completed Practice runs offer `New practice`, using existing puzzle loading behavior so the result screen has one clear next play command plus a compact share utility.
- Race exit-lane cleanup: blue-link choices now have a full route-lane shell with `EXIT 01` metadata, thumbnail, connector, and action badge, making each tap read like advancing the route rather than selecting a generic list row.
- Mystery result cleanup: the failed result now reads as `REVEALED`, matching the stage stamp, and sharing is a compact utility icon instead of a full text action under the result banner.
- Race completion cleanup: New race remains the primary post-result command, while Share route is now a compact utility icon with haptic feedback. The result screen reads as one outcome plus one next play action, not a mini settings panel.
- Map reveal action cleanup: Next stays the primary post-result command, while Share result joins Locate as a compact utility icon. This keeps the lower command sheet focused on replaying the map rather than stacking secondary text actions.
- Map survey-strip cleanup: the lower map header now reads as compact instrument metadata with center, phase, page count, and pin/distance chips instead of a large logo plus explanatory paragraph.
- Map city rail cleanup: sample-city jumps now live in a horizontal command rail with selected-state feedback, keeping the lower sheet tappable on small iPhones instead of squeezing utility chips into one row.
- Map command-deck cleanup: reveal/next now live in a Map-specific primary action lane above the revealed photo, with `PIN READY`, `REVEAL`, `NEXT`, and utility icons visible before the larger article card can push controls down.
- Command-lane motion cleanup: onboarding answers, Mystery guesses, Race exits, and Map reveal/next now share one short command pulse, making taps feel accepted without adding cinematic motion or new dependencies.
- Quest Deck motion consistency: the Daily card and Mystery/Race/Map mode tiles now use the same command pulse as gameplay lanes, so Today feels like the start of play rather than an app menu.
- Dock feedback cleanup: signed-in tab changes now use the same compact command pulse and expose stable dock identifiers for screenshot QA, keeping navigation tactile without bringing back a tall active column.
- Simple W brand cleanup: AppIcon, BrandMark, BrandGlyph, favicons, and web logo now use one optically centered path-based blue `W` with no compass ornament, SVG text, or font dependency. The mark should stay plain so the photo-led game surfaces carry the visual richness.
- Map playfield cleanup: the MapKit stage now keeps only the compact phase badge and HUD on top of the map; the bottom-left instruction panel was removed so pin placement has a clearer play surface and commands stay in the lower sheet.
- Map overlay primitive cleanup: the old `MapCommandOverlay` component was removed from the shared design system so future Map passes do not reintroduce persistent lower-map instruction panels.
- Race trail primitive cleanup: the old generic trail panels were removed from the shared design system; Race keeps its dedicated route rail so path feedback stays attached to gameplay instead of becoming another boxed section.
- Photo-stage signal cleanup: large article stages now expose a tiny `PHOTO`/`CLUE`/`ARCHIVE`/`LOCKED` scan badge, giving onboarding, Deck, Mystery, Race, and reveal previews a live game-object feel without adding new panels or noisy animation.
- Map phase-signal cleanup: the MapKit stage now uses the same scan-badge language for locating, loading, pin, reveal, and empty states, keeping Map visually alive without adding a bottom-left instruction overlay.
- Quest Deck reminder cleanup: the daily notification control is now a compact command strip instead of a `Reminder` card section, keeping Today focused on the play loop while still exposing the retention action.
- Race boot-stage cleanup: pre-route `READY`/`ROUTING` states now render as a Link Race stage with a scan badge, tiny HUD, and route pulse instead of a generic loading glyph above the game flow.
- Mystery loading cleanup: the puzzle-loading state now stays inside the command deck as a `SYNC` strip with clue/shot metadata and a tiny rail, instead of inserting a generic loading component under the photo stage.
- Map loading cleanup: locating/loading now stays inside the lower command sheet as a `LOCATE`/`SCAN` strip with page count and a tiny rail, instead of adding a generic loading block below the MapKit stage.
- Mystery empty-clue cleanup: the clue timeline now opens as a locked clue rail with a live `LOCKED` badge instead of a generic `READY` notice, so the first unrevealed state still reads as game instrumentation.
- Quest Deck rail cleanup: the Daily card's top rail now ticks across markers instead of breathing on a fixed segment, matching the short rail motion used by Mystery, Race, and Map.
- Onboarding boot-handoff cleanup: the first boot no longer ends on a generic `Continue`; it uses a flat `Boot ready` / `Start preview` command with a short rail tick and haptic tap.
- Onboarding path-strip cleanup: first-launch mode rows now read as compact PATH 01/02/03 command lanes with mode glyphs, action badges, and a reduced-motion-aware rail instead of plain app rows.
- Quest Deck mode-path cleanup: signed-in Mystery/Race/Map tiles now cycle a compact path rail, keeping the mode picker alive as route selection without adding another panel.

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
