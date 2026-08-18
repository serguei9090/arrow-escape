import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../data/models/arrow.dart';
import '../../data/models/level.dart';

class InteractiveLevelCanvas extends StatelessWidget {
  final LevelModel level;
  final String? selectedArrowId;
  final String? selectedCell; // 'r,c'
  final List<String>? solverStepHighlight; // list of arrow IDs cleared in order
  final Set<String>? clearedArrowIds; // set of arrow IDs cleared during interactive playtest
  final int currentSolverStep;
  final Function(int row, int col)? onCellTap;
  final Function(ArrowModel arrow)? onArrowTap;

  const InteractiveLevelCanvas({
    super.key,
    required this.level,
    this.selectedArrowId,
    this.selectedCell,
    this.solverStepHighlight,
    this.clearedArrowIds,
    this.currentSolverStep = -1,
    this.onCellTap,
    this.onArrowTap,
  });

  Color _getColorGroupColor(int? colorGroup) {
    if (colorGroup == null) return AppColors.arrowUp;
    return AppColors.getGroupColor(colorGroup);
  }

  IconData _getDirectionIcon(ArrowDirection dir) {
    switch (dir) {
      case ArrowDirection.up:
        return Icons.arrow_upward_rounded;
      case ArrowDirection.down:
        return Icons.arrow_downward_rounded;
      case ArrowDirection.left:
        return Icons.arrow_back_rounded;
      case ArrowDirection.right:
        return Icons.arrow_forward_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = level.gridSize;

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellSize = constraints.maxWidth / size;

            return Stack(
              children: [
                // Grid Cells
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: size * size,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: size,
                  ),
                  itemBuilder: (context, index) {
                    final r = index ~/ size;
                    final c = index % size;
                    final cellKey = '$r,$c';
                    final isMaskActive = level.mask.contains(cellKey);
                    final isCellSelected = selectedCell == cellKey;

                    return GestureDetector(
                      onTap: () => onCellTap?.call(r, c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: isMaskActive
                              ? (isCellSelected
                                  ? Colors.amber.withValues(alpha: 0.35)
                                  : const Color(0xFF2A2E3D))
                              : Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCellSelected
                                ? Colors.amber
                                : (isMaskActive
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.03)),
                            width: isCellSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$r,$c',
                            style: TextStyle(
                              color: isMaskActive
                                  ? Colors.white24
                                  : Colors.white10,
                              fontSize: max(8.0, cellSize * 0.22),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Snake Path Overlay Lines
                CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _SnakePathPainter(
                    level: level,
                    cellSize: cellSize,
                    colorMapper: _getColorGroupColor,
                    clearedArrowIds: clearedArrowIds,
                  ),
                ),

                // Arrows Overlay
                ...level.arrows.map((arrow) {
                  final isSelected = selectedArrowId == arrow.id;
                  final color = _getColorGroupColor(arrow.colorGroup);

                  // Check if cleared via playtest or solver
                  bool isCleared = clearedArrowIds?.contains(arrow.id) ?? false;
                  bool isNextToClear = false;
                  if (solverStepHighlight != null && currentSolverStep >= 0) {
                    final orderIndex = solverStepHighlight!.indexOf(arrow.id);
                    if (orderIndex != -1) {
                      if (orderIndex < currentSolverStep) {
                        isCleared = true;
                      } else if (orderIndex == currentSolverStep) {
                        isNextToClear = true;
                      }
                    }
                  }

                  return Positioned(
                    left: arrow.col * cellSize,
                    top: arrow.row * cellSize,
                    width: cellSize,
                    height: cellSize,
                    child: GestureDetector(
                      onTap: () => onArrowTap?.call(arrow),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isCleared ? 0.0 : 1.0,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: isNextToClear
                                ? Colors.greenAccent.withValues(alpha: 0.9)
                                : color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.amber
                                  : (isNextToClear
                                      ? Colors.white
                                      : Colors.white30),
                              width: isSelected ? 3 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: isSelected ? 2 : 0,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                _getDirectionIcon(arrow.direction),
                                color: isNextToClear
                                    ? Colors.black
                                    : (arrow.colorGroup == null ? Colors.white : Colors.black87),
                                size: cellSize * 0.55,
                              ),

                              // Mechanic Badge
                              if (arrow.mechanic != SnakeMechanic.standard)
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.sync_alt_rounded,
                                      color: Colors.amberAccent,
                                      size: cellSize * 0.25,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// High-performance 2D Canvas painter for gallery card thumbnails (60+ FPS scrolling)
class LevelThumbnailCanvas extends StatelessWidget {
  final LevelModel level;

  const LevelThumbnailCanvas({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF181B24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(
              painter: _ThumbnailPainter(level: level),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  final LevelModel level;

  _ThumbnailPainter({required this.level});

  Color _getColorGroupColor(int? colorGroup) {
    if (colorGroup == null) return const Color(0xFF0284C7);
    return AppColors.getGroupColor(colorGroup);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gs = level.gridSize;
    final cellW = size.width / gs;
    final cellH = size.height / gs;

    final cellPaintActive = Paint()..color = const Color(0xFF2A2E3D);
    final cellPaintBg = Paint()..color = Colors.black.withValues(alpha: 0.3);
    final cellBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final emptyDotPaint = Paint()..color = Colors.white.withValues(alpha: 0.22);

    // A mask cell not covered by any arrow's path is a leftover gap
    // (orphan dot or, rarely, a truly uncovered cell) - the real game
    // renders these as a visible faint dot rather than solid fill, so the
    // thumbnail must match that or it misrepresents how "complete" the
    // level actually looks compared to the real in-game/editor rendering.
    final occupiedCells = <String>{};
    for (final arrow in level.arrows) {
      for (final pt in arrow.path) {
        occupiedCells.add('${pt[0]},${pt[1]}');
      }
    }

    // 1. Draw Grid Cells
    for (int r = 0; r < gs; r++) {
      for (int c = 0; c < gs; c++) {
        final key = '$r,$c';
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(c * cellW + 0.5, r * cellH + 0.5, cellW - 1, cellH - 1),
          const Radius.circular(2),
        );
        final isActive = level.mask.contains(key);
        canvas.drawRRect(rect, isActive ? cellPaintActive : cellPaintBg);
        canvas.drawRRect(rect, cellBorder);

        if (isActive && !occupiedCells.contains(key)) {
          canvas.drawCircle(
            Offset((c + 0.5) * cellW, (r + 0.5) * cellH),
            max(1.0, min(cellW, cellH) * 0.08),
            emptyDotPaint,
          );
        }
      }
    }

    // 2. Draw Snake Paths
    for (final arrow in level.arrows) {
      if (arrow.path.length <= 1) continue;
      final pathColor = _getColorGroupColor(arrow.colorGroup).withValues(alpha: 0.7);
      final linePaint = Paint()
        ..color = pathColor
        ..strokeWidth = max(1.5, cellW * 0.15)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      for (int i = 0; i < arrow.path.length; i++) {
        final x = (arrow.path[i][1] + 0.5) * cellW;
        final y = (arrow.path[i][0] + 0.5) * cellH;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, linePaint);
    }

    // 3. Draw Arrow Heads
    for (final arrow in level.arrows) {
      final color = _getColorGroupColor(arrow.colorGroup);
      final cx = (arrow.col + 0.5) * cellW;
      final cy = (arrow.row + 0.5) * cellH;
      final radius = max(3.0, min(cellW, cellH) * 0.35);

      final circlePaint = Paint()..color = color;
      final borderPaint = Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawCircle(Offset(cx, cy), radius, circlePaint);
      canvas.drawCircle(Offset(cx, cy), radius, borderPaint);

      // Draw simple direction arrow line
      final delta = arrow.direction.delta;
      final arrowLine = Paint()
        ..color = Colors.white
        ..strokeWidth = max(1.2, radius * 0.3)
        ..strokeCap = StrokeCap.round;

      final startPoint = Offset(cx - delta[1] * radius * 0.4, cy - delta[0] * radius * 0.4);
      final endPoint = Offset(cx + delta[1] * radius * 0.5, cy + delta[0] * radius * 0.5);
      canvas.drawLine(startPoint, endPoint, arrowLine);
    }
  }

  @override
  bool shouldRepaint(covariant _ThumbnailPainter oldDelegate) => false;
}

class _SnakePathPainter extends CustomPainter {
  final LevelModel level;
  final double cellSize;
  final Color Function(int? group) colorMapper;
  final Set<String>? clearedArrowIds;

  _SnakePathPainter({
    required this.level,
    required this.cellSize,
    required this.colorMapper,
    this.clearedArrowIds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final arrow in level.arrows) {
      if (clearedArrowIds?.contains(arrow.id) ?? false) continue;
      if (arrow.path.length <= 1) continue;

      final color = colorMapper(arrow.colorGroup);
      final paint = Paint()
        ..color = color.withValues(alpha: 0.8)
        ..strokeWidth = max(2.5, cellSize * 0.12)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      for (int i = 0; i < arrow.path.length; i++) {
        final r = arrow.path[i][0];
        final c = arrow.path[i][1];
        final x = (c + 0.5) * cellSize;
        final y = (r + 0.5) * cellSize;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnakePathPainter oldDelegate) => true;
}
