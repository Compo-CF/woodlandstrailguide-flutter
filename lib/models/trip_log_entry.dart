/// A completed walk. Persisted so users can look back at where they've
/// been. Mirrors iOS TripLogEntry.
class TripLogEntry {
  final String id;
  final DateTime date;
  final double distanceMeters;
  /// Name of the first named segment along the route (e.g. "Sawmill Path").
  final String startLabel;
  /// Name of the last named segment along the route.
  final String endLabel;

  const TripLogEntry({
    required this.id,
    required this.date,
    required this.distanceMeters,
    required this.startLabel,
    required this.endLabel,
  });

  double get miles => distanceMeters / 1609.344;

  factory TripLogEntry.fromJson(Map<String, dynamic> json) => TripLogEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        startLabel: json['startLabel'] as String,
        endLabel: json['endLabel'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'distanceMeters': distanceMeters,
        'startLabel': startLabel,
        'endLabel': endLabel,
      };
}

/// Rolled-up stats over the trip log: total miles, total walks, longest
/// single walk, and consecutive-day streak. Mirrors iOS TripStats.
class TripStats {
  final double totalMeters;
  final int walkCount;
  final double longestMeters;
  final int currentStreakDays;

  const TripStats({
    required this.totalMeters,
    required this.walkCount,
    required this.longestMeters,
    required this.currentStreakDays,
  });

  double get totalMiles => totalMeters / 1609.344;
  double get longestMiles => longestMeters / 1609.344;
  bool get isEmpty => walkCount == 0;

  static const empty = TripStats(
    totalMeters: 0,
    walkCount: 0,
    longestMeters: 0,
    currentStreakDays: 0,
  );
}
