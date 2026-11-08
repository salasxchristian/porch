import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'camera.dart';

/// Keeps the camera list in a JSON file in the app's support folder.
class CameraStore extends ChangeNotifier {
  CameraStore(this.file);

  final File file;
  List<Camera> _cameras = [];

  List<Camera> get cameras => List.unmodifiable(_cameras);

  static Future<CameraStore> open() async {
    final dir = await getApplicationSupportDirectory();
    final store = CameraStore(
      File('${dir.path}${Platform.pathSeparator}cameras.json'),
    );
    await store.load();
    return store;
  }

  Future<void> load() async {
    if (!await file.exists()) return;
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _cameras = [
        for (final c in json['cameras'] as List)
          Camera.fromJson(c as Map<String, dynamic>),
      ];
    } on FormatException {
      _cameras = [];
    }
    notifyListeners();
  }

  Future<void> add(Camera camera) async {
    _cameras = [..._cameras, camera];
    await _save();
  }

  Future<void> addAll(Iterable<Camera> cameras) async {
    _cameras = [..._cameras, ...cameras];
    await _save();
  }

  Future<void> update(Camera camera) async {
    _cameras = [for (final c in _cameras) c.id == camera.id ? camera : c];
    await _save();
  }

  Future<void> remove(String id) async {
    _cameras = [
      for (final c in _cameras)
        if (c.id != id) c,
    ];
    await _save();
  }

  Future<void> _save() async {
    notifyListeners();
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'cameras': [for (final c in _cameras) c.toJson()],
      }),
    );
    await tmp.rename(file.path);
  }
}
