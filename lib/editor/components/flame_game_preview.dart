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
  State<FlameGamePreview> createState() => _FlameGamePreviewState();
}

class _FlameGamePreviewState extends State<FlameGamePreview> {
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
    if (oldWidget.level != widget.level) {
      _resetGame();
    }
  }

  void _initGame() {
    _gameState = GameState(
      level: widget.level,
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

  void _resetGame() {
    setState(() {
      _gameKeyCounter++;
      _initGame();
    });
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
                  onPressed: _resetGame,
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
