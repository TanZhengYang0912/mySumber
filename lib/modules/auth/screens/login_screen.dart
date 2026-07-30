import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../state/auth_state.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? intendedRole;
  const LoginScreen({super.key, this.intendedRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    if (widget.intendedRole == 'admin') {
      _emailController.text = 'admin@mysumber.my';
    } else if (widget.intendedRole == 'worker') {
      _emailController.text = 'worker@mysumber.my';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final auth = context.read<RoleState>();
    await auth.login(_emailController.text.trim(), _passwordController.text);
  }

  /// Shared by email/password login and the async Google OAuth callback.
  /// Just reveals whatever the app root is now showing underneath (it
  /// decides wizard vs. main app from [RoleState] itself) — this never
  /// picks the destination directly, since a cold app start via the
  /// email-link deep link wouldn't have this screen mounted to do that.
  void _navigateAfterAuth(RoleState auth) {
    if (_navigated || !auth.isLoggedIn) return;
    _navigated = true;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _verifyEmailPanel(RoleState auth, Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(Icons.mark_email_read_outlined, color: primary, size: 36),
              const SizedBox(height: 12),
              const Text(
                'Check your email',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Your password is correct. For extra security, we sent a '
                'confirmation link to ${auth.pendingEmail} — click it to '
                'finish signing in.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        if (auth.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              auth.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.critical, fontSize: 13),
            ),
          ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => auth.resendVerificationEmail(),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Resend email'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            auth.cancelSecondFactor();
            _passwordController.clear();
          },
          child: const Text('Use a different account'),
        ),
      ],
    );
  }

  String _roleLabel() {
    switch (widget.intendedRole) {
      case 'admin':
        return 'Admin';
      case 'worker':
        return 'Worker';
      default:
        return 'Customer';
    }
  }

  bool _isPhoneLandscape(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    return viewport.shortestSide < 600 && viewport.width > viewport.height;
  }

  Widget _phoneLandscapeScaffold(
    BuildContext context,
    Color primary,
    bool isCustomer,
  ) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        toolbarHeight: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: Text(
          'Sign in as ${_roleLabel()}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        systemOverlayStyle: null,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.water_drop_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'mySumber',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_roleLabel()} sign in',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      flex: 7,
                      child: Consumer<RoleState>(
                        builder: (context, auth, _) {
                          if (auth.isLoggedIn && !_navigated) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _navigateAfterAuth(auth);
                            });
                          }
                          if (auth.awaitingSecondFactor) {
                            return _verifyEmailPanel(auth, primary);
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'Enter your email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _passwordController,
                                obscureText: !_showPassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Enter your password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () => _showPassword = !_showPassword,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _login(),
                              ),
                              if (auth.errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    auth.errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.critical,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(46),
                                ),
                                onPressed: auth.isLoading ? null : _login,
                                icon: auth.isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.login),
                                label: Text(
                                  auth.isLoading ? 'Signing in…' : 'Sign In',
                                ),
                              ),
                              if (isCustomer) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Expanded(child: Divider()),
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        'or',
                                        style: TextStyle(
                                          color: AppColors.textTertiary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 190,
                                      child: OutlinedButton(
                                        onPressed: auth.isLoading
                                            ? null
                                            : () => auth.signInWithGoogle(),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize:
                                              const Size.fromHeight(42),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10),
                                        ),
                                        child: const Text('Google'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => RegisterScreen(
                                              onBack: () =>
                                                  Navigator.pop(context),
                                            ),
                                          ),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: primary,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      child: const Text('Sign Up'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = rolePrimary(widget.intendedRole);
    final isCustomer = widget.intendedRole == 'user' ||
        widget.intendedRole == null ||
        widget.intendedRole == 'customer';

    if (_isPhoneLandscape(context)) {
      return _phoneLandscapeScaffold(context, primary, isCustomer);
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: Text(
          'Sign in as ${_roleLabel()}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        systemOverlayStyle: null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'mySumber',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_roleLabel()} sign in',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              Consumer<RoleState>(
                builder: (context, auth, _) {
                  if (auth.isLoggedIn && !_navigated) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _navigateAfterAuth(auth);
                    });
                  }
                  if (auth.awaitingSecondFactor) {
                    return _verifyEmailPanel(auth, primary);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        onSubmitted: (_) => _login(),
                      ),
                      if (auth.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.criticalSurface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppColors.critical, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    auth.errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.critical,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: auth.clearError,
                                  child: const Icon(Icons.close,
                                      color: AppColors.critical, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: auth.isLoading ? null : _login,
                        icon: auth.isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(auth.isLoading ? 'Signing in…' : 'Sign In'),
                      ),
                      if (isCustomer) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('or',
                                  style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 13)),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton(
                          onPressed: auth.isLoading
                              ? null
                              : () => auth.signInWithGoogle(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: const BorderSide(color: AppColors.divider),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://www.gstatic.com/images/branding/product/1x/googleg_standard_color_18dp.png',
                                height: 18,
                                width: 18,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.g_mobiledata,
                                    size: 22,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Sign in with Google',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RegisterScreen(
                                      onBack: () => Navigator.pop(context),
                                    ),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: primary,
                                textStyle:
                                    const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              child: const Text('Sign Up'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
