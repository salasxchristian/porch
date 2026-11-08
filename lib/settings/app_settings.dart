import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum CameraLayout { spotlight, grid }

/// App preferences kept in a JSON file in the app's support folder.
///
/// [shown] is every Home Assistant entity the app shows. [pinned] is the
/// ordered subset that also appears on Home.
class AppSettings extends ChangeNotifier {
  AppSettings(this.file);

  final File file;

  String themeId = 'sage';
  String haUrl = '';
  String haToken = '';
  Set<String> shown = {};
  List<String> pinned = [];
  CameraLayout cameraLayout = CameraLayout.spotlight;

  bool get hasConnection => haUrl.isNotEmpty && haToken.isNotEmpty;

  static Future<AppSettings> open() async {
    final dir = await getApplicationSupportDirectory();
    final settings = AppSettings(
      File('${dir.path}${Platform.pathSeparator}settings.json'),
    );
    await settings.load();
    return settings;
  }

  Future<void> load() async {
    if (!await file.exists()) return;
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      themeId = json['theme'] as String? ?? themeId;
      haUrl = json['haUrl'] as String? ?? '';
      haToken = json['haToken'] as String? ?? '';
      shown = {...(json['shown'] as List? ?? []).cast<String>()};
      pinned = [
        for (final id in (json['pinned'] as List? ?? []).cast<String>())
          if (shown.contains(id)) id,
      ];
      cameraLayout = CameraLayout.values.firstWhere(
        (l) => l.name == json['cameraLayout'],
        orElse: () => CameraLayout.spotlight,
      );
    } on FormatException {
      // Keep defaults when the file is unreadable.
    }
    notifyListeners();
  }

  Future<void> setTheme(String id) => _update(() => themeId = id);

  Future<void> setConnection(String url, String token) => _update(() {
    haUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    haToken = token.trim();
  });

  Future<void> setCameraLayout(CameraLayout layout) =>
      _update(() => cameraLayout = layout);

  /// Hiding an entity also takes it off Home.
  Future<void> setShown(String id, bool show) => _update(() {
    if (show) {
      shown = {...shown, id};
    } else {
      shown = {...shown}..remove(id);
      pinned = [...pinned]..remove(id);
    }
  });

  Future<void> setPinned(String id, bool pin) => _update(() {
    if (pin && shown.contains(id) && !pinned.contains(id)) {
      pinned = [...pinned, id];
    } else if (!pin) {
      pinned = [...pinned]..remove(id);
    }
  });

  /// Moves pinned entity [id] to sit where [beforeId] is now.
  Future<void> movePinned(String id, String beforeId) => _update(() {
    if (id == beforeId) return;
    final next = [...pinned]..remove(id);
    final at = next.indexOf(beforeId);
    if (at < 0) return;
    final from = pinned.indexOf(id);
    final to = pinned.indexOf(beforeId);
    next.insert(from < to ? at + 1 : at, id);
    pinned = next;
  });

  Future<void> _update(void Function() change) async {
    change();
    notifyListeners();
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'theme': themeId,
        'haUrl': haUrl,
        'haToken': haToken,
        'shown': shown.toList()..sort(),
        'pinned': pinned,
        'cameraLayout': cameraLayout.name,
      }),
    );
    await tmp.rename(file.path);
  }
}
