import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_geometry.dart';
import '../core/utils/context_x.dart';
import '../features/gamification/celebration_overlay.dart';
import '../features/tasks/quick_add_sheet.dart';
import '../state/timer_controller.dart';
import '../widgets/pressable.dart';
import '../widgets/surfaces.dart';

/// Persistent chrome: the five-tab bar, the quick-add button, and the
/// celebration layer that sits above everything.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _tabs = <_TabSpec>[
    _TabSpec('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
    _TabSpec('Boards', Icons.view_kanban_outlined, Icons.view_kanban_rounded),
    _TabSpec('Focus', Icons.track_changes_outlined, Icons.track_changes_rounded),
    _TabSpec('Week', Icons.calendar_today_outlined, Icons.calendar_today_rounded),
    _TabSpec('Settings', Icons.tune_outlined, Icons.tune_rounded),
  ];

  static const int _focusTabIndex = 2;

  void _goTo(int index) {
    // Tapping the active tab pops that branch back to its root — the standard
    // expectation for a tab bar.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = context.isWide;
    final timerRunning = ref.watch(hasRunningTimerProvider);

    final body = Stack(
      children: [
        Positioned.fill(child: shell),
        // Celebrations float above the content but never block it — the
        // overlay handles its own hit-testing.
        const Positioned.fill(child: CelebrationOverlay()),
      ],
    );

    if (isWide) {
      // Tablet / desktop: a rail keeps the primary content area wider and puts
      // navigation where a pointer expects it.
      return Scaffold(
        body: Row(
          children: [
            _NavigationRail(
              tabs: _tabs,
              currentIndex: shell.currentIndex,
              onSelected: _goTo,
              timerRunning: timerRunning,
              focusTabIndex: _focusTabIndex,
              onQuickAdd: () => showQuickAddSheet(context),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      extendBody: true,
      floatingActionButton: _QuickAddButton(
        onPressed: () => showQuickAddSheet(context),
      ),
      bottomNavigationBar: _BottomBar(
        tabs: _tabs,
        currentIndex: shell.currentIndex,
        onSelected: _goTo,
        timerRunning: timerRunning,
        focusTabIndex: _focusTabIndex,
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.tabs,
    required this.currentIndex,
    required this.onSelected,
    required this.timerRunning,
    required this.focusTabIndex,
  });

  final List<_TabSpec> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final bool timerRunning;
  final int focusTabIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = context.safeArea.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppGeometry.md,
        0,
        AppGeometry.md,
        // Sit above the gesture bar rather than under it.
        math.max(bottomInset, AppGeometry.md),
      ),
      child: GlassPanel(
        radius: AppGeometry.brXl,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _TabButton(
                    spec: tabs[i],
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                    pulsing: i == focusTabIndex && timerRunning,
                    accent: colors.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.spec,
    required this.selected,
    required this.onTap,
    required this.pulsing,
    required this.accent,
  });

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;
  final bool pulsing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    final tint = selected ? accent : colors.textTertiary;

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      semanticLabel: spec.label,
      minSize: 48,
      child: SizedBox(
        height: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // The selected pill grows behind the icon instead of the icon
                // simply changing colour.
                AnimatedContainer(
                  duration: motion.base,
                  curve: motion.overshoot,
                  width: selected ? 40 : 0,
                  height: selected ? 26 : 0,
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                AnimatedScale(
                  scale: selected ? 1.06 : 1.0,
                  duration: motion.base,
                  curve: motion.overshoot,
                  child: Icon(
                    selected ? spec.activeIcon : spec.icon,
                    size: 22,
                    color: tint,
                  ),
                ),
                if (pulsing)
                  Positioned(
                    top: -3,
                    right: -6,
                    child: _LiveDot(color: colors.success),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: motion.fast,
              style: context.text.labelSmall!.copyWith(
                color: tint,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 10.5,
              ),
              child: Text(spec.label),
            ),
          ],
        ),
      ),
    );
  }
}

/// Breathing dot marking a live timer.
class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color});

  final Color color;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.surface, width: 1.5),
      ),
    );

    if (!context.motion.enabled) return dot;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(_controller),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.1).animate(_controller),
        child: dot,
      ),
    );
  }
}

/// FAB with a slow idle breath and a press-morph into the quick-add sheet.
class _QuickAddButton extends StatefulWidget {
  const _QuickAddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_QuickAddButton> createState() => _QuickAddButtonState();
}

class _QuickAddButtonState extends State<_QuickAddButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  bool _opening = false;

  Future<void> _handleTap() async {
    // Collapse the button as the sheet rises, then restore it — a cheap,
    // convincing stand-in for a true container morph.
    setState(() => _opening = true);
    widget.onPressed();
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (mounted) setState(() => _opening = false);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;

    Widget button = Pressable(
      onTap: _handleTap,
      semanticLabel: 'Quick add task',
      borderRadius: BorderRadius.circular(20),
      hoverScale: 1.05,
      enableHoverGlow: true,
      glowColor: colors.primary,
      minSize: 56,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.primary.lighten(0.08), colors.primary],
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.38),
              blurRadius: 20,
              spreadRadius: -3,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(Icons.add_rounded, color: colors.onPrimary, size: 28),
      ),
    );

    if (motion.enabled) {
      button = AnimatedBuilder(
        animation: _breath,
        builder: (context, child) => Transform.scale(
          scale: 1 + 0.018 * _breath.value,
          child: child,
        ),
        child: button,
      );
    }

    return AnimatedScale(
      scale: _opening ? 0.2 : 1,
      duration: motion.base,
      curve: motion.emphasized,
      child: AnimatedOpacity(
        opacity: _opening ? 0 : 1,
        duration: motion.fast,
        child: Padding(
          // Clear the floating nav bar.
          padding: const EdgeInsets.only(bottom: 70),
          child: button,
        ),
      ),
    );
  }
}

/// Wide-layout navigation rail.
class _NavigationRail extends StatelessWidget {
  const _NavigationRail({
    required this.tabs,
    required this.currentIndex,
    required this.onSelected,
    required this.timerRunning,
    required this.focusTabIndex,
    required this.onQuickAdd,
  });

  final List<_TabSpec> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final bool timerRunning;
  final int focusTabIndex;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: AppGeometry.xl),
            Pressable(
              onTap: onQuickAdd,
              semanticLabel: 'Quick add task',
              borderRadius: BorderRadius.circular(18),
              hoverScale: 1.05,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.add_rounded, color: colors.onPrimary),
              ),
            ),
            const SizedBox(height: AppGeometry.xl),
            for (var i = 0; i < tabs.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _TabButton(
                  spec: tabs[i],
                  selected: i == currentIndex,
                  onTap: () => onSelected(i),
                  pulsing: i == focusTabIndex && timerRunning,
                  accent: colors.primary,
                ),
              ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
