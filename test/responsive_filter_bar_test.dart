import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/theme/filter_controls.dart';
import 'package:mysumber/theme/responsive_filter_bar.dart';
import 'package:mysumber/theme/tokens.dart';

Future<void> pumpBar(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

FilterDropdown dropdown(String caption, Key key) => FilterDropdown(
      key: key,
      caption: caption,
      value: null,
      allLabel: 'All',
      options: const ['One'],
      onChanged: (_) {},
    );

void main() {
  test('counts search plus active dropdowns', () {
    expect(
      countActiveFilters(query: ' Sabah ', filters: const [true, false, true]),
      3,
    );
    expect(
      countActiveFilters(query: '   ', filters: const [false, false]),
      0,
    );
  });

  testWidgets('four filters render as two equal rows', (tester) async {
    await pumpBar(
      tester,
      FilterDropdownGrid(children: [
        dropdown('State', const Key('state')),
        dropdown('Severity', const Key('severity')),
        dropdown('Status', const Key('status')),
        dropdown('Utility', const Key('utility')),
      ]),
    );

    expect(tester.getSize(find.byKey(const Key('state'))).width,
        tester.getSize(find.byKey(const Key('severity'))).width);
    expect(tester.getTopLeft(find.byKey(const Key('state'))).dy,
        tester.getTopLeft(find.byKey(const Key('severity'))).dy);
    expect(tester.getTopLeft(find.byKey(const Key('status'))).dy,
        tester.getTopLeft(find.byKey(const Key('utility'))).dy);
  });

  testWidgets('third filter spans the full second row', (tester) async {
    await pumpBar(
      tester,
      FilterDropdownGrid(children: [
        dropdown('State', const Key('state')),
        dropdown('Outcome', const Key('outcome')),
        dropdown('Utility', const Key('utility')),
      ]),
    );

    final half = tester.getSize(find.byKey(const Key('state'))).width;
    final full = tester.getSize(find.byKey(const Key('utility'))).width;
    expect(full, closeTo(half * 2 + 8, 0.1));
  });

  testWidgets('search-only inline mode has no grid or clear icon',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpBar(
      tester,
      ResponsiveFilterBar(
        mode: ResponsiveFilterBarMode.inline,
        searchController: controller,
        onSearchChanged: (_) {},
        filters: const [],
        searchHint: 'Search workers',
      ),
    );

    expect(find.byType(FilterSearchField), findsOneWidget);
    expect(find.byType(FilterDropdownGrid), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('inline mode leaves spacing below to the consuming list',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpBar(
      tester,
      ResponsiveFilterBar(
        mode: ResponsiveFilterBarMode.inline,
        searchController: controller,
        onSearchChanged: (_) {},
        filters: const [],
      ),
    );

    final outerPadding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byType(ResponsiveFilterBar),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(outerPadding.padding, const EdgeInsets.fromLTRB(16, 16, 16, 0));
  });

  testWidgets('menu mode hides controls until Filters opens', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpBar(
      tester,
      Align(
        alignment: Alignment.topRight,
        child: ResponsiveFilterBar(
          mode: ResponsiveFilterBarMode.menu,
          searchController: controller,
          onSearchChanged: (_) {},
          filters: [dropdown('State', const Key('state'))],
          activeFilterCount: 2,
          accent: AppColors.workerPrimary,
        ),
      ),
    );

    expect(find.byType(FilterSearchField), findsNothing);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.byType(FilterSearchField), findsOneWidget);
    expect(find.text('State'), findsOneWidget);
  });
}
