# KẾ HOẠCH KHÁM NGHIỆM & TÁI CẤU TRÚC KIẾN TRÚC (TRIAGE PLAN) — RUSHOUT

**Vai trò thực hiện:** Principal Software Architect  
**Phạm vi kiểm toán:** Toàn bộ source code Flutter (`lib/`), schema & RPC backend (`supabase/schema.sql`), CLI tools (`tool/`), bộ kiểm thử (`test/`), tài nguyên (`assets/`) và cấu hình build/run (`.idea/`, `.github/`, `pubspec.yaml`, `android/`, `ios/`).  
**Trạng thái:** Chỉ đọc & lập kế hoạch (`TRIAGE_PLAN.md`). Chưa chỉnh sửa bất kỳ file code nào.

---

## 1. TỔNG QUAN KIẾN TRÚC & ĐÁNH GIÁ HIỆN TRẠNG

Codebase RushOut được tổ chức theo hướng Clean Architecture (`core`, `data`, `domain`, `presentation`) kết hợp `flutter_bloc` (`Cubit`). Phần lõi giải đố 6×6 (`BoardEngine`, `BfsSolver`, `DaylightTheme`, các tactile widgets) được viết sạch sẽ và bám sát quy luật game Rush Hour.

Tuy nhiên, quá trình mở rộng thêm các tính năng thương mại (4.050 màn chơi, Tutorial, Hint, In-progress persistence, Anonymous Auth, Cloud Sync, Daily Challenge & Leaderboard) đã tạo ra **3 nhóm vấn đề kiến trúc nghiêm trọng**:

1. **Sai bản chất nghiệp vụ & dữ liệu giả ở tầng Backend/Cloud:**
   - Hệ thống **Cloud Profile & Reinstall Restore** (`PlayerIdentityService` + `SupabaseRemoteDataSource` + `supabase/schema.sql`) tuyên bố hỗ trợ khôi phục tiến trình sau khi gỡ cài đặt/cài lại máy, nhưng thực tế dùng **Anonymous Auth** lưu token trong `SharedPreferences` (mất sạch khi gỡ app) và query theo `auth.uid()` (bỏ qua hoàn toàn tham số `deviceId`). Unit test `player_identity_service_test.dart` lại dùng fake data che lấp lỗ hổng này.
   - Hệ thống **Daily Challenge** hardcode seed đúng 7 ngày (`CURRENT_DATE .. CURRENT_DATE + 6`), bơm 3 bản ghi xếp hạng giả (`SpeedRacer_VN`, `PuzzleMaster`, `RushHourPro`) vào bảng `leaderboard_scores`, và RPC `submit_daily_score` tin tuyệt đối con số `p_moves_count` từ client mà không kiểm chứng chuỗi nước đi.
2. **Vi phạm ranh giới UI / Logic / Persistence (trái quy tắc `GEMINI.md`):**
   - `VehicleWidget` gọi trực tiếp `BoardEngine.getMovementBounds`.
   - `GameCubit` gọi trực tiếp `SharedPreferences` không qua Repository.
   - `GameScreen` tự quản lý bản sao mutable `_levels` và logic mở khóa màn tiếp theo; `LevelSelectScreen` tự tính trạng thái `isSkipped`; `ProfileDialog` và `UsernamePromptDialog` tự điều khiển nghiệp vụ sync/validation và hiển thị thông báo trạng thái sai thực tế khi lỗi.
3. **Lỗi Async Race Conditions & Edge-Case Validation:**
   - Race condition khi tính Hint trong `Isolate.run` (kéo xe/Undo/Reset lúc đang solve vẫn bị áp dụng hint cũ và trừ lượt).
   - Timer 520ms sau khi thắng (`ParkingBoardWidget`) không kiểm tra lại `widget.isWon`; các thao tác `_restoreInProgressState`, `_saveInProgressState`, `_clearInProgressState` không `await` tuần tự.
   - `AudioService` mất BGM hoàn toàn suốt phiên nếu app mở ở trạng thái đang mute rồi mới unmute.
   - `LocalDatabaseDataSource` âm thầm fallback sang RAM (`_memoryLevelProgress`) trên Desktop (`windows/`) vì thiếu `sqflite_common_ffi`, làm mất toàn bộ tiến trình khi tắt app.

---

## 2. BẢNG TÓM TẮT PHÂN LOẠI TÍNH NĂNG (TRIAGE MATRIX)

| Nhóm | Tính năng / Phân hệ | Kết luận | Vấn đề cốt lõi |
| :--- | :--- | :--- | :--- |
| **1** | Core Game Rules & Board Engine (`BoardEngine`, Entities) | `[GIỮ NGUYÊN]` | Thuần domain, bất biến, đúng luật Rush Hour 6×6 & tính sao. |
| **1** | Thuật toán giải tối ưu (`BfsSolver`) | `[GIỮ NGUYÊN]` | BFS chuẩn, có giới hạn `maxVisitedStates` chống tràn RAM. |
| **1** | Asset Level Loader (`LevelAssetDataSource`) | `[GIỮ NGUYÊN]` | Đọc asset & parse trong `Isolate.run`, cache in-memory hợp lý. |
| **1** | Design System, Tactile UI Kit & Dialog tĩnh | `[GIỮ NGUYÊN]` | Tách bạch UI thuần túy, đủ 4 trạng thái Loading/Content/Empty/Error. |
| **1** | Domain UseCases, Contracts & Exceptions | `[GIỮ NGUYÊN]` | Hợp đồng Clean Architecture gọn rõ (chỉ cần chỉnh lại docstring cũ). |
| **2** | Level Parser & CLI Tool (`LevelParser`, `tool/parse_levels.dart`) | `[SỬA LẠI]` | Thiếu validate xe `'A'` (tồn tại, hướng ngang, row 2, dài 2) & `optimalMoves > 0`. |
| **2** | Thuật toán sắp xếp màn (`LevelOrderingPipeline`) | `[SỬA LẠI]` | 1.053 màn Hard ở phần `tail` bỏ qua lọc đa dạng layout (`_pickDiverse`). |
| **2** | Tương tác kéo xe & Bảng đỗ xe (`VehicleWidget`, `ParkingBoardWidget`) | `[SỬA LẠI]` | UI gọi thẳng `BoardEngine`; lỗi timer Win 520ms; kẹt drag state & hiển thị Daily đã thắng. |
| **2** | Hệ thống Gợi ý (`requestHint`, `remainingHints`, Bonus +1) | `[SỬA LẠI]` | Async race condition khi đang giải BFS; quota hint chỉ lưu RAM (thoát màn là mất). |
| **2** | Luồng Campaign, Tutorial, Skip Level & Lưu ván dở dang | `[SỬA LẠI]` | `GameCubit` đọc/ghi `SharedPreferences` trực tiếp; `GameScreen` giữ `_levels`; lỗi Back khi Tutorial lần đầu; Skip vô hạn. |
| **2** | Lưu trữ SQLite Local (`LocalDatabaseDataSource`) | `[SỬA LẠI]` | Race condition mở DB; silent RAM fallback làm mất dữ liệu trên Windows Desktop. |
| **2** | Global Leaderboard Viewer (`LeaderboardCubit`, `LeaderboardScreen`) | `[SỬA LẠI]` | `ScoreModel` fallback dữ liệu giả (`'Anonymous'`, `0`); chưa hiện thứ hạng cá nhân & nhãn UTC. |
| **2** | Audio, NetworkInfo, ErrorReporting & Env Config | `[SỬA LẠI]` | Bug BGM im bặt khi unmute; check connectivity sai với multi-result; IDE run thiếu `.env`. |
| **3** | Định danh, Anonymous Auth & Cloud Sync (`PlayerIdentityService`, Profile/Username UI) | `[XÓA VIẾT LẠI]` | Sai bản chất khôi phục khi cài lại máy (Anonymous Auth xóa mất `auth.uid()`, query bỏ qua `deviceId`); lưu JWT plaintext; UI trộn logic & báo sai trạng thái. |
| **3** | Daily Challenge Backend Seed, Anti-Cheat RPC & Replay/Submit Flow | `[XÓA VIẾT LẠI]` | Seed cứng 7 ngày + 3 điểm giả trên Leaderboard; RPC không verify nước đi; dựng bàn cờ sai vật lý khi mở lại Daily đã thắng & gửi nhầm điểm replay kém hơn. |

---

## 3. CHI TIẾT PHÂN LOẠI THEO 3 NHÓM

### NHÓM 1: `[GIỮ NGUYÊN]` — Chạy đúng cả kỹ thuật lẫn quy luật nghiệp vụ thực tế

#### 1.1. Core Game Rules & Board Engine
- **Files:**
  - `lib/domain/engine/board_engine.dart`
  - `lib/domain/entities/board_state.dart`
  - `lib/domain/entities/vehicle.dart`
  - `lib/domain/entities/move.dart`
  - `lib/core/constants/app_constants.dart`
- **Đánh giá:** Code thuần Dart, bất biến (`Equatable`), không phụ thuộc Flutter UI hay DB. Đảm bảo đúng các quy luật vật lý Rush Hour 6×6: khóa trục di chuyển ngang/dọc (`isHorizontal`), phát hiện va chạm thông qua `buildOccupancyGrid` và `getMovementBounds`, chặn nhảy cóc qua xe khác hoặc tràn biên `0..5`, trượt nhiều ô trong một thao tác tính 1 nước đi, không tính move nếu thả về lại ô cũ, hoàn tác (`undo`) khôi phục chính xác vị trí & `moveCount`, kiểm tra thắng khi xe `'A'` chạm `(row: 2, col: 4)`, và công thức tính sao (`<= optimal` → 3★, `<= optimal + 3` → 2★, `> optimal + 3` → 1★).

#### 1.2. Thuật toán Tìm đường Tối ưu (BFS Solver)
- **Files:**
  - `lib/domain/solver/bfs_solver.dart`
- **Đánh giá:** Tìm đường đi ngắn nhất chính xác từ `BoardState` bất kỳ bằng trạng thái chuẩn hóa 36 ký tự (`toBoardString()`), kiểm tra điều kiện xe mục tiêu `'A'` trước khi duyệt, có ngưỡng `maxVisitedStates` bảo vệ bộ nhớ. Phần bất đồng bộ Isolate & kiểm soát trạng thái thuộc tầng Cubit (xử lý ở Nhóm 2).

#### 1.3. Asset Level Loader
- **Files:**
  - `lib/data/datasources/level_asset_datasource.dart`
- **Đánh giá:** Đọc file `assets/levels/rush1000.txt` qua `rootBundle`, đẩy việc parse & sắp xếp 4.050 màn chơi sang `Isolate.run` để giữ UI 60–120fps và cache kết quả trong bộ nhớ tránh parse lại mỗi lần mở `LevelSelectScreen`.

#### 1.4. Hệ thống Giao diện Tactile, Theme & Các Widget Presentation Thuần túy
- **Files:**
  - `lib/presentation/theme/daylight_theme.dart`
  - `lib/presentation/widgets/tactile_widgets.dart` (`DaylightDotGridPainter`, `TactileKeycap`)
  - `lib/presentation/widgets/state_views.dart` (`ShimmerLoadingView`, `EmptyStateView`, `ErrorStateView`)
  - `lib/presentation/widgets/game_controls.dart`
  - `lib/presentation/widgets/win_dialog.dart`
  - `lib/presentation/widgets/how_to_play_dialog.dart`
  - `lib/presentation/widgets/dialogs/settings_dialog.dart`
  - `lib/presentation/widgets/dialogs/privacy_policy_dialog.dart` *(chỉ cần cập nhật nội dung văn bản sau khi viết lại tính năng Cloud Sync ở Nhóm 3)*
- **Đánh giá:** Thuần túy presentation, không chứa logic nghiệp vụ hay truy vấn DB, tái sử dụng nhất quán hệ thống màu/typography Daylight và phản hồi xúc giác 3D keycap.

#### 1.5. Domain Use Cases, Entities, Haptics & Core Exceptions
- **Files:**
  - `lib/domain/entities/level.dart`
  - `lib/domain/entities/leaderboard_entry.dart`
  - `lib/domain/usecases/get_levels.dart`
  - `lib/domain/usecases/save_progress.dart`
  - `lib/domain/usecases/get_leaderboard.dart`
  - `lib/domain/usecases/submit_score.dart`
  - `lib/core/error/exceptions.dart`
  - `lib/core/services/haptic_service.dart`
  - `lib/core/services/tutorial_service.dart`

---

### NHÓM 2: `[SỬA LẠI]` — Cấu trúc ổn, thiếu ràng buộc validation hoặc sai lệch nhỏ

#### 2.1. Level Parser & CLI Level Tool
- **Thực tế đang chạy sai như thế nào?**
  - `LevelParser.parseBoardString` (`lib/core/utils/level_parser.dart`) không kiểm tra xe mục tiêu `'A'` có tồn tại, có nằm ngang trên hàng thoát (`row == AppConstants.exitRow == 2`), và có độ dài đúng `length == 2` hay không. Trong khi `parseCampaignLevels` có kiểm tra `hasValidTarget` (nhưng vẫn bỏ sót check `v.length == 2`), thì `parseToBoardState` — vốn được gọi trực tiếp cho Daily Challenge từ server và khôi phục ván dở dang — có thể tạo ra bàn cờ thiếu xe `'A'` hoặc xe `'A'` dài 3 ô (gây vô nghiệm hoặc lỗi win ở `col == 4` tràn ra cột 6).
  - `LevelParser.parseLine` không kiểm tra `optimalMoves > 0` và `clusterSize >= 0`.
  - Comment/docstring ở `level_parser.dart` (dòng 178–181), `tool/parse_levels.dart` (dòng 7–8, 61) và `level_repository.dart` (dòng 4) vẫn ghi "30 campaign levels (10 Easy, 10 Medium, 10 Hard)" mâu thuẫn với hằng số thực tế `1350 * 3 = 4050` màn.
- **Quy luật nghiệp vụ đúng phải là gì?**
  - Mọi `boardString` hợp lệ khi parse phải bắt buộc có đúng 1 xe `'A'`, `isHorizontal == true`, `row == AppConstants.exitRow (2)`, `length == 2`, nằm gọn trong lưới `0..5`.
  - `parseLine` chỉ chấp nhận `optimalMoves >= 1` và `clusterSize >= 0`.
  - Đồng bộ lại toàn bộ docstring/CLI output theo đúng quy mô 4.050 màn chơi.
- **Danh sách file liên quan cần tác động:**
  - `lib/core/utils/level_parser.dart`
  - `lib/domain/repositories/level_repository.dart`
  - `tool/parse_levels.dart`
  - `test/domain/level_parser_test.dart`

#### 2.2. Thuật toán Sắp xếp Chiến dịch (`LevelOrderingPipeline`)
- **Thực tế đang chạy sai như thế nào?**
  - Trong Zone 3 (`LevelOrderingPipeline.orderLevels`, dòng 440–508), `rush1000.txt` có 1.350 Easy + 1.350 Medium + 1.350 Hard. Sau 19 màn onboarding, `mainPool` còn ~2.681 màn (Easy + Medium) nên vòng lặp kết hợp 9 thường + 1 Hard chỉ chạy 297 wave, để lại **1.053 màn Hard** dồn xuống phần `tail` (`#2990–#4050`). Khối `tail` này chỉ sort theo `difficultyScore` và cắt cụm 10 mà **bỏ qua bộ lọc đa dạng hình thái bàn cờ `_pickDiverse` (cửa sổ Jaccard 55 màn)**, khiến nhiều biến thể gần giống nhau của cùng một cụm puzzle xuất hiện liên tiếp nhau.
- **Quy luật nghiệp vụ đúng phải là gì?**
  - Không ngoại lệ hóa phần `tail`: toàn bộ các màn còn lại trong Zone 3 sau khi hết Easy/Medium vẫn phải đi qua `_pickDiverse` và cập nhật `recentWindow` (`_diversityWindow = 55`) trước khi sắp nhịp sóng 10 màn, đảm bảo trải nghiệm không lặp layout từ màn `#1` đến `#4050`.
- **Danh sách file liên quan cần tác động:**
  - `lib/domain/engine/level_ordering_pipeline.dart`
  - `test/domain/level_ordering_pipeline_test.dart`

#### 2.3. Tương tác Kéo Xe & Bảng Đỗ Xe (`VehicleWidget`, `ParkingBoardWidget`)
- **Thực tế đang chạy sai như thế nào?**
  - **Vi phạm tách lớp UI/Logic (`GEMINI.md`):** `VehicleWidget` (dòng 5, 161–164) import và gọi thẳng `BoardEngine.getMovementBounds(widget.boardState, widget.vehicle.id)` trong UI widget, đồng thời tự tính toán snap cell (`(currentPx / cellSize).round()`) và gọi `HapticFeedback.lightImpact()` + `playSfx(AppConstants.sfxHornCollide)` thay vì đi qua `GameCubit.onVehicleDragStart` (method này đã được viết sẵn ở `game_cubit.dart` nhưng không có widget nào gọi) hoặc `AudioService.playHornCollide()`.
  - **Lỗi Timer sau Win:** `ParkingBoardWidget.didUpdateWidget` (dòng 63–69) tạo `Future.delayed(520ms)` gọi `onEscapeAnimationComplete?.call()`, nhưng bên trong callback chỉ kiểm tra `if (mounted)` mà không kiểm tra `widget.isWon` còn đúng hay không. Nếu người chơi bấm Reset hoặc chuyển sang Tutorial trong khoảng 520ms đó, dialog Win vẫn hiện đè lên bàn cờ đang chơi.
  - **Stale State Closure:** Trong `GameScreen` (dòng 699) và `DailyScreen` (dòng 558), `onEscapeAnimationComplete: () => _handleEscapeComplete(state)` capture biến `state` tại thời điểm build trước đó thay vì đọc state hiện hành lúc callback chạy.
  - **Kẹt trạng thái drag cục bộ:** `VehicleWidget.didUpdateWidget` chỉ reset `_dragOffsetPx` và `_isDragging` khi `row` hoặc `col` của xe đó thay đổi. Nếu người chơi dùng ngón thứ 2 kéo xe `'A'` về đích trong lúc ngón thứ nhất đang giữ 1 xe khác (hoặc có lệnh reset/đổi board mà xe đó vẫn ở tọa độ cũ), `_isDragging` và `_dragOffsetPx` không tự reset.
  - **Hiển thị bất nhất khi mở lại màn đã thắng:** Ở `DailyScreen`, khi mở lại thử thách đã hoàn thành trước đó (`isWon == true` ngay từ khi mount), `ParkingBoardWidget._buildVehiclePositioned` đẩy xe `'A'` ra ngoài biên phải (`col = 6`, `opacity = 0.0`) làm xe biến mất trong khi các xe cản vẫn đứng nguyên ở vị trí khởi đầu.
- **Quy luật nghiệp vụ đúng phải là gì?**
  - UI Widget (`VehicleWidget`) không được import `BoardEngine`; giới hạn kéo (`minCol/maxCol/minRow/maxRow`) phải nhận từ callback do Cubit cung cấp (`onDragStart`).
  - Hiệu ứng thoát màn chỉ kích hoạt `onEscapeAnimationComplete` khi `mounted && widget.isWon` vẫn đúng tại thời điểm kết thúc animation (nên dùng `AnimationController` có `dispose()`/cancel thay cho `Future.delayed` rời rạc), và màn hình cha phải lấy `cubit.state` mới nhất.
  - Mọi chuyển đổi sang `isWon == true` hoặc thay đổi tham chiếu bàn cờ phải buộc hủy thao tác drag đang dở và đưa `_dragOffsetPx` về `0.0`.
- **Danh sách file liên quan cần tác động:**
  - `lib/presentation/widgets/vehicle_widget.dart`
  - `lib/presentation/widgets/parking_board_widget.dart`
  - `lib/presentation/screens/game_screen.dart`
  - `lib/presentation/screens/daily_screen.dart`
  - `lib/presentation/bloc/game_cubit.dart`
  - `lib/presentation/bloc/daily_cubit.dart`

#### 2.4. Hệ thống Gợi ý Thông minh (`requestHint`, `remainingHints`, Bonus +1)
- **Thực tế đang chạy sai như thế nào?**
  - **Async Race Condition:** `GameCubit.requestHint()` (dòng 626–657) và `DailyCubit.requestHint()` (dòng 325–357) chạy `BfsSolver.findNextMove` trong `Isolate.run`, nhưng trong thời gian Isolate đang chạy, bàn cờ không khóa thao tác kéo/Undo/Reset/LoadLevel. Khi Isolate trả kết quả về, Cubit không đối chiếu `state.boardState == snapshot` (hay `state.level.id` / `state.dateKey`), dẫn đến trừ `remainingHints` và vẽ mũi tên `HintArrowPainter` theo tọa độ cũ trên bàn cờ mới.
  - **Quota Hint chỉ lưu trên RAM:** Khởi tạo `remainingHints = 3` và phần thưởng `+1 hint` khi đạt 3★ lần đầu chỉ tồn tại trong `GameState` trên RAM. Khi thoát `GameScreen` về `LevelSelectScreen` và vào lại, hoặc refresh `DailyScreen`, số hint tự reset về `3` — vô hiệu hóa cả giới hạn 3 hint lẫn phần thưởng bonus 3★.
- **Quy luật nghiệp vụ đúng phải là gì?**
  - Khi kết quả BFS Isolate hoàn tất, chỉ emit `activeHint` và trừ `remainingHints` nếu `state.boardState == snapshot && state.level.id == snapshotLevelId && !state.isWon`. Nếu người chơi đã tự đi nước khác/Undo/Reset trong lúc chờ, bỏ qua kết quả cũ và giữ nguyên lượt hint.
  - Lưu trữ bền vững ví hint (hoặc quota hint theo ngày/màn) trong `LocalDatabaseDataSource` / Repository để phần thưởng `+1 hint` khi đạt 3★ lần đầu và số lượt đã tiêu không bị mất khi chuyển màn.
- **Danh sách file liên quan cần tác động:**
  - `lib/presentation/bloc/game_cubit.dart`
  - `lib/presentation/bloc/daily_cubit.dart`
  - `lib/data/datasources/local_database_datasource.dart`
  - `lib/domain/repositories/level_repository.dart`
  - `lib/data/repositories/level_repository_impl.dart`
  - `test/domain/game_cubit_test.dart`
  - `test/domain/production_fixes_test.dart`

#### 2.5. Tiến trình Campaign, Tutorial, Skip Level & Lưu Ván Dở Dang
- **Thực tế đang chạy sai như thế nào?**
  - **Persistence đặt sai tầng & Race Condition trong `GameCubit`:** `GameCubit` (`lib/presentation/bloc/game_cubit.dart`, dòng 6, 150, 219–284) import và gọi trực tiếp `SharedPreferences` để lưu/khôi phục bàn cờ đang chơi (`rush_out_in_progress_level_X`). Các lời gọi `_restoreInProgressState` (ở constructor & `loadLevel`), `_saveInProgressState` (ở `undo`), `_clearInProgressState` (ở `reset`) không được `await`/serialize tuần tự, khiến thao tác `undo` -> `reset` nhanh có thể làm `undo` ghi đè lại sau `reset`, hoặc `_restoreInProgressState` hoàn thành trễ ghi đè ván mới; đồng thời không kiểm tra tính nhất quán giữa `savedBoard` với danh sách xe gốc của `level.boardString`.
  - **Logic Campaign nằm trong UI (`GameScreen`, `LevelSelectScreen`, `HomeScreen`):**
    - `GameScreen` tự giữ bản sao mutable `List<Level> _levels` và tự vá trạng thái mở khóa (`_syncLevelProgressInMemory`, `_findNextLevel`). Trong `_confirmAndSkipLevel` (dòng 251, 358, 362), `nextLevel` được lấy trước khi `_syncLevelProgressInMemory` chạy nên truyền `Level` mang `isUnlocked: false` vào `loadLevel`.
    - Khi người chơi Replay Tutorial từ Level #N thông qua nút `?` (`_replayLevel1Tutorial`), hoàn tất Level #1 tutorial rồi bấm "Next" sẽ bị đẩy qua Level #2 thay vì quay lại ngữ cảnh Level #N đang chơi.
    - Ở lần mở app đầu tiên (`HomeScreen._onPlayCampaignTapped`), app đẩy thẳng `GameScreen(initialTutorialMode: true)` mà không đẩy `LevelSelectScreen` bên dưới. Khi xong Tutorial và bấm nút **"Back to Levels" (`Icons.grid_view_rounded`)** trên `WinDialog`, người chơi bị đẩy thẳng ra **`HomeScreen`** thay vì màn chọn màn chơi.
    - `LevelSelectScreen` tự viết điều kiện xác định `isSkipped` ngay trong UI (`SliverChildBuilderDelegate`, dòng 332–335), trùng lặp với logic `frontierIndex` của `LevelSelectCubit`, và gọi trực tiếp `tutorialService.hasCompletedTutorial()`.
  - **Skip Level thiếu ràng buộc nghiệp vụ:** Cho phép bỏ qua vô hạn mọi màn chơi (từ #1 tới #4050) chỉ bằng vài cú chạm, không có giới hạn hay phân biệt trạng thái `is_skipped` tường minh trong DB (đang dùng chung `stars == 0, isUnlocked == true`, dễ nhầm với màn mới mở nếu kiểm tra đơn lẻ).
  - **Tutorial Solver chạy trên UI Thread:** `GameCubit._createInitialState` và `loadLevel` gọi `BfsSolver.solve(initialBoard)` đồng bộ trên main thread.
- **Quy luật nghiệp vụ đúng phải là gì?**
  - Chuyển toàn bộ lưu/khôi phục/xóa ván dở dang vào `LevelRepository` & `LocalDatabaseDataSource` với hàng đợi ghi tuần tự theo `levelId` và validate tương thích với `level.boardString`.
  - Đưa trạng thái danh sách màn, logic chuyển màn kế tiếp và cờ `isSkipped` vào tầng Domain/Cubit (`Level`, `LevelRepository`, `GameCubit`, `LevelSelectCubit`); xóa `_levels` mutable khỏi `GameScreen`.
  - Sửa stack điều hướng lần đầu chơi: khi bấm "Back to Levels" sau Tutorial lần đầu phải mở/điều hướng tới `LevelSelectScreen`; khi chạy "Replay Tutorial" từ một màn đang chơi, kết thúc phải trả về đúng màn cũ hoặc menu cài đặt.
  - Bổ sung cột `is_skipped` tường minh trong DB (thay vì suy đoán qua màn kế tiếp) và thiết lập quy tắc giới hạn hợp lý cho Skip Level (ví dụ: chỉ hiện sau khi thử N nước / dùng quota / cooldown).
- **Danh sách file liên quan cần tác động:**
  - `lib/presentation/bloc/game_cubit.dart`
  - `lib/presentation/screens/game_screen.dart`
  - `lib/presentation/bloc/level_select_cubit.dart`
  - `lib/presentation/screens/level_select_screen.dart`
  - `lib/presentation/screens/home_screen.dart`
  - `lib/data/repositories/level_repository_impl.dart`
  - `lib/domain/repositories/level_repository.dart`
  - `lib/data/models/level_model.dart`
  - `lib/domain/entities/level.dart`
  - `lib/data/datasources/local_database_datasource.dart`
  - `test/domain/game_cubit_test.dart`
  - `test/domain/level_select_cubit_test.dart`
  - `test/domain/level1_tutorial_test.dart`

#### 2.6. Lưu trữ Local SQLite & Hỗ trợ Đa nền tảng (`LocalDatabaseDataSource`)
- **Thực tế đang chạy sai như thế nào?**
  - `LocalDatabaseDataSource.database` (dòng 20–80) không có cơ chế memoize `Future<Database?>` khi khởi tạo; nếu nhiều caller gọi song song lúc startup sẽ gọi `openDatabase(...)` nhiều lần đồng thời.
  - Bắt `MissingPluginException`, `UnimplementedError`, `StateError('databaseFactory')` và tự fallback sang `Map` trên RAM (`_memoryLevelProgress`, `_memoryDailyCache`) ngay trong code production. Do `pubspec.yaml` không khai báo `sqflite_common_ffi` dù dự án có target `windows/`, toàn bộ tiến trình game khi chạy trên Windows **lưu trên RAM và mất trắng khi đóng ứng dụng**; đồng thời che giấu các lỗi khởi tạo SQLite thật.
- **Quy luật nghiệp vụ đúng phải là gì?**
  - Khởi tạo SQLite thông qua một `Completer`/`Future<Database>` dùng chung để chống mở DB trùng lặp.
  - Tích hợp `sqflite_common_ffi` cho Desktop (hoặc ném `CacheException` rõ ràng nếu không thể mở DB trên thiết bị thật) và tách phần lưu trữ In-Memory thành fake implementation riêng trong thư mục `test/`, không trộn mock fallback vào `lib/data/`.
- **Danh sách file liên quan cần tác động:**
  - `lib/data/datasources/local_database_datasource.dart`
  - `lib/app/app_dependencies.dart`
  - `pubspec.yaml`
  - `test/domain/level_select_cubit_test.dart`
  - `test/domain/player_identity_service_test.dart`

#### 2.7. Global Leaderboard Viewer (`LeaderboardCubit`, `LeaderboardScreen`, `ScoreModel`)
- **Thực tế đang chạy sai như thế nào?**
  - `ScoreModel.fromJson` (`lib/data/models/score_model.dart`, dòng 15–17) tự điền dữ liệu giả `'Anonymous'` và `movesCount: 0` nếu JSON thiếu trường thay vì báo lỗi dữ liệu hỏng (`movesCount <= 0` là vô nghĩa trong Rush Hour).
  - `LeaderboardScreen` hiển thị `state.challengeDate` mà không ghi rõ đây là ngày theo múi giờ **UTC** (lệch với ngày địa phương ở các múi giờ như UTC+7 vào sáng sớm), giới hạn cứng Top 20 không phân trang, không làm nổi bật dòng của người chơi hiện tại và không hiển thị thứ hạng của chính người chơi nếu nằm ngoài Top 20.
  - `LeaderboardCubit` hiện nguyên chuỗi `e.toString()` từ exception lên UI nếu có lỗi không qua `ServerException`.
- **Quy luật nghiệp vụ đúng phải là gì?**
  - Parse `ScoreModel` chặt chẽ (`playerName` không rỗng, `movesCount >= 1`, `challengeDate` hợp lệ); ném `ServerException` nếu bản ghi từ API sai định dạng.
  - Bổ sung nhãn ngày `(UTC)`, làm nổi bật hàng của người chơi hiện tại (kết hợp sau khi viết lại hệ thống định danh ở Nhóm 3), hỗ trợ xem xếp hạng cá nhân ("My Rank") và phân trang/chọn ngày.
  - Chuẩn hóa thông báo lỗi thân thiện người dùng ở tầng Cubit.
- **Danh sách file liên quan cần tác động:**
  - `lib/data/models/score_model.dart`
  - `lib/data/repositories/leaderboard_repository_impl.dart`
  - `lib/domain/repositories/leaderboard_repository.dart`
  - `lib/presentation/bloc/leaderboard_cubit.dart`
  - `lib/presentation/screens/leaderboard_screen.dart`

#### 2.8. Audio, NetworkInfo, ErrorReporting & Bootstrap/Env Config
- **Thực tế đang chạy sai như thế nào?**
  - **Bug BGM khi app mở trong trạng thái Mute:** `AudioService.startBgm()` (`lib/core/services/audio_service.dart`, dòng 83–93) đặt `_bgmStarted = true` rồi `return` ngay nếu `_isMuted == true` mà không nạp audio source cho `_bgmPlayer`. Khi người dùng bật lại âm thanh (`toggleMute()` -> `resumeBgm()`), `_bgmPlayer!.resume()` chạy trên player chưa từng `play(...)` nên **nhạc nền im bặt suốt phiên**. Ngoài ra `init()` đặt `_isInitialized = true` trước `await`, gây nguy cơ gọi đồng thời trả về sớm khi chưa load xong preference.
  - **`NetworkInfoImpl`:** Kiểm tra `!results.contains(ConnectivityResult.none) && results.isNotEmpty`; nếu hệ điều hành trả danh sách gồm nhiều interface có chứa `none`, hàm trả về sai là offline.
  - **`ErrorReportingService`:** `scrubSensitiveData` chưa lọc header `apikey` của Supabase và chưa lọc các chuỗi UUID trần (`auth.uid()`) không có prefix `dev_`/`win_`.
  - **Env & IDE Configuration:** `main.dart` chỉ fallback `.env.example` (chứa URL/key giả `your-project-id`), trong khi `.idea/runConfigurations/main_dart.xml` không truyền `--dart-define-from-file=.env` khiến khi chạy từ IDE mặc định bị tắt hoàn toàn kết nối Supabase. Ngoài ra `_BootstrapErrorApp` nuốt lỗi im lặng nếu người dùng bấm Retry mà `AppDependencies.init()` tiếp tục thất bại.
- **Quy luật nghiệp vụ đúng phải là gì?**
  - `AudioService` tách biệt trạng thái `_bgmRequested` và `_bgmLoaded`; khi unmute nếu chưa nạp source phải gọi `_bgmPlayer!.play(...)`, đặt `_isInitialized` bằng `Completer`/lock sau khi `await` hoàn tất, và cung cấp `ValueListenable<bool>` cho UI theo dõi reactive.
  - `NetworkInfoImpl` kiểm tra `results.any((r) => r != ConnectivityResult.none)`.
  - `ErrorReportingService` che thêm UUID chuẩn và `apikey`; `_BootstrapErrorApp` hiển thị phản hồi lỗi khi Retry thất bại; bổ sung cấu hình `--dart-define-from-file=.env` vào run config/tài liệu build.
- **Danh sách file liên quan cần tác động:**
  - `lib/core/services/audio_service.dart`
  - `lib/core/network/network_info.dart`
  - `lib/core/services/error_reporting_service.dart`
  - `lib/main.dart`
  - `lib/presentation/screens/home_screen.dart`
  - `.idea/runConfigurations/main_dart.xml`

---

### NHÓM 3: `[XÓA VIẾT LẠI]` — Code spaghetti, dữ liệu giả, hoặc sai hoàn toàn bản chất nghiệp vụ

#### 3.1. Hệ thống Định danh Người chơi, Anonymous Auth & Cloud Progress Sync
- **Thực tế đang chạy sai như thế nào?**
  - **Sai hoàn toàn bản chất nghiệp vụ (Tính năng khôi phục khi cài lại máy là ảo):**
    - `PlayerIdentityService` (`lib/core/services/player_identity_service.dart`) và thông báo UI hứa hẹn lưu hồ sơ theo thiết bị để tự động khôi phục username, tutorial và 4.050 màn chơi sau khi gỡ app cài lại (và thậm chí có unit test "Case 3: Reinstall on same device" trong `player_identity_service_test.dart` giả lập hành vi này bằng mock).
    - Trên thực tế, `SupabaseRemoteDataSource` xác thực bằng **Supabase Anonymous Auth** và lưu `access_token`, `refresh_token`, `user_id` vào `SharedPreferences` (bị hệ điều hành xóa sạch khi gỡ app hoặc Clear Data). Khi cài lại, client gọi `/auth/v1/signup` tạo một `auth.uid()` hoàn toàn mới.
    - Hai hàm `fetchDeviceProfile(String deviceId)` và `fetchDeviceLevelProgress(String deviceId)` trong `SupabaseRemoteDataSource` (dòng 386, 448) **bỏ qua hoàn toàn tham số `deviceId`**, chỉ query `user_id=eq.${session.userId}`, và RLS trong `supabase/schema.sql` (`auth.uid() = user_id`) cũng khóa chặt theo `auth.uid()`. Trên Android, `_resolveInstallationFallbackId()` còn sinh UUID ngẫu nhiên lưu trong `SharedPreferences`. Do đó **khi gỡ app cài lại hoặc đổi máy, toàn bộ tiến trình trên cloud cũ vĩnh viễn mất liên kết (orphan rows) và không bao giờ khôi phục được**.
  - **Lỗ hổng bảo mật, Race Condition & Validate lỗi:**
    - Lưu JWT `access_token` và `refresh_token` dạng plaintext trong `SharedPreferences` thay vì Secure Storage.
    - `PlayerIdentityService.init()` gán `_isInitialized = true` trước `await _prefs()`. `syncWithCloud` luôn để local username thắng remote mà không so sánh `updated_at`, và gửi toàn bộ mảng hàng nghìn màn chơi trong một HTTP POST duy nhất (dễ timeout 8s).
    - Regex `r'^[a-zA-Z0-9_\-\sÀ-ỹ]+$'` bao gồm cả ký tự toán học `×` (`U+00D7`) và `÷` (`U+00F7`), trong khi `_blockedTerms` kiểm tra token ngắn (`cc`, `vl`, `dm`) dễ chặn nhầm tên hợp lệ nhưng lại bỏ sót biến thể tiếng Việt có dấu.
  - **Trộn lẫn UI với logic & báo trạng thái giả trong Dialog (`ProfileDialog`, `UsernamePromptDialog`, `HomeScreen`):**
    - `ProfileDialog` gọi trực tiếp `identity.setCloudSyncEnabled` và `identity.syncWithCloud` trong `StatefulBuilder`, **tự hiển thị thông báo giả `'Sync enabled. Will sync when online.'`** ngay cả khi thất bại do chưa đặt username, chưa cấu hình Supabase hoặc lỗi server; nút `Sync Now` tự bật `setCloudSyncEnabled(true)` dù sync không thành công.
    - `UsernamePromptDialog` khi `isFirstLaunch == true` ép chặn toàn màn hình (`barrierDismissible: false`, không có nút Skip/Play as Guest) nhưng thiếu `PopScope(canPop: false)` nên vẫn bị thoát bằng nút Back Android, và hiển thị raw `e.toString()` lên giao diện.
    - `HomeScreen` đọc `identity.isCloudSynced` và `identity.username` thủ công, không cập nhật reactive khi background sync sau khi thắng level hoàn tất.
- **Quy luật nghiệp vụ đúng phải là gì?**
  - **Tách rạch ròi Chế độ Khách (Local Anonymous) và Tài khoản Đồng bộ Cloud (Recoverable Account):**
    - Nếu người dùng muốn đồng bộ & khôi phục tiến trình qua các lần cài lại hoặc đổi thiết bị, bắt buộc phải liên kết tài khoản thực (OAuth Google/Apple, Email OTP/Magic Link, hoặc Recovery Transfer Token được server xác thực và chuyển quyền `user_id`), sử dụng `supabase_flutter` hoặc Auth client chuẩn kèm `flutter_secure_storage` để lưu JWT token an toàn.
    - Không ép người chơi offline phải nhập tên mới được chơi khi mở app lần đầu (cung cấp tùy chọn chơi ngay / đặt tên sau khi dùng tính năng online).
  - **Kiến trúc UI sạch:** Đưa toàn bộ state profile, validation, liên kết tài khoản và sync status vào `ProfileCubit` (hoặc `AuthSyncBloc`). `ProfileDialog` và `UsernamePromptDialog` chỉ gửi intent và render đúng trạng thái thực (`idle`, `syncing`, `success`, `error` với thông báo lỗi thực tế từ kết quả xử lý).
  - **Sync tin cậy:** Hợp nhất profile dựa trên `updated_at` / phiên bản, chia nhỏ batch upload (`chunk` 200–500 dòng/request) và viết lại integration/unit test bám sát hành vi thật của datasource thay vì fake sai quy luật.
- **Danh sách file liên quan cần tác động:**
  - `lib/core/services/player_identity_service.dart` *(xóa/thay thế bằng tầng Auth/Sync Repository + Service chuẩn)*
  - `lib/data/datasources/supabase_remote_datasource.dart`
  - `lib/presentation/widgets/dialogs/profile_dialog.dart`
  - `lib/presentation/widgets/dialogs/username_prompt_dialog.dart`
  - `lib/presentation/widgets/dialogs/privacy_policy_dialog.dart`
  - `lib/presentation/screens/home_screen.dart`
  - `lib/app/app_dependencies.dart`
  - `lib/app/rush_out_app.dart`
  - `supabase/schema.sql`
  - `pubspec.yaml`
  - `test/domain/player_identity_service_test.dart`
  - *(Tạo mới)* `lib/presentation/bloc/profile_cubit.dart` (và repository/auth datasource tương ứng)

#### 3.2. Hệ thống Daily Challenge (Backend Seed, Anti-Cheat RPC & Luồng Trạng thái/Nộp điểm)
- **Thực tế đang chạy sai như thế nào?**
  - **Dữ liệu giả & Seed cứng chết sau 7 ngày (`supabase/schema.sql`):**
    - Mục 4 của `supabase/schema.sql` hardcode đúng 7 ngày (`CURRENT_DATE .. CURRENT_DATE + 6`), không có cơ chế sinh/lên lịch tự động dài hạn -> sau 7 ngày `daily_challenges` cạn sạch và người chơi vĩnh viễn gặp `EmptyStateView`.
    - Bơm sẵn **3 dòng dữ liệu giả** (`SpeedRacer_VN`, `PuzzleMaster`, `RushHourPro`) với `user_id = NULL` vào bảng `leaderboard_scores` thật (vi phạm trực tiếp quy tắc cấm dùng dữ liệu giả).
    - `DailyChallengeModel.fromSupabaseJson` tự ý điền fallback giả `optimalMoves ?? 10` nếu thiếu field từ server.
  - **Sai bản chất Anti-Cheat (Tin tuyệt đối số bước từ Client):**
    - RPC `submit_daily_score(p_player_name, p_challenge_date, p_moves_count)` chỉ kiểm tra `p_moves_count >= v_optimal_moves AND p_moves_count <= 999`. Không nhận `move_history` và không mô phỏng kiểm chứng lời giải trên `board_string`. Bất kỳ ai dùng `SUPABASE_ANON_KEY` công khai gọi `/auth/v1/signup` rồi gọi RPC đều có thể gửi `p_moves_count = optimal_moves` để chiếm Top 1 mà không cần giải bài.
  - **Sai hoàn toàn logic trạng thái bàn cờ đã hoàn thành & Replay/Submit (`DailyCubit`, `DailyScreen`):**
    - Khi người chơi đã thắng Daily Challenge hôm nay, thoát màn hình rồi mở lại `DailyScreen`, `DailyCubit.loadDailyChallenge()` (dòng 174–191) gán `boardState: parsedBoard.copyWith(moveCount: solvedMoves)` (trạng thái **xe nằm ở vị trí chưa giải**) nhưng lại gán `isWon: true`! Kết quả là `ParkingBoardWidget` ẩn xe mục tiêu `'A'` ở ngoài biên phải (`col = 6`) trong khi các xe cản vẫn chắn kín hàng 2, đồng thời nút `Reset` ở thanh điều khiển bị khóa (`canReset` kiểm tra `!isWon`).
    - Nếu người chơi thắng 12 bước (chưa nộp điểm), bấm `Replay`, giải lại dở hơn (20 bước) rồi bấm `Submit Score`: `DailyCubit.submitPlayerScore` gửi `currentBoard.moveCount` (**20 bước**) lên Leaderboard thay vì thành tích tốt nhất đã lưu (`challenge.userMoves` = 12 bước).
    - Trạng thái `scoreSubmitted` chỉ dựa vào cờ local `daily_cache.score_submitted`; nếu xóa cache local hoặc đổi máy, app vẫn hiện form cho nộp lại rồi mới bị Postgres ném lỗi `23505` thay vì kiểm tra trạng thái đã nộp của `auth.uid()` từ server khi load.
    - Nếu người chơi để trống tên trong dialog và bấm `Submit Score`, cả `DailyScreen` (dòng 221) và `DailyCubit` (dòng 369) đều im lặng `return` không hiển thị bất kỳ lỗi validation nào.
    - `DailyScreen` nhúng logic dialog thắng + `TextEditingController` dài gần 300 dòng trong StatefulWidget, và phụ thuộc callback `onOpenLeaderboard` giữ từ `HomeScreen` (context ở màn hình bên dưới).
- **Quy luật nghiệp vụ đúng phải là gì?**
  - **Backend sạch & Anti-Cheat thật:**
    - Xóa toàn bộ seed điểm bảng xếp hạng giả (`SpeedRacer_VN`, `PuzzleMaster`, `RushHourPro`) khỏi `supabase/schema.sql`.
    - Thay thế seed tĩnh 7 ngày bằng kho puzzle định kỳ hoặc Supabase Scheduled Job / Edge Function sinh lịch Daily Challenge dài hạn từ tập puzzle đã kiểm chứng (hoặc bảng schedule tự động xoay vòng không trùng ngày).
    - Viết lại luồng nộp điểm qua Edge Function / PL/pgSQL verifier: client gửi kèm danh sách `moves` (`move_history` của ván thắng tốt nhất), server replay từng bước trên `board_string` của ngày hôm đó để xác nhận hợp lệ, đạt trạng thái thắng `(row: 2, col: 4)`, và tự tính `moves_count = array_length(moves)` ở server (chống gian lận `moves_count` giả).
  - **Client State & UX đúng quy luật:**
    - Khi lưu kết quả hoàn thành Daily cục bộ (hoặc khôi phục lại màn đã thắng), lưu kèm `solved_board_string` / `best_move_history` (hoặc hiển thị chế độ Review/Completed rõ ràng cho phép người chơi bấm Replay ngay trên màn hình chính mà không hiển thị bàn cờ xuất phát bị thiếu xe `'A'`).
    - Luôn giữ và nộp điểm thành tích tốt nhất (`bestMoves` + `bestMoveHistory` tương ứng) ngay cả khi người chơi bấm Replay thử giải lại.
    - Đồng bộ trạng thái `hasSubmittedToday` (và điểm đã nộp) trực tiếp từ server theo `user_id + challenge_date` khi load Daily Challenge.
    - Hiển thị lỗi validation rõ ràng khi nickname rỗng, tách `DailyWinDialog` thành widget riêng, bỏ fallback `optimalMoves ?? 10`, và cho `DailyScreen` tự điều hướng sang `LeaderboardScreen` độc lập.
- **Danh sách file liên quan cần tác động:**
  - `supabase/schema.sql` *(+ Edge Function mới nếu xác thực `move_history` bằng TypeScript/Deno)*
  - `lib/data/models/daily_challenge_model.dart`
  - `lib/data/datasources/supabase_remote_datasource.dart`
  - `lib/data/datasources/local_database_datasource.dart`
  - `lib/data/repositories/daily_challenge_repository_impl.dart`
  - `lib/domain/repositories/daily_challenge_repository.dart`
  - `lib/domain/entities/leaderboard_entry.dart`
  - `lib/domain/usecases/submit_score.dart`
  - `lib/presentation/bloc/daily_cubit.dart`
  - `lib/presentation/screens/daily_screen.dart`
  - `lib/presentation/screens/home_screen.dart`
  - `test/domain/production_fixes_test.dart`
  - *(Tạo mới)* Widget dialog thắng riêng cho Daily (`lib/presentation/widgets/daily_win_dialog.dart`)

---

## 4. LỘ TRÌNH TÁI CẤU TRÚC ĐỀ XUẤT (EXECUTION ORDER)

Để đảm bảo an toàn, kiểm thử được sau từng bước và tuân thủ nguyên tắc **chỉ chỉnh sửa đúng danh sách file được chỉ định ở từng lượt**, đề xuất chia quá trình tái cấu trúc thành 6 đợt tuần tự:

1. **Đợt 1 — Dọn nền tảng Core, Parser & Storage (Low-risk, High-impact):**
   - Sửa `LevelParser`, `LevelOrderingPipeline` (diversity cho phần `tail`), `AudioService` (bug BGM khi unmute), `NetworkInfoImpl`, `ErrorReportingService`.
   - Sửa `LocalDatabaseDataSource` (init lock + `sqflite_common_ffi` cho Windows + tách in-memory fake ra khỏi production code).
2. **Đợt 2 — Tách lớp Game Engine khỏi UI & Sửa Race Condition Gameplay:**
   - Rút `BoardEngine` khỏi `VehicleWidget`; nối `onDragStart` qua `GameCubit`/`DailyCubit`.
   - Sửa timer 520ms ở `ParkingBoardWidget`, stale closure, drag reset khi multi-touch/win.
   - Chặn async race condition của `requestHint` và lưu bền vững quota hint + phần thưởng 3★.
3. **Đợt 3 — Chuẩn hóa Campaign Progression, In-Progress Persistence & Điều hướng:**
   - Đưa `_saveInProgressState`/`_restoreInProgressState` từ `GameCubit` xuống `LevelRepository` + `LocalDatabaseDataSource`.
   - Loại bỏ `_levels` mutable khỏi `GameScreen`, sửa lỗi Back về `HomeScreen` sau Tutorial lần đầu, phân tách trạng thái `isSkipped` & quy tắc Skip Level.
4. **Đợt 4 — Viết lại Hệ thống Auth, Định danh & Cloud Sync (Group 3.1):**
   - Thiết kế lại `supabase/schema.sql` phần Identity/Sync + Auth thực (hoặc Recovery Code) + `flutter_secure_storage`.
   - Xây dựng `ProfileCubit`, viết lại `ProfileDialog`, `UsernamePromptDialog`, `HomeScreen` (reactive, không báo trạng thái giả), cập nhật `PrivacyPolicyDialog` và viết lại test thật.
5. **Đợt 5 — Viết lại Daily Challenge Backend/Anti-Cheat & Client Flow (Group 3.2):**
   - Xóa seed giả, bổ sung cơ chế lịch Daily dài hạn và RPC/Edge Function kiểm chứng `move_history`.
   - Viết lại `DailyChallengeModel`, `DailyChallengeRepositoryImpl`, `DailyCubit`, `DailyScreen` (sửa lỗi bàn cờ khi mở lại, giữ best score khi replay, validate form submit, sync `hasSubmittedToday` từ server).
6. **Đợt 6 — Nâng cấp Leaderboard & Kiểm thử Toàn diện:**
   - Sửa `ScoreModel`, `LeaderboardCubit`, `LeaderboardScreen` (My Rank, nhãn UTC, phân trang, loại bỏ raw error text).
   - Cập nhật `.idea/runConfigurations/main_dart.xml` / tài liệu build `--dart-define-from-file=.env` và chạy kiểm thử `flutter analyze` + `flutter test` toàn dự án.
