import 'package:csv/csv.dart';

/// The four government dataset shapes this app ships in `assets/`. Their
/// columns are not consistently ordered, so the header row identifies the
/// file before its rows are read.
enum StateCsvKind {
  waterProduction,
  waterConsumption,
  electricitySupply,
  electricityConsumption,
}

extension StateCsvKindLabel on StateCsvKind {
  String get label => switch (this) {
        StateCsvKind.waterProduction => 'Water production',
        StateCsvKind.waterConsumption => 'Water consumption',
        StateCsvKind.electricitySupply => 'Electricity supply',
        StateCsvKind.electricityConsumption => 'Electricity consumption',
      };
}

class StateCsvRow {
  final String state;
  final DateTime date;
  final String? sector;
  final double value;

  const StateCsvRow({
    required this.state,
    required this.date,
    required this.value,
    this.sector,
  });
}

class StateCsvResult {
  final StateCsvKind kind;
  final List<StateCsvRow> rows;

  /// One human-readable line per rejected row, with its 1-based line number.
  final List<String> errors;

  const StateCsvResult({
    required this.kind,
    required this.rows,
    required this.errors,
  });

  int get stateCount => rows.map((row) => row.state).toSet().length;

  DateTime? get earliest => rows.isEmpty
      ? null
      : rows.map((row) => row.date).reduce(
            (a, b) => a.isBefore(b) ? a : b,
          );

  DateTime? get latest => rows.isEmpty
      ? null
      : rows.map((row) => row.date).reduce(
            (a, b) => a.isAfter(b) ? a : b,
          );
}

const _headers =
    <String, ({StateCsvKind kind, int date, int value, int? sector})>{
  'state,date,value': (
    kind: StateCsvKind.waterProduction,
    date: 1,
    value: 2,
    sector: null,
  ),
  'state,sector,date,value': (
    kind: StateCsvKind.waterConsumption,
    date: 2,
    value: 3,
    sector: 1,
  ),
  'state,date,sector,supply': (
    kind: StateCsvKind.electricitySupply,
    date: 1,
    value: 3,
    sector: 2,
  ),
  'state,date,sector,consumption': (
    kind: StateCsvKind.electricityConsumption,
    date: 1,
    value: 3,
    sector: 2,
  ),
};

/// Parses a government state CSV for preview only. It does not read paths or
/// persist rows; callers provide the already-selected file contents.
StateCsvResult parseStateCsv(String csv) {
  final table = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
      .convert(csv);
  if (table.isEmpty) {
    throw const FormatException('The file is empty.');
  }

  final headerKey =
      table.first.map((cell) => cell.toString().trim().toLowerCase()).join(',');
  final spec = _headers[headerKey];
  if (spec == null) {
    throw FormatException(
      'Unrecognised header "$headerKey". Expected one of: '
      '${_headers.keys.join(" | ")}',
    );
  }

  final rows = <StateCsvRow>[];
  final errors = <String>[];

  for (var index = 1; index < table.length; index++) {
    final raw = table[index];
    final lineNumber = index + 1;
    if (raw.isEmpty ||
        (raw.length == 1 && raw.first.toString().trim().isEmpty)) {
      continue;
    }
    if (raw.length <= spec.value) {
      errors.add('Line $lineNumber: expected ${spec.value + 1} columns, '
          'found ${raw.length}.');
      continue;
    }

    final state = raw[0].toString().trim();
    if (state.isEmpty) {
      errors.add('Line $lineNumber: state is blank.');
      continue;
    }

    final date = DateTime.tryParse(raw[spec.date].toString().trim());
    if (date == null) {
      errors.add('Line $lineNumber: "${raw[spec.date]}" is not a date.');
      continue;
    }

    final value = double.tryParse(raw[spec.value].toString().trim());
    if (value == null) {
      errors.add('Line $lineNumber: "${raw[spec.value]}" is not a number.');
      continue;
    }

    rows.add(StateCsvRow(
      state: state,
      date: date,
      value: value,
      sector: spec.sector == null ? null : raw[spec.sector!].toString().trim(),
    ));
  }

  return StateCsvResult(kind: spec.kind, rows: rows, errors: errors);
}
