import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/achievement.dart';
import '../services/iap_store.dart';
import '../stores/user_data_store.dart';
import '../theme/natural_palette.dart';
import '../theme/natural_type.dart';

/// Grid of every achievement.
///
/// Earned ones are filled and checked; locked ones keep their own icon,
/// ghosted, with how far along you are. The previous version drew every
/// locked badge as an identical grey padlock, which made a screen users open
/// on purpose look like a wall of denial — and told somebody sitting at 24
/// of 25 miles exactly as much as it told somebody at zero. Every threshold
/// in the catalog is numeric, so there was no reason not to say.
class AchievementsSheet extends StatelessWidget {
  const AchievementsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NaturalPalette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NaturalMetrics.radiusLarge),
        ),
      ),
      builder: (_) => const AchievementsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = context.watch<UserDataStore>();
    final iap = context.watch<IAPStore>();
    final stats = userData.tripStats;
    final earned = userData.celebratedAchievementIds;
    final hasTipped = iap.tipCount > 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return SafeArea(
          child: CustomScrollView(
            controller: controller,
            slivers: [
              SliverToBoxAdapter(child: _header(earnedCount: earned.length)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    // Tall enough for the title, the subtitle and, on a
                    // locked tile, the progress bar and its label below.
                    mainAxisExtent: 190,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final a = Achievement.all[i];
                      return _AchievementTile(
                        achievement: a,
                        unlocked: earned.contains(a.id),
                        progress: a.progress(
                          stats: stats,
                          favoritesCount: userData.favoriteWayIDs.length,
                          hasTipped: hasTipped,
                        ),
                      );
                    },
                    childCount: Achievement.all.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header({required int earnedCount}) {
    final total = Achievement.all.length;
    final fraction = total > 0 ? earnedCount / total : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$earnedCount',
                style: NaturalType.display(32,
                    weight: FontWeight.w700, color: NaturalPalette.ink),
              ),
              const SizedBox(width: 6),
              Text(
                'of $total earned',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: NaturalPalette.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 220,
            child: _ProgressBar(fraction: fraction, height: 6),
          ),
        ],
      ),
    );
  }
}

/// Thin capsule bar. Shared by the header and the locked tiles so a single
/// visual language carries "how far along" everywhere on this screen.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction, this.height = 4});

  final double fraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final clamped = fraction.clamp(0.0, 1.0);
        // Keep a sliver visible at tiny values so "started" reads
        // differently from "not started".
        final filled = clamped <= 0
            ? 0.0
            : (constraints.maxWidth * clamped)
                .clamp(height, constraints.maxWidth);
        return Stack(
          children: [
            Container(
              height: height,
              decoration: BoxDecoration(
                color: NaturalPalette.chipBg,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            Container(
              height: height,
              width: filled,
              decoration: BoxDecoration(
                color: NaturalPalette.forest,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    required this.unlocked,
    required this.progress,
  });

  final Achievement achievement;
  final bool unlocked;
  final AchievementProgress? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: NaturalPalette.buttonBg,
        borderRadius: BorderRadius.circular(NaturalMetrics.radiusMedium),
        border: Border.all(
          color: unlocked
              ? NaturalPalette.forest.withValues(alpha: 0.45)
              : NaturalPalette.hairline,
          width: unlocked ? 1.5 : 1,
        ),
        boxShadow: NaturalMetrics.shadowResting,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _badge(),
          const SizedBox(height: 8),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: NaturalType.display(
              15,
              color: unlocked ? NaturalPalette.ink : NaturalPalette.inkMuted,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              achievement.subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10.5, color: NaturalPalette.inkMuted),
            ),
          ),
          // Only on locked tiles: once it's earned the number is history,
          // and showing "25 / 25" next to a checkmark is just clutter.
          if (!unlocked && progress != null) ...[
            const SizedBox(height: 8),
            _ProgressBar(fraction: progress!.fraction),
            const SizedBox(height: 4),
            Text(
              progress!.label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                fontFeatures: [FontFeature.tabularFigures()],
                color: NaturalPalette.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The badge itself. Locked tiles keep the achievement's own symbol rather
  /// than swapping in a padlock — the grid should read as a set to complete,
  /// not a list of things withheld.
  Widget _badge() {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? NaturalPalette.forest : NaturalPalette.chipBg,
            ),
          ),
          Icon(
            _iconFor(achievement.iconName),
            size: 23,
            color: unlocked
                ? Colors.white
                : NaturalPalette.inkMuted.withValues(alpha: 0.55),
          ),
          if (unlocked)
            // Small earned marker, bottom-trailing, so a filled badge is
            // unambiguous at a glance even in a dense grid.
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: NaturalPalette.buttonBg,
                ),
                child: const Icon(Icons.check_circle,
                    size: 18, color: NaturalPalette.forest),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'directions_walk':
        return Icons.directions_walk;
      case 'terrain':
        return Icons.terrain;
      case 'military_tech':
        return Icons.military_tech;
      case 'repeat':
        return Icons.repeat;
      case 'flag':
        return Icons.flag;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'favorite':
        return Icons.favorite;
      case 'coffee':
        return Icons.coffee;
      default:
        return Icons.emoji_events;
    }
  }
}

/// Brief celebratory toast shown when a walk earns a new achievement.
/// Mirrors iOS's toastAchievement overlay in MapTabView.
class AchievementToast extends StatelessWidget {
  final Achievement achievement;
  const AchievementToast({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: NaturalPalette.ink.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Achievement unlocked!',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              Text(achievement.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}
