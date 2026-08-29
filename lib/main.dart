import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/local_database/cache_status.dart';
import 'core/local_database/local_database.dart';
import 'core/local_database/offline_status_banner.dart';
import 'theme/tokens.dart';

import 'modules/admin/screens/abnormal_production_screen.dart';
import 'modules/admin/screens/oversight_screen.dart';
import 'modules/admin/screens/worker_accounts_screen.dart';
import 'modules/admin/services/admin_tablet_layout.dart';
import 'modules/admin/widgets/admin_compact_rail.dart';

import 'modules/auth/data/account_repository.dart';
import 'modules/auth/screens/login_screen.dart';
import 'modules/auth/screens/reset_password_screen.dart';
import 'modules/auth/state/auth_state.dart' show RoleState;
import 'modules/auth/widgets/exit_confirmation_scope.dart';

import 'modules/leakage/data/leakage_repository.dart';
import 'modules/leakage/models/alert.dart' show Utility;
import 'modules/leakage/screens/alert_queue_screen.dart';
import 'modules/leakage/screens/report_history_screen.dart';
import 'modules/leakage/services/baseline_service.dart';
import 'modules/leakage/services/anomaly_ai_service.dart';
import 'modules/leakage/services/nrw_service.dart';
import 'modules/leakage/services/simulation_service.dart';
import 'modules/leakage/services/worker_compact_layout.dart';
import 'modules/leakage/state/app_state.dart';
import 'modules/leakage/widgets/worker_compact_rail.dart';

import 'modules/dataset/data/dataset_repository.dart';
import 'modules/dataset/screens/dashboard_screen.dart';
import 'modules/dataset/screens/inventory_screen.dart';
import 'modules/dataset/state/dataset_state.dart';

import 'modules/usage/screens/customer_home_screen.dart';
import 'modules/usage/screens/compare_usage_screen.dart';
import 'modules/usage/screens/profile_setup_screen.dart';
import 'modules/usage/screens/report_problem_screen.dart';
import 'modules/usage/data/usage_repository.dart';
import 'modules/usage/services/customer_compact_layout.dart';
import 'modules/usage/services/local_notification_service.dart';
import 'modules/usage/state/usage_state.dart';
import 'modules/usage/widgets/customer_compact_rail.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://tnmznkdvrrpigevxdfet.supabase.co',
    publishableKey: 'sb_publishable_rPQeDFFfv1HQoYnqN2g9QQ_bLBVlaZE',
  );
  await LocalNotificationService.instance.init();
  runApp(MySumberApp(
    // Drift's web backend needs sqlite3.wasm and drift_worker.js served from
    // web/, and driftDatabase() throws ArgumentError outright when its `web:`
    // option is missing. A browser already needs the network to reach
    // Supabase, so the offline cache earns nothing there — skip it and let the
    // repositories run in their online-only mode.
    database: kIsWeb ? null : LocalDatabase.defaults(),
    cacheStatus: CacheStatus(),
  ));
}

class MySumberApp extends StatelessWidget {
  const MySumberApp({
    super.key,
    required this.database,
    required this.cacheStatus,
  });

  /// Null on web, where Drift cannot open a database without wasm assets.
  /// Every repository below treats a null database as "online only".
  final LocalDatabase? database;
  final CacheStatus cacheStatus;

  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Nullable because web has no local database. Nothing reads this
        // provider today; it stays exposed for the offline work on main.
        Provider<LocalDatabase?>.value(value: database),
        ChangeNotifierProvider<CacheStatus>.value(value: cacheStatus),
        ChangeNotifierProvider<RoleState>(
          create: (_) {
            final localDatabase = database;
            final roleState = RoleState(
              accountRepository: localDatabase == null
                  ? AccountRepository(client: Supabase.instance.client)
                  : AccountRepository.cached(
                      client: Supabase.instance.client,
                      database: localDatabase,
                      cacheStatus: cacheStatus,
                    ),
            );
            roleState.checkExistingSession();
            return roleState;
          },
        ),
        ChangeNotifierProvider<AppState>(
          create: (_) {
            final baseline = BaselineService();
            final nrw = NrwService();
            final localDatabase = database;
            final repository = localDatabase == null
                ? LeakageRepository(Supabase.instance.client)
                : LeakageRepository.cached(
                    client: Supabase.instance.client,
                    database: localDatabase,
                    cacheStatus: cacheStatus,
                  );
            final simulation = SimulationService(
              baseline: baseline,
              repository: repository,
            );
            final anomalyAi = AnomalyAiService();
            final state = AppState(
              baseline: baseline,
              nrw: nrw,
              repository: repository,
              simulation: simulation,
              anomalyAi: anomalyAi,
            );
            state.init();
            return state;
          },
        ),
        ChangeNotifierProvider<DatasetState>(
          create: (_) => DatasetState(
            repository: DatasetRepository(
              client: Supabase.instance.client,
              database: database,
              cacheStatus: cacheStatus,
            ),
          ),
        ),
        ChangeNotifierProvider<UsageState>(
          create: (_) {
            final localDatabase = database;
            return UsageState(
              repository: localDatabase == null
                  ? UsageRepository(Supabase.instance.client)
                  : UsageRepository.cached(
                      client: Supabase.instance.client,
                      database: localDatabase,
                      cacheStatus: cacheStatus,
                    ),
            );
          },
        ),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'mySumber',
        debugShowCheckedModeBanner: false,
        builder: (context, child) => OfflineStatusBanner(
          child: child ?? const SizedBox.shrink(),
        ),
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.canvas,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.adminPrimary,
            surface: AppColors.canvas,
          ),
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.textPrimary,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            color: AppColors.surface,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: AppColors.divider),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.adminPrimary),
            ),
          ),
        ),
        home: Consumer<RoleState>(
          builder: (BuildContext context, RoleState authState, Widget? _) {
            if (authState.requiresPasswordReset) {
              // ResetPasswordScreen just became the root route, but a
              // pushed screen (e.g. ForgotPasswordScreen) may still be
              // sitting on top of it from before the reset-link email was
              // opened — pop back to root so it's actually visible.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _navigatorKey.currentState?.popUntil((route) => route.isFirst);
              });
              return const ResetPasswordScreen();
            }
            if (authState.isLoggedIn) {
              // Authoritative regardless of how the session arrived — a
              // cold app start via the email-link deep link never has
              // LoginScreen mounted to redirect from, so this has to be
              // decided here, not by whichever screen happened to trigger
              // the sign-in.
              if (authState.needsProfileSetup) {
                return const ProfileSetupScreen();
              }
              return AppShell(userRole: authState.userRole!);
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  final String userRole;

  const AppShell({super.key, required this.userRole});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  late final List<_NavItem> _navItems;

  @override
  void initState() {
    super.initState();
    _setupScreensByRole();
    if (widget.userRole == 'user') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<UsageState>().init();
      });
    }
  }

  void _setupScreensByRole() {
    switch (widget.userRole) {
      case 'admin':
        _screens = [
          DashboardScreen(
            onStateTap: _openInventoryForState,
            onOpenTab: (index) => setState(() => _currentIndex = index),
          ),
          InventoryScreen(),
          const AbnormalProductionScreen(),
          const OversightScreen(),
          const WorkerAccountsScreen(),
        ];
        _navItems = const [
          _NavItem(icon: Icons.grid_view_outlined, label: 'Dashboard'),
          _NavItem(icon: Icons.location_city_outlined, label: 'Mall'),
          _NavItem(icon: Icons.notifications_outlined, label: 'Anomalies'),
          _NavItem(icon: Icons.shield_outlined, label: 'Oversight'),
          _NavItem(icon: Icons.manage_accounts_outlined, label: 'Workers'),
        ];
        break;
      case 'worker':
        _screens = const [
          AlertQueueScreen(utility: Utility.water),
          AlertQueueScreen(utility: Utility.electricity),
          ReportHistoryScreen(),
        ];
        _navItems = const [
          _NavItem(icon: Icons.water_drop_outlined, label: 'Water'),
          _NavItem(icon: Icons.electric_bolt_outlined, label: 'Electricity'),
          _NavItem(icon: Icons.description_outlined, label: 'Reports'),
        ];
        break;
      default:
        _screens = [
          CustomerHomeScreen(
              onUsageTap: () => setState(() => _currentIndex = 1)),
          const CompareUsageScreen(),
          const ReportProblemScreen(),
        ];
        _navItems = const [
          _NavItem(icon: Icons.home_outlined, label: 'Home'),
          _NavItem(icon: Icons.bar_chart_outlined, label: 'Usage'),
          _NavItem(icon: Icons.person_outline, label: 'Profile'),
        ];
    }
  }

  void _openInventoryForState(String state) {
    setState(() {
      _screens[1] = InventoryScreen(initialState: state);
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = rolePrimary(widget.userRole);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isAdmin = widget.userRole == 'admin';
        final isWorker = widget.userRole == 'worker';
        final isCustomer = widget.userRole == 'user';
        final mode = isAdmin
            ? adminLayoutModeFor(
                Size(constraints.maxWidth, constraints.maxHeight),
              )
            : null;
        final useCompactRail = mode == AdminLayoutMode.phoneLandscape;
        final useTabletRail = mode == AdminLayoutMode.tabletLandscape;
        final usesAdminRail = useCompactRail || useTabletRail;
        final usesCustomerCompactRail = isCustomer &&
            usesCustomerPhoneLandscape(
              Size(constraints.maxWidth, constraints.maxHeight),
            );
        final usesWorkerCompactRail = isWorker &&
            usesWorkerPhoneLandscape(
              Size(constraints.maxWidth, constraints.maxHeight),
            );
        final usesRoleRail =
            usesAdminRail || usesCustomerCompactRail || usesWorkerCompactRail;
        final screenStack = IndexedStack(
          index: _currentIndex,
          children: _screens,
        );
        final Widget? rail = !usesRoleRail
            ? null
            : useCompactRail
                ? AdminCompactRail(
                    currentIndex: _currentIndex,
                    onDestinationSelected: (index) =>
                        setState(() => _currentIndex = index),
                  )
                : useTabletRail
                    ? NavigationRail(
                        selectedIndex: _currentIndex,
                        onDestinationSelected: (index) =>
                            setState(() => _currentIndex = index),
                        labelType: NavigationRailLabelType.all,
                        backgroundColor: Colors.white,
                        indicatorColor: AppColors.adminSurface,
                        selectedIconTheme: const IconThemeData(
                          color: AppColors.adminPrimary,
                        ),
                        selectedLabelTextStyle: const TextStyle(
                          color: AppColors.adminPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedIconTheme: const IconThemeData(
                          color: AppColors.textTertiary,
                        ),
                        unselectedLabelTextStyle: const TextStyle(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                        destinations: [
                          for (final item in _navItems)
                            NavigationRailDestination(
                              icon: Icon(item.icon),
                              selectedIcon: Icon(item.icon),
                              label: Text(item.label),
                            ),
                        ],
                      )
                    : usesWorkerCompactRail
                        ? WorkerCompactRail(
                            currentIndex: _currentIndex,
                            onDestinationSelected: (index) =>
                                setState(() => _currentIndex = index),
                          )
                        : CustomerCompactRail(
                            currentIndex: _currentIndex,
                            onDestinationSelected: (index) =>
                                setState(() => _currentIndex = index),
                          );

        return ExitConfirmationScope(
          child: Scaffold(
            backgroundColor: AppColors.canvas,
            body: RoleShellBody(rail: rail, child: screenStack),
            bottomNavigationBar:
                usesRoleRail ? null : _buildBottomNavigation(primary),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation(Color primary) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_navItems.length, (i) {
            final item = _navItems[i];
            final selected = i == _currentIndex;
            return Expanded(
              child: InkWell(
                onTap: () => setState(() => _currentIndex = i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: selected ? primary : AppColors.textTertiary,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? primary : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class RoleShellBody extends StatefulWidget {
  const RoleShellBody({super.key, required this.child, this.rail});

  final Widget child;
  final Widget? rail;

  @override
  State<RoleShellBody> createState() => _RoleShellBodyState();
}

class _RoleShellBodyState extends State<RoleShellBody> {
  /// Moving [widget.child] beside the rail changes its tree depth. A stable
  /// global key re-parents the role screen instead of resetting its filters.
  final _childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final keyed = KeyedSubtree(key: _childKey, child: widget.child);
    if (widget.rail == null) return keyed;
    return Row(
      children: [
        widget.rail!,
        const VerticalDivider(width: 1),
        Expanded(child: keyed),
      ],
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
