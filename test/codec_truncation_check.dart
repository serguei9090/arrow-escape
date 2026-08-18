import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/data/level_generator/level_generator_v2.dart';
import 'package:arrow_escape/data/level_binary_codec.dart';

void main() {
  test('long patternName does not corrupt the level record', () {
    final base = LevelGeneratorV2.generateLevel(10);
    final longName = 'x' * 300 + 'END';
    final level = base.copyWith(patternName: longName);

    final encoded = encodeLevels([level]);
    final decoder = LevelBinaryDecoder.fromBytes(encoded);
    final decoded = decoder.decodeLevelByNumber(1)!;

    expect(decoded.patternName.length, lessThanOrEqualTo(255));
    // must decode as valid UTF-8 with no exception (already implied by not throwing above)
    // and every field after patternName must survive intact
    expect(decoded.gridSize, level.gridSize);
    expect(decoded.arrows.length, level.arrows.length);
    expect(decoded.mask.length, level.mask.length);
    expect(decoded.orphanDots.length, level.orphanDots.length);
  });

  test('multi-byte patternName near the boundary does not split a character', () {
    // emoji are 4-byte UTF-8 sequences
    final base = LevelGeneratorV2.generateLevel(11);
    final longName = ('a' * 252) + 'X' + '\u{1F600}' * 5; // crosses byte 255 mid-emoji
    final level = base.copyWith(patternName: longName);

    final encoded = encodeLevels([level]);
    final decoder = LevelBinaryDecoder.fromBytes(encoded);
    final decoded = decoder.decodeLevelByNumber(1)!;

    // Must not throw and must be valid decodable UTF-8 (already implied above).
    expect(decoded.patternName.length, greaterThan(0));
    expect(decoded.gridSize, level.gridSize);
  });
}
