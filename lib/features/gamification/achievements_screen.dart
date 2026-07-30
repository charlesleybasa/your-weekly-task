import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user_stats.dart';
import '../../core/theme/app_geometry.dart';
import '../../core/utils/context_x.dart';
import '../../core/utils/date_x.dart';
import '../../state/gamification_controller.dart';
import '../../widgets/progress_indicators.dart';
import '../../widgets/stagger.dart';
import '../../widgets/surfaces.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final gutter = context.geometry.gutter;
    final achievements = ref.watch(achievementsProvider);
    final level = ref.watch(levelProvider);
    final unlocked = achievements.where((a) => a.unlockedAt != null).length;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Progress'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppGeometry.huge),
        children: [
          StaggerReveal(
            index: 0,
            child: AppSurface(
              padding: const EdgeInsets.all(AppGeometry.xl),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              colors.xp.withValues(alpha: 0.35),
                              colors.xp.withValues(alpha: 0.08),
                            ],
                          ),
                          border: Border.all(
                            color: colors.xp.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${level.level}',
                            style: context.text.headlineSmall?.copyWith(
                              color: colors.isDark
                                  ? colors.xp
                                  : const Color(0xFF8A6100),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppGeometry.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(level.title, style: context.text.headlineSmall),
                            Text(
                              '${level.xp} XP total · '
                              '${Levels.xpRemainingToNextLevel(level.xp)} to level '
                              '${level.level + 1}',
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppGeometry.lg),
                  AppProgressBar(
                    value: level.progress,
                    color: colors.xp,
                    height: 8,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppGeometry.section),

          SectionHeader(
            title: 'Achievements',
            subtitle: '$unlocked of ${achievements.length} unlocked',
          ),

          for (var i = 0; i < achievements.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppGeometry.sm),
              child: StaggerReveal(
                index: i + 1,
                child: _AchievementRow(view: achievements[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.view});

  final AchievementView view;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final achievement = view.achievement;
    final unlocked = view.unlockedAt != null;

    return AppSurface(
      padding: const EdgeInsets.all(AppGeometry.lg),
      accent: unlocked ? achievement.tint : null,
      child: Row(
        children: [
          // Locked badges are desaturated and outlined rather than hidden —
          // seeing what is available is most of the motivation.
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: unlocked
                  ? achievement.tint.withValues(alpha: colors.isDark ? 0.2 : 0.14)
                  : colors.surfaceSunken,
              borderRadius: AppGeometry.brMd,
              border: Border.all(
                color: unlocked
                    ? achievement.tint.withValues(alpha: 0.45)
                    : colors.border,
              ),
            ),
            child: Icon(
              unlocked ? achievement.icon : Icons.lock_outline_rounded,
              size: 22,
              color: unlocked ? achievement.tint : colors.textTertiary,
            ),
          ),
          const SizedBox(width: AppGeometry.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        achievement.title,
                        style: context.text.titleMedium?.copyWith(
                          color: unlocked
                              ? colors.textPrimary
                              : colors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unlocked) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: colors.success,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  unlocked
                      ? 'Unlocked ${view.unlockedAt!.relativeDayLabel}'
                      : achievement.description,
                  style: context.text.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!unlocked && view.progress != null) ...[
                  const SizedBox(height: AppGeometry.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppProgressBar(
                          value: view.progress!,
                          color: achievement.tint,
                          height: 5,
                        ),
                      ),
                      if (view.progressLabel != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          view.progressLabel!,
                          style: context.text.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (achievement.xpBonus > 0 && !unlocked) ...[
            const SizedBox(width: AppGeometry.sm),
            AppChip(
              label: '+${achievement.xpBonus}',
              dense: true,
              foreground: colors.isDark ? colors.xp : const Color(0xFF8A6100),
              background:
                  colors.xp.withValues(alpha: colors.isDark ? 0.15 : 0.2),
            ),
          ],
        ],
      ),
    );
  }
}
