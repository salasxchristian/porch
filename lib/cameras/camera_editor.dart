import 'package:flutter/material.dart';

import '../theme.dart';
import 'camera.dart';
import 'camera_list.dart';
import 'camera_store.dart';

Future<void> addCamera(BuildContext context, CameraStore store) async {
  final camera = await showDialog<Camera>(
    context: context,
    builder: (_) => const CameraForm(),
  );
  if (camera != null) await store.add(camera);
}

Future<void> editCamera(
  BuildContext context,
  CameraStore store,
  Camera existing,
) async {
  final camera = await showDialog<Camera>(
    context: context,
    builder: (_) => CameraForm(existing: existing),
  );
  if (camera != null) await store.update(camera);
}

Future<void> pasteCameras(BuildContext context, CameraStore store) async {
  final cameras = await showDialog<List<Camera>>(
    context: context,
    builder: (_) => PasteCamerasDialog(existing: store.cameras),
  );
  if (cameras != null && cameras.isNotEmpty) await store.addAll(cameras);
}

Future<void> showManageCameras(BuildContext context, CameraStore store) {
  return showDialog<void>(
    context: context,
    builder: (_) => ManageCamerasDialog(store: store),
  );
}

class ManageCamerasDialog extends StatelessWidget {
  const ManageCamerasDialog({super.key, required this.store});

  final CameraStore store;

  Future<void> _confirmRemove(BuildContext context, Camera camera) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${camera.name}?'),
        content: const Text('It will disappear from the camera grid.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove == true) await store.remove(camera.id);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cameras'),
      content: SizedBox(
        width: 520,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final cameras = store.cameras;
            if (cameras.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No cameras yet.',
                  style: TextStyle(color: context.porch.muted),
                ),
              );
            }
            return ListView(
              shrinkWrap: true,
              children: [
                for (final camera in cameras)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.videocam_outlined),
                    title: Text(camera.name),
                    subtitle: Text(
                      camera.displayHost,
                      style: TextStyle(color: context.porch.muted),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit ${camera.name}',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => editCamera(context, store, camera),
                        ),
                        IconButton(
                          tooltip: 'Remove ${camera.name}',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmRemove(context, camera),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => pasteCameras(context, store),
          icon: const Icon(Icons.content_paste),
          label: const Text('Paste a list'),
        ),
        TextButton.icon(
          onPressed: () => addCamera(context, store),
          icon: const Icon(Icons.add),
          label: const Text('Add camera'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Add or edit one camera. Pops with the saved [Camera], or null on cancel.
class CameraForm extends StatefulWidget {
  const CameraForm({super.key, this.existing});

  final Camera? existing;

  @override
  State<CameraForm> createState() => _CameraFormState();
}

class _CameraFormState extends State<CameraForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _url = TextEditingController(text: widget.existing?.url);
  late final _fullUrl = TextEditingController(text: widget.existing?.fullUrl);

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _fullUrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final fullUrl = _fullUrl.text.trim();
    final camera = Camera(
      id: widget.existing?.id ?? Camera.newId(),
      name: _name.text.trim(),
      url: _url.text.trim(),
      fullUrl: fullUrl.isEmpty ? null : fullUrl,
    );
    Navigator.pop(context, camera);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add camera' : 'Edit camera'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Front door',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Give the camera a name'
                    : null,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'Stream URL',
                  hintText: 'rtsp://user:password@192.168.1.20:554/stream2',
                  helperText:
                      'A low-resolution substream works best in the grid.',
                ),
                validator: (v) => Camera.validateUrl(v ?? ''),
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullUrl,
                decoration: const InputDecoration(
                  labelText: 'Full-quality URL (optional)',
                  hintText: 'rtsp://user:password@192.168.1.20:554/stream1',
                  helperText: 'Used when the camera is opened full size.',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? null
                    : Camera.validateUrl(v),
                onFieldSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// Adds many cameras at once from pasted text, one per line, with a preview
/// of what will be added. Pops with the new cameras, or null on cancel.
class PasteCamerasDialog extends StatefulWidget {
  const PasteCamerasDialog({super.key, this.existing = const []});

  final List<Camera> existing;

  @override
  State<PasteCamerasDialog> createState() => _PasteCamerasDialogState();
}

class _PasteCamerasDialogState extends State<PasteCamerasDialog> {
  final _text = TextEditingController();
  List<PastedLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      setState(
        () => _lines = parseCameraList(_text.text, existing: widget.existing),
      );
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  List<Camera> get _cameras => [
    for (final l in _lines)
      if (l.camera != null) l.camera!,
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    final count = _cameras.length;
    return AlertDialog(
      title: const Text('Paste a list of cameras'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'One camera per line: a name and its rtsp:// address. Rows '
              'copied from a spreadsheet work too. A second address on a line '
              'is used when the camera is opened full size.',
              style: TextStyle(color: p.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 6,
              maxLines: 10,
              keyboardType: TextInputType.multiline,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(fontSize: 13, height: 1.5),
              decoration: const InputDecoration(
                hintText:
                    'Front door, rtsp://user:password@192.168.1.50:554/stream2\n'
                    'Driveway  rtsp://192.168.1.51/live\n'
                    'rtsp://192.168.1.52/h264',
              ),
            ),
            if (_lines.isNotEmpty) ...[
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  shrinkWrap: true,
                  children: [for (final l in _lines) _PreviewRow(line: l)],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: count == 0 ? null : () => Navigator.pop(context, _cameras),
          child: Text(
            count == 0
                ? 'Add cameras'
                : 'Add $count camera${count == 1 ? '' : 's'}',
          ),
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.line});

  final PastedLine line;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    final camera = line.camera;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            camera != null ? Icons.check_circle : Icons.remove_circle_outline,
            size: 18,
            color: camera != null ? p.accent : p.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: camera != null
                ? Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: camera.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text:
                              '   ${camera.displayHost}'
                              '${camera.fullUrl != null ? ' | full quality too' : ''}',
                          style: TextStyle(color: p.muted),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                : Text(
                    'Line ${line.line} skipped: ${line.problem}',
                    style: TextStyle(color: p.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }
}
