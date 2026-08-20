import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/tokens.dart';
import '../../leakage/services/baseline_service.dart';
import '../data/usage_repository.dart';
import '../models/app_notification.dart';
import '../models/utility_entry.dart';
import '../services/electricity_baseline_service.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _monthYearLabel(DateTime month) =>
    '${_monthNames[month.month - 1]} ${month.year}';

class UsageState extends ChangeNotifier {
  final UsageRepository _repository;
  final BaselineService _waterBaseline;
  final ElectricityBaselineService _electricityBaseline;

  UsageState({
    UsageRepository? repository,
    BaselineService? waterBaseline,
    ElectricityBaselineService? electricityBaseline,
  })  : _repository = repository ?? UsageRepository(),
        _waterBaseline = waterBaseline ?? BaselineService(),
        _electricityBaseline =
            electricityBaseline ?? ElectricityBaselineService();

  /// Assumed household size used to scale the government's per-capita
  /// figures into a household-comparable monthly total.
  static const int householdSize = 4;
  static const _defaultState = 'Selangor';

  bool _loading = true;
  bool _baselinesLoaded = false;
  String? _error;
  String _selectedState = _defaultState;
  final Map<UtilityType, List<UtilityEntry>> _entries = {
    UtilityType.water: [],
    UtilityType.electricity: [],
  };

  final List<AppNotification> _notifications = [
    AppNotification(
      icon: Icons.warning_amber_rounded,
      color: AppColors.warning,
      bg: AppColors.warningSurface,
      title: 'Bill Due Soon',
      message: 'Your July bill of RM 78.40 is due on 31 Jul 2025.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      showStrip: true,
    ),
    AppNotification(
      icon: Icons.check_circle_outline,
      color: AppColors.success,
      bg: AppColors.successSurface,
      title: 'Usage Down This Month',
      message: 'Great news! Your water usage dropped 3.1% vs last month.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      showStrip: true,
    ),
    AppNotification(
      icon: Icons.info_outline,
      color: AppColors.waterAccent,
      bg: AppColors.waterSurface,
      title: 'Scheduled Maintenance',
      message: 'Water supply interruption on 10 Aug, 9am–12pm.',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
    AppNotification(
      icon: Icons.check_circle_outline,
      color: AppColors.success,
      bg: AppColors.successSurface,
      title: 'Meter Reading Confirmed',
      message: 'Your July meter reading has been recorded successfully.',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  bool get loading => _loading;
  String? get error => _error;
  String get selectedState => _selectedState;

  /// Newest first.
  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications.reversed);

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  /// Whether [selectedState] came from the user's saved service address
  /// (Profile tab) rather than the fallback default.
  bool get hasProfileState =>
      Supabase.instance.client.auth.currentUser?.userMetadata?['service_state'] !=
      null;

  List<String> get states =>
      BaselineService.statePopulation.keys.toList()..sort();

  int get waterBaselineYear => _waterBaseline.latestYear;
  int get electricityBaselineYear => _electricityBaseline.latestYear;

  /// Called after the user saves a new service address so the government
  /// comparison immediately follows their real state.
  void selectState(String state) {
    if (state == _selectedState) return;
    _selectedState = state;
    notifyListeners();
  }

  /// Re-derives [selectedState] from the currently signed-in user's saved
  /// profile, always resetting to the default when they have none set —
  /// otherwise a previous account's state (from earlier in this app
  /// session) would keep showing for a brand-new account.
  void _loadStateFromProfile() {
    final metaState = Supabase
        .instance.client.auth.currentUser?.userMetadata?['service_state'] as String?;
    _selectedState =
        (metaState != null && BaselineService.statePopulation.containsKey(metaState))
            ? metaState
            : _defaultState;
  }

  static DateTime get _currentMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  Future<void> init() async {
    _loadStateFromProfile();
    await Future.wait([
      ...UtilityType.values.map(_reload),
      _loadBaselines(),
    ]);
  }

  Future<void> _loadBaselines() async {
    try {
      await Future.wait([
        _waterBaseline.load(),
        _electricityBaseline.load(),
      ]);
      _baselinesLoaded = true;
    } catch (_) {
      // Government benchmark is a nice-to-have; leave it unavailable.
    }
    notifyListeners();
  }

  /// Government benchmark for [utility] in [month], scaled to a
  /// [householdSize]-person household. Government datasets are annual, so
  /// this is a flat figure repeated across whichever months are requested —
  /// not a real month-to-month series.
  double? governmentMonthlyValue(UtilityType utility, DateTime month) {
    if (!_baselinesLoaded) return null;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    if (utility == UtilityType.water) {
      // expectedHouseholdLPerDay is in liters; entries are logged in m³.
      final litersPerMonth = _waterBaseline.expectedHouseholdLPerDay(
              _selectedState, householdSize) *
          daysInMonth;
      return litersPerMonth / 1000;
    }
    return _electricityBaseline.expectedHouseholdKwhPerDay(
            _selectedState, householdSize) *
        daysInMonth;
  }

  Future<void> _reload(UtilityType utility) async {
    try {
      final entries = await _repository.entriesFor(utility);
      _entries[utility] = entries;
      _error = null;
    } catch (e) {
      _error = 'Could not load $utility usage: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<UtilityEntry> entries(UtilityType utility) =>
      List.unmodifiable(_entries[utility] ?? const []);

  /// Last [count] months of entries, oldest first, for chart/trend display.
  List<UtilityEntry> recent(UtilityType utility, {int count = 6}) {
    final list = entries(utility);
    if (list.length <= count) return list;
    return list.sublist(list.length - count);
  }

  UtilityEntry? entryForMonth(UtilityType utility, DateTime month) {
    for (final e in _entries[utility] ?? const <UtilityEntry>[]) {
      if (e.periodMonth.year == month.year &&
          e.periodMonth.month == month.month) {
        return e;
      }
    }
    return null;
  }

  UtilityEntry? currentMonthEntry(UtilityType utility) =>
      entryForMonth(utility, _currentMonth);

  UtilityEntry? previousMonthEntry(UtilityType utility) => entryForMonth(
      utility, DateTime(_currentMonth.year, _currentMonth.month - 1, 1));

  bool hasCurrentMonthEntry(UtilityType utility) =>
      currentMonthEntry(utility) != null;

  /// This user's own historical average for [utility], excluding the current
  /// (possibly incomplete) month. Falls back to including it if that's all
  /// there is.
  double? average(UtilityType utility) {
    final list = entries(utility);
    if (list.isEmpty) return null;
    final past = list.where((e) {
      final m = _currentMonth;
      return !(e.periodMonth.year == m.year && e.periodMonth.month == m.month);
    }).toList();
    final source = past.isNotEmpty ? past : list;
    return source.map((e) => e.value).reduce((a, b) => a + b) / source.length;
  }

  /// Percent change of current month vs previous month. Null if either is
  /// missing.
  double? percentVsLastMonth(UtilityType utility) {
    final current = currentMonthEntry(utility);
    final previous = previousMonthEntry(utility);
    if (current == null || previous == null || previous.value == 0) {
      return null;
    }
    return (current.value - previous.value) / previous.value * 100;
  }

  /// Percent change of current month vs this user's own average. Null if
  /// either is missing.
  double? percentVsAverage(UtilityType utility) {
    final current = currentMonthEntry(utility);
    final avg = average(utility);
    if (current == null || avg == null || avg == 0) return null;
    return (current.value - avg) / avg * 100;
  }

  Future<void> addEntry({
    required UtilityType utility,
    required double value,
    DateTime? month,
  }) async {
    final resolvedMonth = month ?? _currentMonth;
    await _repository.upsertEntry(
      utility: utility,
      month: resolvedMonth,
      value: value,
    );
    await _reload(utility);
    _notifications.add(AppNotification(
      icon: Icons.check_circle_outline,
      color: AppColors.success,
      bg: AppColors.successSurface,
      title: '${utility.label} Reading Saved',
      message:
          '${_monthYearLabel(resolvedMonth)} was successfully entered.',
      timestamp: DateTime.now(),
      showStrip: true,
    ));
    notifyListeners();
  }
}
