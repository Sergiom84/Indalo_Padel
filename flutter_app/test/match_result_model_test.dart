import 'package:flutter_test/flutter_test.dart';
import 'package:indalo_padel/features/community/models/match_result_model.dart';

void main() {
  group('SetScore contract', () {
    test('keeps two-digit tie-break values through parse and serialization',
        () {
      final score = SetScore.fromJson({
        'a': 7,
        'b': 6,
        'tie_break_a': 12,
        'tie_break_b': 10,
      });

      expect(score.hasTieBreak, isTrue);
      expect(score.winnerSide, 1);
      expect(score.displayLabel, '7-6 (12-10)');
      expect(score.toJson(), {
        'a': 7,
        'b': 6,
        'tie_break_a': 12,
        'tie_break_b': 10,
      });
    });
  });
}
