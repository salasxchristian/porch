import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'camera.dart';
import 'camera_editor.dart';
import 'camera_video.dart';

/// All cameras, as one big camera with the rest beside it, or as a grid.
class CamerasPage extends StatefulWidget {
  const CamerasPage({super.key});

  static int columnsFor(int count) {
    if (count <= 1) return 1;
    if (count <= 4) return 2;
    if (count <= 9) return 3;
    return 4;
  }

  static void openCamera(
    BuildContext context,
    Camera camera,
    List<Camera> all,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) =>
            CameraFocusPage(initial: camera, cameras: all),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<CamerasPage> createState() => _CamerasPageState();
}

class _CamerasPageState extends State<CamerasPage> {
  String? _featuredId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = context.porch;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.cameras, scope.settings]),
      builder: (context, _) {
        final cameras = scope.cameras.cameras;
        final layout = scope.settings.cameraLayout;
        final header = Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            PageTitle(
              'Cameras',
              overline: cameras.isEmpty
                  ? null
                  : '${cameras.length} camera${cameras.length == 1 ? '' : 's'}',
            ),
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (cameras.length > 1)
                  SegmentedButton<CameraLayout>(
                    segments: const [
                      ButtonSegment(
                        value: CameraLayout.spotlight,
                        label: Text('Spotlight'),
                      ),
                      ButtonSegment(
                        value: CameraLayout.grid,
                        label: Text('Grid'),
                      ),
                    ],
                    selected: {layout},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        scope.settings.setCameraLayout(s.first),
                    style: SegmentedButton.styleFrom(
                      backgroundColor: p.side,
                      selectedBackgroundColor: p.surface,
                      selectedForegroundColor: p.ink,
                      foregroundColor: p.ink,
                      side: BorderSide(color: p.side),
                      minimumSize: const Size(0, 44),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                OutlinedButton(
                  onPressed: () => showManageCameras(context, scope.cameras),
                  child: const Text('Manage cameras'),
                ),
              ],
            ),
          ],
        );

        if (cameras.isEmpty) {
          return PageBody(
            children: [
              header,
              const SizedBox(height: 28),
              NoticeCard(
                icon: Icons.videocam_outlined,
                title: 'No cameras yet',
                message: 'Add a camera with its RTSP address to see it here.',
                actionLabel: 'Add camera',
                onAction: () => addCamera(context, scope.cameras),
              ),
            ],
          );
        }

        final featured = cameras.firstWhere(
          (c) => c.id == _featuredId,
          orElse: () => cameras.first,
        );
        final others = cameras.where((c) => c.id != featured.id).toList();
        void open(Camera c) => CamerasPage.openCamera(context, c, cameras);

        final Widget body;
        if (layout == CameraLayout.grid || cameras.length == 1) {
          body = LayoutBuilder(
            builder: (context, box) {
              const gap = 16.0;
              final cols = CamerasPage.columnsFor(cameras.length);
              final width = (box.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final c in cameras)
                    SizedBox(
                      width: width,
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CameraTile(
                          key: ValueKey(c.id),
                          camera: c,
                          onOpen: () => open(c),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        } else {
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CameraTile(
                    key: ValueKey('featured-${featured.id}'),
                    camera: featured,
                    large: true,
                    onOpen: () => open(featured),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    for (final c in others) ...[
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CameraTile(
                          key: ValueKey(c.id),
                          camera: c,
                          tooltip: 'Show ${c.name} large',
                          onOpen: () => setState(() => _featuredId = c.id),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ],
          );
        }
        return PageBody(children: [header, const SizedBox(height: 24), body]);
      },
    );
  }
}

class CameraTile extends StatefulWidget {
  const CameraTile({
    super.key,
    required this.camera,
    required this.onOpen,
    this.large = false,
    this.tooltip,
  });

  final Camera camera;
  final VoidCallback onOpen;
  final bool large;
  final String? tooltip;

  @override
  State<CameraTile> createState() => _CameraTileState();
}

class _CameraTileState extends State<CameraTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.tooltip ?? 'Open ${widget.camera.name} full size';
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.large ? 18 : 14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CameraVideo(url: widget.camera.url, liveBadge: true),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(0, 0.3),
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x99000000)],
                ),
              ),
            ),
          ),
          Positioned(
            left: widget.large ? 20 : 14,
            right: 14,
            bottom: widget.large ? 16 : 10,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.camera.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFFFF4E4),
                      fontSize: widget.large ? 20 : 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _hovered ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    Icons.open_in_full,
                    color: Color(0xFFFFF4E4),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: label,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onOpen,
                onHover: (h) => setState(() => _hovered = h),
                hoverColor: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One camera filling the window, with the others in a side panel.
class CameraFocusPage extends StatefulWidget {
  const CameraFocusPage({
    super.key,
    required this.initial,
    required this.cameras,
  });

  final Camera initial;
  final List<Camera> cameras;

  @override
  State<CameraFocusPage> createState() => _CameraFocusPageState();
}

class _CameraFocusPageState extends State<CameraFocusPage> {
  late Camera _camera = widget.initial;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    const cream = Color(0xFFFFF4E4);
    final others = widget.cameras.where((c) => c.id != _camera.id).toList();
    Widget pill({required Widget child}) => Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraVideo(
                      key: ValueKey(_camera.id),
                      url: _camera.bestUrl,
                      fit: BoxFit.contain,
                    ),
                    Positioned(
                      left: 20,
                      top: 20,
                      child: Row(
                        children: [
                          Material(
                            color: const Color(0x99000000),
                            borderRadius: BorderRadius.circular(22),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () => Navigator.of(context).pop(),
                              child: const SizedBox(
                                height: 44,
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(14, 0, 18, 0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_back,
                                        color: cream,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'All cameras',
                                        style: TextStyle(
                                          color: cream,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          pill(
                            child: Center(
                              child: Text(
                                _camera.name,
                                style: const TextStyle(
                                  color: cream,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 18,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x8C000000),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Press Esc to go back',
                          style: TextStyle(
                            color: p.darkMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (others.isNotEmpty)
                Container(
                  width: 300,
                  color: p.dark,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'OTHER CAMERAS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: p.darkMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final c in others)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: p.darkCard,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => _camera = c),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.videocam_outlined,
                                      color: p.darkMuted,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        c.name,
                                        style: const TextStyle(
                                          color: cream,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
