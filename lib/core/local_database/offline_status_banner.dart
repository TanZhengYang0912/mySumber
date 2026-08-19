import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'cache_status.dart';

class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final status = context.watch<CacheStatus>();
    if (!status.isOffline) return child;

    final lastSync = status.lastSuccessfulSync;
    final detail = lastSync == null
        ? 'Showing saved data'
        : 'Last synced ${DateFormat('MMM d, h:mm a').format(lastSync.toLocal())}';

    return Column(
      children: [
        Material(
          color: const Color(0xFFFFF3CD),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 18,
                    color: Color(0xFF795600),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Offline data',
                    style: TextStyle(
                      color: Color(0xFF5F4500),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      detail,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF795600),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
