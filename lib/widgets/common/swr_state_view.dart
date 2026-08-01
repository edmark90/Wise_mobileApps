import 'package:flutter/material.dart';

import '../../core/cache/swr_cache.dart';
import '../common/swr_view.dart';

export '../../core/cache/swr_cache.dart' show SwrState;

/// Convenience wrapper for controllers that manage exactly one SWR key.
///
/// Ties together a [ChangeNotifier] controller that owns the [SwrState] and
/// the [SwrView] renderer, so screens stay tiny:
///
/// ```dart
/// ListenableBuilder(
///   listenable: ProfileController.instance,
///   builder: (_, __) => SwrStateView(
///     state: ProfileController.instance.state!,
///     onRetry: ProfileController.instance.load,
///     builder: (context, profile) => ...,
///   ),
/// )
/// ```
class SwrStateView<T> extends StatelessWidget {
  final SwrState<T> state;
  final Widget Function(BuildContext context, T data) builder;
  final Future<void> Function() onRetry;
  final Widget? loadingWidget;

  const SwrStateView({
    super.key,
    required this.state,
    required this.builder,
    required this.onRetry,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) => SwrView<T>(
        state: state,
        builder: builder,
        onRetry: onRetry,
        loadingWidget: loadingWidget,
      );
}
