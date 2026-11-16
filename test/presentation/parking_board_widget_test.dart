import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/services/audio_service.dart';
import 'package:rush_out/domain/entities/board_state.dart';
import 'package:rush_out/domain/entities/vehicle.dart';
import 'package:rush_out/presentation/widgets/parking_board_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BoardState sampleBoard({int aCol = 0, int bRow = 1, int moveCount = 0}) {
    return BoardState(
      vehicles: [
        Vehicle(
          id: 'A',
          length: 2,
          isHorizontal: true,
          row: 2,
          col: aCol,
        ),
        Vehicle(
          id: 'B',
          length: 2,
          isHorizontal: false,
          row: bRow,
          col: 3,
        ),
      ],
      moveCount: moveCount,
      optimalMoves: 2,
    );
  }

  group('ParkingBoardWidget & VehicleWidget Tests (Mục 2.3)', () {
    testWidgets(
      'cancels pending 520ms win escape callback if board resets (isWon becomes false) before animation finishes',
      (tester) async {
        bool isWon = false;
        BoardState board = sampleBoard(aCol: 0, bRow: 3);
        int escapeCalls = 0;
        late StateSetter setHostState;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 360,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    setHostState = setState;
                    return ParkingBoardWidget(
                      boardState: board,
                      isWon: isWon,
                      audioService: AudioService(enablePlatformAudio: false),
                      onMoveCommitted: (_, {required draggedRow, required draggedCol}) async {},
                      onEscapeAnimationComplete: () {
                        escapeCalls++;
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Transition to won state -> starts 520ms escape animation
        setHostState(() {
          board = sampleBoard(aCol: 4, bRow: 3, moveCount: 1);
          isWon = true;
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Player clicks Reset / switches state before 520ms elapses
        setHostState(() {
          board = sampleBoard(aCol: 0, bRow: 1, moveCount: 0);
          isWon = false;
        });
        await tester.pump();

        // Advance well past 520ms
        await tester.pump(const Duration(milliseconds: 500));

        expect(escapeCalls, 0);
      },
    );

    testWidgets(
      'resets active local drag state when boardState changes or isWon becomes true mid-drag',
      (tester) async {
        bool isWon = false;
        BoardState board = sampleBoard(aCol: 0, bRow: 1);
        final List<String> dragStartVehicleIds = [];
        late StateSetter setHostState;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 360,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    setHostState = setState;
                    return ParkingBoardWidget(
                      boardState: board,
                      isWon: isWon,
                      audioService: AudioService(enablePlatformAudio: false),
                      onDragStart: (vehicleId) {
                        dragStartVehicleIds.add(vehicleId);
                        if (vehicleId == 'B') {
                          return (minRow: 0, maxRow: 3, minCol: 3, maxCol: 3);
                        }
                        return (minRow: 2, maxRow: 2, minCol: 0, maxCol: 4);
                      },
                      onMoveCommitted: (_, {required draggedRow, required draggedCol}) async {},
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Find vehicle B (vertical, '↕') and start dragging it downward without releasing
        final vehicleBFinder = find.text('↕');
        expect(vehicleBFinder, findsOneWidget);

        final center = tester.getCenter(vehicleBFinder);
        final gesture = await tester.startGesture(center);
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();

        expect(dragStartVehicleIds, ['B']);

        // Vehicle B should currently be translated downward while dragged
        final transformsDuringDrag = tester
            .widgetList<Transform>(
              find.ancestor(
                of: vehicleBFinder,
                matching: find.byType(Transform),
              ),
            )
            .where((t) => t.transform.getTranslation().y != 0.0)
            .toList();
        expect(transformsDuringDrag, isNotEmpty);

        // Another finger wins or board updates while vehicle B stays at (1, 3)
        setHostState(() {
          board = sampleBoard(aCol: 4, bRow: 1, moveCount: 1);
          isWon = true;
        });
        await tester.pump();

        // Local drag translation on B must have been reset to zero immediately
        final nonZeroTransformsAfterWin = tester
            .widgetList<Transform>(
              find.ancestor(
                of: vehicleBFinder,
                matching: find.byType(Transform),
              ),
            )
            .where((t) => t.transform.getTranslation().y.abs() > 0.01)
            .toList();
        expect(nonZeroTransformsAfterWin, isEmpty);

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets(
      'fires onEscapeAnimationComplete once after 520ms when isWon stays true',
      (tester) async {
        bool isWon = false;
        BoardState board = sampleBoard(aCol: 0, bRow: 3);
        int escapeCalls = 0;
        late StateSetter setHostState;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 360,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    setHostState = setState;
                    return ParkingBoardWidget(
                      boardState: board,
                      isWon: isWon,
                      audioService: AudioService(enablePlatformAudio: false),
                      onMoveCommitted: (_, {required draggedRow, required draggedCol}) async {},
                      onEscapeAnimationComplete: () {
                        escapeCalls++;
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );

        setHostState(() {
          board = sampleBoard(aCol: 4, bRow: 3, moveCount: 1);
          isWon = true;
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(escapeCalls, 0);

        await tester.pump(const Duration(milliseconds: 50));
        expect(escapeCalls, 1);
      },
    );
  });
}
