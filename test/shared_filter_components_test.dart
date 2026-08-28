import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/theme/app_tab_bar.dart';
import 'package:mysumber/theme/filter_controls.dart';
import 'package:mysumber/theme/responsive_filter_bar.dart';
import 'package:mysumber/theme/tokens.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
        home: Scaffold(
            body: Padding(
      padding: const EdgeInsets.all(16),
      child: child,
    ))),
  );
}

void main() {
  testWidgets('a search-only bar renders no dropdown row', (tester) async {
    await _pump(
        tester,
        ResponsiveFilterBar(
          mode: ResponsiveFilterBarMode.inline,
          searchController: TextEditingController(),
          onSearchChanged: (_) {},
          searchHint: 'Search workers',
          filters: const [],
        ));

    expect(find.byType(FilterSearchField), findsOneWidget);
    expect(find.byType(FilterDropdown), findsNothing);
    expect(find.text('Search workers'), findsOneWidget);
  });

  testWidgets('every dropdown handed to the bar is rendered', (tester) async {
    await _pump(
        tester,
        ResponsiveFilterBar(
          mode: ResponsiveFilterBarMode.inline,
          searchController: TextEditingController(),
          onSearchChanged: (_) {},
          filters: [
            FilterDropdown(
              caption: 'State',
              value: null,
              allLabel: 'All',
              options: const ['Perlis'],
              onChanged: (_) {},
            ),
            FilterDropdown(
              caption: 'Status',
              value: null,
              allLabel: 'All',
              options: const ['Critical'],
              onChanged: (_) {},
            ),
          ],
        ));

    expect(find.byType(FilterDropdown), findsNWidgets(2));
    expect(find.text('State'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
  });

  testWidgets('the bar defaults its hint and forwards its accent',
      (tester) async {
    await _pump(
        tester,
        ResponsiveFilterBar(
          mode: ResponsiveFilterBarMode.inline,
          searchController: TextEditingController(),
          onSearchChanged: (_) {},
          accent: AppColors.workerPrimary,
          filters: const [],
        ));

    expect(find.text('Type anything to search'), findsOneWidget);
    final field = tester.widget<FilterSearchField>(
      find.byType(FilterSearchField),
    );
    expect(field.accent, AppColors.workerPrimary);
  });

  testWidgets('a tab bar badges every tab with its count', (tester) async {
    final controller = TabController(length: 2, vsync: const TestVSync());
    addTearDown(controller.dispose);

    await _pump(
        tester,
        AppTabBar(
          controller: controller,
          tabs: const [
            (label: 'Unresolved', count: 18),
            (label: 'Resolved', count: 10),
          ],
        ));

    expect(find.text('Unresolved'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.byType(CountBadge), findsNWidgets(2));
    expect(find.text('18'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('a tab bar tints itself from the accent it is given',
      (tester) async {
    final controller = TabController(length: 1, vsync: const TestVSync());
    addTearDown(controller.dispose);

    await _pump(
        tester,
        AppTabBar(
          controller: controller,
          accent: AppColors.workerPrimary,
          tabs: const [(label: 'Water', count: 3)],
        ));

    final bar = tester.widget<TabBar>(find.byType(TabBar));
    expect(bar.labelColor, AppColors.workerPrimary);
    expect(bar.indicatorColor, AppColors.workerPrimary);
  });

  testWidgets('the empty state centres its message in muted text',
      (tester) async {
    await _pump(
        tester, const FilterEmptyState('No alerts match these filters.'));

    expect(find.text('No alerts match these filters.'), findsOneWidget);
    expect(find.byType(Center), findsOneWidget);
    final text = tester.widget<Text>(
      find.text('No alerts match these filters.'),
    );
    expect(text.style?.color, AppColors.textSecondary);
  });

  testWidgets('a pinned filter row survives scrolling its list',
      (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ResponsiveFilterBar(
              mode: ResponsiveFilterBarMode.inline,
              searchController: TextEditingController(),
              onSearchChanged: (_) {},
              searchHint: 'Search workers',
              filters: const [],
            ),
            Expanded(
              child: ListView(
                children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: 60, child: Text('row $i')),
                ],
              ),
            ),
          ],
        ),
      ),
    ));

    expect(find.text('Search workers'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pump();

    // The filter is a sibling of the scrollable, not a child, so dragging
    // the list cannot move it off screen.
    expect(find.text('Search workers'), findsOneWidget);
  });
}
