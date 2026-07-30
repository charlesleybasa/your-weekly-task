# Momentum

A gamified weekly kanban task manager with a built-in focus timer. Offline-first,
no account, no network. Plan a week, work one task at a time, finish it on a
timer, and watch the XP add up.

---

## Getting it running

This repository contains `lib/`, `test/`, `assets/` and `pubspec.yaml`. The
platform runner projects are **not** included — generate them first:

```bash
cd "Gamified Task Manager"

# Creates android/, ios/, windows/, macos/, linux/, web/ without touching lib/
flutter create . --project-name momentum --platforms=android,ios,windows,macos,linux

flutter pub get
flutter run
```

Requires **Flutter 3.29 or newer** (Dart 3.7+). The floor comes from
`Color.withValues` and the `CardThemeData` / `DialogThemeData` theme properties
used in `lib/core/theme/app_theme.dart`.

```bash
flutter analyze
flutter test
```

### Platform setup for notifications

Notifications are optional and degrade to nothing if unavailable, but for them
to actually fire:

**Android** — add to `android/app/src/main/AndroidManifest.xml` inside
`<manifest>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

and inside `<application>`:

```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
    </intent-filter>
</receiver>
```

**iOS** — no extra setup; permission is requested in-app from Settings.

### Fonts and offline behaviour

The app uses `google_fonts` (Plus Jakarta Sans + Inter), which fetches font
files on first launch and caches them to disk. Everything else is fully
offline, so **before release you should bundle the two families** into
`assets/fonts/` and declare them in `pubspec.yaml`; `google_fonts` then uses
the bundled copies and never touches the network. Until then, a first launch
with no connectivity falls back to the platform default font — the layout still
works, it just looks less considered.

---

## Architecture

```
lib/
├── core/
│   ├── models/       Domain records with hand-written JSON codecs
│   ├── services/     Sound, haptics, notifications, XP, achievements, stats
│   ├── storage/      Hive boxes + one repository per aggregate
│   ├── theme/        Colour / motion / geometry / type tokens
│   └── utils/        Date and BuildContext extensions
├── state/            Riverpod controllers and derived providers
├── widgets/          Reusable, feature-agnostic UI primitives
├── features/
│   ├── boards/       Board grid, board editor, kanban board
│   ├── calendar/     Week strip, weekly planner
│   ├── dashboard/    Home screen
│   ├── gamification/ Celebrations, achievements, statistics
│   ├── settings/     Preferences
│   ├── tasks/        Card tile, quick add, full editor
│   └── timer/        Focus screen, completion flow
└── routing/          GoRouter config + app shell
```

Dependencies point inwards: `features` → `state` → `core`. Nothing in `core`
imports a feature, and no widget touches a repository directly.

### State

Riverpod 2 with plain `Notifier`s (no code generation).

The interesting piece is `CardIndex` (`lib/state/card_index.dart`). Rather than
storing a flat `List<TaskCard>` and filtering it in every `build()`, each
mutation pays one indexing pass that produces pre-bucketed views: by board, by
`board|status` column, by scheduled day, plus per-board counters.

Slices are returned as `CardSlice`, a wrapper with **value equality**. This
matters: Riverpod decides whether to rebuild by comparing with `==`, and two
`List`s with identical contents are not equal. Without the wrapper, editing one
card would rebuild every kanban column, every day cell, and every board tile.
With it, only the columns whose contents actually changed rebuild.

### Storage

Hive (`hive_ce`) with records stored as JSON strings — no generated type
adapters, so there is no `build_runner` step to keep in sync and the schema
stays inspectable. Settings live in `SharedPreferences` so they can be read
*before* the database opens, which is what removes the theme flash on cold
start.

Every box is opened in `main()` before `runApp`. Consequently reads are
synchronous and **the app has no loading states at all** — no spinners and no
skeleton loaders, because there is nothing to wait for. A corrupt record is
logged and skipped rather than thrown, so one bad row costs the user that row
and not the whole board.

### The timer

Elapsed time is always recomputed from wall-clock timestamps
(`startedAt`, `accumulatedSeconds`, `lastResumedAt`), never accumulated tick by
tick. A suspended app, a locked screen, a cold restart, or an OS-throttled
timer all resume with the correct remaining time; a session that expired while
the app was closed presents as finished rather than silently vanishing.
`AppLifecycleState.resumed` re-syncs against the clock.

Only one timer can exist. Starting a second one requires explicitly stopping
the first, and the UI asks before doing so.

### Gamification

All completion funnels through `GamificationController.completeTask` — dragging
a card into Done, swiping it, ticking the checkbox, and finishing a timer all
call the same method. There is exactly one place a reward can be granted, so no
path can bypass XP, streaks or achievements.

Celebrations are emitted as domain events onto a FIFO queue and rendered by a
single overlay above the whole app. Finishing a task that also levels you up
*and* unlocks a badge plays three beats in sequence rather than stacking three
modals.

XP already granted is recorded on the card, so re-opening and re-completing it
cannot farm the same reward twice.

---

## Design system

Tokens live in `lib/core/theme` and are consumed through extensions
(`context.colors`, `context.motion`, `context.geometry`).

**Colour.** Semantic tokens only — no raw hex in any widget. The dark theme is
designed rather than inverted: a cool near-black canvas, surfaces that step
*up* in luminance, and accents lifted so they hold their contrast ratio against
a dark bed. Body text is ≥ 4.5:1 and secondary text ≥ 3:1 in both themes;
`primaryText` is a darkened primary specifically so small blue text passes on
white, where the brand `#4F7CFF` only reaches 3.7:1.

**Motion.** `AppMotion` is a `ThemeExtension` carrying every duration and curve
in the app. Turning motion down is therefore a single switch — durations
collapse to a 70 ms fade, parallax and tilt are disabled outright, and press
scale becomes 1.0 so nothing moves under the finger. It is driven by
`MediaQuery.disableAnimations` **or** the in-app toggle, whichever asks for
less.

**Sound.** The 16 cues in `assets/sounds/` are synthesised additively (sine
partials with exponential decay envelopes, plus band-passed noise for the
whoosh) rather than sampled — see `scripts/` note below. They are short, soft
and deliberately not arcade-like: every one reinforces a state change that has
already happened visually, so the app is fully usable muted.

**Interaction.** `Pressable` is the single primitive behind every tappable
surface: hover lift on pointer devices, press scale, haptic tick, sound cue,
focus ring, and a guaranteed 48 dp target. Scale and lift are transforms, never
layout changes, so pressing something cannot nudge its neighbours.

**Particles.** One `CustomPainter` per burst with no per-particle widgets,
behind a `RepaintBoundary`, one-shot and self-disposing. Reserved for
completion, level up, achievements, week completion and card drops.

---

## Deliberate deviations from the brief

- **`flutter_animate` and `reorderables` are not used.** The drag physics,
  particle system, countdown ring and staggered reveals are hand-built on
  `AnimationController` / `CustomPainter` because they need control those
  packages do not expose. Board reordering uses the framework's
  `SliverReorderableList`. Carrying a dependency the code never calls would be
  worse than the deviation, so both were dropped from `pubspec.yaml`.
- **No skeleton loaders.** The brief asks for skeletons instead of spinners;
  the architecture has neither, because storage is synchronous and no screen
  ever waits. A shimmer component was written and then deleted rather than
  shipped unused.
- **Swipe actions are on the weekly planner, not the kanban board.** A kanban
  column already owns the drag gesture; layering a horizontal swipe on the same
  card would make both unreliable. One primary gesture per region.
- **Attachments are schema-only.** `TaskCard.attachments` persists and
  round-trips, but nothing reads it — the field exists so shipping attachments
  later needs no data migration.
- **Export / import are visible but disabled**, labelled as future work rather
  than hidden.

---

## Verification status

**Honest summary: this code has never been compiled.** No Flutter or Dart SDK
is installed on the machine it was written on, so `flutter analyze`,
`flutter test` and `flutter run` have not been executed. Expect to fix some
compile errors on first build.

What *was* verified mechanically:

- Every relative import across all 63 files in `lib/` resolves to a real file.
- Every `package:` import is declared in `pubspec.yaml`.
- Every Riverpod provider referenced is defined exactly once; four dead
  providers were found and removed.
- No duplicate top-level public type names across the codebase.
- Unused project imports were scanned for and removed.
- All 16 WAV assets were parsed and confirmed as valid 44.1 kHz 16-bit mono PCM
  with correct RIFF headers and sane durations.

`test/` contains 49 unit tests covering the logic most likely to be subtly
wrong — the XP curve and its inverse, streak advancement across day boundaries,
week/ISO-week arithmetic, timer wall-clock reconstruction, `CardIndex`
bucketing, and JSON round-trips. **These have not been run either.**

Roughly 13,400 lines across `lib/`, 540 across `test/`.

## Regenerating the sounds

`tool/generate_sounds.ps1` synthesises the whole `assets/sounds/` set from
scratch. The WAVs are committed, so you only need this to retune them:

```powershell
./tool/generate_sounds.ps1 -OutDir ./assets/sounds
```

Each cue is defined additively — sine partials with attack/decay envelopes,
frequency sweeps for the gestural sounds, and band-passed noise for the whoosh.
Edit the parameters at the bottom of the script to change the palette.
#   y o u r - w e e k l y - t a s k  
 