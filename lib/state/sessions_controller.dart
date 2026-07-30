import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/focus_session.dart';
import '../core/utils/date_x.dart';
import 'app_providers.dart';

/// Append-only log of finished focus blocks, newest first.
class SessionsController extends Notifier<List<FocusSession>> {
  @override
  List<FocusSession> build() => ref.read(sessionRepositoryProvider).loadAll();

  Future<void> add(FocusSession session) async {
    state = [session, ...state];
    await ref.read(sessionRepositoryProvider).add(session);
  }

  Future<void> clear() async {
    state = const [];
    await ref.read(localDatabaseProvider).sessions.clear();
  }
}

final sessionsProvider =
    NotifierProvider<SessionsController, List<FocusSession>>(
  SessionsController.new,
);

/// Total focused time today — shown on the dashboard and used by the Deep Work
/// achievement.
final todayFocusProvider = Provider<Duration>((ref) {
  final key = DateTime.now().dayKey;
  final sessions = ref.watch(sessionsProvider);
  var seconds = 0;
  for (final s in sessions) {
    if (s.dayKey == key) seconds += s.actualSeconds;
  }
  return Duration(seconds: seconds);
});

/// Most recent sessions, for the focus screen's history strip.
final recentSessionsProvider = Provider<List<FocusSession>>((ref) {
  final sessions = ref.watch(sessionsProvider);
  return sessions.length <= 10 ? sessions : sessions.sublist(0, 10);
});
