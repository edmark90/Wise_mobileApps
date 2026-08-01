import 'package:flutter/material.dart';

/// Slim animated banner shown while the SWR cache is synchronizing in the
/// background, or while the device is offline. It tells the user "you are
/// seeing cached data" without blocking the UI.
class SyncBanner extends StatelessWidget {
  final bool syncing;
  final bool offline;

  const SyncBanner({
    super.key,
    this.syncing = false,
    this.offline = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!syncing && !offline) return const SizedBox.shrink();

    final isOffline = offline;
    final bg = isOffline ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF);
    final fg = isOffline ? const Color(0xFF92400E) : const Color(0xFF1D4ED8);

    return Material(
      color: bg,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: isOffline
                  ? Icon(Icons.cloud_off_rounded, size: 13, color: fg)
                  : CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: fg,
                    ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isOffline
                    ? 'Offline — showing saved data'
                    : 'Syncing…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
