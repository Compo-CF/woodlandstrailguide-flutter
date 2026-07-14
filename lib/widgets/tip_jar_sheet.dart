import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../services/iap_store.dart';
import '../theme/natural_palette.dart';

/// Three-tier tip picker. Direct port of iOS TipJarSheet — tapping a
/// tier fires the Play Billing purchase flow; on success we show a
/// thank-you dialog. Tips are UI-only, they don't unlock anything.
class TipJarSheet extends StatefulWidget {
  const TipJarSheet({super.key});

  @override
  State<TipJarSheet> createState() => _TipJarSheetState();
}

class _TipJarSheetState extends State<TipJarSheet> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final iap = context.watch<IAPStore>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.coffee, size: 54, color: NaturalPalette.route),
            const SizedBox(height: 16),
            const Text('Support the app',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: NaturalPalette.ink)),
            const SizedBox(height: 8),
            const Text(
              "Built and maintained by one local on weekends. Every tip goes "
              "toward keeping the trail data current and building new features.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: NaturalPalette.inkMuted),
            ),
            const SizedBox(height: 20),
            if (iap.tipProducts.isEmpty)
              iap.isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(),
                    )
                  : const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Text('Tips are temporarily unavailable',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: NaturalPalette.inkMuted)),
                          SizedBox(height: 6),
                          Text(
                            'Check back in a moment, or reach out via Support & FAQ '
                            'if this keeps happening.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: NaturalPalette.inkMuted),
                          ),
                        ],
                      ),
                    )
            else
              ...iap.tipProducts.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _tipButton(context, iap, p),
                  )),
            if (iap.tipCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                "You've supported the app ${iap.tipCount} time${iap.tipCount == 1 ? '' : 's'} — thank you.",
                style: const TextStyle(fontSize: 12.5, color: NaturalPalette.forest),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Tips are processed by Google Play and are non-refundable through '
              'the app. Contact Google Play Support if you need a refund.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: NaturalPalette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tipButton(BuildContext context, IAPStore iap, ProductDetails product) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isProcessing
            ? null
            : () async {
                setState(() => _isProcessing = true);
                final ok = await iap.purchase(product);
                if (mounted) setState(() => _isProcessing = false);
                if (ok && context.mounted) {
                  showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Thank you!'),
                      content: const Text(
                          'Every tip goes toward keeping the trail data current and '
                          'building new features. It means a lot.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("You're welcome"),
                        ),
                      ],
                    ),
                  );
                }
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: NaturalPalette.ink,
          side: const BorderSide(color: NaturalPalette.hairline),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        child: Row(
          children: [
            Icon(_iconFor(product.id), color: NaturalPalette.forest, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_labelFor(product.id),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(_captionFor(product.id),
                      style: const TextStyle(fontSize: 11, color: NaturalPalette.inkMuted)),
                ],
              ),
            ),
            Text(product.price,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  String _labelFor(String id) => switch (id) {
        IAPStore.tipSmallID => 'Small tip',
        IAPStore.tipMediumID => 'Regular tip',
        IAPStore.tipLargeID => 'Generous tip',
        _ => 'Tip',
      };

  String _captionFor(String id) => switch (id) {
        IAPStore.tipSmallID => 'A quick thanks',
        IAPStore.tipMediumID => 'Covers hosting for a while',
        IAPStore.tipLargeID => 'Funds a new feature',
        _ => '',
      };

  IconData _iconFor(String id) => switch (id) {
        IAPStore.tipSmallID => Icons.favorite_border,
        IAPStore.tipMediumID => Icons.favorite,
        IAPStore.tipLargeID => Icons.local_fire_department,
        _ => Icons.favorite_border,
      };
}
