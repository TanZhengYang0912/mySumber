import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../models/utility_entry.dart';
import '../services/customer_compact_layout.dart';
import '../state/usage_state.dart';

Color _accentFor(UtilityType utility) => utility == UtilityType.water
    ? AppColors.waterAccent
    : AppColors.electricityAccent;

IconData _iconFor(UtilityType utility) => utility == UtilityType.water
    ? Icons.water_drop_outlined
    : Icons.electric_bolt_outlined;

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _monthYearLabel(DateTime month) =>
    '${_monthNames[month.month - 1]} ${month.year}';

/// Entry point for every "Add +" affordance. If [utility] is omitted the
/// user first picks water or electricity, then enters this month's reading.
Future<void> showAddConsumptionFlow(BuildContext context,
    {UtilityType? utility}) async {
  final chosen = utility ?? await _pickUtility(context);
  if (chosen == null || !context.mounted) return;
  await _promptValue(context, chosen);
}

Future<UtilityType?> _pickUtility(BuildContext context) {
  return showModalBottomSheet<UtilityType>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add consumption',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Choose a utility to log a monthly reading',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _utilityChoiceCard(ctx, UtilityType.water),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _utilityChoiceCard(ctx, UtilityType.electricity),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _utilityChoiceCard(BuildContext context, UtilityType utility) {
  final accent = _accentFor(utility);
  return Material(
    color: accent.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).pop(utility),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(_iconFor(utility), color: accent, size: 28),
            const SizedBox(height: 8),
            Text(utility.label,
                style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ],
        ),
      ),
    ),
  );
}

Future<void> _promptValue(BuildContext context, UtilityType utility) async {
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => _ValueEntryDialog(utility: utility),
  );
}

class _ValueEntryDialog extends StatefulWidget {
  final UtilityType utility;
  const _ValueEntryDialog({required this.utility});

  @override
  State<_ValueEntryDialog> createState() => _ValueEntryDialogState();
}

class _ValueEntryDialogState extends State<_ValueEntryDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedMonth;
  late final DateTime _maxMonth;
  late final DateTime _minMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _maxMonth = _selectedMonth;
    _minMonth = DateTime(now.year - 5, 1, 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickMonth() async {
    var picked = _selectedMonth;
    final isPhoneLandscape =
        usesCustomerPhoneLandscape(MediaQuery.sizeOf(context));
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: isPhoneLandscape,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                isPhoneLandscape ? 10 : 16,
                8,
                isPhoneLandscape ? 0 : 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select month',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  TextButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: isPhoneLandscape ? 176 : 216,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.monthYear,
                initialDateTime: _selectedMonth,
                minimumDate: _minMonth,
                maximumDate: _maxMonth,
                onDateTimeChanged: (d) => picked = DateTime(d.year, d.month, 1),
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() => _selectedMonth = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final value = double.parse(_controller.text.trim());
    final month = _selectedMonth;
    final usage = context.read<UsageState>();
    final rootContext = context;
    Navigator.of(context).pop();
    try {
      await usage.addEntry(
        utility: widget.utility,
        value: value,
        month: month,
      );
      if (rootContext.mounted) {
        ScaffoldMessenger.of(rootContext).showSnackBar(SnackBar(
          content: Text(
            '${widget.utility.label} usage for ${_monthYearLabel(month)} saved: '
            '${value.toStringAsFixed(1)} ${widget.utility.unit}',
          ),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (rootContext.mounted) {
        ScaffoldMessenger.of(rootContext).showSnackBar(SnackBar(
          content: Text('Could not save reading: $e'),
          backgroundColor: AppColors.critical,
        ));
      }
    }
  }

  Widget _saveButton(Color accent, bool isDuplicate, {bool compact = false}) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        minimumSize: compact ? const Size(0, 40) : null,
      ),
      onPressed: isDuplicate ? null : _save,
      child: const Text('Save'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final utility = widget.utility;
    final accent = _accentFor(utility);
    final existing =
        context.watch<UsageState>().entryForMonth(utility, _selectedMonth);
    final isDuplicate = existing != null;
    final isPhoneLandscape =
        usesCustomerPhoneLandscape(MediaQuery.sizeOf(context));

    return AlertDialog(
      insetPadding: isPhoneLandscape
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: isPhoneLandscape
          ? const EdgeInsets.fromLTRB(20, 14, 20, 0)
          : null,
      contentPadding: isPhoneLandscape
          ? const EdgeInsets.fromLTRB(20, 8, 20, 4)
          : null,
      actionsPadding: isPhoneLandscape
          ? const EdgeInsets.fromLTRB(12, 0, 12, 10)
          : null,
      title: Row(
        children: [
          Icon(_iconFor(utility), color: accent, size: 20),
          const SizedBox(width: 8),
          Text('Add ${utility.label} Reading'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Month',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            SizedBox(height: isPhoneLandscape ? 4 : 6),
            Material(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickMonth,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: isPhoneLandscape ? 8 : 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 18, color: accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _monthYearLabel(_selectedMonth),
                          style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                        ),
                      ),
                      Icon(Icons.unfold_more, size: 18, color: accent),
                    ],
                  ),
                ),
              ),
            ),
            if (isDuplicate) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: Color(0xFFC2410C)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You already logged ${existing.value.toStringAsFixed(1)} ${utility.unit} for '
                        '${_monthYearLabel(_selectedMonth)}. Edit it from the Usage tab\'s record log instead.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9A3412),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(height: isPhoneLandscape ? 10 : 16),
              if (isPhoneLandscape) ...[
                const Text(
                  'Usage',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              TextFormField(
                controller: _controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isPhoneLandscape ? null : 'Usage',
                  hintText: isPhoneLandscape ? 'Enter usage' : null,
                  suffixText: utility.unit,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accent),
                  ),
                ),
                validator: (v) {
                  final value = double.tryParse((v ?? '').trim());
                  if (value == null) return 'Enter a valid number';
                  if (value < 0) return 'Must be zero or more';
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (isPhoneLandscape)
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              SizedBox(
                width: 112,
                child: _saveButton(accent, isDuplicate, compact: true),
              ),
            ],
          )
        else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          _saveButton(accent, isDuplicate),
        ],
      ],
    );
  }
}

/// Green circular FAB used on both Home and Usage tabs.
class AddConsumptionFab extends StatelessWidget {
  final UtilityType? utility;
  const AddConsumptionFab({super.key, this.utility});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: AppColors.success,
      foregroundColor: Colors.white,
      onPressed: () => showAddConsumptionFlow(context, utility: utility),
      icon: const Icon(Icons.add),
      label: const Text('Add',
          style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
