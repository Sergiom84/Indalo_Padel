import 'package:flutter_test/flutter_test.dart';
import 'package:indalo_padel/core/api/api_client.dart';

void main() {
  test('resolveBaseUrl returns a usable default', () {
    expect(resolveBaseUrl(), isNotEmpty);
  });
}
