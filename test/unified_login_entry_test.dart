import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mysumber/modules/auth/data/account_repository.dart';
import 'package:mysumber/modules/auth/models/account_profile.dart';
import 'package:mysumber/modules/auth/screens/login_screen.dart';
import 'package:mysumber/modules/auth/screens/register_screen.dart';
import 'package:mysumber/modules/auth/state/auth_state.dart';
import 'package:mysumber/theme/tokens.dart';

class _NoopAccountRepository extends AccountRepository {
  _NoopAccountRepository() : super(client: Supabase.instance.client);

  @override
  Future<AccountProfile?> currentProfile(String userId) async => null;
}

class _NoopPkceStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async => null;

  @override
  Future<void> setItem({required String key, required String value}) async {}

  @override
  Future<void> removeItem({required String key}) async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _NoopPkceStorage(),
      ),
    );
  });

  testWidgets('opens one shared login form without role-selection cards',
      (tester) async {
    final roleState = RoleState(accountRepository: _NoopAccountRepository());
    addTearDown(roleState.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<RoleState>.value(
        value: roleState,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Continue as:'), findsNothing);
    expect(find.text('Administrator'), findsNothing);
    expect(find.text('Worker'), findsNothing);
    expect(find.text('Customer'), findsNothing);
  });

  testWidgets('asks for confirmation before exiting the login screen',
      (tester) async {
    final roleState = RoleState(accountRepository: _NoopAccountRepository());
    addTearDown(roleState.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<RoleState>.value(
        value: roleState,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Exit mySumber?'), findsOneWidget);
    expect(find.text('Are you sure you want to exit the app?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Exit mySumber?'), findsNothing);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('asks for confirmation when the system back button is used',
      (tester) async {
    final roleState = RoleState(accountRepository: _NoopAccountRepository());
    addTearDown(roleState.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<RoleState>.value(
        value: roleState,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Exit mySumber?'), findsOneWidget);
    expect(find.text('Are you sure you want to exit the app?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Exit mySumber?'), findsNothing);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('keeps register branding aligned with login', (tester) async {
    final roleState = RoleState(accountRepository: _NoopAccountRepository());
    addTearDown(roleState.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<RoleState>.value(
        value: roleState,
        child: MaterialApp(
          home: RegisterScreen(onBack: () {}),
        ),
      ),
    );
    await tester.pump();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, AppColors.adminPrimary);
    expect(find.byIcon(Icons.water_drop_rounded), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });
}
