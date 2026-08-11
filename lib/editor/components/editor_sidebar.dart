import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/editor_state.dart';
import '../utils/web_file_helper.dart';
import '../../data/level_binary_codec.dart';
import '../../data/models/level.dart';

class EditorSidebar extends StatelessWidget {
  final VoidCallback onOpenBulkGenerator;

  const EditorSidebar({
    super.key,
    required this.onOpenBulkGenerator,
  });

  Future<void> _loadBundledLevels(BuildContext context) async {
    try {
      final bytes = await rootBundle.load('assets/levels.bin');
      final uint8 = bytes.buffer.asUint8List();
      final decoder = LevelBinaryDecoder.fromBytes(uint8);
      final levels = decoder.decodeAll();
      if (context.mounted) {
        context.read<EditorState>().setLevels(levels);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully loaded ${levels.length} levels from assets!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading assets/levels.bin: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _openLocalBinFile(BuildContext context) async {
    try {
      final bytes = await WebFileHelper.pickFileBytes(accept: '.bin');
      if (bytes == null) return;
      final decoder = LevelBinaryDecoder.fromBytes(bytes);
      final levels = decoder.decodeAll();
      if (context.mounted) {
        context.read<EditorState>().setLevels(levels);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${levels.length} levels from local file!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to parse .bin file: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _exportBinFile(BuildContext context) {
    final state = context.read<EditorState>();
    if (state.levels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No levels available to export.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      final encoded = encodeLevels(state.levels);
      WebFileHelper.downloadBytes(encoded, 'levels.bin');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${state.levels.length} levels to levels.bin!'),
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

  void _addNewBlankLevel(BuildContext context) {
    final state = context.read<EditorState>();
    final newLevelNumber = state.levels.length + 1;
    final blankLevel = LevelModel(
      levelNumber: newLevelNumber,
      gridSize: 8,
      arrows: [],
      patternName: 'Custom Pattern',
      difficulty: Difficulty.easy,
      solutionOrder: [],
      maskShape: MaskShape.square,
      mask: {
        for (int r = 0; r < 8; r++)
          for (int c = 0; c < 8; c++) '$r,$c'
      },
      orphanDots: [],
    );
    state.addLevel(blankLevel);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: Color(0xFF0F1117),
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          // App Title Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.compass,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ARROW ESCAPE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Level Editor & Generator',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable Sidebar Controls
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // SECTION: File Operations
                _buildSectionHeader('FILE OPERATIONS'),
                ElevatedButton.icon(
                  onPressed: () => _loadBundledLevels(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2230),
                    foregroundColor: Colors.white,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(LucideIcons.package, size: 18),
                  label: const Text('Load Bundled Assets'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _openLocalBinFile(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2230),
                    foregroundColor: Colors.white,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(LucideIcons.fileUp, size: 18),
                  label: const Text('Open Local .bin File'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _exportBinFile(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(LucideIcons.download, size: 18),
                  label: const Text('Export levels.bin'),
                ),

                const SizedBox(height: 24),

                // SECTION: Actions & Quick Add
                _buildSectionHeader('LEVEL ACTIONS'),
                OutlinedButton.icon(
                  onPressed: () => _addNewBlankLevel(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    side: const BorderSide(color: Colors.amberAccent),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text('Create New Blank Level'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: onOpenBulkGenerator,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(LucideIcons.sparkles, size: 18),
                  label: const Text('Run Bulk Generator'),
                ),

                const SizedBox(height: 24),

                // SECTION: Search & Filters
                _buildSectionHeader('SEARCH & FILTERS'),
                TextField(
                  onChanged: (val) => state.setSearchQuery(val),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search level # or name...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon:
                        const Icon(LucideIcons.search, color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1B1E28),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),

                // Difficulty Filter Chips
                const Text('Difficulty:',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildFilterChip(
                      label: 'All',
                      isSelected: state.difficultyFilter == null,
                      onTap: () => state.setDifficultyFilter(null),
                    ),
                    ...Difficulty.values.map(
                      (diff) => _buildFilterChip(
                        label: diff.name.toUpperCase(),
                        isSelected: state.difficultyFilter == diff,
                        onTap: () => state.setDifficultyFilter(diff),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Solvability Filter Chips
                const Text('Solvability:',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildFilterChip(
                      label: 'All',
                      isSelected: state.solvabilityFilter == null,
                      onTap: () => state.setSolvabilityFilter(null),
                    ),
                    _buildFilterChip(
                      label: 'Solvable',
                      isSelected: state.solvabilityFilter == true,
                      onTap: () => state.setSolvabilityFilter(true),
                      activeColor: Colors.greenAccent,
                    ),
                    _buildFilterChip(
                      label: 'Unsolvable',
                      isSelected: state.solvabilityFilter == false,
                      onTap: () => state.setSolvabilityFilter(false),
                      activeColor: Colors.redAccent,
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white38,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color activeColor = Colors.indigoAccent,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : const Color(0xFF1B1E28),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : Colors.white60,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
