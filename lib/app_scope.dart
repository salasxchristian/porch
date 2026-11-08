import 'package:flutter/widgets.dart';

import 'cameras/camera_store.dart';
import 'ha/ha_client.dart';
import 'settings/app_settings.dart';

enum PorchPage { home, cameras, rooms, settings }

/// Hands the app's long-lived objects to every screen.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.settings,
    required this.ha,
    required this.cameras,
    required this.page,
    required super.child,
  });

  final AppSettings settings;
  final HaClient ha;
  final CameraStore cameras;

  /// The sidebar page that is showing.
  final ValueNotifier<PorchPage> page;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
