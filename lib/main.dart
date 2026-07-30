import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/sound_service.dart';
import 'core/storage/board_repository.dart';
import 'core/storage/card_repository.dart';
import 'core/storage/local_database.dart';
import 'core/storage/seed_data.dart';
import 'core/storage/settings_repository.dart';
import 'state/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Edge-to-edge with a transparent system chrome; the shell handles insets.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Everything the first frame needs is resolved here, so no screen has to
  // render a loading state: by the time `runApp` is called the database is
  // open, settings are read, and the services are live.
  final database = await LocalDatabase.open();
  final settingsRepository = await SettingsRepository.open();

  await _seedIfFirstRun(database);

  final sound = SoundService();
  final notifications = NotificationService();
  await Future.wait([sound.init(), notifications.init()]);

  final settings = settingsRepository.load();
  sound.enabled = settings.soundEnabled;

  runApp(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        soundServiceProvider.overrideWithValue(sound),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const MomentumApp(),
    ),
  );
}

/// Populates a brand-new install with a small, realistic example week.
///
/// Gated on a flag rather than on emptiness, so a user who deletes everything
/// does not get the sample content resurrected on next launch.
Future<void> _seedIfFirstRun(LocalDatabase database) async {
  if (database.meta.get(MetaKeys.seeded) == 'true') return;

  final seed = SeedData.build();
  await BoardRepository(database).upsertAll(seed.boards);
  await CardRepository(database).upsertAll(seed.cards);
  await database.meta.put(MetaKeys.seeded, 'true');
}
