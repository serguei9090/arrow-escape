import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/data/level_generator/level_generator_v2.dart';

void main() {
  test('Profile Level Generation 1 to 60', () {
    for (int i = 1; i <= 60; i++) {
      final s = Stopwatch()..start();
      final level = LevelGeneratorV2.generateLevel(i);
      s.stop();
      print('Level $i generated in ${s.elapsedMilliseconds} ms. Grid: ${level.gridSize}, Arrows: ${level.arrows.length}, Orphans: ${level.orphanDots.length}, Pattern: ${level.patternName}');
    }
  });
}
