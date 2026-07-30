import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_typography.dart';
import '../core/utils/context_x.dart';

/// Circular progress that animates from its previous value rather than
/// snapping. Used for weekly completion and the focus countdown.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 120,
    this.strokeWidth = 10,
    this.color,
    this.trackColor,
    this.gradientEnd,
    this.glow = false,
    this.child,
    this.duration,
  });

  /// 0.0 – 1.0.
  final double value;

  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;

  /// When set, the arc sweeps from [color] to this colour.
  final Color? gradientEnd;

  /// Adds an outer bloom — reserved for the final ten seconds of a timer.
  final bool glow;

  final Widget? child;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    final arcColor = color ?? colors.primary;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.clamp(0.0, 1.0)),
      duration: duration ?? motion.slower,
      curve: motion.decelerate,
      builder: (context, animated, child) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              value: animated,
              strokeWidth: strokeWidth,
              color: arcColor,
              gradientEnd: gradientEnd,
              trackColor: trackColor ?? colors.surfaceSunken,
              glow: glow,
            ),
            child: Center(child: child),
          ),
        );
      },
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
    required this.gradientEnd,
    required this.glow,
  });

  final double value;
  final double strokeWidth;
  final Color color;
  final Color trackColor;
  final Color? gradientEnd;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (value <= 0) return;

    const start = -math.pi / 2;
    final sweep = 2 * math.pi * value;

    if (glow) {
      final bloom = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 1.7
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawArc(rect, start, sweep, false, bloom);
    }

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (gradientEnd != null) {
      // A SweepGradient always begins at 3 o'clock; rotating it by `start`
      // lines the colour ramp up with the arc, which begins at 12.
      arc.shader = SweepGradient(
        colors: [color, gradientEnd!, color],
        stops: const [0.0, 0.65, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    } else {
      arc.color = color;
    }

    canvas.drawArc(rect, start, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.glow != glow ||
      old.gradientEnd != gradientEnd;
}

/// A number that counts to its new value instead of jumping.
///
/// Digits are tabular so the width never jitters mid-count.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration,
  });

  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: duration ?? motion.slower,
      curve: motion.decelerate,
      builder: (context, animated, _) => Text(
        '$prefix${animated.round()}$suffix',
        style: (style ?? AppTypography.stat(context.colors.textPrimary))
            .copyWith(fontFeatures: AppTypography.tabular),
      ),
    );
  }
}

/// Horizontal progress bar that fills from its previous value.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
    this.trackColor,
    this.duration,
  });

  final double value;
  final double height;
  final Color? color;
  final Color? trackColor;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: value.clamp(0.0, 1.0)),
          duration: duration ?? motion.slower,
          curve: motion.decelerate,
          builder: (context, animated, _) => Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: trackColor ?? colors.surfaceSunken),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: animated,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height),
                    gradient: LinearGradient(
                      colors: [
                        (color ?? colors.primary).withValues(alpha: 0.85),
                        color ?? colors.primary,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Level badge + XP bar. The header's progression readout.
class XpProgressBar extends StatelessWidget {
  const XpProgressBar({
    super.key,
    required this.level,
    required this.title,
    required this.progress,
    required this.xpIntoLevel,
    required this.xpForLevel,
    this.compact = false,
  });

  final int level;
  final String title;
  final double progress;
  final int xpIntoLevel;
  final int xpForLevel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.xp.withValues(alpha: colors.isDark ? 0.18 : 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'LV $level',
                style: context.text.labelSmall?.copyWith(
                  color: colors.isDark ? colors.xp : const Color(0xFF8A6100),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: context.text.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!compact)
              Text(
                '$xpIntoLevel / $xpForLevel XP',
                style: context.text.labelSmall,
              ),
          ],
        ),
        const SizedBox(height: 8),
        AppProgressBar(value: progress, color: colors.xp, height: 7),
      ],
    );
  }
}

/// Streak flame. Idles with a slow flicker, and swells briefly when the count
/// goes up so the increment is felt rather than just read.
class StreakFlame extends StatefulWidget {
  const StreakFlame({
    super.key,
    required this.days,
    this.live = true,
    this.size = 22,
  });

  final int days;

  /// A lapsed streak renders cold — the flame should not keep burning for a
  /// streak the user has already lost.
  final bool live;

  final double size;

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flicker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  double _boost = 0;

  @override
  void didUpdateWidget(StreakFlame old) {
    super.didUpdateWidget(old);
    if (widget.days > old.days) {
      setState(() => _boost = 1);
      Future<void>.delayed(const Duration(milliseconds: 520), () {
        if (mounted) setState(() => _boost = 0);
      });
    }
  }

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    final cold = !widget.live || widget.days == 0;
    final tint = cold ? colors.textTertiary : colors.streak;

    Widget flame = Icon(
      Icons.local_fire_department_rounded,
      size: widget.size,
      color: tint,
    );

    if (!cold && motion.enabled) {
      flame = AnimatedBuilder(
        animation: _flicker,
        builder: (context, child) {
          final t = _flicker.value;
          return Transform.scale(
            // Small, irregular breathing — a perfectly even pulse reads
            // mechanical rather than alive.
            scale: 1 + 0.045 * math.sin(t * math.pi * 2) + 0.02 * math.sin(t * 7),
            child: child,
          );
        },
        child: flame,
      );
    }

    return AnimatedScale(
      scale: 1 + _boost * 0.35,
      duration: motion.slow,
      curve: motion.overshoot,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!cold && motion.enabled)
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.streak.withValues(alpha: 0.35 * (0.4 + _boost)),
                    blurRadius: 14 + 10 * _boost,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: flame,
            )
          else
            flame,
          const SizedBox(width: 5),
          Text(
            '${widget.days}',
            style: context.text.titleMedium?.copyWith(
              color: cold ? colors.textTertiary : colors.textPrimary,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      ),
    );
  }
}
