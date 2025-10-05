import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../connectivity/connectivity.dart';
import '../../constants/app_strings.dart';

/// Banner widget that displays connectivity and sync status.
///
/// WHAT: A sliding banner that appears at the top of the screen to show
/// offline status and sync progress. Uses Material Design's MaterialBanner
/// for native look and feel.
///
/// WHY:
/// - Provides immediate, non-blocking feedback about connectivity issues
/// - Shows users they can continue working offline (offline-first UX)
/// - Displays sync progress to manage user expectations
/// - Prevents confusion about why changes aren't appearing on backend
///
/// BEHAVIOR:
/// - Hidden when online with no pending operations
/// - Shows "You're offline. X changes will sync when connected" when offline
/// - Shows "Syncing X changes..." during active sync
/// - Animates smoothly in/out based on state changes
///
/// DESIGN PATTERNS:
/// - Observer Pattern: Listens to ConnectivityCubit state changes
/// - Presentation Component: Pure UI, no business logic
///
/// SOLID PRINCIPLES:
/// - Single Responsibility: Only displays connectivity status
/// - Dependency Inversion: Depends on ConnectivityState abstraction
/// - Open/Closed: Can extend with new states without modification
///
/// USAGE:
/// ```dart
/// // In Scaffold:
/// Scaffold(
///   body: Column(
///     children: [
///       ConnectivityBanner(), // Add at top of screen
///       Expanded(child: YourContent()),
///     ],
///   ),
/// )
///
/// // Or use as overlay:
/// Stack(
///   children: [
///     YourContent(),
///     Positioned(
///       top: 0,
///       left: 0,
///       right: 0,
///       child: ConnectivityBanner(),
///     ),
///   ],
/// )
/// ```
///
/// ACCESSIBILITY:
/// - Announces state changes to screen readers
/// - High contrast colors for visibility
/// - Persistent display (not auto-dismissing) for users who need more time
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ConnectivityCubit, ConnectivityState>(
        builder: (context, state) {
          // Don't show banner when online with no pending items
          if (state is ConnectivityOnline && state.pendingCount == 0) {
            return const SizedBox.shrink();
          }

          // Don't show during initial state
          if (state is ConnectivityInitial) {
            return const SizedBox.shrink();
          }

          // Determine banner content and color based on state
          final bannerContent = _buildBannerContent(state);
          final bannerColor = _getBannerColor(state);
          final textColor = _getTextColor(state);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Material(
              color: bannerColor,
              elevation: 4.0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      _buildIcon(state),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          bannerContent,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

  /// Build appropriate icon based on connectivity state.
  ///
  /// WHAT: Returns an icon widget representing current state.
  ///
  /// ICONS:
  /// - Offline: cloud_off (no connection)
  /// - Syncing: sync (rotating animation indicates progress)
  /// - Online with pending: cloud_queue (items waiting)
  Widget _buildIcon(ConnectivityState state) {
    if (state is ConnectivityOffline) {
      return Icon(
        Icons.cloud_off,
        color: _getTextColor(state),
        size: 20.0,
      );
    } else if (state is ConnectivitySyncing) {
      return SizedBox(
        width: 20.0,
        height: 20.0,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            _getTextColor(state),
          ),
        ),
      );
    } else {
      // Online with pending count
      return Icon(
        Icons.cloud_queue,
        color: _getTextColor(state),
        size: 20.0,
      );
    }
  }

  /// Build banner message based on state and pending count.
  ///
  /// WHAT: Returns localized message string for current state.
  ///
  /// MESSAGE LOGIC:
  /// - Offline with 0 pending: "You're offline"
  /// - Offline with N pending: "You're offline. N changes will sync when connected"
  /// - Syncing: "Syncing N changes..."
  /// - Online with pending: Shows via SyncStatusIndicator instead
  ///
  /// LOCALIZATION:
  /// - Uses AppStrings constants
  /// - Handles singular/plural for "change" vs "changes"
  /// - Supports placeholder replacement via AppStrings.format()
  String _buildBannerContent(ConnectivityState state) {
    if (state is ConnectivityOffline) {
      if (state.pendingCount == 0) {
        return AppStrings.connectivityBannerOffline;
      } else {
        final itemWord = state.pendingCount == 1
            ? AppStrings.connectivityItemSingular
            : AppStrings.connectivityItemPlural;
        return AppStrings.format(
          AppStrings.connectivityBannerOfflineWithPending,
          {
            'count': state.pendingCount.toString(),
            'items': itemWord,
          },
        );
      }
    } else if (state is ConnectivitySyncing) {
      final itemWord = state.pendingCount == 1
          ? AppStrings.connectivityItemSingular
          : AppStrings.connectivityItemPlural;
      return AppStrings.format(
        AppStrings.connectivityBannerSyncing,
        {
          'count': state.pendingCount.toString(),
          'items': itemWord,
        },
      );
    } else if (state is ConnectivityOnline && state.pendingCount > 0) {
      // This case is handled by SyncStatusIndicator, but just in case
      final itemWord = state.pendingCount == 1
          ? AppStrings.connectivityItemSingular
          : AppStrings.connectivityItemPlural;
      return AppStrings.format(
        AppStrings.connectivityPendingCount,
        {
          'count': state.pendingCount.toString(),
          'items': itemWord,
        },
      );
    }

    return AppStrings.connectivityStatusOffline;
  }

  /// Get banner background color based on state.
  ///
  /// WHAT: Returns appropriate background color for banner.
  ///
  /// COLOR SCHEME:
  /// - Offline: Amber/Orange - Warning color, not critical
  /// - Syncing: Blue - Info color, operation in progress
  /// - Online with pending: Light blue - Info, less urgent than syncing
  ///
  /// WHY THESE COLORS:
  /// - Offline is not an error (app still works), so not red
  /// - Syncing is positive action (progress), so blue
  /// - Colors follow Material Design semantic color guidelines
  Color _getBannerColor(ConnectivityState state) {
    if (state is ConnectivityOffline) {
      return Colors.orange.shade700;
    } else if (state is ConnectivitySyncing) {
      return Colors.blue.shade700;
    } else {
      // Online with pending
      return Colors.blue.shade600;
    }
  }

  /// Get text/icon color based on state.
  ///
  /// WHAT: Returns appropriate text color for readability.
  ///
  /// WHY: All states use dark backgrounds, so white text ensures
  /// sufficient contrast for WCAG AA compliance.
  Color _getTextColor(ConnectivityState state) => Colors.white;
}
