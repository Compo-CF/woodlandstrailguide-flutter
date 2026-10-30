// The Woodlands Trail Guide — Android edition.
//
// Entry point wires up the shared data stores (TrailStore, POIStore,
// FeaturedWalkStore, RoutingState) via Provider and lays out the
// bottom-tab shell (Map / Trails / Route / Featured / About).
// Individual screens are in `lib/screens/`.

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:provider/provider.dart';

import 'stores/trail_store.dart';
import 'stores/poi_store.dart';
import 'stores/polygon_store.dart';
import 'stores/featured_walk_store.dart';
import 'stores/user_data_store.dart';
import 'stores/weather_store.dart';
import 'services/elevation_service.dart';
import 'services/iap_store.dart';
import 'services/poi_photo_store.dart';
import 'services/routing_bridge.dart';
import 'state/routing_state.dart';
import 'screens/map_screen.dart';
import 'screens/list_screen.dart';
import 'screens/featured_screen.dart';
import 'screens/about_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/natural_palette.dart';
import 'theme/natural_type.dart';
import 'widgets/splash_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Ads start loading immediately; the AdMobBannerView call sites kick
  // off individual requests when shown.
  MobileAds.instance.initialize();
  // Cap ad content to a rating suitable for a general-audience hiking app.
  // Without this, AdMob's default targeting can serve adult/dating/
  // suggestive creative that has no business next to trail directions —
  // mirrors the iOS app's requestConfiguration.maxAdContentRating fix.
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
  );

  // Use Android's system photo picker for POI photos rather than the
  // plugin's default ACTION_GET_CONTENT path. The picker runs out of
  // process and returns a single per-file URI grant, so the app needs no
  // storage permission — which is why AndroidManifest.xml deliberately does
  // not declare READ_MEDIA_IMAGES. The flag still defaults to false in
  // image_picker_android, so it has to be set explicitly.
  final picker = ImagePickerPlatform.instance;
  if (picker is ImagePickerAndroid) {
    picker.useAndroidPhotoPicker = true;
  }
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
        ChangeNotifierProvider(create: (_) => PolygonStore()..load()),
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
        ChangeNotifierProvider(create: (_) => ElevationService()..load()),
        ChangeNotifierProvider(create: (_) => POIPhotoStore()..load()),
        ChangeNotifierProvider(create: (_) => IAPStore()..init()),
      ],
      child: MaterialApp(
        title: 'The Woodlands Trail Guide',
        debugShowCheckedModeBanner: false,
        theme: _naturalTheme(),
        // Pinned light. The palette has no dark variants yet (see the note
        // in natural_palette.dart); leaving themeMode on system would let
        // Material darken its own widgets while every hand-coloured surface
        // stayed cream, which looks worse than simply staying light.
        themeMode: ThemeMode.light,
        home: const SplashGate(child: RootTabShell()),
      ),
    );
  }
}

/// One place that maps the Natural design system onto Material, so screens
/// stop reaching for stock Material colours. Previously this was a bare
/// `ColorScheme.fromSeed`, which derived a whole Material 3 palette from the
/// forest green and then applied it to surfaces the design system already
/// has opinions about — the result was lilac-tinted sheets and grey-blue
/// dividers sitting next to hand-coloured cream cards.
ThemeData _naturalTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: NaturalPalette.forest,
      primary: NaturalPalette.forest,
      secondary: NaturalPalette.route,
      surface: NaturalPalette.cardBg,
      onSurface: NaturalPalette.ink,
    ),
    scaffoldBackgroundColor: NaturalPalette.cardBg,
  );

  return base.copyWith(
    // Display face for the headline slots only. Body and label styles stay
    // on the system font: Fraunces is a display serif and gets fragile
    // below ~15sp, which is most of what a UI actually renders.
    textTheme: base.textTheme.copyWith(
      displayLarge: NaturalType.hero(color: NaturalPalette.ink),
      headlineSmall: NaturalType.title(color: NaturalPalette.ink),
      titleLarge: NaturalType.title(color: NaturalPalette.ink),
      titleMedium: NaturalType.heading(color: NaturalPalette.ink),
    ),
    dividerTheme: const DividerThemeData(
      color: NaturalPalette.hairline,
      thickness: 1,
      space: 1,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: NaturalPalette.cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NaturalMetrics.radiusLarge),
        ),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: NaturalPalette.cardBg,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(
      color: NaturalPalette.cardBg,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: NaturalPalette.cardBg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: NaturalPalette.chipBg,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? NaturalPalette.forest
                : NaturalPalette.inkMuted,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? NaturalPalette.forest
                : NaturalPalette.inkMuted,
          )),
    ),
  );
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

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  late final RoutingState _routingState;
  late final UserDataStore _userDataStore;
  bool _onboardingShown = false;

  @override
  void initState() {
    super.initState();
    _routingState = context.read<RoutingState>();
    // Whenever a pending route appears — from a deep link or from
    // Featured Walks' "Walk this route" — jump to the Map tab so
    // MapScreen can actually apply it. Mirrors iOS ContentView's
    // onChange(of: routingBridge.pending).
    _routingState.addListener(_onRoutingChanged);
    _initDeepLinks();

    _userDataStore = context.read<UserDataStore>();
    _userDataStore.addListener(_checkOnboarding);
    _checkOnboarding();
  }

  void _onRoutingChanged() {
    // The Route tab displays the map too, so somebody sitting on it is
    // already where a pending route needs them and should not be yanked onto
    // the Map tab -- that would silently un-highlight Route for no reason.
    final showingMap = _index == 0 || _index == _routeTabIndex;
    if (_routingState.pending != null && !showingMap && mounted) {
      setState(() => _index = 0);
    }
  }

  /// Shows the first-run walkthrough once UserDataStore has finished
  /// loading from disk (gating on isLoaded, not just hasSeenOnboarding,
  /// avoids a false-positive flash for returning users before their
  /// SharedPreferences read completes).
  void _checkOnboarding() {
    if (_onboardingShown) return;
    if (!_userDataStore.isLoaded) return;
    if (_userDataStore.hasSeenOnboarding) return;
    _onboardingShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const OnboardingScreen(),
      ));
    });
  }

  Future<void> _initDeepLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleLink(initial);
    } catch (_) {}
    _linkSub = _appLinks.uriLinkStream.listen(_handleLink, onError: (_) {});
  }

  void _handleLink(Uri uri) {
    final parsed = RoutingBridge.parse(uri);
    if (parsed == null) return;
    _routingState.setPending(parsed);
  }

  @override
  void dispose() {
    _routingState.removeListener(_onRoutingChanged);
    _userDataStore.removeListener(_checkOnboarding);
    _linkSub?.cancel();
    super.dispose();
  }

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
      // Route shows the map's content, so the index is translated here, at
      // display time, rather than at selection time. Doing it the other way
      // round -- recording Map as the selected tab and hoping Route looked
      // selected -- is what made the bottom bar claim you were on the plain
      // map while the route planner was open on top of it. The old
      // `_index == _routeTabIndex ? 0 : _index` on selectedIndex was dead
      // code: _index was never set to the Route tab in the first place.
      body: IndexedStack(
        index: _index == _routeTabIndex ? 0 : _index,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (i == _routeTabIndex) {
            setState(() {
              _index = _routeTabIndex;
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
