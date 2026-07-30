import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The app's sound palette.
///
/// Every cue is a short, soft, non-arcade tone. Sounds reinforce a state change
/// that already happened visually; none of them is the primary signal, so the
/// app is fully usable with audio off.
enum Sfx {
  tap('tap.wav'),
  pickUp('pickup.wav'),
  drop('drop.wav'),
  taskCreated('create.wav'),
  boardCreated('board_created.wav'),
  taskStarted('start.wav'),
  taskCompleted('complete.wav'),
  timerStart('timer_start.wav'),
  timerPause('pause.wav'),
  timerResume('resume.wav'),
  timerFinished('timer_done.wav'),
  timerTick('tick.wav'),
  xpEarned('xp.wav'),
  levelUp('level_up.wav'),
  achievement('achievement.wav'),
  notification('notify.wav');

  const Sfx(this.file);

  final String file;

  String get assetPath => 'sounds/$file';
}

/// Plays UI sounds through a small round-robin pool.
///
/// A pool rather than a single player because cues overlap — an XP chime can
/// land while the completion sound is still ringing, and re-using one player
/// would cut the first off mid-tail.
class SoundService {
  SoundService();

  static const _poolSize = 4;

  final List<AudioPlayer> _pool = [];
  int _cursor = 0;
  bool _enabled = true;
  bool _ready = false;

  /// Prevents a stuck audio session from spamming the log on every tap.
  bool _muteAfterFailure = false;

  bool get enabled => _enabled;

  set enabled(bool value) {
    _enabled = value;
    if (!value) stopAll();
  }

  Future<void> init() async {
    if (_ready) return;
    if (kIsWeb) {
      _ready = true;
      return;
    }
    try {
      for (var i = 0; i < _poolSize; i++) {
        final player = AudioPlayer(playerId: 'sfx_$i')
          ..setReleaseMode(ReleaseMode.stop);
        await player.setPlayerMode(PlayerMode.lowLatency);
        // Ducking rather than exclusive playback: a focus chime should not stop
        // whatever the user is listening to while working.
        await player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: false,
              stayAwake: false,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.assistanceSonification,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.ambient,
              options: const {AVAudioSessionOptions.mixWithOthers},
            ),
          ),
        );
        _pool.add(player);
      }
      _ready = true;
    } catch (e) {
      // Audio is a nicety. If the platform refuses to set up a session the app
      // must still run — degrade to silence instead of failing startup.
      _muteAfterFailure = true;
      if (kDebugMode) debugPrint('Momentum: sound disabled ($e)');
    }
  }

  void play(Sfx sfx, {double volume = 1.0}) {
    if (!_enabled || !_ready || _muteAfterFailure) return;
    final player = _pool[_cursor];
    _cursor = (_cursor + 1) % _pool.length;
    // Fire-and-forget: a UI cue must never make the caller await.
    unawaited(_playOn(player, sfx, volume));
  }

  Future<void> _playOn(AudioPlayer player, Sfx sfx, double volume) async {
    try {
      await player.stop();
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.play(AssetSource(sfx.assetPath));
    } catch (e) {
      _muteAfterFailure = true;
      if (kDebugMode) debugPrint('Momentum: could not play ${sfx.file} ($e)');
    }
  }

  void stopAll() {
    for (final player in _pool) {
      unawaited(player.stop().catchError((_) {}));
    }
  }

  Future<void> dispose() async {
    for (final player in _pool) {
      await player.dispose().catchError((_) {});
    }
    _pool.clear();
    _ready = false;
  }
}
