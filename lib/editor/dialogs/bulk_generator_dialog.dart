import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/editor_state.dart';
import '../utils/web_file_helper.dart';
import '../../data/level_binary_codec.dart';
import '../../data/models/level.dart';
import '../../data/level_generator/level_generator_v2.dart';
import '../../data/level_generator/solver.dart';

class BulkGeneratorDialog extends StatefulWidget {
  const BulkGeneratorDialog({super.key});

  @override
  State<BulkGeneratorDialog> createState() => _BulkGeneratorDialogState();
}

class _BulkGeneratorDialogState extends State<BulkGeneratorDialog> {
  int _targetLevelCount = 500;
  final double _normalRatio = 0.70;
  final double _bossRatio = 0.20;
  final double _godRatio = 0.10;

  List<NamedBytes> _uploadedPngMasks = [];

  bool _isGenerating = false;
  double _progress = 0.0;
  String _logText = '';
  int _generatedCount = 0;
  int _solvableCount = 0;
  List<LevelModel>? _generatedLevels;

  final ScrollController _logScrollController = ScrollController();

  Future<void> _pickBatchPngMasks() async {
    try {
      final files = await WebFileHelper.pickMultipleFiles(accept: 'image/png');
      if (files.isNotEmpty) {
        setState(() {
          _uploadedPngMasks = files;
        });
        _appendLog('Uploaded ${files.length} custom PNG masks.');
      }
    } catch (e) {
      _appendLog('Error picking PNG masks: $e');
    }
  }

  void _appendLog(String line) {
    setState(() {
      _logText += '$line\n';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController
            .jumpTo(_logScrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _startBulkGeneration() async {
    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _logText = '';
      _generatedCount = 0;
      _solvableCount = 0;
      _generatedLevels = [];
    });

    _appendLog(
        '=== Starting Bulk Generation Target: $_targetLevelCount Levels ===');

    final levels = <LevelModel>[];
    final pngCount = _uploadedPngMasks.length;

    for (int i = 1; i <= _targetLevelCount; i++) {
      Difficulty diff = Difficulty.forLevel(i);
      LevelModel generatedLevel;

      // Try custom PNG mask if available for this index
      if (i <= pngCount) {
        try {
          final pngBytes = _uploadedPngMasks[i - 1].bytes;
          final gridSize = 8;
          final mask =
              await WebFileHelper.parsePngToGridMask(pngBytes, gridSize);

          if (mask.isNotEmpty) {
            final baseGen = LevelGeneratorV2.generateLevel(i);
            generatedLevel = LevelModel(
              levelNumber: i,
              gridSize: gridSize,
              arrows: baseGen.arrows,
              patternName: _uploadedPngMasks[i - 1].name,
              difficulty: diff,
              solutionOrder: baseGen.solutionOrder,
              maskShape: MaskShape.square,
              mask: mask,
              orphanDots: baseGen.orphanDots,
            );
          } else {
            generatedLevel = LevelGeneratorV2.generateLevel(i);
          }
        } catch (_) {
          generatedLevel = LevelGeneratorV2.generateLevel(i);
        }
      } else {
        generatedLevel = LevelGeneratorV2.generateLevel(i);
      }

      // Solvability check
      final isSolvable = LevelSolver.solve(generatedLevel) != null;
      if (isSolvable) {
        _solvableCount++;
      }

      levels.add(generatedLevel);
      _generatedCount++;

      final curProgress = i / _targetLevelCount;
      if (i % 10 == 0 || i == _targetLevelCount) {
        setState(() {
          _progress = curProgress;
        });
        _appendLog(
            'Generated level $i/$_targetLevelCount [${diff.name.toUpperCase()}] - Solvable: $isSolvable');
        // Yield to browser UI event loop
        await Future.delayed(const Duration(milliseconds: 5));
      }
    }

    _appendLog('=== Bulk Generation Completed! ===');
    _appendLog(
        'Total: $_generatedCount | Solvable: $_solvableCount (${((_solvableCount / _generatedCount) * 100).toStringAsFixed(1)}%)');

    setState(() {
      _isGenerating = false;
      _generatedLevels = levels;
    });

    if (mounted) {
      context.read<EditorState>().setLevels(levels);
    }
  }

  void _downloadBinaryOutput() {
    if (_generatedLevels == null || _generatedLevels!.isEmpty) return;
    try {
      final encoded = encodeLevels(_generatedLevels!);
      WebFileHelper.downloadBytes(encoded, 'levels.bin');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Downloaded ${_generatedLevels!.length} levels binary file!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to encode levels: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141720),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 800,
        height: 650,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Title Header
            Row(
              children: [
                const Icon(LucideIcons.sparkles,
                    color: Colors.amberAccent, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'BULK LEVEL GENERATOR PIPELINE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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

            // Controls Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E28),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('Target Level Count:',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: TextEditingController(
                              text: '$_targetLevelCount'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed > 0) {
                              _targetLevelCount = parsed;
                            }
                          },
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFF282D3C),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),

                      // PNG Mask Upload Button
                      ElevatedButton.icon(
                        onPressed: _isGenerating ? null : _pickBatchPngMasks,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E3547),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(LucideIcons.folderUp, size: 16),
                        label: Text(_uploadedPngMasks.isEmpty
                            ? 'Upload PNG Masks'
                            : '${_uploadedPngMasks.length} PNGs Uploaded'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Difficulty Mix Ratios
                  Row(
                    children: [
                      const Text('Difficulty Ratio: ',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 8),
                      Text('Normal: ${(_normalRatio * 100).toInt()}%',
                          style: const TextStyle(color: Colors.greenAccent)),
                      const SizedBox(width: 12),
                      Text('Boss: ${(_bossRatio * 100).toInt()}%',
                          style: const TextStyle(color: Colors.orangeAccent)),
                      const SizedBox(width: 12),
                      Text('God: ${(_godRatio * 100).toInt()}%',
                          style: const TextStyle(color: Colors.purpleAccent)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Progress & Log Console Output
            if (_isGenerating || _generatedCount > 0) ...[
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white12,
                color: Colors.indigoAccent,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progress: ${(_progress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                  Text(
                      'Generated: $_generatedCount / $_targetLevelCount | Solvable: $_solvableCount',
                      style: const TextStyle(
                          color: Colors.greenAccent, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Console Output Window
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: SingleChildScrollView(
                  controller: _logScrollController,
                  child: Text(
                    _logText.isEmpty
                        ? 'Ready. Configure target level count and click "Start Bulk Generation".'
                        : _logText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.greenAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_generatedLevels != null && _generatedLevels!.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _downloadBinaryOutput,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(LucideIcons.download, size: 18),
                    label: const Text('Download levels.bin'),
                  ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _startBulkGeneration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  icon: Icon(_isGenerating
                      ? LucideIcons.loader
                      : LucideIcons.play),
                  label: Text(_isGenerating
                      ? 'Generating...'
                      : 'Start Bulk Generation'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
