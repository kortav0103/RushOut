import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/audio_service.dart';
import '../../domain/entities/board_state.dart';
import '../../domain/entities/move.dart';
import '../../domain/entities/vehicle.dart';
import 'vehicle_widget.dart';

class ParkingBoardWidget extends StatefulWidget {
  final BoardState boardState;
  final Move? activeHint;
  final bool isWon;
  final Set<String>? unlockedVehicleIds;
  final ({int minRow, int maxRow, int minCol, int maxCol})? Function(
    Vehicle vehicle,
  )? customDragBounds;
  final ({int row, int col, int length, bool isHorizontal})? tutorialTargetSlot;
  final AudioService? audioService;
  final VoidCallback? onLockedVehicleTapped;
  final Future<void> Function(
    String vehicleId, {
    required double draggedRow,
    required double draggedCol,
  }) onMoveCommitted;
  final VoidCallback? onEscapeAnimationComplete;

  const ParkingBoardWidget({
    super.key,
    required this.boardState,
    this.activeHint,
    this.isWon = false,
    this.unlockedVehicleIds,
    this.customDragBounds,
    this.tutorialTargetSlot,
    this.audioService,
    this.onLockedVehicleTapped,
    required this.onMoveCommitted,
    this.onEscapeAnimationComplete,
  });

  @override
  State<ParkingBoardWidget> createState() => _ParkingBoardWidgetState();
}

class _ParkingBoardWidgetState extends State<ParkingBoardWidget>
    with SingleTickerProviderStateMixin {
  bool _escapeScheduled = false;
  late final AnimationController _hintPulseController;

  @override
  void initState() {
    super.initState();
    _hintPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ParkingBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWon && !oldWidget.isWon && !_escapeScheduled) {
      _escapeScheduled = true;
      Future.delayed(const Duration(milliseconds: 520), () {
        if (mounted) {
          widget.onEscapeAnimationComplete?.call();
        }
      });
    } else if (!widget.isWon) {
      _escapeScheduled = false;
    }
  }

  @override
  void dispose() {
    _hintPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boardSize = constraints.maxWidth;
          if (!boardSize.isFinite || boardSize <= 0) {
            return const SizedBox.shrink();
          }
          final wallThickness = boardSize * 0.045;
          final innerSize = boardSize - (wallThickness * 2);
          final cellSize = innerSize / AppConstants.gridSize;
          if (cellSize <= 0) {
            return const SizedBox.shrink();
          }

          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2B2D30),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. RepaintBoundary + CustomPainter for Static Asphalt Grid, Walls & Exit Bay
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: ParkingLotPainter(
                          wallThickness: wallThickness,
                          cellSize: cellSize,
                        ),
                      ),
                    ),
                  ),

                  // 2. Vehicles Layer (Each VehicleWidget manages its own 60-120fps ValueNotifier & Transform.translate)
                  Padding(
                    padding: EdgeInsets.all(wallThickness),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (widget.tutorialTargetSlot != null)
                          _buildTutorialTargetHighlight(
                            slot: widget.tutorialTargetSlot!,
                            cellSize: cellSize,
                          ),

                        for (final vehicle in widget.boardState.vehicles)
                          _buildVehiclePositioned(
                            vehicle: vehicle,
                            cellSize: cellSize,
                          ),

                        // 3. Animated Hint Arrow Overlay
                        if (widget.activeHint != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: RepaintBoundary(
                                child: AnimatedBuilder(
                                  animation: _hintPulseController,
                                  builder: (context, _) {
                                    return CustomPaint(
                                      painter: HintArrowPainter(
                                        hintMove: widget.activeHint!,
                                        vehicle:
                                            widget.boardState.getVehicleById(
                                          widget.activeHint!.vehicleId,
                                        ),
                                        cellSize: cellSize,
                                        pulseValue: _hintPulseController.value,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTutorialTargetHighlight({
    required ({int row, int col, int length, bool isHorizontal}) slot,
    required double cellSize,
  }) {
    final left = slot.col * cellSize + 3;
    final top = slot.row * cellSize + 3;
    final width =
        (slot.isHorizontal ? slot.length * cellSize : cellSize) - 6;
    final height =
        (slot.isHorizontal ? cellSize : slot.length * cellSize) - 6;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _hintPulseController,
          builder: (context, _) {
            final alpha = 0.25 + (_hintPulseController.value * 0.35);
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D4D).withValues(alpha: alpha * 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFF9F1C).withValues(alpha: alpha + 0.3),
                  width: 2.5,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVehiclePositioned({
    required Vehicle vehicle,
    required double cellSize,
  }) {
    final isHinted = widget.activeHint?.vehicleId == vehicle.id;
    final isLocked = widget.unlockedVehicleIds != null &&
        !widget.unlockedVehicleIds!.contains(vehicle.id);

    final effectiveCol = (widget.isWon && vehicle.isTarget)
        ? AppConstants.targetEscapeCol.toDouble()
        : vehicle.col.toDouble();
    final left = effectiveCol * cellSize;
    final top = vehicle.row * cellSize;

    final child = VehicleWidget(
      vehicle: vehicle,
      boardState: widget.boardState,
      cellSize: cellSize,
      isHinted: isHinted,
      isWon: widget.isWon,
      isLocked: isLocked,
      customDragBounds: widget.customDragBounds,
      audioService: widget.audioService,
      onLockedTap: isLocked ? widget.onLockedVehicleTapped : null,
      onMoveCommitted: widget.onMoveCommitted,
    );

    // Only animate layout position when target car escapes out the exit gate on win
    if (widget.isWon && vehicle.isTarget) {
      return AnimatedPositioned(
        key: ValueKey('veh_${vehicle.id}'),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInCubic,
        left: left,
        top: top,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeIn,
          opacity: 0.0,
          child: child,
        ),
      );
    }

    return Positioned(
      key: ValueKey('veh_${vehicle.id}'),
      left: left,
      top: top,
      child: child,
    );
  }
}

class ParkingLotPainter extends CustomPainter {
  final double wallThickness;
  final double cellSize;

  const ParkingLotPainter({
    required this.wallThickness,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark Asphalt Background (#2B2D30)
    final asphaltPaint = Paint()..color = const Color(0xFF2B2D30);
    canvas.drawRect(Offset.zero & size, asphaltPaint);

    final innerRect = Rect.fromLTWH(
      wallThickness,
      wallThickness,
      size.width - wallThickness * 2,
      size.height - wallThickness * 2,
    );

    final lotSurfacePaint = Paint()..color = const Color(0xFF242629);
    canvas.drawRect(innerRect, lotSurfacePaint);

    // 2. Dashed Parking Stall Grid Lines (6x6)
    final stallLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 1; i < AppConstants.gridSize; i++) {
      final offset = i * cellSize;
      _drawDashedLine(
        canvas,
        Offset(wallThickness + offset, wallThickness),
        Offset(wallThickness + offset, size.height - wallThickness),
        stallLinePaint,
      );
      _drawDashedLine(
        canvas,
        Offset(wallThickness, wallThickness + offset),
        Offset(size.width - wallThickness, wallThickness + offset),
        stallLinePaint,
      );
    }

    final dotPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.22);
    for (int r = 0; r <= AppConstants.gridSize; r++) {
      for (int c = 0; c <= AppConstants.gridSize; c++) {
        canvas.drawCircle(
          Offset(wallThickness + c * cellSize, wallThickness + r * cellSize),
          2.0,
          dotPaint,
        );
      }
    }

    // Highlight exit lane on row = 2 (main escape corridor)
    final exitLaneRect = Rect.fromLTWH(
      wallThickness,
      wallThickness + AppConstants.exitRow * cellSize,
      innerRect.width,
      cellSize,
    );
    final exitLanePaint = Paint()
      ..color = const Color(0xFFFFCA28).withValues(alpha: 0.11);
    canvas.drawRect(exitLaneRect, exitLanePaint);

    // Top & bottom lane guide lines along row = 2
    final laneGuidePaint = Paint()
      ..color = const Color(0xFFFFCA28).withValues(alpha: 0.45)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(wallThickness, exitLaneRect.top),
      Offset(size.width - wallThickness, exitLaneRect.top),
      laneGuidePaint,
    );
    canvas.drawLine(
      Offset(wallThickness, exitLaneRect.bottom),
      Offset(size.width - wallThickness, exitLaneRect.bottom),
      laneGuidePaint,
    );

    // Subtle directional chevrons along the exit lane
    final laneArrowMidY = exitLaneRect.top + cellSize * 0.5;
    final stepChevronSize = cellSize * 0.11;
    final stepChevronPaint = Paint()
      ..color = const Color(0xFFFFCA28).withValues(alpha: 0.22)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (int c = 0; c < AppConstants.gridSize - 1; c++) {
      final cx = wallThickness + (c + 0.5) * cellSize;
      final p = Path()
        ..moveTo(cx - stepChevronSize * 0.4, laneArrowMidY - stepChevronSize * 0.7)
        ..lineTo(cx + stepChevronSize * 0.4, laneArrowMidY)
        ..lineTo(cx - stepChevronSize * 0.4, laneArrowMidY + stepChevronSize * 0.7);
      canvas.drawPath(p, stepChevronPaint);
    }

    // 3. Concrete Border Walls (#5C626A) with open exit bay on right side of row = 2
    final wallPaint = Paint()..color = const Color(0xFF5C626A);
    final exitTop = wallThickness + AppConstants.exitRow * cellSize;
    final exitBottom = exitTop + cellSize;

    // Top wall
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, wallThickness),
      wallPaint,
    );
    // Bottom wall
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - wallThickness, size.width, wallThickness),
      wallPaint,
    );
    // Left wall
    canvas.drawRect(
      Rect.fromLTWH(0, 0, wallThickness, size.height),
      wallPaint,
    );
    // Right wall above exit bay (rows 0..1)
    canvas.drawRect(
      Rect.fromLTWH(
        size.width - wallThickness,
        0,
        wallThickness,
        exitTop,
      ),
      wallPaint,
    );
    // Right wall below exit bay (rows 3..5)
    canvas.drawRect(
      Rect.fromLTWH(
        size.width - wallThickness,
        exitBottom,
        wallThickness,
        size.height - exitBottom,
      ),
      wallPaint,
    );

    // 4. Open Exit Bay at right side of row = 2 with Yellow/Black Hazard Stripes
    final exitBayRect = Rect.fromLTWH(
      size.width - wallThickness,
      exitTop,
      wallThickness,
      cellSize,
    );
    final hazardBgPaint = Paint()..color = const Color(0xFF1E2022);
    canvas.drawRect(exitBayRect, hazardBgPaint);

    final stripePaint = Paint()
      ..color = const Color(0xFFFFCA28)
      ..strokeWidth = 3.0;
    canvas.save();
    canvas.clipRect(exitBayRect);
    for (double y = exitTop - wallThickness;
        y < exitBottom + wallThickness;
        y += 9) {
      canvas.drawLine(
        Offset(size.width - wallThickness, y),
        Offset(size.width, y + wallThickness),
        stripePaint,
      );
    }
    canvas.restore();

    // 5. Crisp right-pointing Exit Chevron on the exit lane (last cell) & exit bay
    final laneArrowX = size.width - wallThickness - cellSize * 0.28;
    final laneArrowY = exitTop + cellSize * 0.5;
    final chevronSize = cellSize * 0.14;
    final laneChevronPaint = Paint()
      ..color = const Color(0xFFFFCA28).withValues(alpha: 0.35)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final offset in [-chevronSize * 0.75, 0.0]) {
      final path = Path()
        ..moveTo(laneArrowX + offset - chevronSize * 0.45, laneArrowY - chevronSize * 0.65)
        ..lineTo(laneArrowX + offset + chevronSize * 0.35, laneArrowY)
        ..lineTo(laneArrowX + offset - chevronSize * 0.45, laneArrowY + chevronSize * 0.65);
      canvas.drawPath(path, laneChevronPaint);
    }

    // Center badge arrow on the hazard exit bay itself
    final bayCenter = Offset(size.width - wallThickness * 0.5, laneArrowY);
    final badgeRadius = wallThickness * 0.38;
    canvas.drawCircle(
      bayCenter,
      badgeRadius,
      Paint()..color = const Color(0xFF1E2022).withValues(alpha: 0.9),
    );
    final bayArrowSize = badgeRadius * 0.55;
    final bayArrowPath = Path()
      ..moveTo(bayCenter.dx - bayArrowSize * 0.45, bayCenter.dy - bayArrowSize * 0.85)
      ..lineTo(bayCenter.dx + bayArrowSize * 0.55, bayCenter.dy)
      ..lineTo(bayCenter.dx - bayArrowSize * 0.45, bayCenter.dy + bayArrowSize * 0.85);
    canvas.drawPath(
      bayArrowPath,
      Paint()
        ..color = const Color(0xFFFFCA28)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const dashLength = 7.0;
    const gapLength = 5.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance <= 0) return;
    final ux = dx / distance;
    final uy = dy / distance;

    double progress = 0.0;
    while (progress < distance) {
      final segEnd = math.min(progress + dashLength, distance);
      canvas.drawLine(
        Offset(start.dx + ux * progress, start.dy + uy * progress),
        Offset(start.dx + ux * segEnd, start.dy + uy * segEnd),
        paint,
      );
      progress += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant ParkingLotPainter oldDelegate) {
    return oldDelegate.wallThickness != wallThickness ||
        oldDelegate.cellSize != cellSize;
  }
}

class HintArrowPainter extends CustomPainter {
  final Move hintMove;
  final Vehicle? vehicle;
  final double cellSize;
  final double pulseValue;

  const HintArrowPainter({
    required this.hintMove,
    required this.vehicle,
    required this.cellSize,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final v = vehicle;
    if (v == null) return;

    final startCenter = Offset(
      (hintMove.fromCol + (v.isHorizontal ? v.length / 2.0 : 0.5)) * cellSize,
      (hintMove.fromRow + (v.isHorizontal ? 0.5 : v.length / 2.0)) * cellSize,
    );
    final endCenter = Offset(
      (hintMove.toCol + (v.isHorizontal ? v.length / 2.0 : 0.5)) * cellSize,
      (hintMove.toRow + (v.isHorizontal ? 0.5 : v.length / 2.0)) * cellSize,
    );

    final paint = Paint()
      ..color = Colors.amberAccent.withValues(alpha: 0.75 + 0.25 * pulseValue)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(startCenter, endCenter, paint);

    final angle = math.atan2(
      endCenter.dy - startCenter.dy,
      endCenter.dx - startCenter.dx,
    );
    const arrowSize = 14.0;
    final path = Path()
      ..moveTo(endCenter.dx, endCenter.dy)
      ..lineTo(
        endCenter.dx - arrowSize * math.cos(angle - math.pi / 6),
        endCenter.dy - arrowSize * math.sin(angle - math.pi / 6),
      )
      ..lineTo(
        endCenter.dx - arrowSize * math.cos(angle + math.pi / 6),
        endCenter.dy - arrowSize * math.sin(angle + math.pi / 6),
      )
      ..close();

    final headPaint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, headPaint);
  }

  @override
  bool shouldRepaint(covariant HintArrowPainter oldDelegate) {
    return oldDelegate.hintMove != hintMove ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.cellSize != cellSize;
  }
}
