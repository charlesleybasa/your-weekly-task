import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme/app_geometry.dart';
import '../core/utils/context_x.dart';

/// The standard card surface: rounded, bordered, softly shadowed.
///
/// Depth is carried by the border in light mode and by surface luminance in
/// dark mode, so neither theme relies on a shadow that the other cannot show.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppGeometry.lg),
    this.radius = AppGeometry.brLg,
    this.color,
    this.borderColor,
    this.elevated = false,
    this.accent,
    this.showBorder = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final BorderRadius radius;
  final Color? color;
  final Color? borderColor;
  final bool elevated;

  /// When set, tints the border — used to key a card to its board colour.
  final Color? accent;

  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: radius,
        border: showBorder
            ? Border.all(
                color: borderColor ??
                    (accent != null
                        ? accent!.withValues(alpha: colors.isDark ? 0.28 : 0.22)
                        : colors.border),
              )
            : null,
        boxShadow:
            elevated ? AppGeometry.raised(colors) : AppGeometry.rest(colors),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A surface that tilts slightly towards the pointer.
///
/// Used only for board tiles, where the 3D response sells them as physical
/// objects. Disabled entirely when motion is reduced — parallax is the first
/// thing that should go for users sensitive to movement.
class TiltSurface extends StatefulWidget {
  const TiltSurface({
    super.key,
    required this.child,
    this.maxTilt = 0.045,
    this.hoverScale = 1.02,
    this.liftPx = 6,
    this.glowColor,
    this.radius = AppGeometry.brXl,
  });

  final Widget child;

  /// Maximum rotation in radians at the corners.
  final double maxTilt;

  final double hoverScale;
  final double liftPx;
  final Color? glowColor;
  final BorderRadius radius;

  @override
  State<TiltSurface> createState() => _TiltSurfaceState();
}

class _TiltSurfaceState extends State<TiltSurface> {
  Offset _pointer = Offset.zero; // -1..1 on each axis
  bool _hovered = false;

  void _update(PointerEvent event, Size size) {
    if (size.isEmpty) return;
    setState(() {
      _pointer = Offset(
        (event.localPosition.dx / size.width - 0.5) * 2,
        (event.localPosition.dy / size.height - 0.5) * 2,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    if (!motion.enabled) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final tiltX = _hovered ? -_pointer.dy * widget.maxTilt : 0.0;
        final tiltY = _hovered ? _pointer.dx * widget.maxTilt : 0.0;
        final scale = _hovered ? widget.hoverScale : 1.0;
        final lift = _hovered ? widget.liftPx : 0.0;

        return MouseRegion(
          onEnter: (e) {
            setState(() => _hovered = true);
            _update(e, size);
          },
          onHover: (e) => _update(e, size),
          onExit: (_) => setState(() {
            _hovered = false;
            _pointer = Offset.zero;
          }),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _hovered ? 1 : 0),
            duration: motion.base,
            curve: motion.decelerate,
            builder: (context, t, child) {
              final matrix = Matrix4.identity()
                ..setEntry(3, 2, 0.0012) // perspective
                ..rotateX(tiltX * t)
                ..rotateY(tiltY * t)
                ..scale(1 + (scale - 1) * t);

              return Transform(
                alignment: Alignment.center,
                transform: matrix,
                child: Transform.translate(
                  offset: Offset(0, -lift * t),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: widget.radius,
                      boxShadow: t == 0 || widget.glowColor == null
                          ? const []
                          : [
                              BoxShadow(
                                color: widget.glowColor!
                                    .withValues(alpha: 0.26 * t),
                                blurRadius: 28 * t,
                                spreadRadius: -6,
                                offset: Offset(0, 12 * t),
                              ),
                            ],
                    ),
                    child: child,
                  ),
                ),
              );
            },
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Frosted overlay. Used sparingly — only for the bottom navigation and the
/// focus screen's floating controls, where content scrolls beneath.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = AppGeometry.brXl,
    this.blur = 24,
    this.opacity = 0.82,
    this.border = true,
  });

  final Widget child;
  final BorderRadius radius;
  final double blur;
  final double opacity;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: opacity),
            borderRadius: radius,
            border: border ? Border.all(color: colors.border) : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Section heading with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: AppGeometry.md),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: context.text.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small pill label. Priority, tags, durations, counts.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.foreground,
    this.background,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final Color? foreground;
  final Color? background;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = foreground ?? colors.textSecondary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: background ?? colors.surfaceSunken,
        borderRadius: AppGeometry.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: (dense ? context.text.labelSmall : context.text.labelMedium)
                ?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
