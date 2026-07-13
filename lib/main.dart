// Woodlands Trail Guide — Android edition.
//
// Entry point wires up the shared data stores (TrailStore, POIStore,
// FeaturedWalkStore) via Provider and lays out the bottom-tab shell
// (Map / Trails / Featured / About). Individual screens are in
// `lib/screens/`.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'stores/trail_store.dart';
import 'stores/poi_store.dart';
import 'stores/featured_walk_store.dart';
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

/// Bottom tab bar with 4 tabs: Map / Trails / Featured / About.
class RootTabShell extends StatefulWidget {
  const RootTabShell({super.key});

  @override
  State<RootTabShell> createState() => _RootTabShellState();
}

class _RootTabShellState extends State<RootTabShell> {
  int _index = 0;

  static const _tabs = <Widget>[
    MapScreen(),
    ListScreen(),
    FeaturedScreen(),
    AboutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
