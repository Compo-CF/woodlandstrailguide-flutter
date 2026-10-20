import '../models/trip_log_entry.dart';

/// A single badge. Static catalog + a pure unlock-check function — no
/// state of its own. Direct port of iOS Achievement.swift.
class Achievement {
  final String id;
  final String title;
  final String subtitle;
  final String iconName;

  const Achievement({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconName,
  });

  static const List<Achievement> all = [
    Achievement(
        id: 'first_walk',
        title: 'First Steps',
        subtitle: 'Complete your first walk',
        iconName: 'directions_walk'),
    Achievement(
        id: 'miles_5',
        title: 'Getting Started',
        subtitle: 'Walk 5 miles total',
        iconName: 'directions_walk'),
    Achievement(
        id: 'miles_25',
        title: 'Trailblazer',
        subtitle: 'Walk 25 miles total',
        iconName: 'terrain'),
    Achievement(
        id: 'miles_100',
        title: 'Century Walker',
        subtitle: 'Walk 100 miles total',
        iconName: 'military_tech'),
    Achievement(
        id: 'walks_10',
        title: 'Regular',
        subtitle: 'Complete 10 walks',
        iconName: 'repeat'),
    Achievement(
        id: 'longest_5',
        title: 'Marathoner',
        subtitle: 'Complete a single walk of 5+ miles',
        iconName: 'flag'),
    Achievement(
        id: 'streak_3',
        title: '3-Day Streak',
        subtitle: 'Walk 3 days in a row',
        iconName: 'local_fire_department'),
    Achievement(
        id: 'streak_7',
        title: 'Week Streak',
        subtitle: 'Walk 7 days in a row',
        iconName: 'local_fire_department'),
    Achievement(
        id: 'streak_30',
        title: 'Monthly Streak',
        subtitle: 'Walk 30 days in a row',
        iconName: 'local_fire_department'),
    Achievement(
        id: 'favorites_5',
        title: 'Collector',
        subtitle: 'Save 5 favorite trails',
        iconName: 'favorite'),
    Achievement(
        id: 'supporter',
        title: 'Supporter',
        subtitle: 'Send a tip to support the app',
        iconName: 'coffee'),
  ];


  /// How close the user is to earning this one.
  ///
  /// Exists because a locked badge that only says "Walk 25 miles total" is
  /// the same for somebody at 24 miles as for somebody at zero. Every
  /// threshold in the catalog is numeric, so there's no reason not to say
  /// which.
  AchievementProgress? progress({
    required TripStats stats,
    required int favoritesCount,
    required bool hasTipped,
  }) {
    AchievementProgress make(double current, double target, String unit,
        {int decimals = 0}) {
      // Never show more than the target: "27 / 25 mi" on an unearned badge
      // looks like a bug, and on an earned one it's noise.
      final shown = current < target ? current : target;
      String fmt(double v) => v.toStringAsFixed(decimals);
      return AchievementProgress(
        fraction: target > 0 ? (current / target).clamp(0.0, 1.0) : 0,
        label: '${fmt(shown)} / ${fmt(target)} $unit',
      );
    }

    switch (id) {
      case 'first_walk':
        return make(stats.walkCount.toDouble(), 1, 'walk');
      case 'miles_5':
        return make(stats.totalMiles, 5, 'mi', decimals: 1);
      case 'miles_25':
        return make(stats.totalMiles, 25, 'mi', decimals: 1);
      case 'miles_100':
        return make(stats.totalMiles, 100, 'mi', decimals: 1);
      case 'walks_10':
        return make(stats.walkCount.toDouble(), 10, 'walks');
      case 'longest_5':
        return make(stats.longestMiles, 5, 'mi', decimals: 1);
      case 'streak_3':
        return make(stats.currentStreakDays.toDouble(), 3, 'days');
      case 'streak_7':
        return make(stats.currentStreakDays.toDouble(), 7, 'days');
      case 'streak_30':
        return make(stats.currentStreakDays.toDouble(), 30, 'days');
      case 'favorites_5':
        return make(favoritesCount.toDouble(), 5, 'saved');
      default:
        // Nil when there's nothing meaningful to count toward — the
        // supporter badge is binary, a half-tip isn't a thing.
        return null;
    }
  }

  /// Pure function: which achievement ids are earnable given the current
  /// stats snapshot. Doesn't know about "already celebrated" — that's
  /// UserDataStore's job (checkForNewAchievements), since a
  /// previously-earned badge should never un-earn (e.g. streak drops
  /// back to zero shouldn't take streak_3 away).
  static Set<String> unlockedIds({
    required TripStats stats,
    required int favoritesCount,
    required bool hasTipped,
  }) {
    final out = <String>{};
    if (stats.walkCount >= 1) out.add('first_walk');
    if (stats.totalMiles >= 5) out.add('miles_5');
    if (stats.totalMiles >= 25) out.add('miles_25');
    if (stats.totalMiles >= 100) out.add('miles_100');
    if (stats.walkCount >= 10) out.add('walks_10');
    if (stats.longestMiles >= 5) out.add('longest_5');
    if (stats.currentStreakDays >= 3) out.add('streak_3');
    if (stats.currentStreakDays >= 7) out.add('streak_7');
    if (stats.currentStreakDays >= 30) out.add('streak_30');
    if (favoritesCount >= 5) out.add('favorites_5');
    if (hasTipped) out.add('supporter');
    return out;
  }
}

/// How far along an unearned badge is. Drives both the bar and its label.
class AchievementProgress {
  const AchievementProgress({required this.fraction, required this.label});

  /// 0...1, clamped.
  final double fraction;

  /// Human-readable, e.g. "18.4 / 25 mi".
  final String label;
}
