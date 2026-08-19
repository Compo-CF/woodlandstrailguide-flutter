// User-specific per-device state: onboarding flag, launch counter,
// favorites, trip log. Persisted via shared_preferences (Android
// equivalent of UserDefaults) — no backend, no account. Direct port of
// iOS UserDataStore.swift, minus the Ko-fi/App-Store-review-specific
// fields that don't apply here (routesCompleted is kept since it's
// cheap and a future Android review-prompt flow can reuse it).

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/travel_mode.dart';
import '../models/trip_log_entry.dart';

class UserDataStore extends ChangeNotifier {
  static const _favoritesKey = 'favorites.v1';
  static const _onboardingKey = 'hasSeenOnboarding.v1';
  static const _routingIntroKey = 'hasSeenRoutingIntro.v1';
  static const _appLaunchesKey = 'appLaunches.v1';
  static const _tripLogKey = 'tripLog.v1';
  static const _routesCompletedKey = 'routesCompleted.v1';
  static const _travelModeKey = 'travelMode.v1';
  static const _preferPavedKey = 'preferPavedRoutes.v1';
  static const _celebratedAchievementsKey = 'celebratedAchievementIDs.v1';

  SharedPreferences? _prefs;

  /// Permanent record of which achievements have ever been earned.
  /// Unlike the live stats that back them (streak in particular can
  /// drop back to zero), once earned an achievement stays unlocked.
  Set<String> celebratedAchievementIds = {};

  /// Walk/jog/run/bike — changes the pace assumption used for every
  /// ETA/duration display. Doesn't change the routed path itself.
  TravelMode travelMode = TravelMode.walk;
  /// When on, routing penalizes natural-surface trail edges so the
  /// router strongly prefers paved pathways. Still finds a route even
  /// if the only path is unpaved (penalty, not exclusion).
  bool preferPavedRoutes = false;

  /// True once load() has populated state from disk. Callers that need
  /// to distinguish "hasn't loaded yet" from "genuinely false" (e.g.
  /// deciding whether to show onboarding) should gate on this first —
  /// hasSeenOnboarding defaults to false before load() finishes, which
  /// looks identical to a real first-launch otherwise.
  bool isLoaded = false;

  Set<String> favoriteWayIDs = {};
  int appLaunches = 0;
  int routesCompleted = 0;
  List<TripLogEntry> tripLog = [];

  bool get hasSeenOnboarding => _prefs?.getBool(_onboardingKey) ?? false;
  bool get hasSeenRoutingIntro => _prefs?.getBool(_routingIntroKey) ?? false;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    favoriteWayIDs = (_prefs!.getStringList(_favoritesKey) ?? const []).toSet();
    appLaunches = _prefs!.getInt(_appLaunchesKey) ?? 0;
    routesCompleted = _prefs!.getInt(_routesCompletedKey) ?? 0;
    travelMode = TravelMode.fromName(_prefs!.getString(_travelModeKey));
    preferPavedRoutes = _prefs!.getBool(_preferPavedKey) ?? false;
    celebratedAchievementIds =
        (_prefs!.getStringList(_celebratedAchievementsKey) ?? const []).toSet();
    final raw = _prefs!.getString(_tripLogKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        tripLog = decoded
            .map((e) => TripLogEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        tripLog = [];
      }
    }
    isLoaded = true;
    notifyListeners();
  }

  Future<void> setHasSeenOnboarding(bool value) async {
    await _prefs?.setBool(_onboardingKey, value);
    notifyListeners();
  }

  Future<void> setHasSeenRoutingIntro(bool value) async {
    await _prefs?.setBool(_routingIntroKey, value);
    notifyListeners();
  }

  Future<void> recordAppLaunch() async {
    appLaunches++;
    await _prefs?.setInt(_appLaunchesKey, appLaunches);
    notifyListeners();
  }

  Future<void> setTravelMode(TravelMode mode) async {
    travelMode = mode;
    await _prefs?.setString(_travelModeKey, mode.name);
    notifyListeners();
  }

  Future<void> setPreferPavedRoutes(bool value) async {
    preferPavedRoutes = value;
    await _prefs?.setBool(_preferPavedKey, value);
    notifyListeners();
  }

  bool isFavorite(String id) => favoriteWayIDs.contains(id);

  Future<void> toggleFavorite(String id) async {
    if (favoriteWayIDs.contains(id)) {
      favoriteWayIDs.remove(id);
    } else {
      favoriteWayIDs.add(id);
    }
    await _prefs?.setStringList(_favoritesKey, favoriteWayIDs.toList());
    notifyListeners();
    // Doesn't affect the "supporter" badge either way — that's checked
    // with real tip status at the tip-purchase call site.
    await checkForNewAchievements(hasTipped: false);
  }

  // MARK: - Achievements

  /// Diffs the achievements earnable from current stats against what's
  /// already been celebrated, persists any new ones, and returns them
  /// (so the caller can show a toast). Safe to call often — e.g. after
  /// every favorite toggle or tip — since it's a no-op when nothing new
  /// was earned.
  Future<List<Achievement>> checkForNewAchievements({required bool hasTipped}) async {
    final earned = Achievement.unlockedIds(
      stats: tripStats,
      favoritesCount: favoriteWayIDs.length,
      hasTipped: hasTipped,
    );
    final fresh = earned.difference(celebratedAchievementIds);
    if (fresh.isEmpty) return const [];
    celebratedAchievementIds = celebratedAchievementIds.union(fresh);
    await _prefs?.setStringList(
        _celebratedAchievementsKey, celebratedAchievementIds.toList());
    notifyListeners();
    return Achievement.all.where((a) => fresh.contains(a.id)).toList();
  }

  // MARK: - Trip log

  Future<void> recordTrip({
    required double distanceMeters,
    required String startLabel,
    required String endLabel,
    double? durationSeconds,
    TravelMode? travelMode,
  }) async {
    final entry = TripLogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateTime.now(),
      distanceMeters: distanceMeters,
      startLabel: startLabel,
      endLabel: endLabel,
      durationSeconds: durationSeconds,
      travelMode: travelMode ?? this.travelMode,
    );
    tripLog.insert(0, entry);
    // Cap to the most recent 100 to keep storage compact.
    if (tripLog.length > 100) tripLog = tripLog.sublist(0, 100);
    await _saveTripLog();
    notifyListeners();
  }

  Future<void> deleteTrip(String id) async {
    tripLog.removeWhere((e) => e.id == id);
    await _saveTripLog();
    notifyListeners();
  }

  Future<void> _saveTripLog() async {
    final encoded = jsonEncode(tripLog.map((e) => e.toJson()).toList());
    await _prefs?.setString(_tripLogKey, encoded);
  }

  Future<void> markRouteCompleted() async {
    routesCompleted++;
    await _prefs?.setInt(_routesCompletedKey, routesCompleted);
    notifyListeners();
  }

  /// Rolls the trip log into total miles, total walks, longest single
  /// walk, and consecutive-day streak. Recomputed on each access, but
  /// tripLog is tiny (capped at 100 entries) so this is effectively free.
  TripStats get tripStats {
    if (tripLog.isEmpty) return TripStats.empty;
    var total = 0.0;
    var longest = 0.0;
    final walkDays = <DateTime>{};
    for (final entry in tripLog) {
      total += entry.distanceMeters;
      if (entry.distanceMeters > longest) longest = entry.distanceMeters;
      final d = entry.date;
      walkDays.add(DateTime(d.year, d.month, d.day));
    }
    var streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    while (walkDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return TripStats(
      totalMeters: total,
      walkCount: tripLog.length,
      longestMeters: longest,
      currentStreakDays: streak,
    );
  }
}
