import 'package:flutter/material.dart';

class AppNotification {
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool showStrip;

  const AppNotification({
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.message,
    required this.timestamp,
    this.showStrip = false,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
