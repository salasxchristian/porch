import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:porch/settings/app_settings.dart';
import 'package:porch/theme.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('porch_settings'));
  tearDown(() => tmp.deleteSync(recursive: true));

  AppSettings fresh() => AppSettings(File('${tmp.path}/settings.json'));

  test('settings survive a reload', () async {
    final s = fresh();
    await s.setTheme('lilac');
    await s.setConnection('http://ha.local:8123/', ' token ');
    await s.setShown('light.a', true);
    await s.setPinned('light.a', true);
    await s.setCameraLayout(CameraLayout.grid);

    final again = fresh();
    await again.load();
    expect(again.themeId, 'lilac');
    expect(again.haUrl, 'http://ha.local:8123');
    expect(again.haToken, 'token');
    expect(again.pinned, ['light.a']);
    expect(again.cameraLayout, CameraLayout.grid);
  });

  test('only shown entities can be pinned, and hiding unpins', () async {
    final s = fresh();
    await s.setPinned('light.a', true);
    expect(s.pinned, isEmpty);

    await s.setShown('light.a', true);
    await s.setPinned('light.a', true);
    await s.setShown('light.a', false);
    expect(s.pinned, isEmpty);
  });

  test('moving a pinned entity takes the target slot', () async {
    final s = fresh();
    for (final id in ['a', 'b', 'c', 'd']) {
      await s.setShown(id, true);
      await s.setPinned(id, true);
    }
    await s.movePinned('a', 'c');
    expect(s.pinned, ['b', 'c', 'a', 'd']);
    await s.movePinned('d', 'b');
    expect(s.pinned, ['d', 'b', 'c', 'a']);
    await s.movePinned('c', 'b');
    expect(s.pinned, ['d', 'c', 'b', 'a']);
  });

  test('unknown theme falls back to sage', () {
    expect(PorchPalette.byId('nope'), PorchPalette.sage);
    expect(PorchPalette.byId('blue').label, 'Pastel blue');
  });
}
