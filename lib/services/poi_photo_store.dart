// Stores user-attached photos per POI. Local-only, JPEG on disk under
// Documents/poi_photos/<category>__<poi_id>/, keyed by a composite key
// so the same OBJECTID across categories doesn't collide. No upload,
// no cloud sync, no sharing. Direct port of iOS POIPhotoStore.swift.
//
// image_picker already downscales + compresses at pick time (maxWidth
// 1600, quality 82) — matching iOS's manual UIGraphicsImageRenderer
// downscale — so this store only needs to manage file placement, the
// 3-photo cap, and notifying listeners.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PhotoKey {
  final String categoryKey;
  final String poiID;
  const PhotoKey({required this.categoryKey, required this.poiID});

  /// Filesystem-safe directory name for this POI's photos.
  String get diskName {
    final raw = '${categoryKey}__$poiID';
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }
}

class POIPhotoStore extends ChangeNotifier {
  static const maxPhotosPerPOI = 3;

  Directory? _baseDir;
  int version = 0;

  Future<void> load() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/poi_photos');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _baseDir = dir;
    notifyListeners();
  }

  Directory _dirFor(PhotoKey key) {
    final dir = Directory('${_baseDir!.path}/${key.diskName}');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// File paths for photos attached to this POI, oldest-first.
  List<File> photoURLs(PhotoKey key) {
    if (_baseDir == null) return const [];
    final dir = _dirFor(key);
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jpg'))
        .toList();
    files.sort((a, b) =>
        a.statSync().modified.compareTo(b.statSync().modified));
    return files;
  }

  /// Copies an already-picked (and already downscaled) image file into
  /// this POI's folder. Evicts the oldest photo first if already at cap.
  File? addPhoto(String sourcePath, PhotoKey key) {
    if (_baseDir == null) return null;
    final existing = photoURLs(key);
    if (existing.length >= maxPhotosPerPOI) {
      existing.first.deleteSync();
    }
    final dir = _dirFor(key);
    final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = File('${dir.path}/$filename');
    File(sourcePath).copySync(dest.path);
    version++;
    notifyListeners();
    return dest;
  }

  void deletePhoto(File file) {
    if (file.existsSync()) file.deleteSync();
    version++;
    notifyListeners();
  }
}
