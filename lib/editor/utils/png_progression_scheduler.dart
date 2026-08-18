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

    // Determine tier based on grid size and cell count
    final MaskComplexityTier tier;
    if (gridSize <= 20 || activeCount <= 180) {
      tier = MaskComplexityTier.tier1Simple;
    } else if (gridSize <= 28 || activeCount <= 450) {
      tier = MaskComplexityTier.tier2Medium;
    } else {
      tier = MaskComplexityTier.tier3Detailed;
    }

    // Hero shape detection by semantic name or high complexity
    final lowerName = name.toLowerCase();
    final isHeroByName = lowerName.contains('boss') ||
        lowerName.contains('god') ||
        lowerName.contains('dragon') ||
        lowerName.contains('sword') ||
        lowerName.contains('castle') ||
        lowerName.contains('monster') ||
        lowerName.contains('skull') ||
        lowerName.contains('titan') ||
        lowerName.contains('crown') ||
        lowerName.contains('shield') ||
        lowerName.contains('emblem') ||
        lowerName.contains('star');

    final isHeroShape = isHeroByName || complexityScore > 280;

    return MaskComplexityProfile(
      id: id,
      name: name,
      gridSize: gridSize,
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
  /// - Levels 4–15: Assigned Tier 1 / lower-complexity shapes matching small grids.
  /// - Levels 16+: Boss (pos 4) & God (pos 7) milestone slots prioritize Hero & high-complexity shapes.
  /// - Any level without an assigned custom mask is marked as `isProceduralFallback = true`.
  static List<LevelScheduleAssignment<T>> scheduleProgression<T>({
    required List<T> rawItems,
    required List<MaskComplexityProfile> profiles,
    required int totalLevels,
  }) {
    assert(rawItems.length == profiles.length);

    final assignments = <LevelScheduleAssignment<T>>[];
    final pool = List<int>.generate(profiles.length, (i) => i);

    // Helper to score how well a candidate profile fits a target level
    double scoreCandidate(
        int idx, int levelNumber, LevelType type, int targetGrid) {
      final p = profiles[idx];
      final gridDiff = (p.gridSize - targetGrid).abs();
      double score = 1000.0 - (gridDiff * 40.0);

      // Onboarding gate (levels 4–15): reward Tier 1, penalize oversized/overcomplex
      if (levelNumber <= 15) {
        if (p.tier == MaskComplexityTier.tier1Simple) {
          score += 200.0;
        } else if (p.tier == MaskComplexityTier.tier3Detailed) {
          score -= 500.0;
        }
        // Penalize extreme complexity in early levels
        score -= p.complexityScore * 0.5;
      } else {
        // Levels 16+:
        if (type == LevelType.boss || type == LevelType.god) {
          if (p.isHeroShape) score += 300.0;
          if (p.tier == MaskComplexityTier.tier3Detailed) score += 150.0;
          score += p.complexityScore * 0.3;
        } else {
          // Normal levels in mid/late game
          if (p.tier == MaskComplexityTier.tier2Medium) score += 100.0;
          if (p.isHeroShape)
            score -= 80.0; // Save hero shapes for boss/god slots
        }
      }

      return score;
    }

    // Process levels sequentially
    for (int levelNum = 1; levelNum <= totalLevels; levelNum++) {
      final type = AppConstants.levelTypeFor(levelNum);
      final targetGridSize = AppConstants.gridSizeForLevel(levelNum);

      // Tutorials 1-3 are immutable
      if (levelNum <= AppConstants.tutorialLevels) {
        assignments.add(LevelScheduleAssignment<T>(
          levelNumber: levelNum,
          levelType: type,
          targetGridSize: targetGridSize,
          isProceduralFallback: true,
        ));
        continue;
      }

      if (pool.isEmpty) {
        // Pool exhausted: use procedural fallback
        assignments.add(LevelScheduleAssignment<T>(
          levelNumber: levelNum,
          levelType: type,
          targetGridSize: targetGridSize,
          isProceduralFallback: true,
        ));
        continue;
      }

      // Find the best fitting candidate from the available pool
      int bestPoolIndex = -1;
      double highestScore = -99999.0;

      for (int i = 0; i < pool.length; i++) {
        final profileIdx = pool[i];
        final score =
            scoreCandidate(profileIdx, levelNum, type, targetGridSize);
        if (score > highestScore) {
          highestScore = score;
          bestPoolIndex = i;
        }
      }

      // If the best candidate is an acceptable fit, assign it
      if (bestPoolIndex != -1) {
        final chosenIdx = pool.removeAt(bestPoolIndex);
        assignments.add(LevelScheduleAssignment<T>(
          levelNumber: levelNum,
          levelType: type,
          targetGridSize: targetGridSize,
          customMaskItem: rawItems[chosenIdx],
          profile: profiles[chosenIdx],
          isProceduralFallback: false,
        ));
      } else {
        assignments.add(LevelScheduleAssignment<T>(
          levelNumber: levelNum,
          levelType: type,
          targetGridSize: targetGridSize,
          isProceduralFallback: true,
        ));
      }
    }

    return assignments;
  }
}
