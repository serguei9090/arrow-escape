import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/app_colors.dart';
import '../../data/models/arrow.dart';
import '../../data/models/level.dart';
import '../../data/level_generator/solver.dart';
import '../../data/level_generator/level_generator_v2.dart';
import '../components/interactive_level_canvas.dart';
import '../components/flame_game_preview.dart';
import '../models/editor_state.dart';
import '../utils/web_file_helper.dart';

enum EditorViewMode {
  flameGameEngine,
  canvasEditor,
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

  ArrowModel? _selectedArrow;
  String? _selectedCell;

  EditorViewMode _viewMode = EditorViewMode.flameGameEngine;
  final GlobalKey<FlameGamePreviewState> _flameGameKey =
      GlobalKey<FlameGamePreviewState>();

  // Solver Step-by-step state & Auto-Play Controller
  SolveResult? _solveResult;
  bool _isAutoSolving = false;
  int _currentSolveStepIndex = 0;
  Timer? _solveTimer;

  // Interactive Play-Test Mode state
  bool _isPlayTesting = false;
  final Set<String> _playtestClearedArrowIds = {};

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
      orphanDots: [],
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

    if (_viewMode == EditorViewMode.flameGameEngine) {
      // Trigger real Flame engine arrow slide & exit animation!
      _flameGameKey.currentState?.triggerArrowMove(targetArrowId);
    } else {
      // 2D Canvas Fallback step clearance
      setState(() {
        _playtestClearedArrowIds.add(targetArrowId);
      });
    }

    setState(() {
      _currentSolveStepIndex++;
    });
  }

  void _resetSolverBoard() {
    _solveTimer?.cancel();
    setState(() {
      _isAutoSolving = false;
      _currentSolveStepIndex = 0;
      _playtestClearedArrowIds.clear();
    });

    if (_viewMode == EditorViewMode.flameGameEngine) {
      _flameGameKey.currentState?.resetGame();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  void _togglePlayTestingMode() {
    setState(() {
      _isPlayTesting = !_isPlayTesting;
      _playtestClearedArrowIds.clear();
      _isAutoSolving = false;
      _currentSolveStepIndex = 0;
    });
  }

  void _handlePlayTestArrowTap(ArrowModel arrow) {
    if (!_isPlayTesting) return;
    if (_playtestClearedArrowIds.contains(arrow.id)) return;

    final delta = arrow.direction.delta;
    final dr = delta[0];
    final dc = delta[1];

    bool isBlocked = false;
    int r = arrow.row + dr;
    int c = arrow.col + dc;

    while (r >= 0 && r < _gridSize && c >= 0 && c < _gridSize) {
      final cellKey = '$r,$c';
      if (!_mask.contains(cellKey)) {
        break;
      }
      final occupyingArrow = _arrows.firstWhere(
        (other) =>
            !_playtestClearedArrowIds.contains(other.id) &&
            other.path.any((pt) => pt[0] == r && pt[1] == c),
        orElse: () => ArrowModel(
          id: '',
          row: -1,
          col: -1,
          direction: ArrowDirection.up,
          path: [],
        ),
      );

      if (occupyingArrow.id.isNotEmpty) {
        isBlocked = true;
        break;
      }

      r += dr;
      c += dc;
    }

    if (!isBlocked) {
      setState(() {
        _playtestClearedArrowIds.add(arrow.id);
      });

      if (_playtestClearedArrowIds.length == _arrows.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 PUZZLE SOLVED! LEVEL CLEARED!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Arrow is blocked! Clear the path first.'),
          backgroundColor: Colors.orange,
          duration: Duration(milliseconds: 800),
        ),
      );
    }
  }

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
        _selectedArrow = null;
        _selectedCell = null;
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
      _selectedArrow = null;
      _playtestClearedArrowIds.clear();
    });
    _runSolverCheck();
  }

  void _toggleCellMask(int r, int c) {
    if (_isPlayTesting) return;
    final cellKey = '$r,$c';
    setState(() {
      if (_mask.contains(cellKey)) {
        _mask.remove(cellKey);
        _arrows.removeWhere((a) => a.row == r && a.col == c);
        if (_selectedArrow?.row == r && _selectedArrow?.col == c) {
          _selectedArrow = null;
        }
      } else {
        _mask.add(cellKey);
      }
      _selectedCell = cellKey;
    });
    _runSolverCheck();
  }

  void _addArrowAtCell(int r, int c) {
    if (!_mask.contains('$r,$c')) return;
    if (_arrows.any((a) => a.row == r && a.col == c)) return;

    final newArrow = ArrowModel(
      id: 'a_${widget.initialLevel.levelNumber}_${_arrows.length}',
      row: r,
      col: c,
      direction: ArrowDirection.up,
      path: [
        [r, c]
      ],
    );

    setState(() {
      _arrows.add(newArrow);
      _selectedArrow = newArrow;
    });
    _runSolverCheck();
  }

  void _rotateSelectedArrow() {
    if (_selectedArrow == null) return;
    final nextDir = ArrowDirection.values[
        (_selectedArrow!.direction.index + 1) % ArrowDirection.values.length];

    setState(() {
      final idx = _arrows.indexWhere((a) => a.id == _selectedArrow!.id);
      if (idx != -1) {
        _arrows[idx] = _selectedArrow!.copyWith(direction: nextDir);
        _selectedArrow = _arrows[idx];
      }
    });
    _runSolverCheck();
  }

  void _changeSelectedArrowMechanic(SnakeMechanic mechanic) {
    if (_selectedArrow == null) return;
    setState(() {
      final idx = _arrows.indexWhere((a) => a.id == _selectedArrow!.id);
      if (idx != -1) {
        _arrows[idx] = _selectedArrow!.copyWith(mechanic: mechanic);
        _selectedArrow = _arrows[idx];
      }
    });
    _runSolverCheck();
  }

  void _changeSelectedArrowColorGroup(int? colorGroup) {
    if (_selectedArrow == null) return;
    setState(() {
      final idx = _arrows.indexWhere((a) => a.id == _selectedArrow!.id);
      if (idx != -1) {
        _arrows[idx] = _selectedArrow!.copyWith(colorGroup: colorGroup);
        _selectedArrow = _arrows[idx];
      }
    });
  }

  void _deleteSelectedArrow() {
    if (_selectedArrow == null) return;
    setState(() {
      _arrows.removeWhere((a) => a.id == _selectedArrow!.id);
      _selectedArrow = null;
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

                // View Mode Switcher Segment (Flame Game vs Canvas Editor)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C202C),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      _buildViewSegmentButton(
                        label: 'Flame Game Engine',
                        icon: LucideIcons.gamepad2,
                        isSelected: _viewMode == EditorViewMode.flameGameEngine,
                        onTap: () => setState(
                            () => _viewMode = EditorViewMode.flameGameEngine),
                      ),
                      _buildViewSegmentButton(
                        label: 'Canvas Grid Editor',
                        icon: LucideIcons.grid,
                        isSelected: _viewMode == EditorViewMode.canvasEditor,
                        onTap: () => setState(
                            () => _viewMode = EditorViewMode.canvasEditor),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

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
                              _playtestClearedArrowIds.clear();
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
                  // Left Interactive Panel (Flame Game Engine OR Canvas Grid Editor)
                  Expanded(
                    flex: 6,
                    child: Center(
                      child: _viewMode == EditorViewMode.flameGameEngine
                          ? FlameGamePreview(
                              key: _flameGameKey,
                              level: _buildCurrentLevelModel(),
                            )
                          : InteractiveLevelCanvas(
                              level: _buildCurrentLevelModel(),
                              selectedArrowId: _selectedArrow?.id,
                              selectedCell: _selectedCell,
                              solverStepHighlight: _solveResult?.solutionOrder,
                              clearedArrowIds: _playtestClearedArrowIds,
                              currentSolverStep: _currentSolveStepIndex,
                              onCellTap: (r, c) {
                                if (_isPlayTesting) return;
                                final cellKey = '$r,$c';
                                final existingArrow = _arrows.firstWhere(
                                  (a) => a.row == r && a.col == c,
                                  orElse: () => ArrowModel(
                                    id: '',
                                    row: -1,
                                    col: -1,
                                    direction: ArrowDirection.up,
                                    path: [],
                                  ),
                                );

                                if (existingArrow.id.isNotEmpty) {
                                  setState(() {
                                    _selectedArrow = existingArrow;
                                    _selectedCell = cellKey;
                                  });
                                } else {
                                  _toggleCellMask(r, c);
                                }
                              },
                              onArrowTap: (arrow) {
                                if (_isPlayTesting) {
                                  _handlePlayTestArrowTap(arrow);
                                } else {
                                  setState(() {
                                    _selectedArrow = arrow;
                                    _selectedCell = '${arrow.row},${arrow.col}';
                                  });
                                }
                              },
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _viewMode == EditorViewMode.flameGameEngine
                                    ? 'REAL FLAME ENGINE TEST'
                                    : 'CANVAS INSPECTOR & TOOLS',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigoAccent,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white10, height: 20),

                          if (_viewMode == EditorViewMode.flameGameEngine) ...[
                            const Text(
                              '🎮 Real Game Board Interactive Mode',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Renders the authentic Flame engine components from your mobile app:\n\n'
                              '• Real arrowhead carets & vector graphics\n'
                              '• Striped paired arrows & color locks\n'
                              '• Smooth slide & exit animations\n'
                              '• Blocked shake animations\n'
                              '• Long-press trajectory path previews\n\n'
                              'Use Play ▶ / Pause ⏸ / Step ⏭ / Reset ↺ in the toolbar to auto-solve with real Flame animations!',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13, height: 1.4),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _viewMode = EditorViewMode.canvasEditor;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF282F40),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(LucideIcons.pencil, size: 16),
                              label: const Text('Switch to Cell & Arrow Editor'),
                            ),
                          ] else if (_selectedCell != null) ...[
                            Text(
                              'Selected Cell: $_selectedCell',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: () {
                                final parts = _selectedCell!.split(',');
                                _addArrowAtCell(int.parse(parts[0]),
                                    int.parse(parts[1]));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(LucideIcons.plus, size: 16),
                              label: const Text('Add Arrow to Cell'),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (_viewMode != EditorViewMode.flameGameEngine &&
                              _selectedArrow != null) ...[
                            Text(
                              'Arrow #${_selectedArrow!.id}',
                              style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                            const SizedBox(height: 12),

                            // Direction Rotate Button
                            ElevatedButton.icon(
                              onPressed: _rotateSelectedArrow,
                              icon: const Icon(LucideIcons.rotateCw, size: 16),
                              label: Text(
                                  'Direction: ${_selectedArrow!.direction.name.toUpperCase()}'),
                            ),
                            const SizedBox(height: 12),

                            // Mechanic Selector
                            const Text('Mechanic:',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            DropdownButton<SnakeMechanic>(
                              value: _selectedArrow!.mechanic,
                              dropdownColor: const Color(0xFF1C202C),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                              items: SnakeMechanic.values
                                  .map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m.name.toUpperCase())))
                                  .toList(),
                              onChanged: (m) {
                                if (m != null) _changeSelectedArrowMechanic(m);
                              },
                            ),
                            const SizedBox(height: 12),

                            // Color Group Selector
                            const Text('Color Group:',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: [
                                _buildColorDot(null),
                                for (int g = 0; g < 12; g++) _buildColorDot(g),
                              ],
                            ),

                            const Spacer(),

                            OutlinedButton.icon(
                              onPressed: _deleteSelectedArrow,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side:
                                    const BorderSide(color: Colors.redAccent),
                              ),
                              icon: const Icon(LucideIcons.trash2, size: 16),
                              label: const Text('Delete Arrow'),
                            ),
                          ] else if (_viewMode != EditorViewMode.flameGameEngine) ...[
                            const Spacer(),
                            const Center(
                              child: Text(
                                'Click a cell or arrow to inspect and modify.',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const Spacer(),
                          ],
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

  Widget _buildViewSegmentButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigoAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorDot(int? group) {
    final isSelected = _selectedArrow?.colorGroup == group;
    final color = group == null ? Colors.grey : AppColors.getGroupColor(group);

    return GestureDetector(
      onTap: () => _changeSelectedArrowColorGroup(group),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.white30,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: group == null
            ? const Icon(Icons.close, size: 12, color: Colors.white)
            : null,
      ),
    );
  }
}
