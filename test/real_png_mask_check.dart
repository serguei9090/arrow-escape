import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/data/level_generator/level_generator_v2.dart';

// Faithful port of WebFileHelper.parsePngToGridMask's pixel-sampling logic
// (which uses dart:html's canvas, unavailable in a VM test) using dart:ui
// decoding instead, so this exercises the REAL bundled dog.png asset rather
// than a synthetic MaskGeneratorV2 shape.
Future<Set<String>> parsePngToGridMaskViaUi(Uint8List pngBytes, int gridSize) async {
  final codec = await ui.instantiateImageCodec(pngBytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final width = image.width;
  final height = image.height;
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final pixels = byteData!.buffer.asUint8List();

  int idxFor(int x, int y) => (y * width + x) * 4;

  final cornerIndices = [
    idxFor(0, 0),
    idxFor(width - 1, 0),
    idxFor(0, height - 1),
    idxFor(width - 1, height - 1),
  ];

  double cornerLuminanceSum = 0;
  int cornerCount = 0;
  for (final idx in cornerIndices) {
    if (idx + 3 < pixels.length) {
      final a = pixels[idx + 3];
      if (a > 20) {
        final r = pixels[idx], g = pixels[idx + 1], b = pixels[idx + 2];
        final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
        cornerLuminanceSum += lum;
        cornerCount++;
      }
    }
  }
  final isLightBackground = cornerCount == 0 || (cornerLuminanceSum / cornerCount) > 0.5;

  final mask = <String>{};
  final cellW = width / gridSize;
  final cellH = height / gridSize;

  for (int r = 0; r < gridSize; r++) {
    for (int c = 0; c < gridSize; c++) {
      final startX = (c * cellW).floor();
      final startY = (r * cellH).floor();
      final endX = ((c + 1) * cellW).floor().clamp(0, width);
      final endY = ((r + 1) * cellH).floor().clamp(0, height);

      int shapePixelCount = 0;
      int totalPixelCount = 0;

      for (int y = startY; y < endY; y++) {
        for (int x = startX; x < endX; x++) {
          final idx = idxFor(x, y);
          final alpha = pixels[idx + 3];
          final rVal = pixels[idx], gVal = pixels[idx + 1], bVal = pixels[idx + 2];
          totalPixelCount++;
          if (alpha < 20) continue;
          final lum = (0.299 * rVal + 0.587 * gVal + 0.114 * bVal) / 255.0;
          if (isLightBackground) {
            if (lum < 0.85 || (rVal < 230 || gVal < 230 || bVal < 230)) shapePixelCount++;
          } else {
            if (lum > 0.2 || (rVal > 30 || gVal > 30 || bVal > 30)) shapePixelCount++;
          }
        }
      }
      if (totalPixelCount > 0 && (shapePixelCount / totalPixelCount) >= 0.20) {
        mask.add('$r,$c');
      }
    }
  }
  return mask;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Real dog.png -> generateLevelWithMask orphan count', () async {
    final data = await rootBundle.load('assets/PNG_Levels/30x30/dog.png');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final mask = await parsePngToGridMaskViaUi(bytes, 30);
    // ignore: avoid_print
    print('Parsed mask cells: ${mask.length} / 900');

    final level = LevelGeneratorV2.generateLevelWithMask(
      levelNumber: 6,
      gridSize: 30,
      mask: mask,
      patternName: 'dog.png',
    );
    // ignore: avoid_print
    print('Level: mask=${level.mask.length} orphans=${level.orphanDots.length} '
        'arrows=${level.arrows.length} patternName=${level.patternName}');

    // The dog.png silhouette has thin limbs that structurally resist
    // zero-orphan packing (confirmed: raising the polish-attempt budget
    // 4x, 15->60, only reduced orphans 11->10 - a search-budget increase
    // isn't the fix). This regression test isn't asserting "must be zero"
    // - it's a canary for real regressions: a working pipeline should
    // still solve the level and keep the orphan count in the same
    // ballpark, not suddenly produce a fallback or a much worse result.
    expect(level.patternName.startsWith('fallback'), isFalse,
        reason: 'Should never fully fall back to the degenerate placeholder '
            'for this shape');
    expect(level.orphanDots.length, lessThan(25),
        reason: 'Orphan count regressed well past the measured baseline (~10-11)');
  });
}
