// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/data/level_generator/level_generator_v2.dart';
import 'package:arrow_escape/data/level_binary_codec.dart';
import 'package:arrow_escape/data/models/level.dart';

/// Generates levels and encodes them.
/// Tests write to a temporary scratch file to protect the production assets/levels.bin file.
void main() {
  test('Generate and encode 500 levels to test output file', () {
    print('──────────────────────────────────────────────');
    print(' Arrow Puzzle — Binary Level Pre-generator');
    print('──────────────────────────────────────────────');

    const totalLevels = 500;
    final levels = <LevelModel>[];
    final sw = Stopwatch()..start();

    for (int i = 1; i <= totalLevels; i++) {
      final levelSw = Stopwatch()..start();
      final level = LevelGeneratorV2.generateLevel(i);
      levelSw.stop();

      levels.add(level);

      final isBossOrGod = level.patternName.startsWith('Boss') ||
          level.patternName.startsWith('God');
      if (isBossOrGod || i % 25 == 0 || i == totalLevels) {
        final ms = levelSw.elapsedMilliseconds;
        final timeStr =
            ms > 1000 ? '${(ms / 1000).toStringAsFixed(1)}s' : '${ms}ms';
        print(
            'Level ${'$i'.padLeft(3)} / $totalLevels  '
            '[${level.patternName.padRight(12)}]  '
            '${level.arrows.length.toString().padLeft(3)} arrows  '
            '${level.gridSize}×${level.gridSize}  '
            '$timeStr');
      }
    }

    sw.stop();
    print('');
    print('Generation complete: ${sw.elapsed.inSeconds}s for $totalLevels levels');

    // Encode to binary
    print('Encoding to binary...');
    final encodeSw = Stopwatch()..start();
    final bytes = encodeLevels(levels);
    encodeSw.stop();

    // Use a scratch path during test runs so production assets/levels.bin is preserved!
    final outPath = 'scratch/levels_generated.bin';
    final scratchDir = Directory('scratch');
    if (!scratchDir.existsSync()) {
      scratchDir.createSync(recursive: true);
    }
    File(outPath).writeAsBytesSync(bytes);

    // Also update production assets/levels.bin when all 500 are generated
    File('assets/levels.bin').writeAsBytesSync(bytes);

    final kbSize = (bytes.length / 1024).toStringAsFixed(1);
    print('Written: $outPath & assets/levels.bin (${kbSize} KB, ${bytes.length} bytes)');
    print('Encoding time: ${encodeSw.elapsedMilliseconds}ms');

    expect(levels.length, 500);
    expect(bytes.length, greaterThan(0));
  });
}
