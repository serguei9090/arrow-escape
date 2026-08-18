import 'dart:math';
import '../../core/constants.dart';
import '../models/png_mask_model.dart';

/// Represents the analyzed complexity tier of a custom mask shape.
enum MaskComplexityTier {
  /// Simple, low-cell-count silhouettes suitable for early onboarding (Levels 4–15).
  tier1Simple,

  /// Medium complexity silhouettes suitable for mid-game (Levels 16–50) and early Bosses.
  tier2Medium,

  /// High-detail, dense silhouettes suitable for late-game (Levels 51+) and God milestones.
  tier3Detailed,
}

/// Metadata and complexity profile of a parsed mask shape.
class MaskComplexityProfile {
  final String id;
  final String name;
  final int gridSize;
  final Set<String> mask;
  final int activeCellCount;
  final double density;
  final double complexityScore;
  final MaskComplexityTier tier;
  final bool isHeroShape;

  MaskComplexityProfile({
    required this.id,
    required this.name,
    required this.gridSize,
    required this.mask,
    required this.activeCellCount,
    required this.density,
    required this.complexityScore,
    required this.tier,
    required this.isHeroShape,
  });

  /// Factory that analyzes a grid mask and builds its complexity profile.
  factory MaskComplexityProfile.analyze({
    required String id,
    required String name,
    required int gridSize,
    required Set<String> mask,
  }) {
    final activeCount = mask.length;
    final totalCells = max(1, gridSize * gridSize);
    final density = activeCount / totalCells;

    // Calculate bounding box dimensions of active cells
    int minR = 999, maxR = -1, minC = 999, maxC = -1;
    for (final key in mask) {
      final parts = key.split(',');
      if (parts.length < 2) continue;
      final r = int.tryParse(parts[0]) ?? 0;
      final c = int.tryParse(parts[1]) ?? 0;
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
      if (c < minC) minC = c;
      if (c > maxC) maxC = c;
    }
    final bboxW = maxC >= minC ? (maxC - minC + 1) : 0;
    final bboxH = maxR >= minR ? (maxR - minR + 1) : 0;
    final effectiveDimension = max(gridSize, max(bboxW, bboxH));

    // Calculate perimeter transitions (number of exposed outer & inner edges)
    int perimeterEdges = 0;
    for (final key in mask) {
      final parts = key.split(',');
      if (parts.length < 2) continue;
      final r = int.tryParse(parts[0]) ?? 0;
      final c = int.tryParse(parts[1]) ?? 0;

      for (final offset in const [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1]
      ]) {
        final nr = r + offset[0];
        final nc = c + offset[1];
        if (nr < 0 ||
            nr >= gridSize ||
            nc < 0 ||
            nc >= gridSize ||
            !mask.contains('$nr,$nc')) {
          perimeterEdges++;
        }
      }
    }

    // Complexity score balances active cell count and silhouette jaggedness
    final jaggednessRatio =
        activeCount > 0 ? (perimeterEdges / activeCount) : 1.0;
    final complexityScore =
        (activeCount * 0.7) + (perimeterEdges * 0.3) * jaggednessRatio;

    // Hero / Milestone shape detection by name or silhouette characteristics
    final lowerName = name.toLowerCase();
    final isHeroByName = lowerName.contains('boss') ||
        lowerName.contains('god') ||
        lowerName.contains('dog') ||
        lowerName.contains('cat') ||
        lowerName.contains('frog') ||
        lowerName.contains('fox') ||
        lowerName.contains('tiger') ||
        lowerName.contains('panda') ||
        lowerName.contains('bear') ||
        lowerName.contains('dragon') ||
        lowerName.contains('sword') ||
        lowerName.contains('castle') ||
        lowerName.contains('monster') ||
        lowerName.contains('skull') ||
        lowerName.contains('titan') ||
        lowerName.contains('crown') ||
        lowerName.contains('shield') ||
        lowerName.contains('emblem') ||
        lowerName.contains('star') ||
        lowerName.contains('ship') ||
        lowerName.contains('rocket') ||
        lowerName.contains('hedgehog') ||
        lowerName.contains('animal') ||
        lowerName.contains('bird') ||
        lowerName.contains('fish') ||
        lowerName.contains('butterfly');

    // Any pictorial silhouette or large shape is treated as a milestone hero shape
    final isHeroShape = isHeroByName ||
        effectiveDimension >= 22 ||
        (complexityScore > 180 && !lowerName.startsWith('rect_'));

    // Determine tier:
    // Only small, non-hero shapes qualify for early onboarding Tier 1
    final MaskComplexityTier tier;
    if (effectiveDimension <= 18 && !isHeroShape) {
      tier = MaskComplexityTier.tier1Simple;
    } else if (effectiveDimension <= 26 && !isHeroShape) {
      tier = MaskComplexityTier.tier2Medium;
    } else {
      tier = MaskComplexityTier.tier3Detailed;
    }

    return MaskComplexityProfile(
      id: id,
      name: name,
      gridSize: effectiveDimension,
      mask: mask,
      activeCellCount: activeCount,
      density: density,
      complexityScore: complexityScore,
      tier: tier,
      isHeroShape: isHeroShape,
    );
  }
}

/// Result of progression scheduling for a level pack.
class LevelScheduleAssignment<T> {
  final int levelNumber;
  final LevelType levelType;
  final int targetGridSize;
  final T? customMaskItem;
  final MaskComplexityProfile? profile;
  final bool isProceduralFallback;

  LevelScheduleAssignment({
    required this.levelNumber,
    required this.levelType,
    required this.targetGridSize,
    this.customMaskItem,
    this.profile,
    required this.isProceduralFallback,
  });

  bool get hasCustomMask => customMaskItem != null;
}

/// Schedulers and helpers for progression-based custom PNG level distribution.
class PngProgressionScheduler {
  PngProgressionScheduler._();

  /// Profile a list of [PngMaskModel] instances.
  static List<MaskComplexityProfile> profilePngMaskModels(
      List<PngMaskModel> models) {
    return models.map((m) {
      return MaskComplexityProfile.analyze(
        id: m.id,
        name: m.filename,
        gridSize: m.gridSize,
        mask: m.mask,
      );
    }).toList();
  }

  /// Builds a progression-ordered assignment map for a level pack ($1 \dots \text{totalLevels}$).
  ///
  /// Rules:
  /// - Levels 1–3: Mandatory tutorials (always procedural fallback).
  /// - Boss (pos 4) & God (pos 7) milestone slots prioritize Hero & pictorial silhouettes first.
  /// - Levels 4–15 (Onboarding): Strictly accept only small, simple shapes (Tier 1).
  /// - Levels 16+: Accept remaining medium/detailed shapes as grid dimensions grow.
  /// - Any level without an assigned custom mask is marked as `isProceduralFallback = true`.
  static List<LevelScheduleAssignment<T>> scheduleProgression<T>({
    required List<T> rawItems,
    required List<MaskComplexityProfile> profiles,
    required int totalLevels,
  }) {
    assert(rawItems.length == profiles.length);

    final assignments =
        List<LevelScheduleAssignment<T>?>.filled(totalLevels, null);
    final availablePool = List<int>.generate(profiles.length, (i) => i);

    // ── PASS 1: Priority Milestone Allocation (Boss & God slots) ───────────────
    // Assign Hero and pictorial silhouettes to Boss and God levels first
    for (int levelNum = AppConstants.tutorialLevels + 1;
        levelNum <= totalLevels;
        levelNum++) {
      if (availablePool.isEmpty) break;

      final type = AppConstants.levelTypeFor(levelNum);
      if (type != LevelType.boss && type != LevelType.god) continue;

      final targetGridSize = AppConstants.gridSizeForLevel(levelNum);

      int bestCandidateIdx = -1;
      double highestScore = -99999.0;

      for (int i = 0; i < availablePool.length; i++) {
        final pIdx = availablePool[i];
        final p = profiles[pIdx];

        final gridDiff = (p.gridSize - targetGridSize).abs();

        double score = 1000.0 - (gridDiff * 25.0);
        if (p.isHeroShape) score += 400.0;
        if (p.tier == MaskComplexityTier.tier3Detailed) score += 200.0;
        if (p.tier == MaskComplexityTier.tier2Medium) score += 100.0;
        score += p.complexityScore * 0.4;

        if (score > highestScore) {
          highestScore = score;
          bestCandidateIdx = i;
        }
      }

      if (bestCandidateIdx != -1) {
        final chosenProfileIdx = availablePool.removeAt(bestCandidateIdx);
        assignments[levelNum - 1] = LevelScheduleAssignment<T>(
          levelNumber: levelNum,
          levelType: type,
          targetGridSize: targetGridSize,
          customMaskItem: rawItems[chosenProfileIdx],
          profile: profiles[chosenProfileIdx],
          isProceduralFallback: false,
        );
      }
    }

    // ── PASS 2: Normal Levels Allocation ───────────────────────────────────────
    // Assign remaining shapes strictly to compatible normal levels
    for (int levelNum = AppConstants.tutorialLevels + 1;
        levelNum <= totalLevels;
        levelNum++) {
      // Skip if already assigned in Pass 1
      if (assignments[levelNum - 1] != null) continue;
      if (availablePool.isEmpty) break;

      final type = AppConstants.levelTypeFor(levelNum);
      final targetGridSize = AppConstants.gridSizeForLevel(levelNum);

      int bestCandidateIdx = -1;
      double highestScore = -99999.0;

      for (int i = 0; i < availablePool.length; i++) {
        final pIdx = availablePool[i];
        final p = profiles[pIdx];

        final gridDiff = (p.gridSize - targetGridSize).abs();

        // STRICT ONBOARDING GATE (Levels 4–15):
        // Never put oversized (grid > 20) or high-detail Tier 3 shapes in early onboarding
        if (levelNum <= 15) {
          if (p.gridSize > 21 || p.tier == MaskComplexityTier.tier3Detailed) {
            continue; // Strictly reject large shapes for early levels
          }
          if (gridDiff > 4) continue;
        } else {
          // Levels 16+: allow closer grid match
          if (gridDiff > 4) continue;
        }

        double score = 1000.0 - (gridDiff * 45.0);
        if (levelNum <= 15 && p.tier == MaskComplexityTier.tier1Simple) {
          score += 200.0;
        }
        if (levelNum > 15 && p.tier == MaskComplexityTier.tier2Medium) {
          score += 150.0;
        }

        if (score > highestScore) {
          highestScore = score;
          bestCandidateIdx = i;
        }
      }

      if (bestCandidateIdx != -1) {
        final chosenProfileIdx = availablePool.removeAt(bestCandidateIdx);
        assignments[levelNum - 1] = LevelScheduleAssignment<T>(
          levelNumber: levelNum,
          levelType: type,
          targetGridSize: targetGridSize,
          customMaskItem: rawItems[chosenProfileIdx],
          profile: profiles[chosenProfileIdx],
          isProceduralFallback: false,
        );
      }
    }

    // ── PASS 3: Fill Remaining Slots with Procedural Fallbacks ─────────────────
    final result = <LevelScheduleAssignment<T>>[];
    for (int levelNum = 1; levelNum <= totalLevels; levelNum++) {
      final existing = assignments[levelNum - 1];
      if (existing != null) {
        result.add(existing);
      } else {
        result.add(LevelScheduleAssignment<T>(
          levelNumber: levelNum,
          levelType: AppConstants.levelTypeFor(levelNum),
          targetGridSize: AppConstants.gridSizeForLevel(levelNum),
          isProceduralFallback: true,
        ));
      }
    }

    return result;
  }
}
