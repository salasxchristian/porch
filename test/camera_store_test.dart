import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:porch/cameras/camera.dart';
import 'package:porch/cameras/camera_store.dart';
import 'package:porch/cameras/cameras_page.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('porch_store'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('cameras survive a save and reload', () async {
    final file = File('${tmp.path}/cameras.json');
    final store = CameraStore(file);
    await store.add(
      const Camera(id: '1', name: 'Front door', url: 'rtsp://10.0.0.5/sub'),
    );
    await store.add(
      const Camera(
        id: '2',
        name: 'Driveway',
        url: 'rtsp://10.0.0.6/sub',
        fullUrl: 'rtsp://10.0.0.6/main',
      ),
    );
    await store.update(store.cameras.first.copyWith(name: 'Porch'));
    await store.remove('3');

    final reloaded = CameraStore(file);
    await reloaded.load();

    expect(reloaded.cameras.map((c) => c.name), ['Porch', 'Driveway']);
    expect(reloaded.cameras.last.bestUrl, 'rtsp://10.0.0.6/main');
    expect(reloaded.cameras.first.bestUrl, 'rtsp://10.0.0.5/sub');
  });

  test('a corrupt file loads as no cameras', () async {
    final file = File('${tmp.path}/cameras.json')
      ..writeAsStringSync('{not json');
    final store = CameraStore(file);
    await store.load();
    expect(store.cameras, isEmpty);
  });

  test('display host hides credentials', () {
    const camera = Camera(
      id: '1',
      name: 'Gate',
      url: 'rtsp://admin:secret@10.0.0.7:554/s',
    );
    expect(camera.displayHost, '10.0.0.7:554');
  });

  test('URL validation', () {
    expect(Camera.validateUrl('rtsp://10.0.0.5/s'), isNull);
    expect(Camera.validateUrl('rtsps://cam.local/s'), isNull);
    expect(Camera.validateUrl('http://10.0.0.5/s'), isNotNull);
    expect(Camera.validateUrl('not a url'), isNotNull);
  });

  test('grid columns grow with camera count', () {
    expect([1, 2, 4, 5, 9, 10].map(CamerasPage.columnsFor), [1, 2, 2, 3, 3, 4]);
  });
}
