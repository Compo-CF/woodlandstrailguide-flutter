import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Minimal file-based diagnostic logger.
///
/// Temporary — added specifically to track down the map-load ANR when
/// `adb logcat` isn't available (the test tablet's ADB interface won't
/// cooperate, but its MTP/file-transfer interface over the same USB
/// cable does). Writes to the app's external files directory, which a
/// plain Windows file explorer can browse into over MTP without any
/// ADB connection at all. Strip this out once the real bottleneck is
/// found — it doesn't belong in a shipped build.
class DebugLog {
  static File? _file;
  static final _stopwatch = Stopwatch()..start();

  static Future<void> _ensureFile() async {
    if (_file != null) return;
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      _file = File('${dir.path}/trailguide_debug.log');
      await _file!.writeAsString(
        '=== log started at ${DateTime.now()} ===\n',
        mode: FileMode.write,
      );
    } catch (_) {
      // If external storage isn't available for some reason, just skip
      // logging rather than crash the app over a debug aid.
    }
  }

  static Future<void> log(String message) async {
    await _ensureFile();
    if (_file == null) return;
    final elapsed = _stopwatch.elapsedMilliseconds;
    try {
      await _file!.writeAsString(
        '[+${elapsed}ms] $message\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }
}
