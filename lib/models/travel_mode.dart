// Walk, jog, run, or bike. All route over the same shared pathway
// network — this only changes the pace assumption used for ETA/duration
// displays. Direct port of iOS UserDataStore.swift's TravelMode enum.
enum TravelMode {
  walk,
  jog,
  run,
  bike;

  static TravelMode fromName(String? name) => TravelMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => TravelMode.walk,
      );

  String get label {
    switch (this) {
      case TravelMode.walk:
        return 'Walk';
      case TravelMode.jog:
        return 'Jog';
      case TravelMode.run:
        return 'Run';
      case TravelMode.bike:
        return 'Bike';
    }
  }

  /// Material icon name — mapped to an IconData in the widgets that use it.
  String get iconName {
    switch (this) {
      case TravelMode.walk:
        return 'directions_walk';
      case TravelMode.jog:
      case TravelMode.run:
        return 'directions_run';
      case TravelMode.bike:
        return 'directions_bike';
    }
  }

  /// Assumed pace in miles per hour, used for every duration estimate.
  /// jog/run are deliberately conservative (an easy jog, a moderate run).
  double get paceMph {
    switch (this) {
      case TravelMode.walk:
        return 3.0;
      case TravelMode.jog:
        return 5.0;
      case TravelMode.run:
        return 6.0;
      case TravelMode.bike:
        return 12.0;
    }
  }

  /// Noun for the route-summary line: "24 min walk" / "12 min run".
  String get noun {
    switch (this) {
      case TravelMode.walk:
        return 'walk';
      case TravelMode.jog:
        return 'jog';
      case TravelMode.run:
        return 'run';
      case TravelMode.bike:
        return 'ride';
    }
  }

  /// Gerund for share/status messages: "walking" / "running".
  String get gerund {
    switch (this) {
      case TravelMode.walk:
        return 'walking';
      case TravelMode.jog:
        return 'jogging';
      case TravelMode.run:
        return 'running';
      case TravelMode.bike:
        return 'riding';
    }
  }
}
