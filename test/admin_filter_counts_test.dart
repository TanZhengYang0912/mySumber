import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/theme/responsive_filter_bar.dart';

void main() {
  test('counts only narrowed anomaly filters', () {
    expect(
      countActiveFilters(
        query: '  ',
        filters: const [false, false, false, false],
      ),
      0,
    );
    expect(
      countActiveFilters(
        query: 'Sabah',
        filters: const [true, true, true, true],
      ),
      5,
    );
  });

  test('counts only narrowed Mall filters with the shared counter', () {
    expect(
      countActiveFilters(query: '  ', filters: const [false, false, false]),
      0,
    );
    expect(
      countActiveFilters(query: 'Sunway', filters: const [false, false, false]),
      1,
    );
    expect(
      countActiveFilters(query: ' Sunway ', filters: const [true, true, true]),
      4,
    );
  });
}
