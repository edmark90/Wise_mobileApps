import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../core/cache/swr_cache.dart';
import 'error_state_view.dart';
import 'offline_state_view.dart';
import 'sync_banner.dart';

/// Renders a [SwrState] consistently across the whole app.
///
/// Decision table (implements the SWR UX rules):
///  - has data            → show content. If `isRevalidating`, wrap with a
///                          [SyncBanner]; if `isOffline`, show the offline
///                          banner over the cached data.
///  - no data + loading   → centered loader.
///  - no data + offline   → [OfflineStateView] with retry.
///  - no data + error     → [ErrorStateView] with retry.
class SwrView<T> extends StatelessWidget {
  final SwrState<T> state;
  final Widget Function(BuildContext context, T data) builder;
  final Future<void> Function() onRetry;
  final Widget? loadingWidget;

  const SwrView({
    super.key,
    required this.state,
    required this.builder,
    required this.onRetry,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final data = state.data;

    if (data != null) {
      final content = builder(context, data);
      if (state.isRevalidating || state.isOffline) {
        return Column(
          children: [
            SyncBanner(syncing: state.isRevalidating, offline: state.isOffline),
            Expanded(child: content),
          ],
        );
      }
      return content;
    }

    if (state.isLoading) {
      return loadingWidget ??
          const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (state.isOffline) {
      return OfflineStateView(onRetry: onRetry);
    }

    final message = state.error?.toString().replaceFirst('Exception: ', '');
    return ErrorStateView(
      title: 'Could not load data',
      message: message,
      onRetry: onRetry,
    );
  }
}
