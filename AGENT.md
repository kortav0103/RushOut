# PROJECT SPECIFICATION FOR AI CODING AGENT: RUSHOUT (FLUTTER)

## 1. PROJECT OVERVIEW
Build **RushOut**, a 2D top-down Parking Jam / Rush Hour sliding block puzzle game in **Flutter (Dart)**.
- **Goal:** Slide obstructing vehicles along their fixed axis on a $6 \times 6$ parking grid so the red target car (`A`) can exit through the right-side gate at `row = 2`.
- **Architecture:** Clean Architecture + BLoC/Cubit (`flutter_bloc`), strictly separating pure Dart game logic (`domain`) from UI (`presentation`) and data sources (`data`) to ensure 100% unit-testability.
- **Offline-First & Backend:** Local progress and levels stored in SQLite (`sqflite`); Daily Challenge & Leaderboard synced via Supabase REST API (`dio` or `http`) with graceful offline fallback.

---

## 2. FOLDER STRUCTURE (CLEAN ARCHITECTURE)
Generate the project following this exact structure:
```text
lib/
├── core/
│   ├── constants/        # Grid size (6), colors, asset paths
│   ├── error/            # Failures & Exceptions
│   ├── network/          # NetworkInfo connectivity checker
│   ├── services/         # AudioService (BGM + SFX), HapticService
│   └── utils/            # LevelParser (36-char string -> Vehicle list)
├── data/
│   ├── datasources/      # Local (SQLite, Asset loader), Remote (Supabase API)
│   ├── models/           # VehicleModel, LevelModel, ScoreModel
│   └── repositories/     # Repository implementations (Offline-first caching)
├── domain/
│   ├── entities/         # Vehicle, BoardState, Move, Level, LeaderboardEntry
│   ├── engine/           # Pure Dart: BoardEngine (collision, win check, snap)
│   ├── solver/           # Pure Dart: BfsSolver (shortest path hint finder)
│   ├── repositories/     # Abstract repository interfaces
│   └── usecases/         # GetLevels, SaveProgress, GetDailyChallenge, SubmitScore
├── presentation/
│   ├── bloc/             # GameCubit, LevelSelectCubit, DailyCubit, LeaderboardCubit
│   ├── screens/          # HomeScreen, LevelSelectScreen, GameScreen, DailyScreen, LeaderboardScreen
│   └── widgets/          # ParkingBoardWidget, VehicleWidget, GameControls, HowToPlayDialog, StateViews (Loading/Empty/Error)
└── main.dart
test/
└── domain/               # Unit tests for LevelParser, BoardEngine, and BfsSolver
```

---

## 3. CORE GAME LOGIC & ALGORITHMS (PURE DART)

### 3.1. Grid & Coordinate System
- Grid dimensions: `6 rows x 6 cols` (indices `0..5`).
- Exit gate position: Right edge of `row = 2`.
- `Vehicle` entity properties:
  - `String id` (`'A'` is always the target red car, `'B'..'Z'` are obstacles)
  - `int row` (`0..5`), `int col` (`0..5`)
  - `int length` (`2` for cars, `3` for trucks/buses)
  - `bool isHorizontal` (`true` = moves left/right only; `false` = moves up/down only)
  - `bool isTarget` (`id == 'A'`)
- **Win Condition:** Target car (`id == 'A'`, `row == 2`, `length == 2`, `isHorizontal == true`) reaches `col == 4`. Trigger escape animation sliding it out to `col = 6`.

### 3.2. Level Data Format (`assets/levels/rush1000.txt`)
- Source file follows Michael Fogleman's Rush Hour database format, one level per line:
  `<optimal_moves> <36_char_board> <cluster_size>`
  Example: `15 IBBLooIooLooIAAKooMDDFoKMGoFoJMGHHoJ`
- **Parser Rules (`LevelParser`):**
  1. Filter out any line containing `'x'` (fixed walls).
  2. Extract `optimalMoves` (first integer) and `boardString` (36 chars representing `6x6` row-major grid).
  3. `'o'` = empty cell. Group identical uppercase letters (`'A'..'Z'`) to determine top-left `(row, col)`, `length` (2 or 3), and `isHorizontal`.
  4. Select 30 levels from the file and categorize into 3 difficulties:
     - **Easy:** `optimalMoves` 5–10 (10 levels)
     - **Medium:** `optimalMoves` 11–18 (10 levels)
     - **Hard:** `optimalMoves` 19–25 (10 levels)

### 3.3. Collision & Drag Mechanics (`BoardEngine`)
- Calculate valid movement bounds `[minCol, maxCol]` (if horizontal) or `[minRow, maxRow]` (if vertical) for the active vehicle before starting drag, preventing it from jumping over other vehicles or leaving `0..5` bounds.
- On drag end (`onPanEnd`), snap the vehicle to the nearest integer grid cell.
- If the final snapped cell differs from the start cell, increment `moveCount` by 1 and push `Move(vehicleId, fromRow, fromCol, toRow, toCol)` onto the undo stack.

### 3.4. Shortest-Path Hint Solver (`BfsSolver`)
- Implement Breadth-First Search (`Queue<BoardState>`) using the canonical 36-character board string as the visited state key (`Set<String>`).
- Generate all valid single-vehicle sliding moves (1 or more cells in one step counts as 1 move, matching standard Rush Hour rules) until target `'A'` reaches `col == 4`.
- Return the **first `Move`** of the shortest path so the UI can highlight the vehicle and draw an animated directional arrow on the board.

### 3.5. Star Rating Formula
- **3 Stars:** `userMoves <= optimalMoves`
- **2 Stars:** `userMoves <= optimalMoves + 3`
- **1 Star:** `userMoves > optimalMoves + 3`

---

## 4. ASSETS, GRAPHICS & AUDIO

### 4.1. Visuals & Sprites
- **Board Rendering (`CustomPainter`):** Draw a dark asphalt parking lot (`#2B2D30`) with dashed white/yellow parking stall lines, concrete border walls (`#5C626A`), and an open exit bay on the right side of `row = 2` marked with yellow/black hazard stripes.
- **Vehicle Sprites (`assets/images/vehicles/`):**
  - All PNG sprites are oriented vertically (facing UP) by default:
    - `target_car.png` (Red sports car, 2 cells)
    - `car_2_police.png`, `car_2_taxi.png`, `car_2_ambulance.png`, `car_2_sedan.png` (2 cells)
    - `truck_3_firetruck.png`, `truck_3_limo.png` (3 cells)
  - Map obstacle IDs deterministically to sprites based on `length` and character code.
  - When `isHorizontal == true`, wrap `Image.asset(...)` inside `RotatedBox(quarterTurns: 1, child: ...)`.
- **Accessibility:** Overlay a subtle directional indicator (`↔` or `↕`) on each vehicle so color-blind users can immediately identify movement axes.

### 4.2. Audio Architecture (`audioplayers`)
- Maintain two separate `AudioPlayer` instances in `AudioService`:
  1. `_bgmPlayer`: Loops `assets/audio/bgm_loop.mp3` (`ReleaseMode.loop`, volume `0.3`). Pause on `AppLifecycleState.paused`, resume on `resumed`.
  2. `_sfxPlayer`: Plays short sound effects (`volume: 0.8`) from `assets/audio/sfx/`:
     - `car_select.mp3` (touch down on vehicle)
     - `slide.mp3` (vehicle moves to a new cell)
     - `horn_collide.mp3` (vehicle hits boundary/obstacle + trigger `HapticFeedback.lightImpact()`)
     - `undo_whoosh.mp3` (Undo or Reset tapped)
     - `hint_ping.mp3` (Hint tapped)
     - `win.mp3` & `star_pop.mp3` (level cleared & stars revealed)
- Persist mute toggle state in `SharedPreferences`.

---

## 5. DATA, SECURITY & NETWORKING

### 5.1. Local SQLite Schema (`sqflite`)
- `level_progress`: `level_id INTEGER PRIMARY KEY, difficulty TEXT, best_moves INTEGER, stars INTEGER, is_unlocked INTEGER`
- `daily_cache`: `date_key TEXT PRIMARY KEY, board_string TEXT, optimal_moves INTEGER, is_completed INTEGER, user_moves INTEGER`

### 5.2. Supabase REST API & Environment Security
- Load `SUPABASE_URL` and `SUPABASE_ANON_KEY` via `flutter_dotenv` (`.env` file excluded in `.gitignore`, provide `.env.example`). Never hardcode keys in Dart files.
- **Endpoints:**
  1. `GET /rest/v1/daily_challenges?challenge_date=eq.{YYYY-MM-DD}&select=*` -> Fetch today's puzzle and cache into `daily_cache`. If offline, load from `daily_cache` or show offline fallback UI.
  2. `POST /rest/v1/leaderboard` -> Submit `{ "player_name", "challenge_date", "moves_count" }`.
  3. `GET /rest/v1/leaderboard?challenge_date=eq.{YYYY-MM-DD}&order=moves_count.asc&limit=20` -> Fetch top 20 scores.

---

## 6. UI/UX SCREENS & STATES
1. **HomeScreen:** Game title/logo, Play Campaign button, Daily Challenge button, Leaderboard button, Sound Mute/Unmute toggle, and How-to-Play (`?`) dialog button.
2. **LevelSelectScreen:** Tabs for `Easy`, `Medium`, `Hard`; grid of level cards showing lock status, level number, best moves, and earned stars (1–3).
3. **GameScreen:**
   - Top bar: Back button, Level title, `Moves: X / Optimal: Y`, Mute toggle.
   - Center: Responsive `AspectRatio(aspectRatio: 1)` `ParkingBoardWidget` with smooth drag physics, hint highlight overlay, and win modal dialog (showing stars earned, replay, and next level buttons).
   - Bottom toolbar: `Undo`, `Reset`, `Hint` buttons.
4. **DailyScreen & LeaderboardScreen:** Must explicitly handle all 4 UI states:
   - **Loading:** Shimmer placeholder / spinner.
   - **Content:** Puzzle board or ranked list of players.
   - **Empty:** Friendly empty state message when no leaderboard entries exist yet.
   - **Error:** Network error banner/card with a functional `Retry` button.

---

## 7. REQUIRED UNIT TESTS (`test/domain/`)
Write comprehensive unit tests covering:
1. `level_parser_test.dart`: Parsing 36-char strings, filtering `'x'`, verifying vehicle coordinates, lengths, and orientations.
2. `board_engine_test.dart`: Horizontal/vertical axis locking, collision detection against boundaries and adjacent vehicles, undo stack behavior, and win condition at `(row: 2, col: 4)`.
3. `bfs_solver_test.dart`: Verifying `BfsSolver` finds a valid solution matching `optimal_moves` on sample Easy/Medium boards and returns `null` on unsolvable boards.

---

## 8. EXECUTION INSTRUCTIONS FOR AGENT
1. Inspect `pubspec.yaml` and add required dependencies (`flutter_bloc`, `equatable`, `sqflite`, `path`, `dio`, `flutter_dotenv`, `audioplayers`, `shared_preferences`, `connectivity_plus`).
2. Create the Clean Architecture directory structure and implement `domain` layer first (`entities`, `LevelParser`, `BoardEngine`, `BfsSolver`).
3. Run `flutter test` to verify all domain logic and BFS solver unit tests pass before building UI.
4. Implement `data` layer (SQLite + Supabase repository with offline caching) and `core/services` (`AudioService`).
5. Implement `presentation` layer (`BLoC/Cubit`, responsive `ParkingBoardWidget`, all 5 screens, and Loading/Empty/Error states).
6. Ensure `README.md` documents setup steps, `.env` configuration, and architecture overview.  


###WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
# Terminal Execution & Timeout Handling Rules

## 1. Allow Command Execution

The AI agent is allowed and encouraged to execute terminal commands when necessary for development, testing, debugging, and validation.

This includes Flutter commands such as:

- `flutter --version`
- `flutter doctor`
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build`
- `flutter run`

Do not avoid executing commands just because they might take time.

## 2. Strict Timeout Policy

The agent must monitor command execution and avoid waiting indefinitely.

Default timeout guidelines:

- Simple commands: 30 seconds.
- Flutter commands such as `pub get`, `analyze`, and `test`: 60 seconds.
- Heavy build or test operations: up to 180 seconds.

These are maximum waiting guidelines, not guarantees that every command must finish within that time.

If a command exceeds its timeout without meaningful progress or output:

1. Stop waiting for the command.
2. Terminate the hanging process or Background Task if safe.
3. Do not repeatedly poll, retry, or restart the same command automatically.
4. Treat the validation step as skipped due to a terminal execution issue.
5. Continue with the remaining development tasks whenever possible.

## 3. Handling Missing Output

If the terminal does not return output or completion status within the allowed time:

- Do not assume the source code is incorrect.
- Do not repeatedly attempt the same command.
- Do not block the entire workflow.
- Proceed as though the command execution step has been bypassed successfully for workflow purposes.

IMPORTANT: Bypassing a validation step does NOT mean the command has been verified as successful. Never report an unverified command as PASS.

When reporting results, clearly distinguish:
- PASS: Command completed and returned a successful result.
- SKIPPED: Command timed out or terminal output was unavailable.
- FAIL: Command completed and returned an actual error.

## 4. Special Handling for `flutter run`

`flutter run` is an interactive, long-running process and is expected to remain active while the application is running.

Do not classify it as hanging merely because it does not terminate.

Wait for application startup output. If the process produces no meaningful progress for an unusually long period, stop waiting and report the situation.

## 5. Continue Development

A terminal execution problem must not unnecessarily interrupt development.

The agent should continue to:
- Create and modify source code.
- Configure project files.
- Implement features.
- Inspect and review code.
- Fix identifiable issues.
- Complete independent tasks.

Only request manual user intervention when the missing command result is genuinely necessary to proceed.

## 6. Reporting

At the end of each development phase, provide a concise summary containing:

- Completed work.
- Commands successfully executed.
- Commands skipped due to timeout.
- Actual errors found.
- Remaining tasks or unverified items.

## 7. Priority

These rules apply throughout the project unless the user explicitly overrides them.

The primary objective is to maintain development progress without wasting AI usage on indefinitely waiting Background Tasks.

## 8. Sandbox and External SDK Access

The Flutter SDK is installed at D:\flutter, outside the project workspace at C:\Users\Lenovo\Desktop\Na.

The agent must be aware that Sandbox restrictions may prevent access to external drives or directories.

Rules:

Do not repeatedly execute Flutter commands if the Sandbox reports an access-denied or permission error involving D:\flutter.

Do not interpret Sandbox access restrictions as Flutter SDK errors or source-code errors.

Do not attempt to bypass Sandbox security restrictions.

If Flutter commands cannot access the SDK, mark the validation step as SKIPPED - SANDBOX ACCESS RESTRICTION.

Continue development and code inspection without unnecessarily interrupting the workflow.

Provide the exact command for the user to execute manually in their normal PowerShell terminal when validation is needed.

Example:

cd C:\Users\Lenovo\Desktop\Na
flutter test

Do not report the test as PASS unless actual successful test results are available.

YÊU CẦU KỸ THUẬT BẮT BUỘC CHO CƠ CHẾ KÉO THẢ XE (60-120FPS SMOOTH DRAG):
1. Tuyệt đối KHÔNG bắn event vào BLoC/Cubit trong `onPanUpdate` hoặc `onHorizontalDragUpdate`/`onVerticalDragUpdate`.
2. Wrap lớp nền bàn cờ (CustomPainter) trong `RepaintBoundary` để không bị vẽ lại khi xe di chuyển.
3. Mỗi widget xe (`VehicleWidget`) tự quản lý vị trí pixel tạm thời khi kéo bằng `ValueNotifier<double>` và render dịch chuyển bằng `Transform.translate` (không thay đổi layout cây widget khi đang kéo):
   - Tại `onPanStart`: Tính toán sẵn `minOffsetPx` và `maxOffsetPx` (giới hạn pixel chạm tường hoặc chạm xe liền kề).
   - Tại `onPanUpdate`: Cộng dồn `delta` và dùng `.clamp(minOffsetPx, maxOffsetPx)`. Xe phải di chuyển liên tục từng pixel theo ngón tay (cho phép dừng tự do ở giữa các ô khi đang giữ tay), không giật cục theo từng ô. Khi chạm ngưỡng `minOffsetPx` hoặc `maxOffsetPx` lần đầu, kích hoạt `HapticFeedback.lightImpact()` + phát `horn_collide.mp3`.
   - Tại `onPanEnd`: Chạy `AnimationController` (100ms, `Curves.easeOutCubic`) để đưa xe hít mượt mà về tọa độ ô lưới gần nhất (`(currentPx / cellSize).round()`). Chỉ sau khi animation kết thúc và ô lưới thay đổi mới gọi BLoC để cập nhật nước đi, lưu Undo stack và kiểm tra thắng.