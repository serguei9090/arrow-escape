import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/app_colors.dart';
import '../../data/models/level.dart';
import '../../data/models/arrow.dart';
import '../game_state.dart';
import 'arrow_component.dart';

/// Renders the puzzle grid, mask boundary dots, and all arrow components.
///
/// IMPORTANT: the mask used for RENDERING must match the mask used when the
/// level was generated.  We regenerate it from the stored [MaskShape] so we
/// never drift between generator and renderer.
class GridComponent extends PositionComponent {
  final GameState gameState;
  double gridPixelSize;

  final Map<String, ArrowComponent> _arrowComponents = {};
  late Set<String> _mask;
  late LevelType _levelType;

  ui.Picture? _cachedDotGridPicture;
  bool _isDarkCached = AppColors.isDark;

  // ── Level-clear dot-sweep animation ─────────────────────────────────────
  // Pulses every silhouette dot with a color highlight, staggered outward
  // from the grid's center to its border, when the level completes.
  static const double _clearSweepDuration = 0.7; // center -> farthest dot
  static const double _clearPulseDuration = 0.35; // each dot's own pulse
  static const double _clearTotalDuration =
      _clearSweepDuration + _clearPulseDuration;

  bool _clearAnimStarted = false;
  double _clearAnimTime = 0;
  List<_ClearDot>? _clearDots;

  void _invalidateDotGrid() {
    _cachedDotGridPicture?.dispose();
    _cachedDotGridPicture = null;
  }

  @override
  void onRemove() {
    _invalidateDotGrid();
    super.onRemove();
  }

  GridComponent({
    required this.gameState,
    required this.gridPixelSize,
    required Vector2 position,
  }) : super(position: position);

  double get cellSize => gridPixelSize / gameState.level.gridSize;

  @override
  Future<void> onLoad() async {
    size = Vector2.all(gridPixelSize);
    _levelType = AppConstants.levelTypeFor(gameState.level.levelNumber);
    _refreshMask();
    _buildArrows();
  }

  // ── Mask ──────────────────────────────────────────────────────────────────

  /// Rebuilds the mask from the stored MaskShape on the level model.
  /// Uses a deterministic seed derived from level + shape so the shape
  /// is always the same instance for this level (blob needs a seed).
  void _refreshMask() {
    _mask = gameState.level.mask;
  }

  // ── Arrow components ──────────────────────────────────────────────────────

  void _buildArrows() {
    removeAll(children.whereType<ArrowComponent>());
    _arrowComponents.clear();

    for (final arrow in gameState.arrows) {
      final comp = ArrowComponent(
        arrowModel: arrow,
        cellSize: cellSize,
        gameState: gameState,
        levelType: _levelType,
      )..position = Vector2(0, 0);
      _arrowComponents[arrow.id] = comp;
      add(comp);
    }
  }

  void rebuild() {
    _refreshMask();
    _buildArrows();
    _invalidateDotGrid();
    _clearAnimStarted = false;
    _clearAnimTime = 0;
    _clearDots = null;
  }

  void resize(double newGridPixelSize) {
    gridPixelSize = newGridPixelSize;
    size = Vector2.all(gridPixelSize);
    for (final child in children) {
      if (child is ArrowComponent) child.updateCellSize(cellSize);
    }
    _invalidateDotGrid();
  }

  void _recacheDotGrid() {
    _cachedDotGridPicture?.dispose();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final gridSize = gameState.level.gridSize;
    final cs = cellSize;
    final baseDot = (cs * 0.045).clamp(0.6, 1.6);
    final inR = baseDot;

    final inPaint = Paint()
      ..color = AppColors.isDark ? const Color(0x3CFFFFFF) : const Color(0xFFC8BFB0)
      ..style = PaintingStyle.fill;

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final inMask = _mask.contains('$r,$c');
        if (!inMask) continue; // Only render active grid dots inside the mask!

        canvas.drawCircle(
          Offset((c + 0.5) * cs, (r + 0.5) * cs),
          inR,
          inPaint,
        );
      }
    }

    _cachedDotGridPicture = recorder.endRecording();
  }

  void _startClearAnimation() {
    final gridSize = gameState.level.gridSize;
    final centerR = (gridSize - 1) / 2.0;
    final centerC = (gridSize - 1) / 2.0;
    final maxDist =
        sqrt(centerR * centerR + centerC * centerC).clamp(0.0001, double.infinity);

    final dots = <_ClearDot>[];
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (!_mask.contains('$r,$c')) continue;
        final dist = sqrt(pow(r - centerR, 2) + pow(c - centerC, 2));
        final delay = (dist / maxDist) * _clearSweepDuration;
        dots.add(_ClearDot(row: r, col: c, delay: delay));
      }
    }
    _clearDots = dots;
    _clearAnimStarted = true;
    _clearAnimTime = 0;
  }

  void _renderClearAnimation(Canvas canvas) {
    final cs = cellSize;
    final baseDot = (cs * 0.045).clamp(0.6, 1.6);
    final baseColor =
        AppColors.isDark ? const Color(0x3CFFFFFF) : const Color(0xFFC8BFB0);
    final highlightColor = AppColors.accentGreen;

    for (final dot in _clearDots!) {
      final local = _clearAnimTime - dot.delay;
      final center =
          Offset((dot.col + 0.5) * cs, (dot.row + 0.5) * cs);

      if (local <= 0) {
        // Wave hasn't reached this dot yet - render it at rest.
        canvas.drawCircle(
            center, baseDot, Paint()..color = baseColor);
        continue;
      }

      final t = (local / _clearPulseDuration).clamp(0.0, 1.0);
      // Pulse: 0 -> 1 -> 0 scale envelope (ease out on the way up, ease in
      // down), peaking at the pulse's midpoint.
      final pulseEnvelope = sin(t * pi).clamp(0.0, 1.0);
      final scale = 1.0 + pulseEnvelope * 1.8;
      final color = Color.lerp(baseColor, highlightColor, pulseEnvelope)!;

      canvas.drawCircle(center, baseDot * scale, Paint()..color = color);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RENDER
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void render(Canvas canvas) {
    final cs = cellSize;

    if (_clearAnimStarted) {
      // Level cleared - the sweep animation replaces the static dot grid
      // entirely. Orphan-dot redirect plates are irrelevant once the
      // level is solved, so they're intentionally skipped here.
      _renderClearAnimation(canvas);
    } else {
      if (_cachedDotGridPicture == null || _isDarkCached != AppColors.isDark) {
        _isDarkCached = AppColors.isDark;
        _recacheDotGrid();
      }
      canvas.drawPicture(_cachedDotGridPicture!);

      // ── Orphan deflector dots (drawn on top of background dots) ──────────
      final orphanDots = gameState.orphanDots;
      for (final entry in orphanDots.entries) {
        final parts = entry.key.split(',');
        final dotR = int.parse(parts[0]);
        final dotC = int.parse(parts[1]);
        _drawOrphanDot(canvas, Offset((dotC + 0.5) * cs, (dotR + 0.5) * cs),
            entry.value, cs);
      }
    }

    super.render(canvas);
  }

  static void _drawOrphanDot(
      Canvas canvas, Offset center, OrphanDotType type, double cs) {
    if (type == OrphanDotType.neutral) return; // Neutral empty dots can be left empty

    const Color baseColor = Color(0xFFFFAA00); // Gold/orange redirect plate

    // Solid dot body (plate) - enlarged to be highly visible
    canvas.drawCircle(
      center,
      cs * 0.36, // Much larger plate (72% of cell size!)
      Paint()
        ..color = baseColor
        ..style = PaintingStyle.fill,
    );

    // Darker outline for contrast
    canvas.drawCircle(
      center,
      cs * 0.36,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cs * 0.045,
    );

    // Drawing the arrow in the middle of the gold plate
    if (type != OrphanDotType.neutral) {
      final ArrowDirection dir;
      switch (type) {
        case OrphanDotType.up:
          dir = ArrowDirection.up;
          break;
        case OrphanDotType.down:
          dir = ArrowDirection.down;
          break;
        case OrphanDotType.left:
          dir = ArrowDirection.left;
          break;
        case OrphanDotType.right:
          dir = ArrowDirection.right;
          break;
        default:
          return;
      }

      final double angle = dir.rotationRadians; // Right is 0 rad

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      final linePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = cs * 0.075 // Thick lines
        ..strokeCap = StrokeCap.round;

      // Draw the arrow shaft in the middle
      canvas.drawLine(Offset(-cs * 0.22, 0), Offset(cs * 0.06, 0), linePaint);

      // Draw a large centered arrowhead pointing right
      final arrowheadPath = Path()
        ..moveTo(cs * 0.28, 0) // Tip of the arrow
        ..lineTo(cs * 0.04, -cs * 0.18) // Back corner top
        ..lineTo(cs * 0.10, 0) // Recess center point
        ..lineTo(cs * 0.04, cs * 0.18) // Back corner bottom
        ..close();

      canvas.drawPath(
        arrowheadPath,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );

      canvas.restore();
    } else {
      // Draw a small solid white dot in the center of neutral dots for a clean focal point
      canvas.drawCircle(
        center,
        cs * 0.075,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill,
      );
    }
  }



  @override
  void update(double dt) {
    super.update(dt);
    if (_arrowComponents.length != gameState.arrows.length) {
      final current = gameState.arrows.map((a) => a.id).toSet();
      final gone =
          _arrowComponents.keys.where((id) => !current.contains(id)).toList();
      for (final id in gone) {
        _arrowComponents[id]?.removeFromParent();
        _arrowComponents.remove(id);
      }
    }

    if (gameState.isComplete && !_clearAnimStarted) {
      _startClearAnimation();
    }
    if (_clearAnimStarted && _clearAnimTime < _clearTotalDuration) {
      _clearAnimTime += dt;
    }
  }

  void triggerArrowTap(String arrowId) {
    _arrowComponents[arrowId]?.triggerMove();
  }
}

/// A single silhouette dot's precomputed position in the level-clear sweep:
/// [delay] is how far into the sweep (seconds) this dot's own pulse starts,
/// derived from its distance from the grid's center.
class _ClearDot {
  final int row, col;
  final double delay;
  const _ClearDot({required this.row, required this.col, required this.delay});
}
