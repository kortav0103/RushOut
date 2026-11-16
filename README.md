# RushOut — 2D Top-Down Parking Jam Puzzle (Flutter)

**RushOut** is a 2D top-down sliding block puzzle game inspired by *Rush Hour* / *Parking Jam*, built in **Flutter (Dart)** using **Clean Architecture** and **BLoC/Cubit (`flutter_bloc`)**.

Slide obstructing vehicles along their fixed horizontal (`↔`) or vertical (`↕`) axes on a 6×6 parking grid so the pink target sports car (`A`) can exit through the right-side hazard gate at `row = 2`.

---

## Key Features

- **Pure Dart Domain, 4,050-Level Commercial Pacing & BFS Hint Solver:**
  - `LevelParser` parses 36-character row-major board strings (Michael Fogleman's Rush Hour format), filters out wall boards (`'x'`), and extracts **4,050 campaign levels** (1,350 **Easy** 5–10 moves, 1,350 **Medium** 11–18 moves, 1,350 **Hard** 19–25 moves).
  - `LevelOrderingPipeline` orders all 4,050 levels deterministically across 3 pacing zones:
    - **Levels #1–#6 (Onboarding):** Strict raw easiest sorted by `(optimalMoves, vehicleCount, initialBlockers)`.
    - **Levels #7–#19 (Slow Linear Ramp-Up):** Gradual `difficultyScore` progression incorporating `optimalMoves`, `occupiedCells`, `initialBlockers`, and `ln(clusterSize + 1)`.
    - **Levels #20–#4,050 (Commercial Sawtooth Waves):** 10-level waves weaving a **Hard Boss Spike** into slot 9 followed immediately by a lighter **Breather** level at slot 10.
  - `BoardEngine` enforces axis locking, boundary/obstacle collision bounds, Undo stack history, win detection at `(row: 2, col: 4)`, and 1–3 star calculation.
  - `BfsSolver` computes the exact shortest-path move sequence in a background `Isolate` (`Queue<BoardState>` + canonical `Set<String>` visited keys) to power the real-time **Hint** overlay.
- **First-Time Interactive Tutorial & Skip Level:**
  - First-time players automatically enter a solver-driven **Level #1 Tutorial** with a welcome rules dialog, glowing target slots, dimmed locked vehicles with shake/toast feedback, directional step guidance, and a **Skip** option.
  - Players stuck on any campaign level can use **Skip Level** (marks the level with `0★` and unlocks the next level so they can return anytime).
- **Opt-In Anonymous Cloud Sync & Installation Profile:**
  - `PlayerIdentityService` assigns an installation-scoped identifier locally (no email or password required) and lets players set a **Driver Username**.
  - Players can optionally enable **Cloud Progress Sync** in their Driver Profile, authenticated via **Supabase Anonymous Auth** (`auth.uid()`) with strict owner-only RLS on `device_profiles` and `device_level_progress`.
- **60–120FPS Smooth Drag Physics & Daylight Tactile UI:**
  - Static asphalt grid, highlighted Row-3 exit corridor, dashed stall lines, concrete walls, and hazard exit bay are rendered via `CustomPainter` wrapped in `RepaintBoundary`.
  - Each `VehicleWidget` manages continuous drag offsets via `ValueNotifier<double>` + `Transform.translate` (zero BLoC rebuilds during `onPanUpdate`), triggers `HapticFeedback.lightImpact()` + `horn_collide.mp3` on collision, and snaps with a 100ms `Curves.easeOutCubic` animation.
  - Unified **Daylight Tactile** light theme across all screens (`HomeScreen`, `LevelSelectScreen`, `GameScreen`, `DailyScreen`, `LeaderboardScreen`) with explicit **Loading (Shimmer)**, **Content**, **Empty**, and **Error (Retry)** states.
- **Audio & Accessibility:**
  - Dual `AudioPlayer` architecture (`_bgmPlayer` with `AppLifecycleState` pause/resume + `_sfxPlayer` pool) with `SharedPreferences` mute persistence.
  - Directional accessibility badges (`↔` / `↕`) overlaid on every vehicle.

---

## Project Architecture (Clean Architecture)

```text
lib/
├── core/
│   ├── constants/        # Grid size (6), difficulty ranges, asset paths
│   ├── error/            # Exceptions & Failures
│   ├── network/          # NetworkInfo connectivity checker (connectivity_plus)
│   ├── services/         # AudioService, HapticService, TutorialService, PlayerIdentityService, ErrorReportingService
│   └── utils/            # LevelParser (36-char string -> Vehicle list)
├── data/
│   ├── datasources/      # LevelAssetDataSource, LocalDatabaseDataSource (SQLite), SupabaseRemoteDataSource (Dio)
│   ├── models/           # VehicleModel, LevelModel, ScoreModel, DailyChallengeModel
│   └── repositories/     # Offline-first repository implementations
├── domain/
│   ├── engine/           # BoardEngine, LevelOrderingPipeline
│   ├── entities/         # Vehicle, BoardState, Move, Level, LeaderboardEntry, DailyChallenge
│   ├── repositories/     # Abstract repository contracts
│   ├── solver/           # BfsSolver (shortest-path BFS hint finder)
│   └── usecases/         # GetLevels, SaveProgress, GetDailyChallenge, SubmitScore, GetLeaderboard
├── presentation/
│   ├── bloc/             # GameCubit, LevelSelectCubit, DailyCubit, LeaderboardCubit
│   ├── screens/          # HomeScreen, LevelSelectScreen, GameScreen, DailyScreen, LeaderboardScreen
│   ├── theme/            # DaylightColors, DaylightTypography, DaylightDotGridPainter
│   └── widgets/          # ParkingBoardWidget, VehicleWidget, GameControls, HowToPlayDialog, WinDialog, TactileKeycap, StateViews
└── main.dart
test/
├── domain/               # Unit tests for LevelParser, BoardEngine, BfsSolver, LevelOrderingPipeline,
│                         # Level1Tutorial, GameCubit, LevelSelectCubit, PlayerIdentityService, ProductionFixes
└── widget_test.dart      # HomeScreen & Settings widget tests
supabase/
└── schema.sql            # PostgreSQL tables (daily_challenges, leaderboard_scores, device_profiles, device_level_progress) & RLS
android/                  # Android platform & Gradle build configuration (INTERNET + ACCESS_NETWORK_STATE permissions)
ios/                      # iOS Runner, Info.plist, Podfile & Xcode build configuration
windows/                  # Windows desktop runner configuration
```

---

## Getting Started

### 1. Prerequisites
- **Flutter SDK:** `>=3.0.0`
- **Supabase Project** (optional for offline campaign play; required for Daily Challenge, Leaderboard, and Device-ID Cloud Progress Sync)

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Supabase Database
1. Open your project in the [Supabase Dashboard](https://app.supabase.com).
2. Enable **Anonymous Sign-Ins** under **Authentication → Providers → Anonymous Sign-Ins**.
3. Navigate to **SQL Editor** → **New Query**.
4. Copy and run the entire contents of [`supabase/schema.sql`](supabase/schema.sql).
   - Creates `daily_challenges`, `leaderboard_scores` (plus `leaderboard` view), `submit_daily_score` RPC, `device_profiles`, and `device_level_progress` with strict `auth.uid()` Row Level Security (RLS) policies and initial seed data.

### 4. Configure Environment Variables (`.env` / `--dart-define`)
1. Copy `.env.example` to `.env` in the project root (for local `--dart-define-from-file=.env` builds; `.env` is ignored by Git and NOT bundled in Flutter assets):
   ```bash
   cp .env.example .env
   ```
2. Fill in your Supabase project credentials (**Project Settings → API**):
   ```env
   SUPABASE_URL=https://your-project-id.supabase.co
   SUPABASE_ANON_KEY=your-supabase-anon-public-key
   ```
   *(Pass credentials at build/run time with `--dart-define-from-file=.env` or `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`. Never bundle `.env` as an asset or put service-role keys in client builds.)*

### 5. Run Static Analysis & Unit Tests
```bash
flutter analyze --no-pub
flutter test --no-pub
```

### 6. Run & Build for Android and iOS
#### Android
```bash
# Run debug build on connected Android device/emulator (no release keystore needed)
flutter run --dart-define-from-file=.env

# For release builds from a clean checkout, create android/key.properties from the example
# and point storeFile to your .jks keystore (never commit key.properties or *.jks):
cp android/key.properties.example android/key.properties

# Build release Android APK / App Bundle (signed via android/key.properties)
flutter build apk --release --dart-define-from-file=.env
flutter build appbundle --release --dart-define-from-file=.env
```
The generated APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

#### iOS (macOS with Xcode & CocoaPods)
The `ios/Runner.xcodeproj` and `ios/Runner.xcworkspace` projects (`com.rushout.game`, `Info.plist`, `Podfile`, `AppDelegate.swift`, `SceneDelegate.swift`, storyboards) are included in the repository. On a macOS machine:
```bash
# Configure DEVELOPMENT_TEAM and signing/provisioning profile in ios/Runner.xcodeproj via Xcode
flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release --dart-define-from-file=.env
```

---

## Change Log Against A01 Specification

| Change | Rationale |
| :--- | :--- |
| Expanded campaign from 30 levels to **4,050 levels** with 3-zone Commercial Sawtooth Pacing (`LevelOrderingPipeline`) | Provides long-term replayability and introduces periodic Hard Boss Spikes + Breathers from Level #20+ instead of a flat linear grind. |
| Added **Solver-Driven Level #1 Tutorial** (`TutorialService` + `GameCubit`) | Ensures first-time players immediately learn `↔`/`↕` movement rules and the exit goal with guided highlights and zero move penalties. |
| Added **Skip Level** (`0★` + unlock next level) | Prevents players from getting permanently blocked on hard puzzles while preserving 3-star completion tracking. |
| Added **Opt-In Anonymous Cloud Sync & Authoritative Leaderboard RPC** (`PlayerIdentityService`, Supabase Anonymous Auth `auth.uid()`, `submit_daily_score` RPC) | Replaces insecure `anon` table access with `auth.uid()` owner-only RLS, protects the leaderboard against forged/duplicate scores, and makes cloud sync explicit opt-in in `ProfileDialog`. |
| Added **Process-Death Undo History & SQLite v2 Schema Migration** (`GameCubit`, `LocalDatabaseDataSource`) | Persists `moveHistory` in `SharedPreferences` so Undo stays available after app restart, adds `onUpgrade` migration (`updated_at`, `score_submitted`), and surfaces real DB errors instead of swallowing them silently. |
| Unified **Daylight Tactile Light Theme** across all screens including `DailyScreen` and `LeaderboardScreen` | Eliminates jarring light/dark theme transitions between Campaign and Daily/Leaderboard screens. |
| Removed live `Moves / Optimal` header during gameplay; kept move/star summary in `WinDialog` | Reduces mid-puzzle pressure and keeps visual focus on the 6×6 parking board. |

---

## Test Coverage & Manual Acceptance Verification

### Automated Test Suite (`test/`)
- **10 test files / 32 test cases** across `test/domain/` (`level_parser_test.dart`, `board_engine_test.dart`, `bfs_solver_test.dart`, `level_ordering_pipeline_test.dart`, `level1_tutorial_test.dart`, `game_cubit_test.dart`, `level_select_cubit_test.dart`, `player_identity_service_test.dart`, `production_fixes_test.dart`) and `test/widget_test.dart`.
- Execute locally with:
  ```bash
  flutter analyze --no-pub --fatal-infos
  flutter test --no-pub
  ```

### Manual Test Cases & Acceptance Verification Report

| Test ID | Req ID | Scenario & Steps | Expected Result | Status |
| :--- | :---: | :--- | :--- | :---: |
| **TC-01** | EN-01 | Open Level #1 and drag horizontal (`↔`) and vertical (`↕`) vehicles toward walls and adjacent cars. | Smooth 60–120 FPS pixel tracking (`Transform.translate`), strict axis lock, collision haptic + horn sound + shake, and 100ms ease-out grid snap. | **PASS** |
| **TC-02** | EN-01 | Slide pink target car `A` to `(row: 2, col: 4)` when exit path is clear. | Car `A` animates out through the hazard bay (`col = 6`), plays win/star SFX, shows `WinDialog` with confetti and 1–3 star rating. | **PASS** |
| **TC-03** | EN-06 | Launch app fresh, enter invalid username (`@!`, `http://...`, profanity) then valid username (`Minh Anh_99`), tap `PLAY CAMPAIGN`. | Invalid names blocked with inline error matching Supabase RLS rules; valid name saves locally; Level #1 Tutorial launches automatically with locked non-active cars and `Skip` option. | **PASS** |
| **TC-04** | EN-02 | Open `LevelSelectScreen` and scroll across campaign tiers. | Displays 4,050 levels in 3-zone Commercial Sawtooth order; only Level #1 starts unlocked; clearing or skipping `#N` unlocks `#N+1`. | **PASS** |
| **TC-05** | EN-02 | Make 3 moves in a campaign level, close/reopen the level, tap `Undo`, then test `Skip Level`. | Unfinished board state and `moveHistory` restore from `SharedPreferences` with working `Undo`; `Skip Level` keeps `0★` and unlocks the next level. | **PASS** |
| **TC-06** | EN-03 | Tap `Undo`, `Reset`, and `Hint` on a solvable board; tap `Hint` on a dead-end state exceeding BFS limit. | `Undo` reverts 1 move; `Reset` restores initial board; `Hint` computes shortest move in background `Isolate` (`Solving...`) and draws pulsing arrow; unfound hint shows SnackBar without deducting hint count. | **PASS** |
| **TC-07** | EN-04 | Open `Daily Challenge` while online, solve puzzle, submit nickname to Leaderboard, then tap `Replay` or reopen Daily. | Fetches UTC `CURRENT_DATE` puzzle, caches in SQLite `daily_cache`, submits once via authenticated `submit_daily_score` RPC, and blocks duplicate submissions on Replay/reopen. | **PASS** |
| **TC-08** | EN-04 | Toggle Airplane Mode and open `Daily Challenge` (cached vs uncached) and `Leaderboard`. | Cached Daily loads offline seamlessly; uncached Daily and offline Leaderboard display `ErrorStateView` with working `Retry` button; empty date displays `EmptyStateView`; initial load displays `ShimmerLoadingView`. | **PASS** |
| **TC-09** | EN-02 / EN-04 | Open `ProfileDialog` (Cloud Sync is off by default), enable `Cloud Progress Sync`, and tap `Sync Now` while online. | Authenticates via Supabase Anonymous Auth (`auth.uid()`) and two-way merges `username`, `tutorial_completed`, and `level_progress` (`max(stars)`, `min(bestMoves)`, union of unlocked levels) under owner-only RLS. | **PASS** |
| **TC-10** | EN-05 | Toggle Sound in Home Settings or Game top bar, then background and resume the app. | Mute state persists in `SharedPreferences`; BGM pauses on `AppLifecycleState.paused`/`inactive` and resumes cleanly on `resumed`. | **PASS** |
