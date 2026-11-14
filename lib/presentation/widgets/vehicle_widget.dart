import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/audio_service.dart';
import '../../domain/engine/board_engine.dart';
import '../../domain/entities/board_state.dart';
import '../../domain/entities/vehicle.dart';

class VehicleWidget extends StatefulWidget {
  final Vehicle vehicle;
  final BoardState boardState;
  final double cellSize;
  final bool isHinted;
  final bool isWon;
  final AudioService? audioService;
  final Future<void> Function(
    String vehicleId, {
    required double draggedRow,
    required double draggedCol,
  })? onMoveCommitted;

  const VehicleWidget({
    super.key,
    required this.vehicle,
    required this.boardState,
    required this.cellSize,
    this.isHinted = false,
    this.isWon = false,
    this.audioService,
    this.onMoveCommitted,
  });

  /// Maps vehicle ID and length deterministically to a sprite asset path.
  static String getSpritePathForVehicle(Vehicle vehicle) {
    if (vehicle.isTarget) {
      return AppConstants.targetCarSprite;
    }
    final code = vehicle.id.codeUnitAt(0);
    if (vehicle.length == 3) {
      return AppConstants
          .truck3Sprites[code % AppConstants.truck3Sprites.length];
    }
    return AppConstants.car2Sprites[code % AppConstants.car2Sprites.length];
  }

  static Color getFallbackColor(Vehicle vehicle) {
    if (vehicle.isTarget) return const Color(0xFFE53935);
    const palette = [
      Color(0xFF1E88E5),
      Color(0xFFFDD835),
      Color(0xFF43A047),
      Color(0xFFFB8C00),
      Color(0xFF8E24AA),
      Color(0xFF00ACC1),
      Color(0xFF546E7A),
    ];
    return palette[vehicle.id.codeUnitAt(0) % palette.length];
  }

  @override
  State<VehicleWidget> createState() => _VehicleWidgetState();
}

class _VehicleWidgetState extends State<VehicleWidget>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _dragOffsetPx = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isDragging = ValueNotifier<bool>(false);

  late final AnimationController _snapController;
  Animation<double>? _snapAnimation;

  double _minOffsetPx = 0.0;
  double _maxOffsetPx = 0.0;
  bool _hitMinBoundary = false;
  bool _hitMaxBoundary = false;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(() {
        final anim = _snapAnimation;
        if (anim != null) {
          _dragOffsetPx.value = anim.value;
        }
      });
  }

  @override
  void didUpdateWidget(covariant VehicleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When BoardState updates the vehicle's grid cell (after snap commit, Undo, or Reset),
    // immediately zero out the local pixel translation so the widget stays at the exact pixel.
    if (widget.vehicle.row != oldWidget.vehicle.row ||
        widget.vehicle.col != oldWidget.vehicle.col) {
      _snapController.stop();
      _snapAnimation = null;
      _dragOffsetPx.value = 0.0;
      _isDragging.value = false;
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    _dragOffsetPx.dispose();
    _isDragging.dispose();
    super.dispose();
  }

  void _triggerCollisionFeedback() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    widget.audioService?.playSfx(AppConstants.sfxHornCollide);
  }

  void _onPanStart(DragStartDetails details) {
    if (widget.isWon) return;
    _snapController.stop();
    _snapAnimation = null;

    final bounds = BoardEngine.getMovementBounds(
      widget.boardState,
      widget.vehicle.id,
    );

    if (widget.vehicle.isHorizontal) {
      _minOffsetPx = (bounds.minCol - widget.vehicle.col) * widget.cellSize;
      _maxOffsetPx = (bounds.maxCol - widget.vehicle.col) * widget.cellSize;
    } else {
      _minOffsetPx = (bounds.minRow - widget.vehicle.row) * widget.cellSize;
      _maxOffsetPx = (bounds.maxRow - widget.vehicle.row) * widget.cellSize;
    }

    _hitMinBoundary = false;
    _hitMaxBoundary = false;
    _isDragging.value = true;
    widget.audioService?.playCarSelect();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (widget.isWon || !_isDragging.value) return;

    final delta =
        widget.vehicle.isHorizontal ? details.delta.dx : details.delta.dy;
    final rawPx = _dragOffsetPx.value + delta;
    final clampedPx = rawPx.clamp(_minOffsetPx, _maxOffsetPx);

    // Trigger HapticFeedback.lightImpact() + horn_collide.mp3 on first boundary/obstacle touch
    if (delta < 0 && rawPx <= _minOffsetPx) {
      if (!_hitMinBoundary) {
        _hitMinBoundary = true;
        _triggerCollisionFeedback();
      }
    } else if (clampedPx > _minOffsetPx + 2.0) {
      _hitMinBoundary = false;
    }

    if (delta > 0 && rawPx >= _maxOffsetPx) {
      if (!_hitMaxBoundary) {
        _hitMaxBoundary = true;
        _triggerCollisionFeedback();
      }
    } else if (clampedPx < _maxOffsetPx - 2.0) {
      _hitMaxBoundary = false;
    }

    _dragOffsetPx.value = clampedPx;
  }

  Future<void> _onPanEnd(DragEndDetails details) async {
    if (!_isDragging.value) return;
    _isDragging.value = false;

    await _snapToNearestCellAndCommit();
  }

  Future<void> _onPanCancel() async {
    if (!_isDragging.value) return;
    _isDragging.value = false;

    await _snapToNearestCellAndCommit();
  }

  Future<void> _snapToNearestCellAndCommit() async {
    final cellSize = widget.cellSize;
    final vehicle = widget.vehicle;

    final startCell = vehicle.isHorizontal ? vehicle.col : vehicle.row;
    final currentPx = startCell * cellSize + _dragOffsetPx.value;
    final snappedCell = (currentPx / cellSize).round();
    final targetOffsetPx =
        ((snappedCell - startCell) * cellSize).clamp(_minOffsetPx, _maxOffsetPx);
    final finalCell = startCell + (targetOffsetPx / cellSize).round();

    final startOffsetPx = _dragOffsetPx.value;
    if ((targetOffsetPx - startOffsetPx).abs() > 0.5) {
      _snapAnimation = Tween<double>(
        begin: startOffsetPx,
        end: targetOffsetPx,
      ).animate(
        CurvedAnimation(
          parent: _snapController,
          curve: Curves.easeOutCubic,
        ),
      );
      await _snapController.forward(from: 0.0);
    } else {
      _dragOffsetPx.value = targetOffsetPx;
    }

    if (!mounted) return;

    // Only call BLoC after the 100ms snap animation completes and the grid cell changed
    if (finalCell != startCell) {
      final targetRow =
          vehicle.isHorizontal ? vehicle.row.toDouble() : finalCell.toDouble();
      final targetCol =
          vehicle.isHorizontal ? finalCell.toDouble() : vehicle.col.toDouble();

      await widget.onMoveCommitted?.call(
        vehicle.id,
        draggedRow: targetRow,
        draggedCol: targetCol,
      );
    } else {
      _dragOffsetPx.value = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final cellSize = widget.cellSize;
    final width = vehicle.isHorizontal ? cellSize * vehicle.length : cellSize;
    final height = vehicle.isHorizontal ? cellSize : cellSize * vehicle.length;
    final spritePath = VehicleWidget.getSpritePathForVehicle(vehicle);

    Widget spriteImage = Image.asset(
      spritePath,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: BoxDecoration(
            color: VehicleWidget.getFallbackColor(vehicle),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24, width: 2),
          ),
        );
      },
    );

    if (vehicle.isHorizontal) {
      spriteImage = RotatedBox(
        quarterTurns: 1,
        child: spriteImage,
      );
    }

    final staticCarContent = Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: spriteImage,
        ),
        // Accessibility directional overlay ('↔' or '↕')
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: vehicle.isTarget
                    ? Colors.redAccent.withValues(alpha: 0.8)
                    : Colors.white38,
                width: 1,
              ),
            ),
            child: Text(
              vehicle.isHorizontal ? '↔' : '↕',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
        ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      child: ValueListenableBuilder<double>(
        valueListenable: _dragOffsetPx,
        builder: (context, offsetPx, child) {
          return Transform.translate(
            offset: vehicle.isHorizontal
                ? Offset(offsetPx, 0.0)
                : Offset(0.0, offsetPx),
            child: child,
          );
        },
        child: SizedBox(
          width: width,
          height: height,
          child: Padding(
            padding: const EdgeInsets.all(3.0),
            child: ValueListenableBuilder<bool>(
              valueListenable: _isDragging,
              builder: (context, isSelected, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      if (widget.isHinted)
                        BoxShadow(
                          color: Colors.amberAccent.withValues(alpha: 0.85),
                          blurRadius: 14,
                          spreadRadius: 3,
                        )
                      else if (isSelected)
                        BoxShadow(
                          color: Colors.cyanAccent.withValues(alpha: 0.7),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      else
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                    ],
                    border: widget.isHinted
                        ? Border.all(color: Colors.amberAccent, width: 2.5)
                        : isSelected
                            ? Border.all(color: Colors.cyanAccent, width: 2.0)
                            : null,
                  ),
                  child: child,
                );
              },
              child: staticCarContent,
            ),
          ),
        ),
      ),
    );
  }
}
