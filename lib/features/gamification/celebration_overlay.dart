import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/achievement.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/app_geometry.dart';
import '../../core/utils/context_x.dart';
import '../../state/app_providers.dart';
import '../../state/celebration_controller.dart';
import '../../widgets/particles.dart';

/// Renders whatever is at the head of the celebration queue.
///
/// One overlay for the whole app means celebrations survive navigation and can
/// never stack — finishing a task that also levels you up and unlocks a badge
/// plays three beats in order rather than three modals at once.
class CelebrationOverlay extends ConsumerStatefulWidget {
  const CelebrationOverlay({super.key});

  @override
  ConsumerState<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends ConsumerState<CelebrationOverlay> {
  Celebration? _shown;

  void _consume() {
    if (!mounted) return;
    ref.read(celebrationProvider.notifier).consume();
  }

  @override
  Widget build(BuildContext context) {
    final celebration = ref.watch(currentCelebrationProvider);

    // Play the cue once, on the transition into a new celebration.
    if (celebration != null && !identical(celebration, _shown)) {
      _shown = celebration;
      WidgetsBinding.instance.addPostFrameCallback((_) => _announce(celebration));
    } else if (celebration == null) {
      _shown = null;
    }

    return switch (celebration) {
      null => const SizedBox.shrink(),
      XpAwarded e => _XpLayer(key: ValueKey(e), event: e, onDone: _consume),
      LevelUp e => _LevelUpModal(key: ValueKey(e), event: e, onDone: _consume),
      AchievementUnlocked e =>
        _AchievementModal(key: ValueKey(e), event: e, onDone: _consume),
      WeekCompleted e =>
        _WeekCompleteModal(key: ValueKey(e), event: e, onDone: _consume),
    };
  }

  void _announce(Celebration celebration) {
    final sound = ref.read(soundServiceProvider);
    final haptics = ref.read(hapticServiceProvider);

    switch (celebration) {
      case XpAwarded():
        sound.play(Sfx.xpEarned);
        haptics.fire(HapticLevel.light);
      case LevelUp():
        sound.play(Sfx.levelUp);
        haptics.celebrate();
      case AchievementUnlocked():
        sound.play(Sfx.achievement);
        haptics.fire(HapticLevel.heavy);
      case WeekCompleted():
        sound.play(Sfx.levelUp);
        haptics.celebrate();
    }
  }
}

/// XP: a non-blocking flyaway towards the level badge plus a gold sparkle.
/// Deliberately not a modal — earning XP should never interrupt.
class _XpLayer extends StatelessWidget {
  const _XpLayer({super.key, required this.event, required this.onDone});

  final XpAwarded event;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const Positioned.fill(
            child: ParticleBurst(
              style: BurstStyle.sparkle,
              count: 26,
              origin: Alignment(0, 0.1),
              duration: Duration(milliseconds: 1100),
            ),
          ),
          Positioned.fill(
            child: XpFlyaway(
              amount: event.breakdown.total,
              onComplete: onDone,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared scaffold for the three modal celebrations.
class _CelebrationModal extends StatefulWidget {
  const _CelebrationModal({
    required this.badge,
    required this.title,
    required this.message,
    required this.accent,
    required this.onDone,
    this.footer,
    this.burst = BurstStyle.confetti,
  });

  final Widget badge;
  final String title;
  final String message;
  final Color accent;
  final VoidCallback onDone;
  final Widget? footer;
  final BurstStyle burst;

  @override
  State<_CelebrationModal> createState() => _CelebrationModalState();
}

class _CelebrationModalState extends State<_CelebrationModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  bool _closing = false;

  Future<void> _close() async {
    if (_closing) return;
    setState(() => _closing = true);
    await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    final curved = CurvedAnimation(
      parent: _controller,
      curve: motion.enabled ? motion.overshoot : Curves.linear,
      reverseCurve: Curves.easeIn,
    );

    return Semantics(
      liveRegion: true,
      label: '${widget.title}. ${widget.message}',
      child: Stack(
        children: [
          // Tapping anywhere dismisses — a celebration must never trap you.
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.opaque,
              child: FadeTransition(
                opacity: _controller,
                child: ColoredBox(color: colors.scrim),
              ),
            ),
          ),
          if (!_closing)
            Positioned.fill(
              child: ParticleBurst(
                style: widget.burst,
                count: 54,
                origin: const Alignment(0, -0.1),
              ),
            ),
          Center(
            child: FadeTransition(
              opacity: _controller,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.82, end: 1).animate(curved),
                child: Padding(
                  padding: const EdgeInsets.all(AppGeometry.xxl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Container(
                      padding: const EdgeInsets.all(AppGeometry.xxl),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: AppGeometry.brXl,
                        border: Border.all(
                          color: widget.accent.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.accent.withValues(alpha: 0.22),
                            blurRadius: 44,
                            spreadRadius: -8,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SpinInBadge(
                            animation: curved,
                            accent: widget.accent,
                            child: widget.badge,
                          ),
                          const SizedBox(height: AppGeometry.xl),
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: context.text.headlineMedium,
                          ),
                          const SizedBox(height: AppGeometry.sm),
                          Text(
                            widget.message,
                            textAlign: TextAlign.center,
                            style: context.text.bodyMedium,
                          ),
                          if (widget.footer != null) ...[
                            const SizedBox(height: AppGeometry.lg),
                            widget.footer!,
                          ],
                          const SizedBox(height: AppGeometry.xxl),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _close,
                              style: FilledButton.styleFrom(
                                backgroundColor: widget.accent,
                                foregroundColor:
                                    ThemeData.estimateBrightnessForColor(
                                              widget.accent,
                                            ) ==
                                            Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFF12161F),
                              ),
                              child: const Text('Nice'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The badge rotates and scales in — the single most "game-like" moment in the
/// app, so it gets the most expressive entrance.
class _SpinInBadge extends StatelessWidget {
  const _SpinInBadge({
    required this.animation,
    required this.child,
    required this.accent,
  });

  final Animation<double> animation;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final badge = Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accent.withValues(alpha: 0.28),
            accent.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 2),
      ),
      child: Center(child: child),
    );

    if (!motion.enabled) return badge;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Transform.rotate(
        angle: (1 - animation.value) * 0.6,
        child: Transform.scale(scale: 0.6 + 0.4 * animation.value, child: child),
      ),
      child: badge,
    );
  }
}

class _LevelUpModal extends StatelessWidget {
  const _LevelUpModal({super.key, required this.event, required this.onDone});

  final LevelUp event;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _CelebrationModal(
      accent: colors.xp,
      onDone: onDone,
      badge: Text(
        '${event.level}',
        style: context.text.displaySmall?.copyWith(
          color: colors.isDark ? colors.xp : const Color(0xFF8A6100),
          fontSize: 40,
        ),
      ),
      title: 'Level ${event.level}',
      message: 'You are now a ${event.title}. Keep the momentum going.',
    );
  }
}

class _AchievementModal extends StatelessWidget {
  const _AchievementModal({
    super.key,
    required this.event,
    required this.onDone,
  });

  final AchievementUnlocked event;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final Achievement a = event.achievement;
    return _CelebrationModal(
      accent: a.tint,
      onDone: onDone,
      badge: Icon(a.icon, size: 44, color: a.tint),
      title: a.title,
      message: a.description,
      burst: BurstStyle.sparkle,
      footer: a.xpBonus > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.colors.xp.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '+${a.xpBonus} XP',
                style: context.text.labelMedium?.copyWith(
                  color: context.colors.isDark
                      ? context.colors.xp
                      : const Color(0xFF8A6100),
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
    );
  }
}

class _WeekCompleteModal extends StatelessWidget {
  const _WeekCompleteModal({
    super.key,
    required this.event,
    required this.onDone,
  });

  final WeekCompleted event;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _CelebrationModal(
      accent: colors.success,
      onDone: onDone,
      badge: Icon(Icons.rocket_launch_rounded, size: 44, color: colors.success),
      title: 'Week complete',
      message:
          'Every task you planned this week is done — all ${event.tasksFinished} of them.',
    );
  }
}

