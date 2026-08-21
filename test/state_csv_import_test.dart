import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/dataset/services/state_csv_import.dart';

void main() {
  test('detects water production by its three-column header', () {
    final result = parseStateCsv(
      'state,date,value\n'
      'Perlis,2022-01-01,243\n'
      'Sabah,2022-01-01,1404\n',
    );

    expect(result.kind, StateCsvKind.waterProduction);
    expect(result.rows, hasLength(2));
    expect(result.rows.first.state, 'Perlis');
    expect(result.rows.first.value, 243);
    expect(result.rows.first.sector, isNull);
    expect(result.stateCount, 2);
  });

  test('water consumption puts sector second', () {
    final result = parseStateCsv(
      'state,sector,date,value\n'
      'Perlis,domestic,2022-01-01,98\n',
    );

    expect(result.kind, StateCsvKind.waterConsumption);
    expect(result.rows.single.sector, 'domestic');
    expect(result.rows.single.value, 98);
  });

  test('electricity files put sector third', () {
    final supply = parseStateCsv(
      'state,date,sector,supply\n'
      'Kelantan,2018-01-01,total,1112.83\n',
    );
    expect(supply.kind, StateCsvKind.electricitySupply);
    expect(supply.rows.single.sector, 'total');
    expect(supply.rows.single.value, closeTo(1112.83, 0.001));

    final consumption = parseStateCsv(
      'state,date,sector,consumption\n'
      'Kelantan,2018-01-01,total,976.31\n',
    );
    expect(consumption.kind, StateCsvKind.electricityConsumption);
  });

  test('an unrecognised header is rejected outright', () {
    expect(
      () => parseStateCsv('foo,bar\n1,2\n'),
      throwsA(isA<FormatException>()),
    );
  });

  test('a malformed row is collected as an error, not thrown', () {
    final result = parseStateCsv(
      'state,date,value\n'
      'Perlis,2022-01-01,243\n'
      'Sabah,not-a-date,1404\n'
      'Kedah,2022-01-01,not-a-number\n',
    );

    expect(result.rows, hasLength(1));
    expect(result.errors, hasLength(2));
    expect(result.errors.first, contains('3'));
  });

  test('blank trailing lines are ignored', () {
    final result =
        parseStateCsv('state,date,value\nPerlis,2022-01-01,243\n\n\n');
    expect(result.rows, hasLength(1));
    expect(result.errors, isEmpty);
  });
}
