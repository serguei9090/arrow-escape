import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/models/arrow.dart';
import '../../data/models/level.dart';
import '../../data/level_generator/solver.dart';
import '../../data/level_generator/level_generator_v2.dart';
import '../components/flame_game_preview.dart';
import '../utils/web_file_helper.dart';

class SolveResult {
  final bool isSolvable;
  final List<String> solutionOrder;
  const SolveResult({required this.isSolvable, required this.solutionOrder});
}

class SingleLevelEditorDialog extends StatefulWidget {
  final LevelModel initialLevel;
  final Function(LevelModel updatedLevel) onSave;

  const SingleLevelEditorDialog({
    super.key,
    required this.initialLevel,
    required this.onSave,
  });

  @override
  State<SingleLevelEditorDialog> createState() =>
      _SingleLevelEditorDialogState();
}

class _SingleLevelEditorDialogState extends State<SingleLevelEditorDialog> {
  late int _gridSize;
  late Difficulty _difficulty;
  late MaskShape _maskShape;
  late String _patternName;
  late List<ArrowModel> _arrows;
  late Set<String> _mask;
  late List<OrphanDot> _orphanDots;

  final GlobalKey<FlameGamePreviewState> _flameGameKey =
      GlobalKey<FlameGamePreviewState>();

  // Solver Step-by-step state & Auto-Play Controller
  SolveResult? _solveResult;
  bool _isAutoSolving = false;
  int _currentSolveStepIndex = 0;
  Timer? _solveTimer;

  @override
  void initState() {
    super.initState();
    final lvl = widget.initialLevel;
    _gridSize = lvl.gridSize.clamp(5, 40);
    _difficulty = lvl.difficulty;
    _maskShape = lvl.maskShape;
    _patternName = lvl.patternName;
    _arrows = lvl.arrows.map((a) => a.copyWith()).toList();
    _mask = Set.from(lvl.mask);
    _orphanDots = lvl.orphanDots
        .map((od) => OrphanDot(row: od.row, col: od.col, type: od.type))
        .toList();
    _runSolverCheck();
  }

  @override
  void dispose() {
    _solveTimer?.cancel();
    super.dispose();
  }

  LevelModel _buildCurrentLevelModel() {
    return LevelModel(
      levelNumber: widget.initialLevel.levelNumber,
      gridSize: _gridSize,
      arrows: _arrows,
      patternName: _patternName,
      difficulty: _difficulty,
      solutionOrder: _solveResult?.solutionOrder ?? [],
      maskShape: _maskShape,
      mask: _mask,
      orphanDots: _orphanDots,
    );
  }

  void _runSolverCheck() {
    final curLevel = _buildCurrentLevelModel();
    final sol = LevelSolver.solve(curLevel);
    setState(() {
      _solveResult = SolveResult(
        isSolvable: sol != null,
        solutionOrder: sol ?? [],
      );
      _currentSolveStepIndex = 0;
      _isAutoSolving = false;
    });
  }

  // ── Auto Solver Controls (Play / Pause / Step / Reset) ──────────────────

  void _startAutoSolving() {
    if (_solveResult == null || !_solveResult!.isSolvable) return;
    _solveTimer?.cancel();

    setState(() {
      _isAutoSolving = true;
    });

    _solveTimer = Timer.periodic(const Duration(milliseconds: 650), (t) {
      if (_currentSolveStepIndex < _solveResult!.solutionOrder.length) {
        _triggerSingleSolverStep();
      } else {
        _pauseAutoSolving();
      }
    });
  }

  void _pauseAutoSolving() {
    _solveTimer?.cancel();
    setState(() {
      _isAutoSolving = false;
    });
  }

  void _triggerSingleSolverStep() {
    if (_solveResult == null || !_solveResult!.isSolvable) return;
    if (_currentSolveStepIndex >= _solveResult!.solutionOrder.length) return;

    final targetArrowId = _solveResult!.solutionOrder[_currentSolveStepIndex];

    // Trigger real Flame engine arrow slide & exit animation!
    _flameGameKey.currentState?.triggerArrowMove(targetArrowId);

    setState(() {
      _currentSolveStepIndex++;
    });
  }

  void _resetSolverBoard() {
    _solveTimer?.cancel();
    setState(() {
      _isAutoSolving = false;
      _currentSolveStepIndex = 0;
    });

    _flameGameKey.currentState?.resetGame();
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _importPngMask() async {
    try {
      final bytes = await WebFileHelper.pickFileBytes(accept: 'image/png');
      if (bytes == null) return;
      final parsedMask =
          await WebFileHelper.parsePngToGridMask(bytes, _gridSize);

      if (parsedMask.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No valid shape pixels detected in PNG.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      setState(() {
        _mask = parsedMask;
      });
      _regenerateArrowsForCurrentMask();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import PNG mask: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _regenerateArrowsForCurrentMask() {
    final genLevel =
        LevelGeneratorV2.generateLevel(widget.initialLevel.levelNumber);
    setState(() {
      _gridSize = genLevel.gridSize.clamp(5, 40);
      _mask = Set.from(genLevel.mask);
      _arrows = genLevel.arrows.map((a) => a.copyWith()).toList();
      _orphanDots = genLevel.orphanDots
          .map((od) => OrphanDot(row: od.row, col: od.col, type: od.type))
          .toList();
    });
    _runSolverCheck();
  }

  @override
  Widget build(BuildContext context) {
    final isSolvable = _solveResult?.isSolvable ?? false;
    final totalSteps = _solveResult?.solutionOrder.length ?? 0;

    return Dialog(
      backgroundColor: const Color(0xFF141720),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 1060,
        height: 760,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Modal Dialog Header
            Row(
              children: [
                Text(
                  'EDIT LEVEL #${widget.initialLevel.levelNumber}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),

                // Solvability Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isSolvable ? Colors.green : Colors.red)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isSolvable ? Colors.green : Colors.red),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSolvable
                            ? LucideIcons.checkCircle2
                            : LucideIcons.alertTriangle,
                        color:
                            isSolvable ? Colors.greenAccent : Colors.redAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSolvable ? 'SOLVABLE' : 'UNSOLVABLE',
                        style: TextStyle(
                          color: isSolvable
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, color: Colors.white70),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Toolbar Controls & Interactive Auto-Solver Controller
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C202C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Grid Size Selector (5..40 supported!)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Grid: ',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13)),
                      DropdownButton<int>(
                        value: _gridSize,
                        dropdownColor: const Color(0xFF1C202C),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        items: List.generate(
                          36, // 5 to 40
                          (i) => DropdownMenuItem(
                              value: i + 5, child: Text('${i + 5}x${i + 5}')),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _gridSize = val;
                              _mask = {
                                for (int r = 0; r < val; r++)
                                  for (int c = 0; c < val; c++) '$r,$c'
                              };
                            });
                            _runSolverCheck();
                          }
                        },
                      ),
                    ],
                  ),

                  // Difficulty Selector
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Diff: ',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13)),
                      DropdownButton<Difficulty>(
                        value: _difficulty,
                        dropdownColor: const Color(0xFF1C202C),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        items: Difficulty.values
                            .map((d) => DropdownMenuItem(
                                value: d, child: Text(d.name.toUpperCase())))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _difficulty = val);
                          }
                        },
                      ),
                    ],
                  ),

                  // Actions: Import PNG Mask & Regenerate
                  ElevatedButton.icon(
                    onPressed: _importPngMask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(LucideIcons.image, size: 16),
                    label: const Text('Import PNG Mask'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _regenerateArrowsForCurrentMask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: const Text('Regenerate Layout'),
                  ),

                  // ── Full Play / Pause / Step / Reset Auto-Solver Controls ──
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade900.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.purple.shade400),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Play / Pause Toggle Button
                        IconButton(
                          onPressed: isSolvable
                              ? (_isAutoSolving
                                  ? _pauseAutoSolving
                                  : _startAutoSolving)
                              : null,
                          icon: Icon(
                            _isAutoSolving
                                ? LucideIcons.pause
                                : LucideIcons.play,
                            color: isSolvable
                                ? Colors.purpleAccent
                                : Colors.white24,
                            size: 18,
                          ),
                          tooltip: _isAutoSolving
                              ? 'Pause Auto Solve'
                              : 'Play Auto Solve',
                        ),

                        // Step Forward Button
                        IconButton(
                          onPressed: isSolvable &&
                                  _currentSolveStepIndex < totalSteps
                              ? _triggerSingleSolverStep
                              : null,
                          icon: Icon(
                            LucideIcons.stepForward,
                            color: isSolvable &&
                                    _currentSolveStepIndex < totalSteps
                                ? Colors.white
                                : Colors.white24,
                            size: 18,
                          ),
                          tooltip: 'Step Next Arrow',
                        ),

                        // Reset Board Button
                        IconButton(
                          onPressed: isSolvable ? _resetSolverBoard : null,
                          icon: Icon(
                            LucideIcons.rotateCcw,
                            color: isSolvable
                                ? Colors.orangeAccent
                                : Colors.white24,
                            size: 18,
                          ),
                          tooltip: 'Reset Board Layout',
                        ),

                        const SizedBox(width: 6),

                        // Step Counter Indicator
                        Text(
                          'Step $_currentSolveStepIndex / $totalSteps',
                          style: const TextStyle(
                            color: Colors.purpleAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Main Editor Body
            Expanded(
              child: Row(
                children: [
                  // Left Interactive Panel: Authentic Flame Game Engine
                  Expanded(
                    flex: 6,
                    child: Center(
                      child: FlameGamePreview(
                        key: _flameGameKey,
                        level: _buildCurrentLevelModel(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Right Inspector Panel
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1E28),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'REAL FLAME ENGINE TEST',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigoAccent,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          Divider(color: Colors.white10, height: 20),
                          Text(
                            '🎮 Real Game Board Interactive Mode',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Renders the authentic Flame engine components from your mobile app:\n\n'
                            '• Real arrowhead carets & vector graphics\n'
                            '• Striped paired arrows & color locks\n'
                            '• Redirection dots (Orphan Dots)\n'
                            '• Smooth slide & exit animations\n'
                            '• Blocked shake animations\n'
                            '• Long-press trajectory path previews\n\n'
                            'Use Play ▶ / Pause ⏸ / Step ⏭ / Reset ↺ in the toolbar to auto-solve with real Flame animations!',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Dialog Footer Save / Cancel Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onSave(_buildCurrentLevelModel());
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  icon: const Icon(LucideIcons.save, size: 18),
                  label: const Text('Save Level Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
