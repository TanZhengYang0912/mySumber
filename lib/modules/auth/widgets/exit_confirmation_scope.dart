import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<bool> _showExitDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Exit mySumber?'),
          content: const Text('Are you sure you want to exit the app?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Exit'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> showExitConfirmation(
  BuildContext context, {
  Future<void> Function()? onExit,
}) async {
  final shouldExit = await _showExitDialog(context);
  if (!shouldExit || !context.mounted) return;

  if (onExit != null) {
    await onExit();
  } else {
    await SystemNavigator.pop();
  }
}

class ExitConfirmationScope extends StatefulWidget {
  const ExitConfirmationScope({
    super.key,
    required this.child,
    this.onExit,
  });

  final Widget child;
  final Future<void> Function()? onExit;

  @override
  State<ExitConfirmationScope> createState() => _ExitConfirmationScopeState();
}

class _ExitConfirmationScopeState extends State<ExitConfirmationScope> {
  bool _dialogOpen = false;

  void _handlePop(bool didPop) {
    if (didPop || _dialogOpen) return;
    _dialogOpen = true;
    unawaited(_confirmExit());
  }

  Future<void> _confirmExit() async {
    await showExitConfirmation(context, onExit: widget.onExit);
    if (mounted) _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: widget.child,
    );
  }
}
