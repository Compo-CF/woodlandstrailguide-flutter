// FeaturedWalk — mirrors iOS FeaturedWalk.swift. Curator-managed
// walks with waypoints + highlights, fetched from FeaturedWalks.json
// on GitHub Pages (same file the iOS app uses).

class FeaturedWalk {
  final String id;
  final String name;
  final String description;
  final String? village;
  final String? park;
  final DifficultyRating difficulty;
  final double distanceMiles;
  final double? elevationGainFeet;
  final List<WaypointStop> waypoints;
  final List<String> highlights;
  final String? bestTime;
  final String? seasonality;
  final String? curatedBy;

  const FeaturedWalk({
    required this.id,
    required this.name,
    required this.description,
    required this.village,
    required this.park,
    required this.difficulty,
    required this.distanceMiles,
    required this.elevationGainFeet,
    required this.waypoints,
    required this.highlights,
    required this.bestTime,
    required this.seasonality,
    required this.curatedBy,
  });

  factory FeaturedWalk.fromJson(Map<String, dynamic> json) => FeaturedWalk(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        village: json['village'] as String?,
        park: json['park'] as String?,
        difficulty:
            DifficultyRating.fromString(json['difficulty'] as String? ?? 'easy'),
        distanceMiles: (json['distanceMiles'] as num).toDouble(),
        elevationGainFeet: (json['elevationGainFeet'] as num?)?.toDouble(),
        waypoints: (json['waypoints'] as List<dynamic>)
            .map((w) => WaypointStop.fromJson(w as Map<String, dynamic>))
            .toList(),
        highlights: (json['highlights'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        bestTime: json['bestTime'] as String?,
        seasonality: json['seasonality'] as String?,
        curatedBy: json['curatedBy'] as String?,
      );
}

class WaypointStop {
  final double lat;
  final double lon;
  final String? note;

  const WaypointStop({required this.lat, required this.lon, required this.note});

  factory WaypointStop.fromJson(Map<String, dynamic> json) => WaypointStop(
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        note: json['note'] as String?,
      );
}

enum DifficultyRating {
  easy,
  moderate,
  strenuous;

  static DifficultyRating fromString(String s) {
    switch (s.toLowerCase()) {
      case 'moderate':
        return DifficultyRating.moderate;
      case 'strenuous':
        return DifficultyRating.strenuous;
      default:
        return DifficultyRating.easy;
    }
  }

  String get label {
    switch (this) {
      case DifficultyRating.easy:
        return 'Easy';
      case DifficultyRating.moderate:
        return 'Moderate';
      case DifficultyRating.strenuous:
        return 'Strenuous';
    }
  }
}
