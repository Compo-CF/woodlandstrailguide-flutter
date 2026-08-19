import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/achievement.dart';
import '../stores/user_data_store.dart';
import '../theme/natural_palette.dart';

/// Grid of badge tiles — unlocked ones show their real icon/color,
/// locked ones show a lock. Direct port of iOS AchievementsSheet.
class AchievementsSheet extends StatelessWidget {
  const AchievementsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NaturalPalette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AchievementsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = context.watch<UserDataStore>();
    final unlocked = userData.celebratedAchievementIds;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Achievements',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: NaturalPalette.ink)),
            const SizedBox(height: 4),
            Text('${unlocked.length} of ${Achievement.all.length} earned',
                style: const TextStyle(fontSize: 13, color: NaturalPalette.inkMuted)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
              children: Achievement.all
                  .map((a) => _tile(a, unlocked.contains(a.id)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(Achievement a, bool isUnlocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isUnlocked ? NaturalPalette.chipBg : NaturalPalette.chipBg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isUnlocked ? _iconFor(a.iconName) : Icons.lock_outline,
            size: 26,
            color: isUnlocked ? NaturalPalette.forest : NaturalPalette.inkMuted,
          ),
          const SizedBox(height: 8),
          Text(
            a.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isUnlocked ? NaturalPalette.ink : NaturalPalette.inkMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            a.subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9.5, color: NaturalPalette.inkMuted),
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
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}
