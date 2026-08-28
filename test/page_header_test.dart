import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/theme/page_header.dart';

void main() {
  testWidgets('keeps Admin brand, title, logout, and action aligned',
      (tester) async {
    var logoutCount = 0;
    var actionCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageHeader(
            title: 'Inventory',
            onLogout: () => logoutCount++,
            action: AdminHeaderAction(
              icon: Icons.upload_outlined,
              label: 'Import',
              onPressed: () => actionCount++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('mySumber · ADMIN'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    expect(logoutCount, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import'));
    expect(logoutCount, 1);
    expect(actionCount, 1);
  });

  testWidgets('keeps the same header contract in compact landscape mode',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageHeader(
            title: 'Abnormal Production',
            icon: Icons.analytics_outlined,
            compact: true,
            onLogout: () {},
          ),
        ),
      ),
    );

    expect(find.text('mySumber · ADMIN'), findsOneWidget);
    expect(find.text('Abnormal Production'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });

  testWidgets('automatically uses compact geometry in phone landscape',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PageHeader(
              title: 'Worker Accounts',
              icon: Icons.manage_accounts_outlined,
              onLogout: () {},
            ),
          ),
        ),
      ),
    );

    final headerIcon =
        tester.widget<Icon>(find.byIcon(Icons.manage_accounts_outlined));
    expect(headerIcon.size, 22);
  });

  testWidgets('keeps compact landscape header on the shared content edge',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(
      left: 48,
      right: 48,
      top: 28,
    );
    tester.view.viewPadding = const FakeViewPadding(
      left: 48,
      right: 48,
      top: 28,
    );
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageHeader(
            title: 'Dashboard',
            icon: Icons.grid_view_outlined,
            compact: true,
            onLogout: () {},
          ),
        ),
      ),
    );

    final brand = tester.getRect(find.text('mySumber · ADMIN'));
    expect(brand.left, closeTo(16.0, 0.1));
  });

  testWidgets(
      'keeps compact landscape header height consistent with or without actions',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                PageHeader(
                  title: 'Abnormal Production',
                  icon: Icons.notifications_outlined,
                  compact: true,
                  onLogout: () {},
                ),
                PageHeader(
                  title: 'Dashboard',
                  icon: Icons.grid_view_outlined,
                  compact: true,
                  onLogout: () {},
                  action: AdminHeaderAction(
                    icon: Icons.unfold_more,
                    label: 'View full',
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final headers = find.byType(PageHeader);
    final actionlessHeight = tester.getRect(headers.at(0)).height;
    final actionHeight = tester.getRect(headers.at(1)).height;
    expect(actionlessHeight, closeTo(actionHeight, 0.1));
  });

  testWidgets('renders secondary actions as outlined header controls',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminHeaderAction(
            icon: Icons.upload_outlined,
            label: 'Import',
            secondary: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find
          .ancestor(
            of: find.text('Import'),
            matching: find.byType(Material),
          )
          .first,
    );
    final shape = material.shape! as StadiumBorder;
    expect(material.color, Colors.transparent);
    expect(shape.side.color, Colors.white.withValues(alpha: 0.55));
  });

  testWidgets('fixes compact landscape title row height for taller actions',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                PageHeader(
                  title: 'Alerts',
                  icon: Icons.notifications_outlined,
                  compact: true,
                  onLogout: () {},
                ),
                PageHeader(
                  title: 'Inventory',
                  icon: Icons.inventory_2_outlined,
                  compact: true,
                  onLogout: () {},
                  action: const SizedBox(width: 120, height: 48),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final headers = find.byType(PageHeader);
    expect(
      tester.getRect(headers.at(0)).height,
      closeTo(tester.getRect(headers.at(1)).height, 0.1),
    );
  });

  testWidgets('portrait header trims its vertical padding', (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PageHeader(
                title: 'Anomalies',
                icon: Icons.notifications_outlined,
                onLogout: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.getRect(find.byType(PageHeader)).height, 112.0);
    expect(find.text('Anomalies'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });
}
