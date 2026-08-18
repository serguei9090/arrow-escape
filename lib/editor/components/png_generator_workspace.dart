import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/png_mask_model.dart';
import '../models/editor_state.dart';
import '../utils/web_file_helper.dart';
import '../components/interactive_level_canvas.dart';
import '../../core/constants.dart';
import '../../data/models/level.dart';
import '../../data/level_generator/level_generator_v2.dart';
import '../../data/level_generator/solver.dart';
import '../../data/level_binary_codec.dart';

class PngGeneratorWorkspace extends StatefulWidget {
  const PngGeneratorWorkspace({super.key});

  @override
  State<PngGeneratorWorkspace> createState() => _PngGeneratorWorkspaceState();
}

class _PngGeneratorWorkspaceState extends State<PngGeneratorWorkspace> {
  final List<PngMaskModel> _pngMasks = [];
  int _selectedDefaultGridSize = 25;
  int _targetTotalLevelCount = 100;

  // Generation Pipeline State
  bool _isGenerating = false;
  bool _cancelRequested = false;
  double _generationProgress = 0.0;
  int _generatedCount = 0;
  int _solvableCount = 0;
  final StringBuffer _logBuffer = StringBuffer();
  List<LevelModel> _generatedLevels = [];

  Future<void> _loadBundledSamples() async {
    try {
      final samples = [
        {
          'path': 'assets/PNG_Levels/15x15/house.png',
          'name': '15x15_house.png',
          'grid': 15
        },
        {
          'path': 'assets/PNG_Levels/25x25/ship.png',
          'name': '25x25_ship.png',
          'grid': 25
        },
        {
          'path': 'assets/PNG_Levels/30x30/dog.png',
          'name': '30x30_dog.png',
          'grid': 30
        },
      ];

      int addedCount = 0;
      for (final s in samples) {
        final path = s['path'] as String;
        final name = s['name'] as String;
        final gridSize = s['grid'] as int;

        final bytesData = await rootBundle.load(path);
        final bytes = bytesData.buffer.asUint8List();
        final parsedMask =
            await WebFileHelper.parsePngToGridMask(bytes, gridSize);

        _pngMasks.add(
          PngMaskModel(
            id: 'mask_${DateTime.now().millisecondsSinceEpoch}_${_pngMasks.length}',
            filename: name,
            subfolder: '${gridSize}x$gridSize',
            imageBytes: bytes,
            gridSize: gridSize,
            mask: parsedMask,
          ),
        );
        addedCount++;
      }

      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully loaded $addedCount sample PNG masks (House 15x15, Ship 25x25, Dog 30x30)!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sample PNG masks: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _uploadCustomPngFiles() async {
    try {
      final namedBytesList =
          await WebFileHelper.pickMultipleFiles(accept: 'image/png');
      if (namedBytesList.isEmpty) return;

      int addedCount = 0;
      for (final item in namedBytesList) {
        // Detect grid size from filename if formatted like '30x30_sword.png'
        int gridSize = _selectedDefaultGridSize;
        final nameLower = item.name.toLowerCase();
        final match = RegExp(r'(\d+)x(\d+)').firstMatch(nameLower);
        if (match != null) {
          gridSize = int.parse(match.group(1)!).clamp(5, 40);
        }

        final parsedMask =
            await WebFileHelper.parsePngToGridMask(item.bytes, gridSize);

        _pngMasks.add(
          PngMaskModel(
            id: 'mask_${DateTime.now().millisecondsSinceEpoch}_$addedCount',
            filename: item.name,
            subfolder: '${gridSize}x$gridSize',
            imageBytes: item.bytes,
            gridSize: gridSize,
            mask: parsedMask,
          ),
        );
        addedCount++;
      }

      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully loaded $addedCount PNG shape masks!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load PNG masks: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _removeMask(int index) {
    setState(() {
      _pngMasks.removeAt(index);
    });
  }

  void _clearAllMasks() {
    setState(() {
      _pngMasks.clear();
      _generatedLevels.clear();
      _logBuffer.clear();
    });
  }

  void _stopBulkGeneration() {
    if (_isGenerating) {
      setState(() {
        _cancelRequested = true;
      });
    }
  }

  Future<void> _startBulkGeneration() async {
    setState(() {
      _isGenerating = true;
      _cancelRequested = false;
      _generationProgress = 0.0;
      _generatedCount = 0;
      _solvableCount = 0;
      _logBuffer.clear();
      _generatedLevels.clear();
    });

    _logBuffer.writeln('──────────────────────────────────────────────');
    _logBuffer.writeln('  PNG & Procedural Level Pack Generator Pipeline');
    _logBuffer.writeln('  Total Target Pack Levels: $_targetTotalLevelCount');
    _logBuffer
        .writeln('  Custom PNG Shape Masks Available: ${_pngMasks.length}');
    _logBuffer.writeln('  Mandatory Tutorial Levels (1..3): Immutable');
    _logBuffer.writeln('──────────────────────────────────────────────\n');

    final generated = <LevelModel>[];
    final remainingPngMasks = List<PngMaskModel>.from(_pngMasks);

    for (int targetLevelNum = 1;
        targetLevelNum <= _targetTotalLevelCount;
        targetLevelNum++) {
      if (_cancelRequested) {
        _logBuffer.writeln(
            '\n⚠️ Generation stopped by user at Level #$targetLevelNum.');
        _logBuffer.writeln('  Discarded transient level pack data.');
        _logBuffer.writeln('──────────────────────────────────────────────');
        setState(() {
          _generatedLevels.clear();
          _generationProgress = 0.0;
          _isGenerating = false;
          _cancelRequested = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Generation stopped. Transient level pack discarded.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      LevelModel level;
      String levelSourceTag;

      if (targetLevelNum <= AppConstants.tutorialLevels) {
        // ── Mandatory Immutable Tutorial Levels 1, 2, 3 ──────────────────────
        level = LevelGeneratorV2.generateLevel(targetLevelNum);
        levelSourceTag = 'Mandatory Tutorial';
      } else {
        // ── Custom PNG Mask or Procedural Generator Population ───────────────
        final targetGridSize = AppConstants.gridSizeForLevel(targetLevelNum);

        // Find best matching PNG mask for this level's grid size or complexity
        int matchIdx = -1;
        if (remainingPngMasks.isNotEmpty) {
          // Exact grid match preferred
          matchIdx =
              remainingPngMasks.indexWhere((m) => m.gridSize == targetGridSize);
          if (matchIdx == -1) {
            // Closest grid size match
            int minDiff = 999;
            for (int k = 0; k < remainingPngMasks.length; k++) {
              final diff =
                  (remainingPngMasks[k].gridSize - targetGridSize).abs();
              if (diff < minDiff) {
                minDiff = diff;
                matchIdx = k;
              }
            }
          }
        }

        if (matchIdx != -1) {
          final pMask = remainingPngMasks.removeAt(matchIdx);
          if (pMask.mask.isNotEmpty) {
            level = LevelGeneratorV2.generateLevelWithMask(
              levelNumber: targetLevelNum,
              gridSize: pMask.gridSize,
              mask: Set.from(pMask.mask),
              patternName: pMask.filename,
              isCancelled: () => _cancelRequested,
            );
          } else {
            level = LevelGeneratorV2.generateLevel(targetLevelNum,
                isCancelled: () => _cancelRequested);
          }
          levelSourceTag = 'PNG Mask ("${pMask.filename}")';
        } else {
          // Procedural generation fallback via LevelGeneratorV2
          level = LevelGeneratorV2.generateLevel(targetLevelNum,
              isCancelled: () => _cancelRequested);
          levelSourceTag = 'Procedural V2';
        }
      }

      // Verify solvability using LevelSolver
      final sol = LevelSolver.solve(level);
      final isSolvable = sol != null;
      if (isSolvable) {
        _solvableCount++;
        level = level.copyWith(solutionOrder: sol);
      }

      generated.add(level);
      _generatedCount++;
      _generationProgress = targetLevelNum / _targetTotalLevelCount;

      final isFallback = level.patternName.startsWith('fallback');
      final isOrphanRelief = level.patternName.startsWith('orphan-relief');
      _logBuffer.writeln(
          'L#$targetLevelNum [$levelSourceTag] | ${isSolvable ? "SOLVABLE" : "UNSOLVABLE"} | ${level.arrows.length} Arrows | ${level.gridSize}x${level.gridSize} | ${level.orphanDots.length} orphan dot(s)'
          '${isFallback ? ' | ⚠️ FALLBACK (generation exhausted all attempts)' : ''}'
          '${isOrphanRelief ? ' | ⚠️ ORPHAN-RELIEF (could not reach zero-orphan layout)' : ''}');

      setState(() {});
      // This editor is web-only (see WebFileHelper's dart:html dependency),
      // and Flutter Web's compute() does NOT spawn a real background
      // isolate/worker - it just awaits one microtask then runs the
      // callback inline on this same thread (see Flutter SDK's
      // _isolates_web.dart). So wrapping generation in compute() here
      // would add complexity and break the isCancelled callback (compute
      // callbacks can't close over local state) for zero real threading
      // benefit. Yielding every level like this is the actual mitigation
      // available on this target - it lets the browser process input
      // (e.g. the Stop button) and repaint between levels.
      await Future.delayed(const Duration(milliseconds: 20));
    }

    _logBuffer.writeln('\n──────────────────────────────────────────────');
    _logBuffer.writeln(
        ' Generation Complete: $_generatedCount levels built ($_solvableCount solvable)');
    _logBuffer.writeln('──────────────────────────────────────────────');

    setState(() {
      _generatedLevels = generated;
      _isGenerating = false;
      _cancelRequested = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Successfully generated $_generatedCount levels! Ready to export.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _exportGeneratedLevelPack() {
    if (_generatedLevels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No generated level pack available to export.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final encoded = encodeLevels(_generatedLevels);
      WebFileHelper.downloadBytes(
          encoded, 'png_generated_pack_${_generatedLevels.length}.bin');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Exported ${_generatedLevels.length} levels to png_generated_pack.bin!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0D12),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Toolbar
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PNG & Procedural Level Pack Generator',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Preserves mandatory tutorials (L1..L3), matches custom PNG shape masks, and procedurally fills remaining levels.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Total Target Pack Levels Selector
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total Pack Levels: ',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  DropdownButton<int>(
                    value: _targetTotalLevelCount,
                    dropdownColor: const Color(0xFF1C202C),
                    style: const TextStyle(
                        color: Colors.indigoAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                    items: [10, 25, 50, 100, 200, 300, 500]
                        .map((cnt) => DropdownMenuItem(
                            value: cnt, child: Text('$cnt Levels')))
                        .toList(),
                    onChanged: _isGenerating
                        ? null
                        : (val) {
                            if (val != null) {
                              setState(() => _targetTotalLevelCount = val);
                            }
                          },
                  ),
                ],
              ),

              const SizedBox(width: 16),

              // Default Grid Size Selector
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Grid Size: ',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  DropdownButton<int>(
                    value: _selectedDefaultGridSize,
                    dropdownColor: const Color(0xFF1C202C),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: [10, 15, 20, 25, 30, 35, 40]
                        .map((g) => DropdownMenuItem(
                            value: g, child: Text('${g}x$g Grid')))
                        .toList(),
                    onChanged: _isGenerating
                        ? null
                        : (val) {
                            if (val != null) {
                              setState(() => _selectedDefaultGridSize = val);
                            }
                          },
                  ),
                ],
              ),

              const SizedBox(width: 16),

              // Load Sample Masks Button
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _loadBundledSamples,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade700,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(LucideIcons.sparkles, size: 16),
                label: const Text('Load Samples'),
              ),

              const SizedBox(width: 12),

              // Upload Action Buttons
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _uploadCustomPngFiles,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: const Icon(LucideIcons.upload, size: 16),
                label: const Text('Upload PNG Masks'),
              ),
              const SizedBox(width: 12),

              if (_pngMasks.isNotEmpty && !_isGenerating)
                OutlinedButton.icon(
                  onPressed: _clearAllMasks,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  label: const Text('Clear All'),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Main Workspace Split View (PNG Gallery Left + Generator Log Right)
          Expanded(
            child: Row(
              children: [
                // Left PNG Mask Gallery Grid (Flex 7)
                Expanded(
                  flex: 7,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141720),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'LOADED PNG MASKS (${_pngMasks.length})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        if (_pngMasks.isEmpty)
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.imagePlus,
                                    size: 56,
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No PNG shape masks loaded yet.',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Click "Load Samples" to view House (15x15), Ship (25x25) & Dog (30x30)\nor click "Upload PNG Masks" to select custom shapes!',
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: _pngMasks.length,
                              itemBuilder: (context, index) {
                                final maskModel = _pngMasks[index];
                                return _buildPngMaskCard(maskModel, index);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                // Right Generation Console Log & Download Controls (Flex 4)
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141720),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'GENERATOR PIPELINE',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Target: $_targetTotalLevelCount Levels',
                                style: const TextStyle(
                                  color: Colors.indigoAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 20),

                        // Action Buttons: Generate or Stop & Discard
                        if (!_isGenerating)
                          ElevatedButton.icon(
                            onPressed: _startBulkGeneration,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigoAccent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(LucideIcons.play, size: 18),
                            label: Text(
                              'Generate Level Pack ($_targetTotalLevelCount Levels)',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _stopBulkGeneration,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.shade700,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(LucideIcons.square, size: 18),
                            label: Text(
                              'Stop & Discard Generation (L#$_generatedCount / $_targetTotalLevelCount)',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),

                        const SizedBox(height: 12),

                        if (_isGenerating) ...[
                          LinearProgressIndicator(
                            value: _generationProgress,
                            backgroundColor: Colors.white12,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (_generatedLevels.isNotEmpty && !_isGenerating) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    context
                                        .read<EditorState>()
                                        .setLevels(_generatedLevels);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Loaded ${_generatedLevels.length} levels into .bin Level Explorer!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigoAccent,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(LucideIcons.eye, size: 18),
                                  label: const Text(
                                    'Load to Explorer',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _exportGeneratedLevelPack,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(LucideIcons.download,
                                      size: 18),
                                  label: const Text(
                                    'Download .bin',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Log Console Window
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF090B0F),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: SingleChildScrollView(
                              reverse: true,
                              child: Text(
                                _logBuffer.isEmpty
                                    ? '// Console logs will appear here during generation...\n'
                                        '// Pack structure:\n'
                                        '// • L1..L3: Mandatory Tutorials\n'
                                        '// • L4..L$_targetTotalLevelCount: PNG shape masks + LevelGeneratorV2 procedural fill'
                                    : _logBuffer.toString(),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Colors.greenAccent,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPngMaskCard(PngMaskModel maskModel, int index) {
    // Generate a temporary level model to render the parsed grid mask preview
    final previewLevel = LevelModel(
      levelNumber: index + 1,
      gridSize: maskModel.gridSize,
      arrows: [],
      patternName: maskModel.filename,
      difficulty: Difficulty.easy,
      solutionOrder: [],
      maskShape: MaskShape.square,
      mask: maskModel.mask,
      orphanDots: [],
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image / Mask Preview Split Header
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Stack(
                children: [
                  Row(
                    children: [
                      // Original PNG Image
                      Expanded(
                        child: Container(
                          color: Colors.black45,
                          child: Image.memory(
                            maskModel.imageBytes,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const VerticalDivider(color: Colors.white12, width: 1),
                      // Parsed Grid Mask Overlay
                      Expanded(
                        child: Container(
                          color: const Color(0xFF141720),
                          padding: const EdgeInsets.all(4),
                          child: LevelThumbnailCanvas(level: previewLevel),
                        ),
                      ),
                    ],
                  ),
                  if (!_isGenerating)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: IconButton(
                        onPressed: () => _removeMask(index),
                        icon: const Icon(LucideIcons.x,
                            color: Colors.redAccent, size: 16),
                        tooltip: 'Remove Mask',
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Metadata Card Footer
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  maskModel.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${maskModel.gridSize}x${maskModel.gridSize}',
                        style: const TextStyle(
                            color: Colors.indigoAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${maskModel.mask.length} cells',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
