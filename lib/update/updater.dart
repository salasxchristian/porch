import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// The newest Porch release on GitHub.
class PorchRelease {
  const PorchRelease({
    required this.version,
    required this.notes,
    required this.page,
    this.installer,
  });

  final String version;
  final String notes;

  /// The release on github.com.
  final Uri page;

  /// The Windows installer (`PorchSetup-<version>.exe`), when attached.
  final Uri? installer;

  static PorchRelease? fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'];
    final page = Uri.tryParse(json['html_url'] as String? ?? '');
    if (tag is! String || page == null) return null;
    Uri? installer;
    for (final asset in json['assets'] as List? ?? const []) {
      if (asset is! Map) continue;
      final name = asset['name'] as String? ?? '';
      if (name.startsWith('PorchSetup') && name.endsWith('.exe')) {
        installer = Uri.tryParse(asset['browser_download_url'] as String);
      }
    }
    return PorchRelease(
      version: tag.replaceFirst(RegExp('^v'), ''),
      notes: _plainNotes(json['body'] as String? ?? ''),
      page: page,
      installer: installer,
    );
  }

  /// GitHub writes notes in Markdown; keep the words, drop the markup.
  static String _plainNotes(String body) => body
      .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
      .replaceAll(RegExp(r'\*\*|__|`'), '')
      .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
      .trim();
}

/// Compares dotted versions like `0.2.10` and `0.2.9`. Anything after a `+`
/// or `-` is ignored. Returns a positive number when [a] is newer.
int compareVersions(String a, String b) {
  List<int> numbers(String v) => v
      .split(RegExp('[+-]'))
      .first
      .split('.')
      .map((n) => int.tryParse(n) ?? 0)
      .toList();
  final x = numbers(a);
  final y = numbers(b);
  for (var i = 0; i < 3; i++) {
    final diff = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (diff != 0) return diff;
  }
  return 0;
}

enum UpdateState {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  installing,
  failed,
}

/// Looks for a newer release on GitHub when Porch opens and twice a day.
///
/// On Windows, [install] downloads the installer, starts it silently and
/// quits; the installer replaces Porch and opens the new version. Elsewhere
/// it opens the release page.
class Updater extends ChangeNotifier {
  Updater({
    required this.currentVersion,
    Uri? latestReleaseApi,
    bool? installsInApp,
    this.runInstaller = _runInstaller,
  }) : latestReleaseApi = latestReleaseApi ?? _defaultApi,
       installsInApp = installsInApp ?? Platform.isWindows;

  static const repo = 'salasxchristian/porch';
  static final _defaultApi = Uri.parse(
    'https://api.github.com/repos/$repo/releases/latest',
  );
  static final releasesPage = Uri.parse('https://github.com/$repo/releases');
  static const checkEvery = Duration(hours: 12);

  final String currentVersion;
  final Uri latestReleaseApi;
  final bool installsInApp;

  /// Starts the downloaded installer. Replaced in tests.
  final Future<void> Function(File installer) runInstaller;

  UpdateState state = UpdateState.idle;
  PorchRelease? latest;

  /// Download progress from 0 to 1, while [state] is downloading.
  double progress = 0;
  String? error;

  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  Timer? _timer;

  bool get busy => const {
    UpdateState.checking,
    UpdateState.downloading,
    UpdateState.installing,
  }.contains(state);

  /// Checks now, then every [checkEvery].
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(checkEvery, (_) => check(quiet: true));
    check(quiet: true);
  }

  /// A quiet check doesn't report problems; it just stays idle.
  Future<void> check({bool quiet = false}) async {
    if (busy) return;
    _set(UpdateState.checking);
    try {
      final request = await _http.getUrl(latestReleaseApi);
      request.headers.set('Accept', 'application/vnd.github+json');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 404) {
        // No release has been published yet.
        latest = null;
        _set(UpdateState.upToDate);
        return;
      }
      if (response.statusCode != 200) {
        throw HttpException('GitHub answered ${response.statusCode}');
      }
      latest = PorchRelease.fromJson(jsonDecode(body) as Map<String, dynamic>);
      final newer =
          latest != null &&
          compareVersions(latest!.version, currentVersion) > 0;
      _set(newer ? UpdateState.available : UpdateState.upToDate);
    } catch (e) {
      debugPrint('Update check failed: $e');
      _fail("Couldn't check for updates.", quiet: quiet);
    }
  }

  Future<void> install() async {
    final release = latest;
    if (release == null || busy) return;
    final url = release.installer;
    if (!installsInApp || url == null) {
      await openInBrowser(release.page);
      return;
    }
    try {
      final dir = await Directory.systemTemp.createTemp('porch-update-');
      final file = File(
        '${dir.path}${Platform.pathSeparator}${url.pathSegments.last}',
      );
      await _download(url, file);
      _set(UpdateState.installing);
      await runInstaller(file);
    } catch (e) {
      debugPrint('Update install failed: $e');
      _fail("The update didn't install. You can get it from GitHub instead.");
    }
  }

  Future<void> _download(Uri url, File to) async {
    progress = 0;
    _set(UpdateState.downloading);
    final request = await _http.getUrl(url);
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('Download answered ${response.statusCode}');
    }
    final total = response.contentLength;
    var received = 0;
    final sink = to.openWrite();
    try {
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          progress = received / total;
          notifyListeners();
        }
      }
    } finally {
      await sink.close();
    }
  }

  /// The installer closes Porch if needed, installs over it and opens the
  /// new version (see windows/installer.iss).
  static Future<void> _runInstaller(File installer) async {
    await Process.start(installer.path, const [
      '/VERYSILENT',
      '/SUPPRESSMSGBOXES',
      '/NORESTART',
      '/CLOSEAPPLICATIONS',
    ], mode: ProcessStartMode.detached);
    exit(0);
  }

  static Future<void> openInBrowser(Uri url) async {
    try {
      if (Platform.isWindows) {
        await Process.run('rundll32', ['url.dll,FileProtocolHandler', '$url']);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['$url']);
      }
    } catch (e) {
      debugPrint('Could not open $url: $e');
    }
  }

  void _fail(String message, {bool quiet = false}) {
    error = message;
    _set(quiet ? UpdateState.idle : UpdateState.failed);
  }

  void _set(UpdateState next) {
    state = next;
    if (next != UpdateState.failed) error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _http.close(force: true);
    super.dispose();
  }
}
