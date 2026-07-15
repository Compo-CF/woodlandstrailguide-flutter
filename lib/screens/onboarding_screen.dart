import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../stores/user_data_store.dart';
import '../theme/natural_palette.dart';

/// First-run walkthrough — four pages covering what the app is, where
/// the data comes from, what's in it, and how to route a walk. Direct
/// port of iOS OnboardingSheet. Shown once, gated on
/// UserDataStore.hasSeenOnboarding; completing it also flips
/// hasSeenRoutingIntro so MapScreen's first-time routing hint doesn't
/// pop again right after.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  static const _totalPages = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NaturalPalette.cardBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _OverviewPage(),
                  _DataPage(),
                  _FeaturesPage(),
                  _RoutingPage(),
                ],
              ),
            ),
            _pageIndicator(),
            _continueBar(context),
          ],
        ),
      ),
    );
  }

  Widget _pageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalPages, (i) {
          final active = i == _page;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? NaturalPalette.forest : NaturalPalette.hairline,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  Widget _continueBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Row(
        children: [
          Opacity(
            opacity: _page > 0 ? 1 : 0,
            child: IgnorePointer(
              ignoring: _page == 0,
              child: TextButton(
                onPressed: () => _controller.previousPage(
                    duration: const Duration(milliseconds: 220), curve: Curves.easeInOut),
                child: const Text('Back',
                    style: TextStyle(color: NaturalPalette.inkMuted, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () {
              if (_page < _totalPages - 1) {
                _controller.nextPage(
                    duration: const Duration(milliseconds: 220), curve: Curves.easeInOut);
              } else {
                _finish(context);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: NaturalPalette.forest,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: const StadiumBorder(),
              minimumSize: const Size(120, 0),
            ),
            child: Text(_page < _totalPages - 1 ? 'Next' : "Let's go",
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _finish(BuildContext context) {
    final userData = context.read<UserDataStore>();
    userData.setHasSeenOnboarding(true);
    userData.setHasSeenRoutingIntro(true);
    Navigator.of(context).pop();
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.hiking, size: 72, color: NaturalPalette.forest),
            const SizedBox(height: 16),
            const Text('Welcome',
                style: TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w700, color: NaturalPalette.ink)),
            const SizedBox(height: 14),
            const Text(
              "An independent guide to The Woodlands' 200+ miles of hike-and-bike "
              "pathways — every named segment across all nine villages, plus the "
              "parks, bridges, playgrounds, and water fountains you'll pass along the way.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: NaturalPalette.ink),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _StatBadge(number: '200+', label: 'miles'),
                SizedBox(width: 20),
                _StatBadge(number: '1,500+', label: 'trails'),
                SizedBox(width: 20),
                _StatBadge(number: '9', label: 'villages'),
                SizedBox(width: 20),
                _StatBadge(number: '3,400+', label: 'POIs'),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String number;
  final String label;
  const _StatBadge({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(number,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: NaturalPalette.forest)),
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10, letterSpacing: 0.6, color: NaturalPalette.inkMuted)),
      ],
    );
  }
}

class _DataPage extends StatelessWidget {
  const _DataPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.account_balance, size: 60, color: NaturalPalette.forest),
            const SizedBox(height: 16),
            const Text('Built on public data',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w700, color: NaturalPalette.ink)),
            const SizedBox(height: 12),
            const Text(
              "Trail and amenity data comes from The Woodlands Township's public "
              "ArcGIS services — the same database the Township uses internally. "
              "The app bundles a copy for offline use and refreshes over the air "
              "when the Township updates. Weather is from Open-Meteo.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: NaturalPalette.ink),
            ),
            const SizedBox(height: 18),
            const _SourceRow(
              icon: Icons.map,
              title: 'The Woodlands Township GIS',
              detail: 'Pathways, trails, parks, bridges, playgrounds, restrooms, '
                  'and more — 30 categories.',
            ),
            const SizedBox(height: 10),
            const _SourceRow(
              icon: Icons.wb_sunny,
              title: 'Open-Meteo',
              detail: 'Current temperature, condition, and wind. Free, no account.',
            ),
            const SizedBox(height: 10),
            const _SourceRow(
              icon: Icons.public,
              title: 'Google Maps',
              detail: 'Base tiles, imagery, and Standard/Hybrid/Satellite styles.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Nothing you do in the app leaves your phone unless you tap "Report a problem."',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: NaturalPalette.inkMuted),
            ),
            const SizedBox(height: 8),
            const Text(
              'Independently built by a local. Not affiliated with, endorsed by, '
              'or sponsored by The Woodlands Township.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: NaturalPalette.inkMuted),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  const _SourceRow({required this.icon, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NaturalPalette.chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(color: NaturalPalette.forest, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13.5, color: NaturalPalette.ink)),
                Text(detail,
                    style: const TextStyle(fontSize: 11.5, color: NaturalPalette.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.auto_awesome, size: 56, color: NaturalPalette.forest),
            const SizedBox(height: 16),
            const Text("What's here",
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w700, color: NaturalPalette.ink)),
            const SizedBox(height: 18),
            const _FeatureRow(
                icon: Icons.touch_app,
                title: 'Tap any trail',
                detail: 'See its name, surface, length, and which parks it connects to.'),
            const SizedBox(height: 12),
            const _FeatureRow(
                icon: Icons.search,
                title: 'Search',
                detail: 'Find any pathway, park, or amenity by name — jump straight there.'),
            const SizedBox(height: 12),
            const _FeatureRow(
                icon: Icons.wb_sunny,
                title: 'Weather at a glance',
                detail: 'Current temp and condition in the top-left. Tap for advisories.'),
            const SizedBox(height: 12),
            const _FeatureRow(
                icon: Icons.place,
                title: 'Every amenity is tappable',
                detail:
                    'Bridges, playgrounds, restrooms, fountains — tap for distance from you and route-here.'),
            const SizedBox(height: 12),
            const _FeatureRow(
                icon: Icons.public,
                title: 'Three map styles',
                detail: 'Standard, Hybrid (satellite + labels), or Satellite. Toggle top-right.'),
            const SizedBox(height: 12),
            const _FeatureRow(
                icon: Icons.list_alt,
                title: 'Trip log',
                detail: 'Every completed walk is saved to the About tab.'),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  const _FeatureRow({required this.icon, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(color: NaturalPalette.chipBg, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: NaturalPalette.forest),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13.5, color: NaturalPalette.ink)),
              Text(detail,
                  style: const TextStyle(fontSize: 11.5, color: NaturalPalette.inkMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoutingPage extends StatelessWidget {
  const _RoutingPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.directions_walk, size: 56, color: NaturalPalette.forest),
            const SizedBox(height: 16),
            const Text('Get walking directions',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700, color: NaturalPalette.ink)),
            const SizedBox(height: 18),
            const _RouteStep(
                number: 1,
                title: 'Tap the directions button',
                detail: 'Top-right of the map, or the Route tab in the bottom bar.'),
            const SizedBox(height: 12),
            const _RouteStep(
                number: 2,
                title: 'Tap a starting point, then a destination',
                detail: 'Green pin drops on the start, orange on the end.'),
            const SizedBox(height: 12),
            const _RouteStep(
                number: 3,
                title: 'Optional: add a waypoint',
                detail: 'Tap the waypoint icon to route via a specific trail.'),
            const SizedBox(height: 12),
            const _RouteStep(
                number: 4,
                title: 'Tap Start walking',
                detail: 'Live turn-by-turn with the screen kept on.'),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _RouteStep extends StatelessWidget {
  final int number;
  final String title;
  final String detail;
  const _RouteStep({required this.number, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(color: NaturalPalette.forest, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$number',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13.5, color: NaturalPalette.ink)),
              Text(detail,
                  style: const TextStyle(fontSize: 11.5, color: NaturalPalette.inkMuted)),
            ],
          ),
        ),
      ],
    );
  }
}
