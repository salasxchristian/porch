import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:porch/cameras/camera_store.dart';
import 'package:porch/ha/ha_client.dart';
import 'package:porch/main.dart';
import 'package:porch/settings/app_settings.dart';
import 'package:porch/theme.dart';
import 'package:porch/update/updater.dart';
import 'package:porch/widgets/device_details.dart';

import '../tool/fake_ha_server.dart';

void main() {
  late Directory tmp;
  late AppSettings settings;
  late CameraStore cameras;
  late HaClient ha;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('porch_widget');
    settings = AppSettings(File('${tmp.path}/settings.json'));
    cameras = CameraStore(File('${tmp.path}/cameras.json'));
    ha = HaClient();
  });

  tearDown(() {
    ha.dispose();
    tmp.deleteSync(recursive: true);
  });

  Future<void> pumpApp(WidgetTester tester, {Updater? updater}) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      PorchApp(
        settings: settings,
        cameras: cameras,
        ha: ha,
        updater: updater ?? Updater(currentVersion: '0.1.0'),
        useGoogleFonts: false,
      ),
    );
  }

  testWidgets('first run asks to connect Home Assistant', (tester) async {
    await pumpApp(tester);
    expect(find.text('Connect Home Assistant'), findsOneWidget);
    expect(find.text('Not set up'), findsOneWidget);

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Save and connect'), findsOneWidget);
    expect(
      find.text('Connect to Home Assistant below to see your devices.'),
      findsOneWidget,
    );
  });

  testWidgets('switching theme in Settings recolors the app', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lilac'));
    await tester.pumpAndSettle();
    expect(settings.themeId, 'lilac');
  });

  testWidgets('pinned devices show on Home and toggle', (tester) async {
    final server = FakeHaServer();
    await tester.runAsync(() async {
      await server.start();
      await settings.setConnection('http://127.0.0.1:${server.port}', 'dev');
      await settings.setShown('switch.tv_power', true);
      await settings.setPinned('switch.tv_power', true);
      await settings.setShown('lock.front_door', true);
      await settings.setPinned('lock.front_door', true);
      await ha.connect(settings.haUrl, settings.haToken);
      for (var i = 0; i < 100 && ha.status != HaStatus.connected; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    addTearDown(() => tester.runAsync(server.stop));

    await pumpApp(tester);
    await tester.pump();
    expect(find.text('TV'), findsOneWidget);
    expect(find.text('Living room | Off'), findsOneWidget);
    expect(find.text('Front door'), findsOneWidget);

    // The card's switch toggles it.
    await tester.tap(find.byType(Switch));
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && !ha.entities['switch.tv_power']!.isOn; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(find.text('Living room | On'), findsOneWidget);

    // Clicking the card opens its panel instead.
    await tester.tap(find.text('TV'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.text('Edit home'));
    await tester.pump();
    expect(find.byTooltip('Remove TV from Home'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove TV from Home'));
    await tester.pump();
    expect(settings.pinned, ['lock.front_door']);
  });

  testWidgets('dark mode can be picked in Settings', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(settings.appearance, ThemeMode.dark);
    final palette = tester.element(find.text('Appearance')).porch;
    expect(palette.isDark, isTrue);
    expect(palette.id, 'sage');
  });

  group('device panel', () {
    late FakeHaServer server;

    Future<void> openPanel(WidgetTester tester, String entityId) async {
      server = FakeHaServer();
      await tester.runAsync(() async {
        await server.start();
        await ha.connect('http://127.0.0.1:${server.port}', 'dev');
        for (var i = 0; i < 100 && ha.status != HaStatus.connected; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      addTearDown(() => tester.runAsync(server.stop));
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPorchTheme(PorchPalette.sage, useGoogleFonts: false),
          home: Scaffold(
            body: DeviceDetails(ha: ha, entityId: entityId),
          ),
        ),
      );
    }

    Future<void> waitFor(WidgetTester tester, bool Function() done) async {
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && !done(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();
    }

    testWidgets('a color light offers brightness, white, color and effects', (
      tester,
    ) async {
      await openPanel(tester, 'light.floor_lamp');
      expect(find.text('Floor lamp'), findsOneWidget);
      for (final label in ['Brightness', 'White temperature', 'Color']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Candle'), findsOneWidget);

      await tester.tap(find.byTooltip('Blue'));
      await waitFor(
        tester,
        () => ha.entities['light.floor_lamp']!.attributes['color_mode'] == 'hs',
      );
      expect(ha.entities['light.floor_lamp']!.attributes['hs_color'], [
        220.0,
        85,
      ]);

      await tester.tap(find.text('Candle'));
      await waitFor(
        tester,
        () => ha.entities['light.floor_lamp']!.attributes['effect'] == 'Candle',
      );
    });

    testWidgets('a thermostat changes mode and temperature', (tester) async {
      await openPanel(tester, 'climate.thermostat');
      expect(find.text('70°'), findsOneWidget);
      expect(find.text('Inside now 68° | 41% humidity'), findsOneWidget);

      await tester.tap(find.byTooltip('Set to higher'));
      await waitFor(
        tester,
        () => ha.entities['climate.thermostat']!.targetTemperature == 71,
      );
      expect(find.text('71°'), findsOneWidget);

      await tester.tap(find.text('Heat and cool'));
      await waitFor(
        tester,
        () => ha.entities['climate.thermostat']!.state == 'heat_cool',
      );
      expect(find.text('Heat to'), findsOneWidget);
      expect(find.text('Cool to'), findsOneWidget);
      expect(find.text('Hallway | Heat and cool, 71° to 76°'), findsOneWidget);

      await tester.tap(find.text('Away'));
      await waitFor(
        tester,
        () =>
            ha.entities['climate.thermostat']!.attributes['preset_mode'] ==
            'away',
      );
    });

    testWidgets('blinds open, close and show their position', (tester) async {
      await openPanel(tester, 'cover.bedroom_blinds');
      expect(find.text('Position'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await waitFor(
        tester,
        () => ha.entities['cover.bedroom_blinds']!.state == 'closed',
      );
      expect(
        ha.entities['cover.bedroom_blinds']!.attributes['current_position'],
        0,
      );
    });
  });

  testWidgets('a newer release shows an update card', (tester) async {
    // Widget tests answer every HTTP request with 400; this one talks to a
    // local server instead.
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = overrides);
    late HttpServer server;
    late Updater updater;
    File? ran;
    await tester.runAsync(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final base = 'http://127.0.0.1:${server.port}';
      server.listen((request) async {
        if (request.uri.path == '/latest') {
          request.response.write(
            jsonEncode({
              'tag_name': 'v0.2.0',
              'html_url': '$base/page',
              'body': 'Faster cameras',
              'assets': [
                {
                  'name': 'PorchSetup-0.2.0.exe',
                  'browser_download_url': '$base/setup.exe',
                },
              ],
            }),
          );
        } else {
          request.response.add([1, 2, 3]);
        }
        await request.response.close();
      });
      updater = Updater(
        currentVersion: '0.1.0',
        latestReleaseApi: Uri.parse('$base/latest'),
        installsInApp: true,
        runInstaller: (file) async => ran = file,
      );
      await updater.check();
    });
    addTearDown(() => tester.runAsync(() => server.close(force: true)));
    addTearDown(updater.dispose);

    await pumpApp(tester, updater: updater);
    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Porch 0.2.0'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Porch 0.2.0 is out. You have 0.1.0.'), findsOneWidget);
    expect(find.text('Faster cameras'), findsOneWidget);

    await tester.runAsync(() => updater.install());
    await tester.pump();
    expect(ran, isNotNull);
    expect(find.text('Installing update'), findsOneWidget);
    await tester.runAsync(() => ran!.parent.delete(recursive: true));
  });
}
