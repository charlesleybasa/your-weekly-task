import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_geometry.dart';
import '../core/theme/app_palette.dart';
import '../core/utils/context_x.dart';
import 'pressable.dart';

enum EmptyArt { boards, tasks, timer, week, achievements }

/// Empty states carry real weight in this app — a fresh install is *mostly*
/// empty states. Each one gets a purpose-drawn vector illustration with a
/// slow idle animation, a warm line of copy, and a single obvious action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.art,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final EmptyArt art;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppGeometry.xxl,
            vertical: compact ? AppGeometry.xl : AppGeometry.xxxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EmptyIllustration(art: art, size: compact ? 96 : 132),
              SizedBox(height: compact ? AppGeometry.lg : AppGeometry.xxl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.text.headlineSmall,
              ),
              const SizedBox(height: AppGeometry.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppGeometry.xxl),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyIllustration extends StatefulWidget {
  const _EmptyIllustration({required this.art, required this.size});

  final EmptyArt art;
  final double size;

  @override
  State<_EmptyIllustration> createState() => _EmptyIllustrationState();
}

class _EmptyIllustrationState extends State<_EmptyIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: switch (widget.art) {
      EmptyArt.timer => const Duration(milliseconds: 4200),
      EmptyArt.tasks => const Duration(milliseconds: 5200),
      _ => const Duration(milliseconds: 4000),
    },
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final animate = context.motion.enabled;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _EmptyArtPainter(
              art: widget.art,
              t: animate ? _controller.value : 0.25,
              colors: colors,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyArtPainter extends CustomPainter {
  _EmptyArtPainter({required this.art, required this.t, required this.colors});

  final EmptyArt art;
  final double t;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    switch (art) {
      case EmptyArt.boards:
        _paintBoards(canvas, size);
      case EmptyArt.tasks:
        _paintPaper(canvas, size);
      case EmptyArt.timer:
        _paintHourglass(canvas, size);
      case EmptyArt.week:
        _paintWeek(canvas, size);
      case EmptyArt.achievements:
        _paintTrophy(canvas, size);
    }
  }

  Paint get _fill => Paint()..style = PaintingStyle.fill;

  Paint _stroke(Color color, [double width = 2.2]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  /// A stack of three cards bobbing gently out of phase.
  void _paintBoards(Canvas canvas, Size size) {
    final w = size.width * 0.62;
    final h = size.height * 0.4;
    final center = size.center(Offset.zero);

    for (var i = 2; i >= 0; i--) {
      final phase = t * math.pi * 2 - i * 0.7;
      final bob = math.sin(phase) * 4;
      final offsetY = center.dy + (i - 1) * 15 + bob;
      final scale = 1 - i * 0.08;

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, offsetY),
          width: w * scale,
          height: h * scale,
        ),
        const Radius.circular(12),
      );

      canvas.drawRRect(
        rect,
        _fill..color = i == 0 ? colors.primary : colors.surfaceSunken,
      );
      if (i != 0) canvas.drawRRect(rect, _stroke(colors.border, 1.6));

      if (i == 0) {
        // Two content lines on the front card so it reads as a board.
        final lp = _fill..color = Colors.white.withValues(alpha: 0.55);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left + 14, rect.top + 15, rect.width * 0.5, 5),
            const Radius.circular(3),
          ),
          lp,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left + 14, rect.top + 27, rect.width * 0.32, 5),
            const Radius.circular(3),
          ),
          lp..color = Colors.white.withValues(alpha: 0.34),
        );
      }
    }
  }

  /// A sheet of paper drifting, with a checkmark — "nothing left to do".
  void _paintPaper(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final float = math.sin(t * math.pi * 2) * 6;
    final tilt = math.sin(t * math.pi * 2 + 0.8) * 0.06;

    canvas.save();
    canvas.translate(center.dx, center.dy + float);
    canvas.rotate(tilt);

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 0.5,
        height: size.height * 0.58,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, _fill..color = colors.surfaceSunken);
    canvas.drawRRect(rect, _stroke(colors.border, 1.8));

    final line = _fill..color = colors.borderStrong.withValues(alpha: 0.7);
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left + 12,
            rect.top + 16 + i * 13.0,
            rect.width * (i == 2 ? 0.4 : 0.68),
            4,
          ),
          const Radius.circular(2),
        ),
        line,
      );
    }

    // Check badge, drawn last so it sits proud of the sheet.
    final badge = Offset(rect.right - 6, rect.bottom - 8);
    canvas.drawCircle(badge, 15, _fill..color = colors.success);
    final path = Path()
      ..moveTo(badge.dx - 6, badge.dy)
      ..lineTo(badge.dx - 1.5, badge.dy + 4.5)
      ..lineTo(badge.dx + 6.5, badge.dy - 4.5);
    canvas.drawPath(path, _stroke(Colors.white, 2.6));

    canvas.restore();
  }

  /// An hourglass turning slowly, sand falling.
  void _paintHourglass(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final angle = t * math.pi * 2;
    final h = size.height * 0.56;
    final w = size.width * 0.36;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final glass = Path()
      ..moveTo(-w / 2, -h / 2)
      ..lineTo(w / 2, -h / 2)
      ..lineTo(2.5, 0)
      ..lineTo(w / 2, h / 2)
      ..lineTo(-w / 2, h / 2)
      ..lineTo(-2.5, 0)
      ..close();

    canvas.drawPath(glass, _fill..color = colors.surfaceSunken);
    canvas.drawPath(glass, _stroke(colors.borderStrong, 2.2));

    // Sand: top bulb drains as the cycle progresses.
    final drain = (t * 2) % 1.0;
    final top = Path()
      ..moveTo(-w / 2 + 4 + (w / 2 - 6) * drain, -h / 2 + 4)
      ..lineTo(w / 2 - 4 - (w / 2 - 6) * drain, -h / 2 + 4)
      ..lineTo(0, -4)
      ..close();
    canvas.drawPath(top, _fill..color = colors.xp);

    final bottomHeight = (h / 2 - 6) * drain;
    if (bottomHeight > 1) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            -w / 2 + 5,
            h / 2 - 4 - bottomHeight,
            w / 2 - 5,
            h / 2 - 4,
          ),
          const Radius.circular(3),
        ),
        _fill..color = colors.xp,
      );
    }

    canvas.drawLine(
      const Offset(0, -2),
      Offset(0, 8 + 6 * math.sin(t * 18)),
      _stroke(colors.xp, 1.8),
    );

    canvas.drawLine(
      Offset(-w / 2 - 4, -h / 2),
      Offset(w / 2 + 4, -h / 2),
      _stroke(colors.borderStrong, 3),
    );
    canvas.drawLine(
      Offset(-w / 2 - 4, h / 2),
      Offset(w / 2 + 4, h / 2),
      _stroke(colors.borderStrong, 3),
    );

    canvas.restore();
  }

  /// Seven day columns rising in a wave.
  void _paintWeek(Canvas canvas, Size size) {
    final baseline = size.height * 0.74;
    final slot = size.width / 9;

    for (var i = 0; i < 7; i++) {
      final phase = t * math.pi * 2 - i * 0.55;
      final height = 16 + (math.sin(phase) + 1) / 2 * 34;
      final x = slot * (i + 1);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - slot * 0.28, baseline - height, slot * 0.56, height),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        rect,
        _fill
          ..color = i == 3
              ? colors.primary
              : colors.primary.withValues(alpha: 0.22),
      );
    }

    canvas.drawLine(
      Offset(slot * 0.4, baseline + 6),
      Offset(size.width - slot * 0.4, baseline + 6),
      _stroke(colors.border, 2),
    );
  }

  /// A trophy with a slow shine sweep.
  void _paintTrophy(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final bob = math.sin(t * math.pi * 2) * 3;
    canvas.save();
    canvas.translate(center.dx, center.dy + bob);

    final cup = Path()
      ..moveTo(-20, -28)
      ..lineTo(20, -28)
      ..lineTo(16, 2)
      ..quadraticBezierTo(0, 16, -16, 2)
      ..close();
    canvas.drawPath(cup, _fill..color = colors.xp);

    canvas.drawArc(
      Rect.fromCircle(center: const Offset(-26, -16), radius: 11),
      -math.pi * 0.35,
      math.pi * 1.3,
      false,
      _stroke(colors.xp, 3.4),
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(26, -16), radius: 11),
      math.pi * 1.35,
      math.pi * 1.3,
      false,
      _stroke(colors.xp, 3.4),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 20), width: 10, height: 14),
        const Radius.circular(2),
      ),
      _fill..color = colors.xp.darken(0.12),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 30), width: 34, height: 8),
        const Radius.circular(4),
      ),
      _fill..color = colors.xp.darken(0.2),
    );

    // Shine sweep across the cup face.
    final shineX = -24 + 60 * ((t * 1.4) % 1.0);
    canvas.save();
    canvas.clipPath(cup);
    canvas.drawRect(
      Rect.fromLTWH(shineX, -32, 7, 56),
      _fill..color = Colors.white.withValues(alpha: 0.32),
    );
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(_EmptyArtPainter old) =>
      old.t != t || old.art != art || old.colors != colors;
}

/// Compact inline empty message for places a full illustration would dominate
/// — an empty kanban column, for instance.
class InlineEmpty extends StatelessWidget {
  const InlineEmpty({
    super.key,
    required this.message,
    this.icon,
    this.onTap,
    this.actionLabel,
  });

  final String message;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppGeometry.lg,
        vertical: AppGeometry.xl,
      ),
      decoration: BoxDecoration(
        borderRadius: AppGeometry.brLg,
        border: Border.all(
          color: colors.border,
          style: BorderStyle.solid,
        ),
        color: colors.surfaceSunken.withValues(alpha: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: colors.textTertiary),
            const SizedBox(height: AppGeometry.sm),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: colors.textTertiary),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppGeometry.sm),
            Text(
              actionLabel!,
              style: context.text.labelMedium?.copyWith(
                color: colors.primaryText,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return body;
    return Pressable(
      onTap: onTap,
      borderRadius: AppGeometry.brLg,
      semanticLabel: actionLabel ?? message,
      child: body,
    );
  }
}
