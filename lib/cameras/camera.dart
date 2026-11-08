/// One RTSP camera. URLs may carry credentials, so they stay on this device.
class Camera {
  const Camera({
    required this.id,
    required this.name,
    required this.url,
    this.fullUrl,
  });

  final String id;
  final String name;

  /// Stream shown in the grid. A low-resolution substream works best.
  final String url;

  /// Optional higher-quality stream used when the camera is opened full size.
  final String? fullUrl;

  String get bestUrl => fullUrl ?? url;

  /// Host and port only, safe to show without leaking credentials.
  String get displayHost {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return '';
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }

  Camera copyWith({String? name, String? url, String? Function()? fullUrl}) {
    return Camera(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      fullUrl: fullUrl != null ? fullUrl() : this.fullUrl,
    );
  }

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      fullUrl: json['fullUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    if (fullUrl != null) 'fullUrl': fullUrl,
  };

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Returns an error message, or null when [value] is a usable stream URL.
  static String? validateUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty) return 'Enter a full stream URL';
    if (uri.scheme != 'rtsp' && uri.scheme != 'rtsps') {
      return 'URL must start with rtsp:// or rtsps://';
    }
    return null;
  }
}
