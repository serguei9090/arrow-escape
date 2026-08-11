import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/editor_state.dart';
import '../../data/models/level.dart';
import 'interactive_level_canvas.dart';

class LevelGalleryView extends StatelessWidget {
  final Function(LevelModel level) onEditLevel;

  const LevelGalleryView({
    super.key,
    required this.onEditLevel,
  });

  Color _getDifficultyColor(Difficulty diff) {
    switch (diff) {
      case Difficulty.tutorial:
        return Colors.blue;
      case Difficulty.easy:
        return Colors.green;
      case Difficulty.medium:
        return Colors.teal;
      case Difficulty.hard:
        return Colors.orange;
      case Difficulty.expert:
        return Colors.deepOrange;
      case Difficulty.master:
        return Colors.purple;
      case Difficulty.legend:
        return Colors.purpleAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final levels = state.filteredLevels;

    return Column(
      children: [
        // Top Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFF14171F),
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Level Explorer',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Showing ${levels.length} of ${state.levels.length} levels',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
              const Spacer(),

              // Solvability Stats Chips
              _buildStatBadge(
                label: 'Solvable',
                count: state.solvableCount,
                color: Colors.greenAccent,
                icon: LucideIcons.checkCircle2,
              ),
              const SizedBox(width: 12),
              _buildStatBadge(
                label: 'Unsolvable',
                count: state.unsolvableCount,
                color: Colors.redAccent,
                icon: LucideIcons.alertTriangle,
              ),
            ],
          ),
        ),

        // Grid Gallery Content
        Expanded(
          child: levels.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.folderOpen,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No levels found matching active filters.',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisExtent: 360,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: levels.length,
                  itemBuilder: (context, index) {
                    final level = levels[index];
                    final isSolvable = state.isLevelSolvable(level);

                    return RepaintBoundary(
                      child: _buildLevelCard(
                        context,
                        level: level,
                        isSolvable: isSolvable,
                        onEdit: () => onEditLevel(level),
                        onDuplicate: () {
                          state.selectLevel(state.levels.indexOf(level));
                          state.duplicateSelectedLevel();
                        },
                        onDelete: () {
                          state.selectLevel(state.levels.indexOf(level));
                          state.deleteSelectedLevel();
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatBadge({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard(
    BuildContext context, {
    required LevelModel level,
    required bool isSolvable,
    required VoidCallback onEdit,
    required VoidCallback onDuplicate,
    required VoidCallback onDelete,
  }) {
    final diffColor = _getDifficultyColor(level.difficulty);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  '#${level.levelNumber}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: diffColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    level.difficulty.name.toUpperCase(),
                    style: TextStyle(
                      color: diffColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),

                // Solvability Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isSolvable ? Colors.green : Colors.red)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSolvable
                            ? LucideIcons.check
                            : LucideIcons.alertTriangle,
                        color: isSolvable ? Colors.greenAccent : Colors.redAccent,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSolvable ? 'SOLVABLE' : 'UNSOLVABLE',
                        style: TextStyle(
                          color: isSolvable ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mini Canvas Preview (High Performance 2D Painter)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: LevelThumbnailCanvas(level: level),
            ),
          ),

          // Footer Metrics & Action Buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${level.gridSize}x${level.gridSize} Grid',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    Text(
                      '${level.arrows.length} Arrows',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onEdit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(LucideIcons.pencil, size: 14),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: onDuplicate,
                      tooltip: 'Duplicate',
                      icon: const Icon(LucideIcons.copy,
                          size: 16, color: Colors.white70),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      tooltip: 'Delete',
                      icon: const Icon(LucideIcons.trash2,
                          size: 16, color: Colors.redAccent),
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
