import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/theme/compact_rail_layout.dart';

void main() {
  test('no destinations produce no offsets', () {
    expect(compactRailTops(height: 300, count: 0), isEmpty);
  });

  test('a single destination sits dead centre', () {
    final tops = compactRailTops(height: 300, count: 1);

    expect(tops, hasLength(1));
    expect(tops.single, (300 - 54) / 2);
  });

  test('a group is centred as a whole, not spread', () {
    // 3 x 54 + 2 x 8 spacing = 178 tall, so 61 of slack above and below.
    final tops = compactRailTops(height: 300, count: 3);

    expect(tops, [61.0, 123.0, 185.0]);
    expect(tops.first, 300 - (tops.last + 54));
  });

  test('spacing between destinations stays constant', () {
    final tops = compactRailTops(height: 400, count: 5);

    for (var i = 1; i < tops.length; i++) {
      expect(tops[i] - tops[i - 1], 54 + 8);
    }
  });

  test('a group blocked by a centred cutout moves clear of it', () {
    // 500 tall, not 300: a 178-tall group needs somewhere clear to land, and
    // a 300-tall rail has no run of 178 either side of a cutout at 130-170.
    const cutout = Rect.fromLTRB(0, 130, 40, 170);
    final tops = compactRailTops(height: 500, count: 3, cutout: cutout);

    for (final top in tops) {
      final destination = Rect.fromLTRB(0, top, 1, top + 54);
      expect(
        destination.overlaps(const Rect.fromLTRB(0, 128, 1, 172)),
        isFalse,
        reason: 'destination at $top still sits under the cutout',
      );
    }
  });

  test('the group keeps its rhythm after dodging a cutout', () {
    const cutout = Rect.fromLTRB(0, 130, 40, 170);
    final tops = compactRailTops(height: 400, count: 3, cutout: cutout);

    expect(tops[1] - tops[0], 54 + 8);
    expect(tops[2] - tops[1], 54 + 8);
  });

  test('a cutout near the top pushes the group down, not up', () {
    // Reaches 130 so it genuinely overlaps the centred group at 111; a
    // shallower cutout would never collide and the test would pass vacuously.
    const cutout = Rect.fromLTRB(0, 0, 40, 130);
    final tops = compactRailTops(height: 400, count: 3, cutout: cutout);

    expect(tops.first, greaterThanOrEqualTo(130));
  });

  test('a cutout that cannot be cleared still yields ordered offsets', () {
    const cutout = Rect.fromLTRB(0, 0, 40, 300);
    final tops = compactRailTops(height: 300, count: 3, cutout: cutout);

    expect(tops, hasLength(3));
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]));
    }
  });

  test('a rail too short for its group pins to the top inset', () {
    final tops = compactRailTops(height: 100, count: 3);

    expect(tops.first, 8);
    expect(tops, [8.0, 70.0, 132.0]);
  });

  test('insets bound the group', () {
    final tops = compactRailTops(
      height: 300,
      count: 1,
      topInset: 100,
      bottomInset: 100,
    );

    expect(tops.single, greaterThanOrEqualTo(100));
    expect(tops.single + 54, lessThanOrEqualTo(200));
  });
}
