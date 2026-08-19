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
        title: '5-Mile Club',
        subtitle: 'Walk 5 total miles',
        iconName: 'directions_walk'),
    Achievement(
        id: 'miles_25',
        title: 'Trailblazer',
        subtitle: 'Walk 25 total miles',
        iconName: 'terrain'),
    Achievement(
        id: 'miles_100',
        title: 'Century Walker',
        subtitle: 'Walk 100 total miles',
        iconName: 'military_tech'),
    Achievement(
        id: 'walks_10',
        title: 'Regular',
        subtitle: 'Complete 10 walks',
        iconName: 'repeat'),
    Achievement(
        id: 'longest_5',
        title: 'Long Hauler',
        subtitle: 'Complete a single 5+ mile walk',
        iconName: 'flag'),
    Achievement(
        id: 'streak_3',
        title: 'On a Roll',
        subtitle: 'Walk 3 days in a row',
        iconName: 'local_fire_department'),
    Achievement(
        id: 'streak_7',
        title: 'Week Streak',
        subtitle: 'Walk 7 days in a row',
        iconName: 'local_fire_department'),
    Achievement(
        id: 'streak_30',
        title: 'Habit Formed',
        subtitle: 'Walk 30 days in a row',
        iconName: 'local_fire_department'),
    Achievement(
        id: 'favorites_5',
        title: 'Curator',
        subtitle: 'Favorite 5 trails',
        iconName: 'favorite'),
    Achievement(
        id: 'supporter',
        title: 'Supporter',
        subtitle: 'Send a tip',
        iconName: 'coffee'),
  ];

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
