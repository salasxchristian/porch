import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../theme.dart';

enum _Status { connecting, live, offline }

/// Plays one RTSP stream, muted, and reconnects on its own when it drops.
class CameraVideo extends StatefulWidget {
  const CameraVideo({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.liveBadge = false,
  });

  final String url;
  final BoxFit fit;

  /// Shows a small "Live" pill in the top left once frames arrive.
  final bool liveBadge;

  @override
  State<CameraVideo> createState() => _CameraVideoState();
}

class _CameraVideoState extends State<CameraVideo> {
  static const _retryDelay = Duration(seconds: 5);
  static const _connectTimeout = Duration(seconds: 15);

  final _player = Player();
  late final _controller = VideoController(_player);
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _timer;
  _Status _status = _Status.connecting;

  @override
  void initState() {
    super.initState();
    _subscriptions.addAll([
      _player.stream.width.listen((width) {
        if (width != null && width > 0) _setLive();
      }),
      _player.stream.error.listen((_) {
        if (_status != _Status.live) _fail();
      }),
      _player.stream.completed.listen((done) {
        if (done) _fail();
      }),
    ]);
    _start();
  }

  Future<void> _start() async {
    final native = _player.platform;
    if (native is NativePlayer) {
      await native.setProperty('rtsp-transport', 'tcp');
      await native.setProperty('cache', 'no');
    }
    await _player.setVolume(0);
    await _connect();
  }

  Future<void> _connect() async {
    if (!mounted) return;
    setState(() => _status = _Status.connecting);
    _timer?.cancel();
    _timer = Timer(_connectTimeout, () {
      if (_status == _Status.connecting) _fail();
    });
    await _player.open(Media(widget.url));
  }

  void _setLive() {
    if (!mounted || _status == _Status.live) return;
    _timer?.cancel();
    setState(() => _status = _Status.live);
  }

  void _fail() {
    if (!mounted) return;
    setState(() => _status = _Status.offline);
    _timer?.cancel();
    _timer = Timer(_retryDelay, _connect);
  }

  @override
  void didUpdateWidget(CameraVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _connect();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        Video(
          controller: _controller,
          controls: NoVideoControls,
          fit: widget.fit,
        ),
        if (_status == _Status.connecting)
          _StatusOverlay(
            background: p.dark,
            color: p.darkMuted,
            icon: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: p.on),
            ),
            label: 'Connecting',
          ),
        if (_status == _Status.offline)
          _StatusOverlay(
            background: p.dark,
            color: p.darkMuted,
            icon: Icon(
              Icons.videocam_off_outlined,
              color: p.darkMuted,
              size: 26,
            ),
            label: 'Offline, retrying',
          ),
        if (widget.liveBadge && _status == _Status.live)
          Positioned(top: 12, left: 12, child: LiveBadge(color: p.on)),
      ],
    );
  }
}

class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0x8C000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text(
            'Live',
            style: TextStyle(
              color: Color(0xFFFFF4E4),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusOverlay extends StatelessWidget {
  const _StatusOverlay({
    required this.icon,
    required this.label,
    required this.background,
    required this.color,
  });

  final Widget icon;
  final String label;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Small tiles keep just the icon, above the camera name.
    return ColoredBox(
      color: background,
      child: LayoutBuilder(
        builder: (context, box) => Align(
          alignment: const Alignment(0, -0.2),
          child: Tooltip(
            message: label,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                if (box.maxHeight >= 160) ...[
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
