import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../data/models/level.dart';
import '../../game/arrow_puzzle_game.dart';
import '../../game/game_state.dart';

/// Wraps the actual Flame Engine ArrowPuzzleGame for real-time playtesting
/// and authentic game vector rendering (arrowheads, body stripes, slide & shake animations).
class FlameGamePreview extends StatefulWidget {
  final LevelModel level;
  final VoidCallback? onComplete;

  const FlameGamePreview({
    super.key,
    required this.level,
    this.onComplete,
  });

  @override
  State<FlameGamePreview> createState() => FlameGamePreviewState();
}

class FlameGamePreviewState extends State<FlameGamePreview> {
  late ArrowPuzzleGame _game;
  late GameState _gameState;
  int _gameKeyCounter = 0;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  @override
  void didUpdateWidget(covariant FlameGamePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // LevelModel has value equality (see LevelModel.==), so this only
    // triggers when the level's actual content changed - not merely
    // because the parent rebuilt a new-but-identical LevelModel instance
    // (e.g. after a solve-step animation's setState).
    if (oldWidget.level != widget.level) {
      resetGame();
    }
  }

  void _initGame() {
    _gameState = GameState(
      level: widget.level,
      isInfiniteLives: true, // Infinite lives for Level Editor playtesting!
      onLevelComplete: () {
        widget.onComplete?.call();
      },
      onGameOver: () {},
      onLifeLost: () {},
      onDeadlock: () {},
    );

    _game = ArrowPuzzleGame(
      level: widget.level,
      gameState: _gameState,
      onLevelComplete: () {
        widget.onComplete?.call();
      },
      onGameOver: () {},
      onLifeLost: () {},
    );
  }

  /// Triggers full Flame slide & exit animation for the specified arrow!
  void triggerArrowMove(String arrowId) {
    if (_game.gridComponent != null) {
      _game.gridComponent!.triggerArrowTap(arrowId);
    }
  }

  /// Resets the Flame game board back to starting layout
  void resetGame() {
    setState(() {
      _gameKeyCounter++;
      _initGame();
    });
  }

  /// Instantly marks the level as cleared, skipping every arrow's slide-
  /// and-exit animation, so the level-clear animation can be tuned without
  /// playing through the whole solve first.
  void solveInstantly() {
    _gameState.instantWin();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141720),
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Flame Engine Game Widget
              GameWidget(
                key: ValueKey('flame_game_$_gameKeyCounter'),
                game: _game,
              ),

              // Reset Overlay Button
              Positioned(
                right: 12,
                top: 12,
                child: FloatingActionButton.small(
                  onPressed: resetGame,
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  tooltip: 'Reset Flame Game Board',
                  child: const Icon(Icons.refresh, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
