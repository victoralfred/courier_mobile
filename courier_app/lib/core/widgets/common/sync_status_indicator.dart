import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../connectivity/connectivity.dart';
import '../../constants/app_strings.dart';

/// Compact sync status indicator for app bars and status areas.
///
/// WHAT: A small, unobtrusive widget that displays sync status with an icon
/// and optional text. Designed to fit in app bars, toolbars, or footer areas.
///
/// WHY:
/// - Provides persistent sync status visibility without taking much space
/// - Complements ConnectivityBanner with always-visible indicator
/// - Shows real-time sync progress for users who want detail
/// - Helps users understand when their changes are safely synced
///
/// BEHAVIOR:
/// - Shows green checkmark when all synced (online, 0 pending)
/// - Shows sync icon when syncing (with animation)
/// - Shows pending count when online but items queued
/// - Can be tapped to show detailed status (future enhancement)
///
/// DESIGN PATTERNS:
/// - Observer Pattern: Listens to ConnectivityCubit state changes
/// - Presentation Component: Pure UI, no business logic
///
/// SOLID PRINCIPLES:
/// - Single Responsibility: Only displays sync status
/// - Dependency Inversion: Depends on ConnectivityState abstraction
/// - Open/Closed: Can extend styling without modifying core logic
///
/// USAGE:
/// ```dart
/// // In AppBar actions:
/// AppBar(
///   title: Text('Home'),
///   actions: [
///     SyncStatusIndicator(),
///     IconButton(icon: Icon(Icons.settings), onPressed: () {}),
///   ],
/// )
///
/// // In bottom navigation or footer:
/// Row(
///   mainAxisAlignment: MainAxisAlignment.end,
///   children: [
///     SyncStatusIndicator(showText: true),
///   ],
/// )
///
/// // With custom size:
/// SyncStatusIndicator(
///   iconSize: 24.0,
///   showText: true,
/// )
/// ```
///
/// ACCESSIBILITY:
/// - Icon has semantic label for screen readers
/// - Color coding with icon redundancy (not color-only)
/// - Text labels for clarity when space permits
class SyncStatusIndicator extends StatelessWidget {
  /// Whether to show text label alongside icon
  final bool showText;

  /// Icon size (default: 20.0)
  final double iconSize;

  /// Text style (optional, defaults to caption style)
  final TextStyle? textStyle;

  const SyncStatusIndicator({
    super.key,
    this.showText = false,
    this.iconSize = 20.0,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ConnectivityCubit, ConnectivityState>(
        builder: (context, state) {
          // During initial state, show nothing
          if (state is ConnectivityInitial) {
            return const SizedBox.shrink();
          }

          final indicatorContent = _buildIndicatorContent(context, state);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: indicatorContent,
          );
        },
      );

  /// Build indicator content based on state.
  ///
  /// WHAT: Returns appropriate widget for current sync state.
  ///
  /// STATES:
  /// - Online + 0 pending: Green checkmark "All synced"
  /// - Online + N pending: Blue cloud with count
  /// - Syncing: Animated progress indicator
  /// - Offline: Handled by ConnectivityBanner, show minimal indicator
  Widget _buildIndicatorContent(BuildContext context, ConnectivityState state) {
    if (state is ConnectivityOnline && state.pendingCount == 0) {
      return _buildAllSyncedIndicator(context);
    } else if (state is ConnectivityOnline && state.pendingCount > 0) {
      return _buildPendingIndicator(context, state.pendingCount);
    } else if (state is ConnectivitySyncing) {
      return _buildSyncingIndicator(context, state.pendingCount);
    } else if (state is ConnectivityOffline) {
      return _buildOfflineIndicator(context);
    }

    return const SizedBox.shrink();
  }

  /// Build "all synced" indicator (green checkmark).
  ///
  /// WHAT: Shows green checkmark icon with optional "All synced" text.
  ///
  /// WHY: Positive confirmation that all changes are safely on backend.
  /// Green is universally recognized as "good/complete" status.
  Widget _buildAllSyncedIndicator(BuildContext context) => Semantics(
        label: AppStrings.connectivitySyncIndicatorAllSynced,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: iconSize,
            ),
            if (showText) ...[
              const SizedBox(width: 4.0),
              Text(
                AppStrings.connectivitySyncIndicatorAllSynced,
                style: textStyle ??
                    Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
              ),
            ],
          ],
        ),
      );

  /// Build pending operations indicator.
  ///
  /// WHAT: Shows cloud icon with count of pending operations.
  ///
  /// WHY: Informs user that some changes haven't synced yet, but connection
  /// is available. May indicate sync in progress or queued operations.
  ///
  /// COLOR: Blue to indicate informational status, not error.
  Widget _buildPendingIndicator(BuildContext context, int count) {
    final label = AppStrings.format(
      AppStrings.connectivitySyncIndicatorPending,
      {'count': count.toString()},
    );

    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_upload,
            color: Colors.blue,
            size: iconSize,
          ),
          const SizedBox(width: 4.0),
          if (showText)
            Text(
              label,
              style: textStyle ??
                  Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
            )
          else
            Text(
              count.toString(),
              style: textStyle ??
                  Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.0,
                      ),
            ),
        ],
      ),
    );
  }

  /// Build syncing indicator (animated progress).
  ///
  /// WHAT: Shows circular progress indicator with optional "Syncing..." text.
  ///
  /// WHY: Provides immediate feedback that sync is actively happening.
  /// Animation draws attention and indicates ongoing process.
  ///
  /// COLOR: Blue to match Material Design progress indicators.
  Widget _buildSyncingIndicator(BuildContext context, int count) => Semantics(
        label: AppStrings.connectivitySyncIndicatorSyncing,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: const CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            if (showText) ...[
              const SizedBox(width: 8.0),
              Text(
                AppStrings.connectivitySyncIndicatorSyncing,
                style: textStyle ??
                    Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
              ),
            ],
          ],
        ),
      );

  /// Build offline indicator (minimal).
  ///
  /// WHAT: Shows cloud_off icon in grey.
  ///
  /// WHY: Minimal indicator since ConnectivityBanner shows full offline status.
  /// This just provides visual confirmation in status area.
  ///
  /// COLOR: Grey to indicate inactive/disconnected state.
  Widget _buildOfflineIndicator(BuildContext context) => Semantics(
        label: AppStrings.connectivityStatusOffline,
        child: Icon(
          Icons.cloud_off,
          color: Colors.grey,
          size: iconSize,
        ),
      );
}
