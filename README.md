# RushOut — 2D Top-Down Parking Jam Puzzle (Flutter)

**RushOut** is a 2D top-down sliding block puzzle game inspired by *Rush Hour* / *Parking Jam*, built in **Flutter (Dart)** using **Clean Architecture** and **BLoC/Cubit (`flutter_bloc`)**.

Slide obstructing vehicles along their fixed horizontal (`↔`) or vertical (`↕`) axes on a $6 \times 6$ parking grid so the target red sports car (`A`) can exit through the right-side hazard gate at `row = 2`.

---

## Key Features

- **Pure Dart Domain & BFS Hint Solver:**
  - `LevelParser` parses 36-character row-major board strings (Michael Fogleman's Rush Hour format), filters out wall boards (`'x'`), and extracts 30 campaign levels across **Easy** (5–10 moves), **Medium** (11–18 moves), and **Hard** (19–25 moves).
  - `BoardEngine` enforces axis locking, boundary/obstacle collision bounds (`[minCol, maxCol]` / `[minRow, maxRow]`), Undo stack history, win detection at `(row: 2, col: 4)`, and 1–3 star calculation.
  - `BfsSolver` computes the exact shortest-path move sequence using Breadth-First Search (`Queue<BoardState>` + `Set<String>` canonical state keys) to power the real-time **Hint** overlay.
- **60–120FPS Smooth Drag Physics:**
  - Static asphalt grid, dashed stall lines, concrete walls, and hazard exit bay are rendered via `CustomPainter` wrapped in a `RepaintBoundary`.
  - Each `VehicleWidget` manages its own continuous pixel offset during drag using `ValueNotifier<double>` and `Transform.translate` (zero BLoC events or layout rebuilds during `onPanUpdate`), triggers `HapticFeedback.lightImpact()` + `horn_collide.mp3` upon touching boundaries/obstacles, and snaps to the nearest grid cell with a 100ms `Curves.easeOutCubic` `AnimationController` on release.
- **Offline-First Persistence & Supabase Backend:**
  - Local campaign progress (`level_progress`) and cached daily challenges (`daily_cache`) are stored in **SQLite (`sqflite`)**.
  - **Daily Challenge & Leaderboard** sync with **Supabase REST API (`dio`)** and gracefully fall back to local SQLite cache when offline.
  - All network-connected screens explicitly handle **4 UI states**: **Loading** (animated Shimmer skeleton), **Content**, **Empty**, and **Error** (with a functional `Retry` button).
- **Audio & Accessibility:**
  - Dual `AudioPlayer` architecture (`_bgmPlayer` looping background music with `AppLifecycleState` pause/resume + `_sfxPlayer` for sound effects) with `SharedPreferences` mute persistence.
  - Directional accessibility badges (`↔` / `↕`) overlaid on every vehicle.

---

## Project Architecture (Clean Architecture)

```text
lib/
├── core/
│   ├── constants/        # Grid size (6), difficulty ranges, asset paths
│   ├── error/            # Exceptions & Failures
│   ├── network/          # NetworkInfo connectivity checker (connectivity_plus)
│   ├── services/         # AudioService (BGM + SFX + Lifecycle), HapticService
│   └── utils/            # LevelParser (36-char string -> Vehicle list)
├── data/
│   ├── datasources/      # Local (SQLite, Asset loader), Remote (Supabase REST API)
│   ├── models/           # VehicleModel, LevelModel, ScoreModel, DailyChallengeModel
│   └── repositories/     # Offline-first repository implementations
├── domain/
│   ├── entities/         # Vehicle, BoardState, Move, Level, LeaderboardEntry, DailyChallenge
│   ├── engine/           # Pure Dart: BoardEngine (collision bounds, snap, undo, win, stars)
│   ├── solver/           # Pure Dart: BfsSolver (shortest-path hint finder)
│   ├── repositories/     # Abstract repository contracts
│   └── usecases/         # GetLevels, SaveProgress, GetDailyChallenge, SubmitScore, GetLeaderboard
├── presentation/
│   ├── bloc/             # GameCubit, LevelSelectCubit, DailyCubit, LeaderboardCubit
│   ├── screens/          # HomeScreen, LevelSelectScreen, GameScreen, DailyScreen, LeaderboardScreen
│   └── widgets/          # ParkingBoardWidget, VehicleWidget, GameControls, HowToPlayDialog, WinDialog, StateViews
└── main.dart
test/
└── domain/               # Unit tests for LevelParser, BoardEngine, BfsSolver, and GameCubit
supabase/
└── schema.sql            # PostgreSQL tables, indexes, RLS policies, and seed data
```

---

## Getting Started

### 1. Prerequisites
- **Flutter SDK:** `>=3.0.0`
- **Supabase Project** (optional for offline campaign play; required for live Daily Challenge & Leaderboard sync)

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Supabase Database
1. Open your project in the [Supabase Dashboard](https://app.supabase.com).
2. Navigate to **SQL Editor** -> **New Query**.
3. Copy and run the entire contents of [`supabase/schema.sql`](supabase/schema.sql).
   - This creates `public.daily_challenges` and `public.leaderboard_scores` (plus the compatibility view `public.leaderboard`), configures Row Level Security (RLS) policies for `anon` read/insert access, and seeds initial daily puzzles and sample leaderboard scores.

### 4. Configure Environment Variables (`.env`)
1. Copy `.env.example` to `.env` in the project root:
   ```bash
   cp .env.example .env
   ```
2. Fill in your Supabase project credentials (found under **Project Settings -> API** in Supabase):
   ```env
   SUPABASE_URL=https://your-project-id.supabase.co
   SUPABASE_ANON_KEY=your-supabase-anon-public-key
   ```
   *(Note: `.env` is listed in `.gitignore` so API keys are never committed to version control.)*

### 5. Run Unit Tests
Verify all domain logic, parser rules, collision mechanics, and the BFS shortest-path solver:
```bash
flutter test
```

### 6. Run the Application
```bash
flutter run
```
