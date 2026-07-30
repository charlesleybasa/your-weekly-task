import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';
import 'state/settings_controller.dart';
import 'state/timer_controller.dart';

class MomentumApp extends ConsumerStatefulWidget {
  const MomentumApp({super.key});

  @override
  ConsumerState<MomentumApp> createState() => _MomentumAppState();
}

class _MomentumAppState extends ConsumerState<MomentumApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The periodic ticker can be throttled or suspended in the background, so
    // the countdown is re-derived from the wall clock on every resume.
    if (state == AppLifecycleState.resumed) {
      ref.read(timerProvider.notifier).syncWithClock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Momentum',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: settings.themeChoice.mode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      builder: (context, child) {
        // Motion is reduced when *either* the OS asks for it or the user turned
        // animations off in Settings. Resolving it here means the whole tree
        // reads one consistent set of motion tokens.
        final reduce = MediaQuery.disableAnimationsOf(context) ||
            !settings.animationsEnabled;

        final theme = Theme.of(context).brightness == Brightness.dark
            ? AppTheme.dark(reduceMotion: reduce)
            : AppTheme.light(reduceMotion: reduce);

        return Theme(
          data: theme,
          child: MediaQuery(
            // Respect the user's font size, but cap the extreme end so the
            // layout degrades gracefully instead of overflowing.
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.textScalerOf(context).clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.6,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
