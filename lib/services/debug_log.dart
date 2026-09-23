import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:path_provider/path_provider.dart';

/// Minimal file-based diagnostic logger. **Debug builds only.**
///
/// Added to track down the map-load ANR when `adb logcat` wasn't
/// available (the old test tablet's ADB interface wouldn't cooperate, but
/// its MTP/file-transfer interface over the same USB cable did). Writes
/// to the app's external files directory, which a plain Windows file
/// explorer can browse over MTP with no ADB connection at all.
///
/// That investigation is finished — the Pixel 7a runs the map with no ANR,
/// so the original cause was largely the tablet. The logger is kept
/// because it's useful the next time something misbehaves only on a
/// device, but every entry point is hard-gated on `kDebugMode`: it is
/// called ~17 times including from the polyline cache path that runs on
/// every map render, and a shipped build has no business doing that file
/// I/O on a hot path, let alone leaving diagnostic files in the user's
/// external storage for a Data Safety declaration to have to explain.
class DebugLog {
  static File? _file;
  static final _stopwatch = Stopwatch()..start();

  static Future<void> _ensureFile() async {
    if (!kDebugMode) return;
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
    // Single gate for all call sites. Release builds do nothing at all —
    // no file handle, no write, no path_provider call.
    if (!kDebugMode) return;
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
