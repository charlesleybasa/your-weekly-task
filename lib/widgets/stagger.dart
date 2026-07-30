import 'package:flutter/material.dart';

import '../core/utils/context_x.dart';

/// Fades and lifts a child into place after a per-index delay.
///
/// The delay is capped inside [AppMotion.stagger] so a long list does not make
/// its last item wait seconds — past about a dozen items the eye reads the
/// group as a single gesture anyway.
class StaggerReveal extends StatefulWidget {
  const StaggerReveal({
    super.key,
    required this.index,
    required this.child,
    this.offset = 14,
    this.duration,
    this.horizontal = false,
  });

  final int index;
  final Widget child;

  /// Distance travelled during the reveal, in logical pixels.
  final double offset;

  final Duration? duration;

  /// Slide in from the side instead of from below — used by kanban columns.
  final bool horizontal;

  @override
  State<StaggerReveal> createState() => _StaggerRevealState();
}

class _StaggerRevealState extends State<StaggerReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;

    final motion = context.motion;
    _controller.duration = widget.duration ?? motion.slow;

    if (!motion.enabled) {
      _controller.value = 1;
      return;
    }

    final delay = motion.stagger(widget.index);
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: context.motion.emphasized,
    );

    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) {
        final t = curve.value;
        final shift = widget.offset * (1 - t);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: widget.horizontal ? Offset(shift, 0) : Offset(0, shift),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Cross-fades between children with a slight scale, for swapping content in
/// place (an empty column becoming populated, a stat switching value).
class SoftSwitcher extends StatelessWidget {
  const SoftSwitcher({
    super.key,
    required this.child,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    return AnimatedSwitcher(
      duration: motion.base,
      switchInCurve: motion.emphasized,
      switchOutCurve: Curves.easeIn,
      // Exit faster than enter so the outgoing child does not linger under the
      // incoming one.
      reverseDuration: motion.fast,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: motion.enabled
            ? ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                child: child,
              )
            : child,
      ),
      child: child,
    );
  }
}
