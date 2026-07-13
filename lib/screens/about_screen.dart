import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/natural_palette.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: NaturalPalette.cardBg,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('About this app'),
          const Text(
            'A community-built map of The Woodlands\' hike-and-bike pathways. '
            'Built by a local on nights and weekends — feedback welcome.',
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Data'),
          const Text(
            'Trail and amenity data is sourced from The Woodlands Township\'s '
            'public ArcGIS GIS services. The app refreshes its local copy every '
            'launch, so newly-added trails appear automatically.',
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Help & feedback'),
          ListTile(
            leading:
                const Icon(Icons.mail_outline, color: NaturalPalette.forest),
            title: const Text('Report a problem'),
            onTap: () => _launch('mailto:anthony.compofelice@centricfiber.com'
                '?subject=Woodlands%20Trail%20Guide%20(Android)%20-%20Report%20a%20problem'),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline, color: NaturalPalette.route),
            title: const Text('Suggest a Featured Walk'),
            subtitle: const Text(
                'Know a scenic route? Email me your suggestion.'),
            onTap: () => _launch('mailto:anthony.compofelice@centricfiber.com'
                '?subject=Featured%20Walk%20suggestion%20-%20Woodlands%20Trail%20Guide'),
          ),
          ListTile(
            leading:
                const Icon(Icons.help_outline, color: NaturalPalette.forest),
            title: const Text('Support & FAQ'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () =>
                _launch('https://compo-cf.github.io/woodlandstrailguide/support.html'),
          ),
          const SizedBox(height: 32),
          const Text(
            'Trail data © The Woodlands Township.\nApp by Anthony Compofelice.',
            style: TextStyle(fontSize: 12, color: NaturalPalette.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              color: NaturalPalette.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2)),
    );
  }
}
