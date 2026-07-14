// Woodlands Trail Guide — Android edition.
//
// Entry point wires up the shared data stores (TrailStore, POIStore,
// FeaturedWalkStore, RoutingState) via Provider and lays out the
// bottom-tab shell (Map / Trails / Route / Featured / About).
// Individual screens are in `lib/screens/`.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'stores/trail_store.dart';
import 'stores/poi_store.dart';
import 'stores/featured_walk_store.dart';
import 'stores/user_data_store.dart';
import 'stores/weather_store.dart';
import 'state/routing_state.dart';
import 'screens/map_screen.dart';
import 'screens/list_screen.dart';
import 'screens/featured_screen.dart';
import 'screens/about_screen.dart';
import 'theme/natural_palette.dart';

void main() {
  runApp(const WoodlandsTrailGuideApp());
}

class WoodlandsTrailGuideApp extends StatelessWidget {
  const WoodlandsTrailGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider makes all stores available anywhere in the widget tree
    // via `context.watch<T>()` / `context.read<T>()`. Roughly analogous to
    // SwiftUI's `.environment(...)` chain in WoodlandsTrailGuideApp.swift.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TrailStore()..load()),
        ChangeNotifierProvider(create: (_) => POIStore()..load()),
        ChangeNotifierProvider(create: (_) => FeaturedWalkStore()..load()),
        ChangeNotifierProvider(create: (_) {
          // load() must finish before recordAppLaunch() — the cascade
          // operator doesn't await, and recordAppLaunch touches state
          // that load() is responsible for populating.
          final store = UserDataStore();
          store.load().then((_) => store.recordAppLaunch());
          return store;
        }),
        ChangeNotifierProvider(create: (_) => RoutingState()),
        ChangeNotifierProvider(create: (_) => WeatherStore()..refresh()),
      ],
      child: MaterialApp(
        title: 'Woodlands Trail Guide',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: NaturalPalette.forest),
          scaffoldBackgroundColor: NaturalPalette.cardBg,
          useMaterial3: true,
        ),
        home: const RootTabShell(),
      ),
    );
  }
}

/// Bottom tab bar: Map / Trails / Route / Featured / About. The Route
/// tab is a shortcut, not a destination — selecting it flips back to
/// Map and bumps `_routeIntent`, which MapScreen watches (via
/// didUpdateWidget) to enter routing mode immediately. Mirrors the
/// iOS ContentView.AppTab.route pattern.
class RootTabShell extends StatefulWidget {
  const RootTabShell({super.key});

  @override
  State<RootTabShell> createState() => _RootTabShellState();
}

class _RootTabShellState extends State<RootTabShell> {
  int _index = 0;
  int _routeIntent = 0;
  static const _routeTabIndex = 2;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      MapScreen(routeIntent: _routeIntent),
      const ListScreen(),
      const SizedBox.shrink(), // Route tab placeholder — never actually shown
      const FeaturedScreen(),
      const AboutScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index == _routeTabIndex ? 0 : _index,
        onDestinationSelected: (i) {
          if (i == _routeTabIndex) {
            setState(() {
              _index = 0;
              _routeIntent++;
            });
            return;
          }
          setState(() => _index = i);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Map'),
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Trails'),
          NavigationDestination(
              icon: Icon(Icons.directions_walk_outlined),
              selectedIcon: Icon(Icons.directions_walk),
              label: 'Route'),
          NavigationDestination(
              icon: Icon(Icons.star_outline),
              selectedIcon: Icon(Icons.star),
              label: 'Featured'),
          NavigationDestination(
              icon: Icon(Icons.info_outline),
              selectedIcon: Icon(Icons.info),
              label: 'About'),
        ],
      ),
    );
  }
}
