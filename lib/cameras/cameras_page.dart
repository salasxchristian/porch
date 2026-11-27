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
              var cols = CamerasPage.columnsFor(cameras.length);
              if (isPortrait(context) && cols > 2) cols = 2;
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
          final featuredTile = AspectRatio(
            aspectRatio: 16 / 9,
            child: CameraTile(
              key: ValueKey('featured-${featured.id}'),
              camera: featured,
              large: true,
              onOpen: () => open(featured),
            ),
          );
          Widget otherTile(Camera c) => AspectRatio(
            aspectRatio: 16 / 9,
            child: CameraTile(
              key: ValueKey(c.id),
              camera: c,
              tooltip: 'Show ${c.name} large',
              onOpen: () => setState(() => _featuredId = c.id),
            ),
          );
          if (isPortrait(context)) {
            // Portrait: the big camera across the top, the rest two by two.
            body = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                featuredTile,
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, box) {
                    const gap = 12.0;
                    final width = (box.maxWidth - gap) / 2;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final c in others)
                          SizedBox(width: width, child: otherTile(c)),
                      ],
                    );
                  },
                ),
              ],
            );
          } else {
            body = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: featuredTile),
                const SizedBox(width: 20),
                SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      for (final c in others) ...[
                        otherTile(c),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }
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

  /// Keeps the player alive when hiding the panel moves the video to a new
  /// parent, so the stream doesn't reconnect.
  final _videoKey = GlobalKey();

  static const _cream = Color(0xFFFFF4E4);

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => _build(context, settings),
    );
  }

  Widget _build(BuildContext context, AppSettings settings) {
    final p = context.porch;
    final portrait = isPortrait(context);
    final others = widget.cameras.where((c) => c.id != _camera.id).toList();
    final canHide = others.isNotEmpty;
    final panel = canHide && !settings.cameraPanelHidden;
    void togglePanel() {
      if (canHide) settings.setCameraPanelHidden(panel);
    }

    Widget pillButton({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      String? tooltip,
    }) {
      final button = Material(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 18, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: _cream, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: _cream,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return tooltip == null
          ? button
          : Tooltip(message: tooltip, child: button);
    }

    final video = Stack(
      key: _videoKey,
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
          right: 20,
          child: Row(
            children: [
              pillButton(
                icon: Icons.arrow_back,
                label: 'All cameras',
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0x99000000),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        _camera.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _cream,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (canHide) ...[
                const SizedBox(width: 12),
                Semantics(
                  expanded: panel,
                  child: pillButton(
                    icon: portrait
                        ? (panel
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up)
                        : (panel ? Icons.chevron_right : Icons.chevron_left),
                    label: panel ? 'Hide cameras' : 'Show cameras',
                    tooltip: panel
                        ? 'Hide the cameras panel (C)'
                        : 'Show the cameras panel (C)',
                    onTap: togglePanel,
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: 20,
          bottom: 18,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x8C000000),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              canHide
                  ? 'Esc to go back | C to ${panel ? 'hide' : 'show'} cameras'
                  : 'Press Esc to go back',
              style: TextStyle(
                color: p.darkMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );

    final heading = Text(
      'OTHER CAMERAS',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: p.darkMuted,
      ),
    );

    final Widget body;
    if (portrait) {
      // Video across the top, the other cameras as tiles underneath.
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (panel) ...[
            AspectRatio(aspectRatio: 16 / 9, child: video),
            Expanded(
              child: Container(
                color: p.dark,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading,
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, box) {
                          const gap = 16.0;
                          final width = (box.maxWidth - gap) / 2;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final c in others)
                                SizedBox(
                                  width: width,
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: CameraTile(
                                      key: ValueKey('panel-${c.id}'),
                                      camera: c,
                                      tooltip: 'Switch to ${c.name}',
                                      onOpen: () => setState(() => _camera = c),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else
            Expanded(child: video),
        ],
      );
    } else {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: video),
          if (panel)
            Container(
              width: 300,
              color: p.dark,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
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
                                        color: _cream,
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
            ),
        ],
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.keyC): togglePanel,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(backgroundColor: Colors.black, body: body),
      ),
    );
  }
}
