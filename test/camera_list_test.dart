import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:porch/cameras/camera.dart';
import 'package:porch/cameras/camera_editor.dart';
import 'package:porch/cameras/camera_list.dart';
import 'package:porch/theme.dart';

void main() {
  test('reads names and URLs in the common formats', () {
    final lines = parseCameraList('''
Front door, rtsp://user:p%40ss@192.168.1.50:554/stream1
Driveway rtsp://192.168.1.51/live
Back yard\trtsp://192.168.1.53/sub\trtsp://192.168.1.53/main
"Side gate",rtsp://192.168.1.54/s
rtsp://192.168.1.55/cam Garage
rtsp://192.168.1.52/h264

# comments and blank lines are ignored
''');
    final cameras = [for (final l in lines) l.camera!];
    expect(cameras.map((c) => c.name), [
      'Front door',
      'Driveway',
      'Back yard',
      'Side gate',
      'Garage',
      'Camera 192.168.1.52',
    ]);
    expect(cameras[0].url, 'rtsp://user:p%40ss@192.168.1.50:554/stream1');
    expect(cameras[2].url, 'rtsp://192.168.1.53/sub');
    expect(cameras[2].fullUrl, 'rtsp://192.168.1.53/main');
    expect(cameras[1].fullUrl, isNull);
    expect(cameras.map((c) => c.id).toSet(), hasLength(6));
  });

  test('explains skipped lines and leaves out duplicates', () {
    final lines = parseCameraList(
      '''
name,url
Kitchen, http://192.168.1.60/video
Porch, rtsp://192.168.1.50/stream1
Porch again, rtsp://192.168.1.61/a
Twice, RTSP://192.168.1.61/A
Broken, rtsp://
''',
      existing: const [
        Camera(id: '1', name: 'Porch', url: 'rtsp://192.168.1.50/stream1'),
      ],
    );
    expect(
      [for (final l in lines) (l.line, l.camera?.name, l.problem)],
      [
        (1, null, 'No rtsp:// address'),
        (2, null, 'Not an rtsp:// address'),
        (3, null, 'Already added'),
        (4, 'Porch again', null),
        (5, null, 'Already added'),
        (6, null, 'Incomplete address'),
      ],
    );
  });

  testWidgets('paste dialog previews lines and returns the cameras', (
    tester,
  ) async {
    List<Camera>? added;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPorchTheme(PorchPalette.sage, useGoogleFonts: false),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => added = await showDialog<List<Camera>>(
              context: context,
              builder: (_) => const PasteCamerasDialog(),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final addButton = find.widgetWithText(FilledButton, 'Add cameras');
    expect(tester.widget<FilledButton>(addButton).onPressed, isNull);

    await tester.enterText(
      find.byType(TextField),
      'Front door, rtsp://user:secret@10.0.0.5/sub\nKitchen, http://10.0.0.9/',
    );
    await tester.pump();
    expect(find.text('Line 2 skipped: Not an rtsp:// address'), findsOneWidget);
    // The preview shows the host only, never the password.
    expect(find.textContaining('10.0.0.5', findRichText: true), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.textContaining('secret', findRichText: true),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Add 1 camera'));
    await tester.pumpAndSettle();
    expect(added!.single.name, 'Front door');
    expect(added!.single.url, 'rtsp://user:secret@10.0.0.5/sub');
  });
}
