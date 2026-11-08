import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:porch/cameras/camera_store.dart';
import 'package:porch/ha/ha_client.dart';
import 'package:porch/main.dart';
import 'package:porch/settings/app_settings.dart';

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

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      PorchApp(
        settings: settings,
        cameras: cameras,
        ha: ha,
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

    await tester.tap(find.text('TV'));
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && !ha.entities['switch.tv_power']!.isOn; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(find.text('Living room | On'), findsOneWidget);

    await tester.tap(find.text('Edit home'));
    await tester.pump();
    expect(find.byTooltip('Remove TV from Home'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove TV from Home'));
    await tester.pump();
    expect(settings.pinned, ['lock.front_door']);
  });
}
