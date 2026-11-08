import 'camera.dart';

/// One line of a pasted camera list: a camera to add, or why it was skipped.
class PastedLine {
  const PastedLine({required this.line, this.camera, this.problem});

  /// Line number in the pasted text, starting at 1.
  final int line;
  final Camera? camera;
  final String? problem;
}

final _streamUrl = RegExp(r'''rtsps?://[^\s,"']+''', caseSensitive: false);
final _anyUrl = RegExp(r'[a-z][a-z0-9+.-]*://', caseSensitive: false);
final _edgeJunk = RegExp(r'''^[\s,;|"'\-:=]+|[\s,;|"'\-:=]+$''');

/// Reads one camera per line from pasted text. Each line holds a name and an
/// rtsp:// URL in either order, separated by a comma, tab or spaces, so rows
/// copied from a spreadsheet work too. A second URL on the line becomes the
/// full-quality stream. Without a name, the camera is named after its host.
/// Blank lines and lines starting with # are ignored, and URLs already in
/// [existing] or earlier in the list are skipped.
List<PastedLine> parseCameraList(
  String text, {
  Iterable<Camera> existing = const [],
}) {
  final seen = {for (final c in existing) _key(c.url)};
  final results = <PastedLine>[];
  final lines = text.split(RegExp(r'\r?\n'));
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i].trim();
    if (raw.isEmpty || raw.startsWith('#')) continue;
    final number = i + 1;
    final urls = _streamUrl.allMatches(raw).toList();
    if (urls.isEmpty) {
      results.add(
        PastedLine(
          line: number,
          problem: raw.toLowerCase().contains(RegExp('rtsps?://'))
              ? 'Incomplete address'
              : _anyUrl.hasMatch(raw)
              ? 'Not an rtsp:// address'
              : 'No rtsp:// address',
        ),
      );
      continue;
    }
    final url = urls.first.group(0)!;
    final fullUrl = urls.length > 1 ? urls[1].group(0) : null;
    final invalid =
        Camera.validateUrl(url) ??
        (fullUrl == null ? null : Camera.validateUrl(fullUrl));
    if (invalid != null) {
      results.add(PastedLine(line: number, problem: 'Incomplete address'));
      continue;
    }
    if (!seen.add(_key(url))) {
      results.add(PastedLine(line: number, problem: 'Already added'));
      continue;
    }
    final name = raw
        .replaceAll(_streamUrl, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(_edgeJunk, '');
    final camera = Camera(
      id: '${Camera.newId()}-$number',
      name: name.isEmpty ? _nameFromHost(url) : name,
      url: url,
      fullUrl: fullUrl,
    );
    results.add(PastedLine(line: number, camera: camera));
  }
  return results;
}

String _key(String url) => url.trim().toLowerCase();

String _nameFromHost(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return host.isEmpty ? 'Camera' : 'Camera $host';
}
