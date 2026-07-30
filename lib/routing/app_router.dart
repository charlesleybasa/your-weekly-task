import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/context_x.dart';
import '../features/boards/board_detail_screen.dart';
import '../features/boards/boards_screen.dart';
import '../features/calendar/week_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/gamification/achievements_screen.dart';
import '../features/gamification/statistics_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/timer/focus_screen.dart';
import 'app_shell.dart';

abstract final class Routes {
  static const dashboard = '/dashboard';
  static const boards = '/boards';
  static const focus = '/focus';
  static const week = '/week';
  static const settings = '/settings';

  static const statistics = '/statistics';
  static const achievements = '/achievements';

  static String board(String id) => '$boards/$id';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.dashboard,
    routes: [
      // Each tab keeps its own navigation stack, so switching away from a board
      // and back returns you exactly where you were.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.dashboard,
                pageBuilder: (context, state) =>
                    _fadeThrough(state, const DashboardScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.boards,
                pageBuilder: (context, state) =>
                    _fadeThrough(state, const BoardsScreen()),
                routes: [
                  GoRoute(
                    path: ':boardId',
                    pageBuilder: (context, state) => _fadeThrough(
                      state,
                      BoardDetailScreen(
                        boardId: state.pathParameters['boardId'] ?? '',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.focus,
                pageBuilder: (context, state) =>
                    _fadeThrough(state, const FocusScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.week,
                pageBuilder: (context, state) =>
                    _fadeThrough(state, const WeekScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                pageBuilder: (context, state) =>
                    _fadeThrough(state, const SettingsScreen()),
              ),
            ],
          ),
        ],
      ),

      // Full-screen routes that cover the shell.
      GoRoute(
        path: Routes.statistics,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeThrough(state, const StatisticsScreen()),
      ),
      GoRoute(
        path: Routes.achievements,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeThrough(state, const AchievementsScreen()),
      ),
    ],
    errorBuilder: (context, state) => _RouteNotFound(location: state.uri.path),
  );
});

/// Shared page transition: fade + a small rise. Never an abrupt replace.
CustomTransitionPage<void> _fadeThrough(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondary, child) {
      final motion = context.motion;
      final curved = CurvedAnimation(
        parent: animation,
        curve: motion.emphasized,
        reverseCurve: Curves.easeIn,
      );

      if (!motion.enabled) {
        return FadeTransition(opacity: curved, child: child);
      }

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.018),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_off_rounded,
              size: 44,
              color: context.colors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text('Nothing here', style: context.text.headlineSmall),
            const SizedBox(height: 6),
            Text(location, style: context.text.bodySmall),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go(Routes.dashboard),
              child: const Text('Back to dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
