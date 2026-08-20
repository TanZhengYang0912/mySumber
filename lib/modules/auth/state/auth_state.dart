import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/account_repository.dart';
import '../models/account_profile.dart';

/// Must match the intent-filter scheme/host registered in
/// AndroidManifest.xml and the redirect URL configured in the Supabase
/// dashboard's Google provider settings.
const googleOAuthRedirect = 'io.supabase.mysumber://login-callback';

// Temporary development switch: allow password login without the email
// second-factor link while the team is testing the rest of the app.
const enableEmailSecondFactor = false;

bool hasPendingPasswordSetup(User user) =>
    user.userMetadata?['must_set_password'] == true;

class RoleState extends ChangeNotifier {
  RoleState({
    AccountRepository? accountRepository,
    Session? Function()? currentSession,
    Stream<AuthState>? authStateChanges,
  })  : _accountRepository = accountRepository ?? AccountRepository(),
        _currentSession = currentSession ??
            (() => Supabase.instance.client.auth.currentSession) {
    final changes =
        authStateChanges ?? Supabase.instance.client.auth.onAuthStateChange;
    _authSubscription = changes.listen((data) {
      final session = data.session;
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _requiresPasswordReset = true;
        notifyListeners();
      }
      if (session != null && !session.isExpired && !_verifyingCredentials) {
        if (hasPendingPasswordSetup(session.user)) {
          _requiresPasswordReset = true;
          notifyListeners();
        }
        unawaited(_applyProfile(session.user));
      }
    }, onError: (Object _, StackTrace __) {
      debugPrint('Auth state update unavailable while offline.');
    });
  }

  final AccountRepository _accountRepository;
  final Session? Function() _currentSession;
  AccountProfile? _profile;
  String? _userRole;
  String? _email;
  bool _isLoading = false;
  String? _errorMessage;
  bool _awaitingSecondFactor = false;
  String? _pendingEmail;
  bool _profileSetupSkipped = false;
  bool _requiresPasswordReset = false;
  late final StreamSubscription<AuthState> _authSubscription;

  /// True for the brief window in [login] between the factor-1 password
  /// check succeeding and that session being torn down again. The
  /// password check itself fires a SIGNED_IN event on the auth stream —
  /// without this guard the listener below would treat that transient
  /// session as a real login just before it gets signed out.
  bool _verifyingCredentials = false;

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  String? get userRole => _userRole;
  AccountProfile? get profile => _profile;
  String? get email => _email;
  bool get isLoggedIn => _userRole != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// True once the password has been verified but the emailed confirmation
  /// link (second factor) hasn't been clicked yet.
  bool get awaitingSecondFactor => _awaitingSecondFactor;
  String? get pendingEmail => _pendingEmail;
  bool get requiresPasswordReset => _requiresPasswordReset;

  Map<String, dynamic>? get _metadata =>
      Supabase.instance.client.auth.currentUser?.userMetadata;

  /// True when Google is the only sign-in method linked to this account —
  /// such accounts have no Supabase-managed password to reset, so the
  /// password-change UI should be hidden rather than offered and fail.
  bool get isGoogleOnlyAccount {
    final providers =
        Supabase.instance.client.auth.currentUser?.appMetadata['providers'];
    return providers is List &&
        providers.isNotEmpty &&
        providers.every((p) => p == 'google');
  }

  /// True once a customer has been through the enforced profile setup
  /// wizard (name, gender, phone, address all saved). Used to route both
  /// brand-new and returning-but-incomplete accounts (including Google
  /// sign-ins, which have no other "first time" signal) into the wizard.
  bool get needsProfileSetup {
    if (_userRole != 'user') return false;
    if (_profileSetupSkipped) return false;
    final m = _metadata;
    if (m == null) return true;
    bool has(String key) => (m[key] as String?)?.trim().isNotEmpty == true;
    return !(has('display_name') &&
        has('gender') &&
        has('phone_number') &&
        has('service_address'));
  }

  /// Escape hatch for when the wizard itself is broken (e.g. the address
  /// lookup service is down) — lets the user into the app for this session
  /// without saving anything. Cleared on [logout], so the wizard is
  /// enforced again on the next fresh sign-in.
  void skipProfileSetupForNow() {
    _profileSetupSkipped = true;
    notifyListeners();
  }

  /// Custom display name if the user has set one (Profile tab), otherwise
  /// derived from their email's local part.
  String get displayName {
    final custom = _metadata?['display_name'] as String?;
    if (custom != null && custom.trim().isNotEmpty) return custom.trim();
    final email = _email ?? '';
    if (email.isEmpty) return 'there';
    return email.split('@').first.replaceAll('.', ' ').replaceAllMapped(
          RegExp(r'\b\w'),
          (m) => m.group(0)!.toUpperCase(),
        );
  }

  String? get phoneNumber => _metadata?['phone_number'] as String?;
  String? get gender => _metadata?['gender'] as String?;

  /// Persists any combination of display name, phone number, and gender to
  /// the Supabase auth user's metadata and notifies listeners so every
  /// screen using [displayName]/[phoneNumber]/[gender] refreshes.
  Future<bool> updateProfile({
    String? displayName,
    String? phoneNumber,
    String? gender,
  }) async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {
          if (displayName != null) 'display_name': displayName,
          if (phoneNumber != null) 'phone_number': phoneNumber,
          if (gender != null) 'gender': gender,
        }),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Could not update profile: $e';
      notifyListeners();
      return false;
    }
  }

  /// Persists the full profile collected by the post-registration setup
  /// wizard in a single write.
  Future<bool> completeProfileSetup({
    required String displayName,
    required String gender,
    required String phoneNumber,
    required String serviceAddress,
    required String serviceState,
  }) async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {
          'display_name': displayName,
          'gender': gender,
          'phone_number': phoneNumber,
          'service_address': serviceAddress,
          'service_state': serviceState,
        }),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Could not save profile: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> _applyProfile(User user) async {
    try {
      final profile = await _accountRepository.currentProfile(user.id);
      if (profile == null) {
        _errorMessage = 'Your account profile is not ready yet.';
        _userRole = null;
      } else if (profile.role == 'worker' && !profile.isActive) {
        _errorMessage =
            'Your worker account is currently inactive. Please contact your administrator.';
        _userRole = null;
        await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
      } else {
        _profile = profile;
        _email = profile.email;
        _userRole = profile.role == 'customer' ? 'user' : profile.role;
        _awaitingSecondFactor = false;
        _pendingEmail = null;
      }
      notifyListeners();
      return _userRole != null;
    } catch (e) {
      _errorMessage = 'Could not load account profile';
      _userRole = null;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> sendPasswordRecovery(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: googleOAuthRedirect,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Could not send password reset email';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateRecoveredPassword(String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: password,
          data: {'must_set_password': false},
        ),
      );
      _requiresPasswordReset = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Could not update password';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> checkExistingSession() async {
    try {
      final session = _currentSession();
      if (session != null && !session.isExpired) {
        await _applyProfile(session.user);
      }
    } catch (e) {
      // No existing session
    }
  }

  /// If the Supabase project has "Confirm email" enabled, [signUp] returns
  /// a user but no session — the account exists but can't sign in until
  /// the confirmation link is clicked. In that case this sets
  /// [awaitingSecondFactor] (reusing the same "check your email" flow as
  /// login's second factor) instead of attempting an immediate sign-in,
  /// which would otherwise just fail.
  Future<bool> register(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        _errorMessage = 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (response.session != null) {
        // Confirmation isn't required — account is immediately usable.
        final profileReady = await _applyProfile(response.user!);
        _isLoading = false;
        notifyListeners();
        return profileReady;
      }

      _pendingEmail = email;
      _awaitingSecondFactor = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Launches the Google OAuth consent screen in an external browser. There
  /// is no result to await here — success is picked up asynchronously by
  /// the [onAuthStateChange] listener once the browser redirects back via
  /// deep link (see [googleOAuthRedirect]).
  Future<void> signInWithGoogle() async {
    _errorMessage = null;
    notifyListeners();
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: googleOAuthRedirect,
      );
    } catch (e) {
      _errorMessage = 'Google sign-in failed: $e';
      notifyListeners();
    }
  }

  /// Verifies the password (factor 1), then immediately drops that session
  /// and sends a magic-link confirmation email (factor 2) — no fully
  /// privileged session exists until the user clicks that link, so this is
  /// real two-factor, not just a UI gate. Returns true once the password
  /// check passed and the email was sent; [awaitingSecondFactor] then
  /// stays true until the link is clicked (picked up by the auth-state
  /// listener) or [cancelSecondFactor] is called.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _verifyingCredentials = true;
    notifyListeners();

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        _errorMessage = 'Login failed';
        _isLoading = false;
        _verifyingCredentials = false;
        notifyListeners();
        return false;
      }

      if (!enableEmailSecondFactor) {
        _verifyingCredentials = false;
        _awaitingSecondFactor = false;
        _pendingEmail = null;
        final profileReady = await _applyProfile(response.user!);
        _isLoading = false;
        notifyListeners();
        return profileReady;
      }

      await Supabase.instance.client.auth.signOut();
      _verifyingCredentials = false;
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
        emailRedirectTo: googleOAuthRedirect,
      );
      _pendingEmail = email;
      _awaitingSecondFactor = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      _verifyingCredentials = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error: ${e.toString()}';
      _isLoading = false;
      _verifyingCredentials = false;
      notifyListeners();
      return false;
    }
  }

  /// Re-sends the second-factor email to [pendingEmail].
  Future<void> resendVerificationEmail() async {
    final email = _pendingEmail;
    if (email == null) return;
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
        emailRedirectTo: googleOAuthRedirect,
      );
    } catch (e) {
      _errorMessage = 'Could not resend email: $e';
      notifyListeners();
    }
  }

  /// Abandons an in-progress second-factor challenge (e.g. user wants to
  /// go back and try a different account).
  void cancelSecondFactor() {
    _awaitingSecondFactor = false;
    _pendingEmail = null;
    notifyListeners();
  }

  Future<void> logout() async {
    // Cleared up front, before the signOut() await, not after: GoTrue drops
    // its local currentUser synchronously as soon as signOut() starts,
    // ahead of the network call that finishes it. needsProfileSetup reads
    // that live currentUser, so if _userRole were still 'user' during the
    // gap, a frame could render with currentUser already null and flash
    // ProfileSetupScreen (metadata looks missing) before returning to the
    // unauthenticated login state. Nulling _userRole first makes isLoggedIn
    // false immediately, so main.dart never evaluates needsProfileSetup here.
    _isLoading = true;
    _userRole = null;
    _email = null;
    _profile = null;
    _errorMessage = null;
    _profileSetupSkipped = false;
    _requiresPasswordReset = false;
    notifyListeners();

    try {
      await Supabase.instance.client.auth.signOut();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error logging out: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Permanently deletes the signed-in user's Supabase account via the
  /// `delete-account` edge function (deletion requires the service_role
  /// key, which must never ship in the client). Signs out locally on
  /// success.
  Future<bool> deleteAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response =
          await Supabase.instance.client.functions.invoke('delete-account');
      final data = response.data;
      if (response.status != 200 || (data is Map && data['error'] != null)) {
        _errorMessage = data is Map
            ? 'Could not delete account: ${data['error']}'
            : 'Could not delete account (status ${response.status})';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await Supabase.instance.client.auth.signOut();
      _userRole = null;
      _email = null;
      _profileSetupSkipped = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // AuthRetryableFetchError means the request never reached Supabase
      // (network drop, timeout) — it's transient, not a real failure, so
      // don't show the raw exception text.
      _errorMessage = e.toString().contains('AuthRetryableFetchError')
          ? 'Could not delete account: network issue, please try again.'
          : 'Could not delete account: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
