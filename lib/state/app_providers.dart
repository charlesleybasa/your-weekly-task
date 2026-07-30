import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/haptic_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/sound_service.dart';
import '../core/storage/board_repository.dart';
import '../core/storage/card_repository.dart';
import '../core/storage/local_database.dart';
import '../core/storage/session_repository.dart';
import '../core/storage/settings_repository.dart';
import '../core/storage/stats_repository.dart';

/// Everything below is overridden in `main()` once startup has completed.
///
/// Reading them synchronously is what lets every screen build without a
/// `FutureBuilder` — by the time the widget tree exists, the database is open
/// and the services are initialised.
final localDatabaseProvider = Provider<LocalDatabase>(
  (_) => throw StateError('localDatabaseProvider must be overridden'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (_) => throw StateError('settingsRepositoryProvider must be overridden'),
);

final soundServiceProvider = Provider<SoundService>(
  (_) => throw StateError('soundServiceProvider must be overridden'),
);

final hapticServiceProvider = Provider<HapticService>((_) => HapticService());

final notificationServiceProvider = Provider<NotificationService>(
  (_) => throw StateError('notificationServiceProvider must be overridden'),
);

final boardRepositoryProvider = Provider<BoardRepository>(
  (ref) => BoardRepository(ref.watch(localDatabaseProvider)),
);

final cardRepositoryProvider = Provider<CardRepository>(
  (ref) => CardRepository(ref.watch(localDatabaseProvider)),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(localDatabaseProvider)),
);

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(ref.watch(localDatabaseProvider)),
);
