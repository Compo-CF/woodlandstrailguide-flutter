import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../stores/trail_store.dart';
import '../theme/natural_type.dart';

/// Animated splash shown over the app while the trail graph loads. The
/// Android half of iOS's `SplashView.swift`, down to the same curve, colours
/// and timings.
///
/// Two things make this worth having rather than decoration:
///
/// 1. There is real work to cover. TrailStore parses ~1,500 ways and ~44,000
///    nodes on launch; before this, users got a flash of empty scaffold and
///    then a half-drawn map. The splash is sized to that work rather than
///    padded to look busy — it leaves as soon as the graph is ready.
/// 2. The platform's own launch window can't animate. Android renders
///    `LaunchTheme`'s window background before any Dart runs, so the only
///    way to get motion at startup is to hand off from that static window to
///    a view like this one. `launch_background.xml` is painted the same
///    green used here precisely so that handoff is invisible — the animation
///    appears to begin on the system's own screen.
///
/// The motion is a trail drawing itself, which is the most honest summary of
/// what the app does, followed by the wordmark.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  static const Color background = Color(0xFF12351F);
  static const Color cream = Color(0xFFF6EDD7);
  static const Color trail = Color(0xFFDF712A);

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Drives the path's trim. Animating the trim is what produces the
  /// "drawing itself" effect rather than a fade or a slide.
  late final Animation<double> _trailProgress;
  late final Animation<double> _markerScale;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<double> _wordmarkOffset;

  static const _total = Duration(milliseconds: 1250);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total)..forward();

    // Intervals are fractions of _total, chosen to land on the same
    // wall-clock beats as the iOS version's explicit delays.
    _trailProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.68, curve: Curves.easeInOut),
    );
    _markerScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.62, 1.0, curve: Curves.elasticOut),
    );
    final wordmark = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.78, curve: Curves.easeOut),
    );
    _wordmarkOpacity = wordmark;
    _wordmarkOffset = Tween<double>(begin: 8, end: 0).animate(wordmark);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // One announcement to TalkBack rather than a pile of decorative
    // fragments.
    return Semantics(
      label: 'The Woodlands Trail Guide, loading',
      container: true,
      child: ExcludeSemantics(
        child: ColoredBox(
          color: SplashView.background,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 190,
                      height: 96,
                      child: CustomPaint(
                        painter: _TrailMarkPainter(
                          progress: _trailProgress.value,
                          markerScale: _markerScale.value.clamp(0.0, 1.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    Opacity(
                      opacity: _wordmarkOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _wordmarkOffset.value),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'The Woodlands Trail Guide',
                              style: NaturalType.display(
                                25,
                                color: SplashView.cream,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'THE WOODLANDS, TEXAS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.2,
                                color: SplashView.cream.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The trail mark: a meandering path with a marker at its end.
///
/// The curve is defined in unit space and scaled to the canvas, so the end
/// point is a single value the marker can be positioned from — duplicating
/// the curve maths in two places is how a marker and the stroke it should
/// sit on quietly drift apart.
class _TrailMarkPainter extends CustomPainter {
  _TrailMarkPainter({required this.progress, required this.markerScale});

  final double progress;
  final double markerScale;

  /// Unit-space location of the path's final point.
  static const Offset endPoint = Offset(0.92, 0.30);

  static Path _trailPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.06, h * 0.74)
      ..cubicTo(w * 0.17, h * 0.92, w * 0.27, h * 0.44, w * 0.40, h * 0.56)
      ..cubicTo(w * 0.52, h * 0.66, w * 0.55, h * 0.84, w * 0.66, h * 0.64)
      ..cubicTo(w * 0.78, h * 0.46, w * 0.82, h * 0.30, w * endPoint.dx,
          h * endPoint.dy);
  }

  /// Flutter has no `.trim()`, so the drawn fraction is extracted with
  /// PathMetrics — the same thing SwiftUI's trim does internally.
  static Path _trimmed(Path path, double fraction) {
    final out = Path();
    for (final metric in path.computeMetrics()) {
      out.addPath(metric.extractPath(0, metric.length * fraction), Offset.zero);
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _trailPath(size);

    Paint stroke(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    // Faint full path underneath, so the stroke reads as travelling a route
    // that already exists rather than conjuring one out of nothing.
    canvas.drawPath(path, stroke(SplashView.cream.withValues(alpha: 0.14)));

    final drawn = progress.clamp(0.0, 1.0);
    if (drawn > 0) {
      canvas.drawPath(_trimmed(path, drawn), stroke(SplashView.trail));
    }

    if (markerScale > 0) {
      final c = Offset(size.width * endPoint.dx, size.height * endPoint.dy);
      canvas.drawCircle(c, 8 * markerScale, Paint()..color = SplashView.cream);
      canvas.drawCircle(
          c, 3.5 * markerScale, Paint()..color = SplashView.trail);
    }
  }

  @override
  bool shouldRepaint(_TrailMarkPainter old) =>
      old.progress != progress || old.markerScale != markerScale;
}

/// Decides how long the splash stays up.
///
/// Bounded at both ends, deliberately. A minimum so a fast launch doesn't
/// flash something unreadable for 200ms, and a hard maximum so a slow or
/// failed data load can never strand the user staring at a logo — the app
/// behind this has its own loading and error states, and is a better place
/// to be than here.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  static const _minimum = Duration(milliseconds: 1400);
  static const _maximum = Duration(milliseconds: 3500);

  bool _finished = false;
  bool _minimumElapsed = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(_minimum, () {
      if (!mounted) return;
      _minimumElapsed = true;
      _finishIfPossible();
    });
    Future<void>.delayed(_maximum, () {
      // Hard ceiling — fires regardless of readiness.
      if (mounted && !_finished) setState(() => _finished = true);
    });
  }

  void _finishIfPossible() {
    if (!mounted || _finished) return;
    if (!_minimumElapsed) return;
    if (context.read<TrailStore>().graph == null) return;
    setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    // Watching TrailStore is what re-runs the readiness check when the graph
    // finishes parsing; the minimum-duration timer covers the other
    // direction (graph already loaded before that timer fires).
    context.watch<TrailStore>();
    if (!_finished) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finishIfPossible());
    }

    return Stack(
      children: [
        widget.child,
        if (!_finished) const Positioned.fill(child: SplashView()),
      ],
    );
  }
}
