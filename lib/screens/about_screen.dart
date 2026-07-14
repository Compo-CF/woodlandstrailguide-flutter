import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/iap_store.dart';
import '../stores/user_data_store.dart';
import '../theme/natural_palette.dart';
import '../widgets/tip_jar_sheet.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _isPurchasingRemoveAds = false;
  bool _isRestoring = false;

  @override
  Widget build(BuildContext context) {
    final userData = context.watch<UserDataStore>();
    final iap = context.watch<IAPStore>();
    final stats = userData.tripStats;
    final dateFormat = DateFormat('MM/dd/yy');

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
          if (!stats.isEmpty) ...[
            const SizedBox(height: 24),
            const _SectionTitle('Your walking stats'),
            Row(
              children: [
                _statCell(stats.totalMiles.toStringAsFixed(1), 'miles walked'),
                _statDivider(),
                _statCell('${stats.walkCount}', 'walks'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _statCell(stats.longestMiles.toStringAsFixed(2), 'longest'),
                _statDivider(),
                _statCell('${stats.currentStreakDays}', 'day streak'),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Recent walks'),
            ...userData.tripLog.take(10).map((trip) => Dismissible(
                  key: ValueKey(trip.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: NaturalPalette.route,
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) => userData.deleteTrip(trip.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('${trip.miles.toStringAsFixed(2)} mi',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: NaturalPalette.ink)),
                            const Spacer(),
                            Text(dateFormat.format(trip.date),
                                style: const TextStyle(
                                    fontSize: 12, color: NaturalPalette.inkMuted)),
                          ],
                        ),
                        Text('${trip.startLabel} → ${trip.endLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: NaturalPalette.inkMuted)),
                      ],
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 24),
          const _SectionTitle('Data'),
          const Text(
            'Trail and amenity data is sourced from The Woodlands Township\'s '
            'public ArcGIS GIS services. The app refreshes its local copy every '
            'launch, so newly-added trails appear automatically.',
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Support the developer'),
          ListTile(
            leading: const Icon(Icons.coffee, color: NaturalPalette.route),
            title: const Text('Send a tip'),
            subtitle: iap.tipCount > 0
                ? Text("You've supported ${iap.tipCount} time${iap.tipCount == 1 ? '' : 's'} — thank you",
                    style: const TextStyle(color: NaturalPalette.forest))
                : null,
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: NaturalPalette.cardBg,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => const TipJarSheet(),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Remove ads'),
          if (iap.hasRemovedAds)
            const ListTile(
              leading: Icon(Icons.check_circle, color: NaturalPalette.forest),
              title: Text('Ads removed'),
              trailing: Text('Thanks!',
                  style: TextStyle(color: NaturalPalette.inkMuted, fontSize: 12)),
            )
          else if (iap.removeAdsProduct != null)
            ListTile(
              leading: const Icon(Icons.block, color: NaturalPalette.forest),
              title: const Text('Remove ads'),
              subtitle: const Text('Permanently hide the banner. One-time purchase.'),
              trailing: _isPurchasingRemoveAds
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(iap.removeAdsProduct!.price,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onTap: _isPurchasingRemoveAds
                  ? null
                  : () async {
                      setState(() => _isPurchasingRemoveAds = true);
                      await iap.purchase(iap.removeAdsProduct!);
                      if (mounted) setState(() => _isPurchasingRemoveAds = false);
                    },
            )
          else
            ListTile(
              leading: const Icon(Icons.block, color: NaturalPalette.inkMuted),
              title: const Text('Remove ads', style: TextStyle(color: NaturalPalette.inkMuted)),
              trailing: iap.isLoading
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Unavailable',
                      style: TextStyle(color: NaturalPalette.inkMuted, fontSize: 12)),
            ),
          ListTile(
            leading: const Icon(Icons.refresh, color: NaturalPalette.forest),
            title: const Text('Restore purchases'),
            trailing: _isRestoring
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _isRestoring
                ? null
                : () async {
                    setState(() => _isRestoring = true);
                    await iap.restorePurchases();
                    if (mounted) setState(() => _isRestoring = false);
                  },
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

  Widget _statCell(String number, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(number,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: NaturalPalette.ink)),
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.5,
                  color: NaturalPalette.inkMuted)),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(
        width: 1,
        height: 34,
        color: NaturalPalette.hairline,
      );

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
