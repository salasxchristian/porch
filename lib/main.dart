import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_scope.dart';
import 'cameras/camera_store.dart';
import 'ha/ha_client.dart';
import 'settings/app_settings.dart';
import 'shell.dart';
import 'theme.dart';
import 'update/updater.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final settings = await AppSettings.open();
  final cameras = await CameraStore.open();
  final ha = HaClient();
  ha.connect(settings.haUrl, settings.haToken);
  final info = await PackageInfo.fromPlatform();
  final updater = Updater(currentVersion: info.version)..start();
  runApp(
    PorchApp(settings: settings, cameras: cameras, ha: ha, updater: updater),
  );
}

class PorchApp extends StatefulWidget {
  const PorchApp({
    super.key,
    required this.settings,
    required this.cameras,
    required this.ha,
    required this.updater,
    this.useGoogleFonts = true,
  });

  final AppSettings settings;
  final CameraStore cameras;
  final HaClient ha;
  final Updater updater;
  final bool useGoogleFonts;

  @override
  State<PorchApp> createState() => _PorchAppState();
}

class _PorchAppState extends State<PorchApp> {
  final _page = ValueNotifier(PorchPage.home);

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: widget.settings,
      ha: widget.ha,
      cameras: widget.cameras,
      page: _page,
      updater: widget.updater,
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => MaterialApp(
          title: 'Porch',
          debugShowCheckedModeBanner: false,
          themeMode: widget.settings.appearance,
          theme: buildPorchTheme(
            PorchPalette.byId(widget.settings.themeId),
            useGoogleFonts: widget.useGoogleFonts,
          ),
          darkTheme: buildPorchTheme(
            PorchPalette.byId(widget.settings.themeId, dark: true),
            useGoogleFonts: widget.useGoogleFonts,
          ),
          home: const PorchShell(),
        ),
      ),
    );
  }
}
