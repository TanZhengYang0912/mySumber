import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mysumber/modules/admin/data/worker_repository.dart';
import 'package:mysumber/modules/admin/models/worker_account.dart';
import 'package:mysumber/modules/admin/screens/worker_accounts_screen.dart';

void main() {
  testWidgets('worker invite validates the full name', (tester) async {
    final repository = _WorkerRepository();
    await _pumpScreen(tester, repository);

    await _submitInvite(tester, name: '', email: 'worker@mysumber.my');

    expect(find.text("Enter the worker's full name."), findsOneWidget);
    expect(repository.manageCalls, 0);
  });

  testWidgets('worker invite validates a complete work email', (tester) async {
    final repository = _WorkerRepository();
    await _pumpScreen(tester, repository);

    await _submitInvite(tester, name: 'Worker One', email: 'worker@invalid');

    expect(find.text('Enter a valid work email.'), findsOneWidget);
    expect(repository.manageCalls, 0);
  });

  testWidgets('worker invite explains duplicate accounts', (tester) async {
    final repository = _WorkerRepository(
      error: StateError('A user with this email already exists'),
    );
    await _pumpScreen(tester, repository);

    await _submitInvite(
      tester,
      name: 'Worker One',
      email: 'worker@mysumber.my',
    );

    expect(
      find.text('A worker account with this email already exists.'),
      findsOneWidget,
    );
    expect(repository.manageCalls, 1);
  });

  testWidgets('worker invite gives an actionable generic error',
      (tester) async {
    final repository = _WorkerRepository(error: StateError('socket failed'));
    await _pumpScreen(tester, repository);

    await _submitInvite(
      tester,
      name: 'Worker One',
      email: 'worker@mysumber.my',
    );

    expect(
      find.text(
          'Could not invite worker. Check your connection and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('successful worker invite preserves details and refreshes',
      (tester) async {
    final repository = _WorkerRepository();
    await _pumpScreen(tester, repository);

    await _submitInvite(
      tester,
      name: 'Worker One',
      email: 'WORKER@MYSUMBER.MY',
    );

    expect(repository.lastFullName, 'Worker One');
    expect(repository.lastEmail, 'worker@mysumber.my');
    expect(repository.listCalls, 2);
    expect(
      find.textContaining('Worker invited. They can log in with '
          'worker@mysumber.my'),
      findsOneWidget,
    );
  });

  testWidgets('cancelling a worker invite is silent', (tester) async {
    final repository = _WorkerRepository();
    await _pumpScreen(tester, repository);

    await tester.tap(find.text('Add worker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(repository.manageCalls, 0);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _WorkerRepository repository,
) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: WorkerAccountsScreen(repository: repository)),
  );
  await tester.pumpAndSettle();
}

Future<void> _submitInvite(
  WidgetTester tester, {
  required String name,
  required String email,
}) async {
  await tester.tap(find.text('Add worker'));
  await tester.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );
  if (name.isNotEmpty) await tester.enterText(fields.at(0), name);
  if (email.isNotEmpty) await tester.enterText(fields.at(1), email);
  await tester.tap(find.text('Send invite'));
  await tester.pumpAndSettle();
}

class _WorkerRepository extends WorkerRepository {
  _WorkerRepository({this.error})
      : super(
          client: SupabaseClient(
            'https://example.supabase.co',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final Object? error;
  int manageCalls = 0;
  int listCalls = 0;
  String? lastFullName;
  String? lastEmail;

  @override
  Future<List<WorkerAccount>> listWorkers() async {
    listCalls += 1;
    return const [];
  }

  @override
  Future<void> manage({
    required String action,
    String? workerId,
    String? fullName,
    String? email,
  }) async {
    manageCalls += 1;
    lastFullName = fullName;
    lastEmail = email;
    if (error != null) throw error!;
  }
}
