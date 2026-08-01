import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../state/auth_state.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@')) return;
    setState(() => _submitted = true);
    await context.read<RoleState>().sendPasswordRecovery(email);
  }

  bool _isPhoneLandscape(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    return viewport.shortestSide < 600 && viewport.width > viewport.height;
  }

  Widget _brand({required bool compact}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: compact ? 58 : 72,
          height: compact ? 58 : 72,
          decoration: BoxDecoration(
            color: AppColors.adminPrimary,
            borderRadius: BorderRadius.circular(compact ? 16 : 18),
          ),
          child: Icon(
            Icons.water_drop_rounded,
            color: Colors.white,
            size: compact ? 30 : 36,
          ),
        ),
        SizedBox(height: compact ? 10 : 16),
        Text(
          'mySumber',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 26 : 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.1,
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        Text(
          'Account recovery',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 13 : 15,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _form(RoleState auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Forgot password?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your email and we will send a secure reset link.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'Enter your email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.adminPrimary,
            foregroundColor: Colors.white,
          ),
          onPressed: auth.isLoading ? null : _submit,
          icon: auth.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Icon(Icons.mark_email_read_outlined),
          label: Text(auth.isLoading ? 'Sending…' : 'Send reset link'),
        ),
        if (_submitted)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text(
              "If an account exists for this email, we've sent a password reset link.",
              textAlign: TextAlign.center,
            ),
          ),
        if (auth.errorMessage != null && !_submitted)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              auth.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.critical),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<RoleState>();
    if (_isPhoneLandscape(context)) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          toolbarHeight: 56,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          backgroundColor: AppColors.adminPrimary,
          foregroundColor: Colors.white,
          title: const Text(
            'Forgot password',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
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
                      Expanded(flex: 3, child: _brand(compact: true)),
                      const SizedBox(width: 28),
                      Expanded(flex: 7, child: _form(auth)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: Colors.white,
        title: const Text(
          'Forgot password',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _brand(compact: false),
                  const SizedBox(height: 32),
                  _form(auth),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
