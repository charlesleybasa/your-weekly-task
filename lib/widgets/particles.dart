import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/utils/context_x.dart';

/// One particle's initial conditions. Everything after spawn is pure physics,
/// so the whole system is a single [CustomPainter] with no per-particle
/// widgets — which is what keeps a 60-piece burst off the widget tree.
class _Particle {
  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.spin,
    required this.shape,
    required this.delay,
  });

  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double spin;
  final int shape; // 0 rect, 1 circle, 2 ribbon
  final double delay;
}

enum BurstStyle {
  /// Wide, colourful, celebratory. Task completion and level up.
  confetti,

  /// Tight gold spray. XP awards.
  sparkle,

  /// Outward ring of shards. The timer's ring exploding.
  ring,
}

/// A one-shot particle burst.
///
/// Deliberately un-looped and self-disposing: particle effects are reserved for
/// meaningful moments, and one that keeps running is just an animated
/// distraction.
class ParticleBurst extends StatefulWidget {
  const ParticleBurst({
    super.key,
    this.style = BurstStyle.confetti,
    this.count = 44,
    this.origin = const Alignment(0, -0.15),
    this.colors,
    this.duration = const Duration(milliseconds: 1500),
    this.spread = math.pi * 2,
    this.onComplete,
  });

  final BurstStyle style;
  final int count;
  final Alignment origin;
  final List<Color>? colors;
  final Duration duration;

  /// Angular spread in radians. A full circle by default.
  final double spread;

  final VoidCallback? onComplete;

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<ParticleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onComplete?.call();
      });
    _particles = _spawn();
    _controller.forward();
  }

  List<_Particle> _spawn() {
    final palette = widget.colors ?? _defaultPalette();
    final count = widget.style == BurstStyle.sparkle
        ? (widget.count * 0.6).round()
        : widget.count;

    return List<_Particle>.generate(count, (i) {
      final base = widget.style == BurstStyle.ring
          ? (i / count) * math.pi * 2
          : -math.pi / 2 + (_random.nextDouble() - 0.5) * widget.spread;

      return _Particle(
        angle: base + (_random.nextDouble() - 0.5) * 0.25,
        speed: switch (widget.style) {
          BurstStyle.confetti => 190 + _random.nextDouble() * 260,
          BurstStyle.sparkle => 90 + _random.nextDouble() * 150,
          BurstStyle.ring => 160 + _random.nextDouble() * 110,
        },
        size: switch (widget.style) {
          BurstStyle.confetti => 5 + _random.nextDouble() * 7,
          BurstStyle.sparkle => 3 + _random.nextDouble() * 4,
          BurstStyle.ring => 3 + _random.nextDouble() * 5,
        },
        color: palette[_random.nextInt(palette.length)],
        spin: (_random.nextDouble() - 0.5) * 10,
        shape: widget.style == BurstStyle.sparkle
            ? 1
            : _random.nextInt(3),
        delay: _random.nextDouble() * 0.12,
      );
    });
  }

  List<Color> _defaultPalette() {
    final colors = context.colors;
    return switch (widget.style) {
      BurstStyle.confetti => [
          colors.primary,
          colors.success,
          colors.xp,
          colors.streak,
          const Color(0xFF8B5CF6),
          const Color(0xFFEC4899),
        ],
      BurstStyle.sparkle => [
          colors.xp,
          colors.xp.lighten(0.2),
          const Color(0xFFFFF0B8),
        ],
      BurstStyle.ring => [colors.primary, colors.success, colors.xp],
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion replaces the burst with nothing — the state change is
    // already carried by the modal and the sound.
    if (!context.motion.enabled) return const SizedBox.shrink();

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _BurstPainter(
              particles: _particles,
              t: _controller.value,
              origin: widget.origin,
              gravity: widget.style == BurstStyle.confetti ? 620 : 240,
            ),
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.particles,
    required this.t,
    required this.origin,
    required this.gravity,
  });

  final List<_Particle> particles;
  final double t;
  final Alignment origin;
  final double gravity;

  @override
  void paint(Canvas canvas, Size size) {
    final start = origin.alongSize(size);
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      // Drag makes the initial burst fast and the settle slow, which is what
      // separates confetti from a firework.
      final drag = 1 - math.exp(-2.6 * local);
      final distance = p.speed * drag / 2.6;

      final dx = math.cos(p.angle) * distance;
      final dy = math.sin(p.angle) * distance + 0.5 * gravity * local * local;

      final opacity = local < 0.75 ? 1.0 : (1 - (local - 0.75) / 0.25);
      if (opacity <= 0) continue;

      paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(start.dx + dx, start.dy + dy);
      canvas.rotate(p.spin * local);

      switch (p.shape) {
        case 0:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: p.size,
                height: p.size * 0.62,
              ),
              const Radius.circular(1.5),
            ),
            paint,
          );
        case 1:
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
        default:
          // Ribbon: a rectangle that scales on one axis as it tumbles.
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: p.size * 0.45,
                height: p.size * 1.5 * (0.4 + 0.6 * math.cos(p.spin * local).abs()),
              ),
              const Radius.circular(1),
            ),
            paint,
          );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

/// XP flying towards the profile badge.
///
/// A short, directed animation rather than a burst: the point is to connect
/// "task finished here" with "level bar over there".
class XpFlyaway extends StatefulWidget {
  const XpFlyaway({
    super.key,
    required this.amount,
    required this.onComplete,
  });

  final int amount;
  final VoidCallback onComplete;

  @override
  State<XpFlyaway> createState() => _XpFlyawayState();
}

class _XpFlyawayState extends State<XpFlyaway>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward().whenComplete(widget.onComplete);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (!context.motion.enabled) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOutCubic.transform(_controller.value);
          final fade = _controller.value < 0.7
              ? 1.0
              : 1 - (_controller.value - 0.7) / 0.3;
          return Align(
            alignment: Alignment.lerp(
              const Alignment(0, 0.1),
              const Alignment(0, -0.92),
              t,
            )!,
            child: Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.scale(scale: 1 + 0.25 * math.sin(t * math.pi), child: child),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colors.xp,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: colors.xp.withValues(alpha: 0.45),
                blurRadius: 20,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Text(
            '+${widget.amount} XP',
            style: context.text.labelLarge?.copyWith(
              color: const Color(0xFF3D2C00),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
