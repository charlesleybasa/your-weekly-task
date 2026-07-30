import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications only — the app has no server and no account.
///
/// Every method is defensive: permission can be denied, exact alarms can be
/// unavailable on Android 12+, and the plugin has no desktop/web
/// implementation. None of that may break the feature it belongs to, so
/// failures degrade to "no notification" rather than an exception.
class NotificationService {
  NotificationService();

  static const _timerChannel = AndroidNotificationChannel(
    'focus_timer',
    'Focus timer',
    description: 'Fires when a focus session finishes.',
    importance: Importance.max,
  );

  static const _reminderChannel = AndroidNotificationChannel(
    'reminders',
    'Reminders',
    description: 'Daily and weekly planning nudges.',
    importance: Importance.defaultImportance,
  );

  // Fixed ids so re-scheduling replaces rather than stacks.
  static const int _timerId = 1001;
  static const int _dailyId = 1002;
  static const int _weeklyId = 1003;

  final _plugin = FlutterLocalNotificationsPlugin();

  bool _available = false;
  bool _permissionGranted = false;

  bool get isAvailable => _available && _permissionGranted;

  static bool get _supportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> init() async {
    if (!_supportedPlatform) return;
    try {
      // Scheduling requires the timezone database. Times are converted to
      // absolute instants (see _instant), so no platform timezone lookup —
      // and therefore no extra plugin — is needed.
      tzdata.initializeTimeZones();

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Permission is requested explicitly on first use instead, so the
          // prompt arrives with context rather than at cold start.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _plugin.initialize(settings);

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.createNotificationChannel(_timerChannel);
        await android.createNotificationChannel(_reminderChannel);
      }

      _available = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Momentum: notifications unavailable ($e)');
    }
  }

  /// Converts a local [DateTime] to the equivalent absolute instant.
  ///
  /// UTC is used deliberately: every schedule in this app is "at this exact
  /// moment", and an absolute instant is correct regardless of which zone the
  /// device thinks it is in. It also avoids depending on a platform-timezone
  /// plugin just to name the local zone.
  static tz.TZDateTime _instant(DateTime local) =>
      tz.TZDateTime.from(local.toUtc(), tz.UTC);

  /// Asks for permission. Safe to call repeatedly; the OS only prompts once.
  Future<bool> requestPermission() async {
    if (!_available) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        _permissionGranted =
            await android.requestNotificationsPermission() ?? false;
        return _permissionGranted;
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        _permissionGranted = await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
        return _permissionGranted;
      }

      final macos = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      if (macos != null) {
        _permissionGranted = await macos.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
        return _permissionGranted;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Momentum: permission request failed ($e)');
    }
    return false;
  }

  NotificationDetails get _timerDetails => NotificationDetails(
        android: AndroidNotificationDetails(
          _timerChannel.id,
          _timerChannel.name,
          channelDescription: _timerChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: const DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

  NotificationDetails get _reminderDetails => NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannel.id,
          _reminderChannel.name,
          channelDescription: _reminderChannel.description,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  /// Immediate alert, used when a session ends with the app in the foreground.
  Future<void> showTimerFinished(String taskTitle) async {
    if (!isAvailable) return;
    try {
      await _plugin.show(
        _timerId,
        'Mission complete',
        '"$taskTitle" — time is up. Nice focus.',
        _timerDetails,
      );
    } catch (_) {/* nothing actionable */}
  }

  /// One-shot alert so the notification still lands if the app is backgrounded
  /// before the countdown ends.
  ///
  /// Inexact on Android: the countdown itself is rebuilt from the wall clock on
  /// resume, so an alert arriving a minute late is cosmetic — and an inexact
  /// alarm needs no special Android 12+ permission.
  Future<void> scheduleTimerFinish(String taskTitle, Duration after) async {
    if (!isAvailable || after <= Duration.zero) return;
    await cancelTimerFinish();
    try {
      await _plugin.zonedSchedule(
        _timerId,
        'Mission complete',
        '"$taskTitle" — time is up. Nice focus.',
        _instant(DateTime.now().add(after)),
        _timerDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Absolute, not wall-clock: _instant() already resolved the target to
        // a fixed point in time, which is what makes the UTC approach correct.
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Momentum: timer schedule failed ($e)');
    }
  }

  Future<void> cancelTimerFinish() async {
    if (!_available) return;
    try {
      await _plugin.cancel(_timerId);
    } catch (_) {}
  }

  /// Daily "plan your day" nudge at [hour]:[minute] local time.
  ///
  /// Repeats every 24 hours from the first occurrence. Because the schedule is
  /// anchored to an absolute instant, a DST change shifts it by an hour until
  /// the reminder is toggled again — an acceptable trade for not shipping a
  /// platform-timezone plugin.
  Future<void> setDailyReminder({
    required bool enabled,
    int hour = 9,
    int minute = 0,
  }) async {
    if (!_available) return;
    try {
      await _plugin.cancel(_dailyId);
      if (!enabled || !_permissionGranted) return;

      await _plugin.zonedSchedule(
        _dailyId,
        "Today's mission",
        'Pick one task and start a timer.',
        _instant(_nextOccurrence(hour: hour, minute: minute)),
        _reminderDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Absolute, not wall-clock: _instant() already resolved the target to
        // a fixed point in time, which is what makes the UTC approach correct.
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Momentum: daily reminder failed ($e)');
    }
  }

  /// Monday-morning planning nudge.
  Future<void> setWeeklyPlanningReminder({required bool enabled}) async {
    if (!_available) return;
    try {
      await _plugin.cancel(_weeklyId);
      if (!enabled || !_permissionGranted) return;

      await _plugin.zonedSchedule(
        _weeklyId,
        'Plan your week',
        'A few minutes now makes the next seven days easier.',
        _instant(_nextMonday(hour: 8)),
        _reminderDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Absolute, not wall-clock: _instant() already resolved the target to
        // a fixed point in time, which is what makes the UTC approach correct.
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Momentum: weekly reminder failed ($e)');
    }
  }

  /// The next time today's [hour]:[minute] comes around, tomorrow if it has
  /// already passed.
  static DateTime _nextOccurrence({required int hour, required int minute}) {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (!target.isAfter(now)) target = target.add(const Duration(days: 1));
    return target;
  }

  static DateTime _nextMonday({required int hour}) {
    final now = DateTime.now();
    final daysAhead = (DateTime.monday - now.weekday + 7) % 7;
    var target = DateTime(now.year, now.month, now.day, hour)
        .add(Duration(days: daysAhead));
    if (!target.isAfter(now)) target = target.add(const Duration(days: 7));
    return target;
  }

  Future<void> cancelAll() async {
    if (!_available) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
