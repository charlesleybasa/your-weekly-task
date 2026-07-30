import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/haptic_service.dart';
import '../core/services/sound_service.dart';
import '../core/utils/context_x.dart';
import '../state/app_providers.dart';

/// The interaction primitive every tappable surface in the app is built from.
///
/// Handles the full feedback loop in one place: hover lift on pointer devices,
/// press scale, haptic tick, sound cue, focus ring, and a guaranteed minimum
/// tap target. Because scale is a transform it never changes layout bounds, so
/// pressing something cannot nudge its neighbours.
class Pressable extends ConsumerStatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.sfx = Sfx.tap,
    this.haptic = HapticLevel.light,
    this.hoverLift = 0,
    this.hoverScale,
    this.pressScale,
    this.enableHoverGlow = false,
    this.glowColor,
    this.semanticLabel,
    this.enabled = true,
    this.cursor = SystemMouseCursors.click,
    this.padding = EdgeInsets.zero,
    this.minSize = 0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;

  /// Pass null to stay silent — used for surfaces that already play their own
  /// cue (a card moving to Done, for example).
  final Sfx? sfx;
  final HapticLevel? haptic;

  /// Upward translation on hover, in logical pixels.
  final double hoverLift;
  final double? hoverScale;
  final double? pressScale;

  final bool enableHoverGlow;
  final Color? glowColor;

  final String? semanticLabel;
  final bool enabled;
  final MouseCursor cursor;
  final EdgeInsets padding;

  /// Enforces a minimum interactive square. 48 satisfies both platforms.
  final double minSize;

  @override
  ConsumerState<Pressable> createState() => _PressableState();
}

class _PressableState extends ConsumerState<Pressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _fireFeedback() {
    if (widget.sfx != null) {
      ref.read(soundServiceProvider).play(widget.sfx!, volume: 0.7);
    }
    if (widget.haptic != null) {
      ref.read(hapticServiceProvider).fire(widget.haptic!);
    }
  }

  void _handleTap() {
    if (!_interactive) return;
    _fireFeedback();
    widget.onTap?.call();
  }

  void _handleLongPress() {
    if (!_interactive || widget.onLongPress == null) return;
    ref.read(hapticServiceProvider).medium();
    widget.onLongPress!.call();
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final colors = context.colors;

    final active = _hovered || _focused;
    final scale = !_interactive
        ? 1.0
        : _pressed
            ? (widget.pressScale ?? motion.pressScale)
            : active
                ? (widget.hoverScale ?? 1.0)
                : 1.0;

    final lift = active && _interactive && motion.enabled ? widget.hoverLift : 0.0;

    Widget content = widget.child;

    if (widget.minSize > 0) {
      content = ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.minSize,
          minHeight: widget.minSize,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: content),
      );
    }

    if (widget.padding != EdgeInsets.zero) {
      content = Padding(padding: widget.padding, child: content);
    }

    content = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: _interactive ? _handleTap : null,
        onLongPress:
            widget.onLongPress != null && widget.enabled ? _handleLongPress : null,
        onHighlightChanged: (v) {
          if (_pressed != v) setState(() => _pressed = v);
        },
        onFocusChange: (v) {
          if (_focused != v) setState(() => _focused = v);
        },
        borderRadius: widget.borderRadius,
        splashColor: colors.primary.withValues(alpha: 0.10),
        highlightColor: colors.primary.withValues(alpha: 0.05),
        hoverColor: Colors.transparent, // hover is expressed by lift, not tint
        // A visible focus ring is the only affordance keyboard users get.
        focusColor: colors.primary.withValues(alpha: 0.12),
        child: content,
      ),
    );

    if (widget.enableHoverGlow) {
      final glow = widget.glowColor ?? colors.primary;
      content = AnimatedContainer(
        duration: motion.fast,
        curve: motion.decelerate,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: active && motion.enabled
              ? [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.22),
                    blurRadius: 22,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: content,
      );
    }

    return Semantics(
      label: widget.semanticLabel,
      button: _interactive,
      enabled: widget.enabled,
      child: MouseRegion(
        cursor: _interactive ? widget.cursor : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: AnimatedScale(
          scale: scale,
          duration: _pressed ? motion.instant : motion.fast,
          curve: motion.decelerate,
          // Translating via an animated transform (rather than padding or a
          // slide fraction) keeps the lift purely compositional — no layout
          // pass, no effect on siblings.
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: lift),
            duration: motion.fast,
            curve: motion.decelerate,
            builder: (context, value, child) => Transform.translate(
              offset: Offset(0, -value),
              child: child,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Icon button with a guaranteed 48dp target and a descriptive label.
///
/// Wraps [Pressable] rather than Material's IconButton so icon-only controls
/// pick up the same hover/press/sound language as everything else.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
    this.background,
    this.size = 22,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Doubles as the accessibility label — an icon-only control must never ship
  /// without one.
  final String tooltip;

  final Color? color;
  final Color? background;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = enabled
        ? (color ?? colors.textSecondary)
        : colors.textTertiary.withValues(alpha: 0.5);

    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        enabled: enabled && onPressed != null,
        semanticLabel: tooltip,
        borderRadius: BorderRadius.circular(14),
        minSize: 48,
        hoverScale: 1.06,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: size, color: fg),
        ),
      ),
    );
  }
}
