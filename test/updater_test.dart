import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:porch/update/updater.dart';

void main() {
  test('compares versions by number', () {
    expect(compareVersions('0.2.10', '0.2.9'), greaterThan(0));
    expect(compareVersions('1.0.0', '0.9.9'), greaterThan(0));
    expect(compareVersions('0.1.0', '0.1.0+5'), 0);
    expect(compareVersions('0.1', '0.1.1'), lessThan(0));
  });

  test('reads a GitHub release and finds the installer', () {
    final release = PorchRelease.fromJson({
      'tag_name': 'v0.3.0',
      'html_url': 'https://github.com/salasxchristian/porch/releases/v0.3.0',
      'body': '## What changed\n**Dark mode** and [device panels](https://x)',
      'assets': [
        {
          'name': 'Porch-0.3.0-windows-x64.zip',
          'browser_download_url': 'https://example.com/zip',
        },
        {
          'name': 'PorchSetup-0.3.0.exe',
          'browser_download_url': 'https://example.com/setup.exe',
        },
      ],
    })!;
    expect(release.version, '0.3.0');
    expect(release.installer.toString(), 'https://example.com/setup.exe');
    expect(release.notes, 'What changed\nDark mode and device panels');
  });

  group('against a stand-in for GitHub', () {
    late HttpServer server;
    late Uri api;
    var latestStatus = 200;
    final installerBytes = List<int>.generate(50000, (i) => i % 256);

    setUp(() async {
      latestStatus = 200;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final base = 'http://127.0.0.1:${server.port}';
      api = Uri.parse('$base/latest');
      server.listen((request) async {
        final response = request.response;
        if (request.uri.path == '/latest') {
          response.statusCode = latestStatus;
          response.write(
            jsonEncode({
              'tag_name': 'v0.2.0',
              'html_url': '$base/page',
              'body': 'Fixes',
              'assets': [
                {
                  'name': 'PorchSetup-0.2.0.exe',
                  'browser_download_url': '$base/PorchSetup-0.2.0.exe',
                },
              ],
            }),
          );
        } else {
          response.contentLength = installerBytes.length;
          response.add(installerBytes);
        }
        await response.close();
      });
    });

    tearDown(() => server.close(force: true));

    test('finds a newer version', () async {
      final updater = Updater(currentVersion: '0.1.0', latestReleaseApi: api);
      await updater.check();
      expect(updater.state, UpdateState.available);
      expect(updater.latest!.version, '0.2.0');
      updater.dispose();
    });

    test('the same version is up to date', () async {
      final updater = Updater(currentVersion: '0.2.0', latestReleaseApi: api);
      await updater.check();
      expect(updater.state, UpdateState.upToDate);
      updater.dispose();
    });

    test('no release yet counts as up to date', () async {
      latestStatus = 404;
      final updater = Updater(currentVersion: '0.1.0', latestReleaseApi: api);
      await updater.check();
      expect(updater.state, UpdateState.upToDate);
      updater.dispose();
    });

    test('a failed check is quiet unless asked for', () async {
      latestStatus = 500;
      final updater = Updater(currentVersion: '0.1.0', latestReleaseApi: api);
      await updater.check(quiet: true);
      expect(updater.state, UpdateState.idle);
      await updater.check();
      expect(updater.state, UpdateState.failed);
      expect(updater.error, "Couldn't check for updates.");
      updater.dispose();
    });

    test('install downloads the installer and runs it', () async {
      File? ran;
      final updater = Updater(
        currentVersion: '0.1.0',
        latestReleaseApi: api,
        installsInApp: true,
        runInstaller: (file) async => ran = file,
      );
      await updater.check();
      await updater.install();
      expect(updater.state, UpdateState.installing);
      expect(updater.progress, 1);
      expect(ran!.path, endsWith('PorchSetup-0.2.0.exe'));
      expect(await ran!.readAsBytes(), installerBytes);
      await ran!.parent.delete(recursive: true);
      updater.dispose();
    });
  });
}
