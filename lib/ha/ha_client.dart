import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'ha_entity.dart';

enum HaStatus { notConfigured, connecting, connected, authFailed, unreachable }

typedef ChannelConnector = WebSocketChannel Function(Uri uri);

/// Talks to Home Assistant over its WebSocket API: states, areas, live
/// updates and service calls. Reconnects on its own after a drop.
class HaClient extends ChangeNotifier {
  HaClient({
    ChannelConnector? connector,
    this.retryDelay = const Duration(seconds: 5),
  }) : _connector = connector ?? WebSocketChannel.connect;

  final ChannelConnector _connector;
  final Duration retryDelay;

  HaStatus status = HaStatus.notConfigured;
  Map<String, HaEntity> entities = {};
  Map<String, String> areaNames = {};

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  String _url = '';
  String _token = '';
  int _nextId = 1;
  final _pending = <int, Completer<dynamic>>{};

  /// Registry facts that states don't carry.
  final _registryArea = <String, String?>{};
  final _hiddenIds = <String>{};

  /// Entities Porch can show, sorted by area then name.
  List<HaEntity> get supported {
    final list = entities.values
        .where(
          (e) =>
              supportedDomains.contains(e.domain) &&
              !_hiddenIds.contains(e.entityId),
        )
        .toList();
    list.sort((a, b) {
      final aOther = a.areaId == null || !areaNames.containsKey(a.areaId);
      final bOther = b.areaId == null || !areaNames.containsKey(b.areaId);
      if (aOther != bOther) return aOther ? 1 : -1;
      final area = areaName(a).compareTo(areaName(b));
      return area != 0 ? area : a.name.compareTo(b.name);
    });
    return list;
  }

  String areaName(HaEntity e) => areaNames[e.areaId] ?? 'Other';

  /// Turns `http(s)://host:port` into the WebSocket endpoint.
  static Uri websocketUri(String baseUrl) {
    final base = Uri.parse(baseUrl.trim());
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '${base.path.replaceAll(RegExp(r'/+$'), '')}/api/websocket',
    );
  }

  Future<void> connect(String url, String token) async {
    _close();
    _url = url;
    _token = token;
    if (url.isEmpty || token.isEmpty) {
      _setStatus(HaStatus.notConfigured);
      return;
    }
    await _open();
  }

  Future<void> _open() async {
    _setStatus(HaStatus.connecting);
    final WebSocketChannel channel;
    try {
      channel = _connector(websocketUri(_url));
      _channel = channel;
      await channel.ready;
    } catch (_) {
      _channel = null;
      _scheduleRetry();
      return;
    }
    if (_channel != channel) return; // Replaced by a newer connect().
    _sub = channel.stream.listen(
      _onMessage,
      onDone: _onClosed,
      onError: (_) => _onClosed(),
    );
  }

  void _onMessage(dynamic raw) {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    switch (msg['type']) {
      case 'auth_required':
        _channel?.sink.add(
          jsonEncode({'type': 'auth', 'access_token': _token}),
        );
      case 'auth_ok':
        _loadAll();
      case 'auth_invalid':
        final channel = _channel;
        _close();
        channel?.sink.close();
        _setStatus(HaStatus.authFailed);
      case 'result':
        final completer = _pending.remove(msg['id']);
        if (completer == null) return;
        if (msg['success'] == true) {
          completer.complete(msg['result']);
        } else {
          completer.completeError(
            StateError(
              (msg['error'] as Map?)?['message'] as String? ?? 'failed',
            ),
          );
        }
      case 'event':
        _onEvent(msg['event'] as Map<String, dynamic>);
    }
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _send({'type': 'get_states'}),
        _send({'type': 'config/area_registry/list'}),
        _send({'type': 'config/entity_registry/list'}),
        _send({'type': 'config/device_registry/list'}),
      ]);
      areaNames = {
        for (final a in (results[1] as List).cast<Map<String, dynamic>>())
          a['area_id'] as String: a['name'] as String,
      };
      final deviceArea = {
        for (final d in (results[3] as List).cast<Map<String, dynamic>>())
          d['id'] as String: d['area_id'] as String?,
      };
      _registryArea.clear();
      _hiddenIds.clear();
      for (final r in (results[2] as List).cast<Map<String, dynamic>>()) {
        final id = r['entity_id'] as String;
        _registryArea[id] =
            r['area_id'] as String? ?? deviceArea[r['device_id']];
        if (r['hidden_by'] != null ||
            r['disabled_by'] != null ||
            r['entity_category'] != null) {
          _hiddenIds.add(id);
        }
      }
      entities = {
        for (final s in (results[0] as List).cast<Map<String, dynamic>>())
          s['entity_id'] as String: HaEntity.fromState(
            s,
            areaId: _registryArea[s['entity_id']],
          ),
      };
      await _send({'type': 'subscribe_events', 'event_type': 'state_changed'});
      _setStatus(HaStatus.connected);
    } catch (_) {
      _onClosed();
    }
  }

  void _onEvent(Map<String, dynamic> event) {
    if (event['event_type'] != 'state_changed') return;
    final data = event['data'] as Map<String, dynamic>;
    final id = data['entity_id'] as String;
    final newState = data['new_state'] as Map<String, dynamic>?;
    entities = {...entities};
    if (newState == null) {
      entities.remove(id);
    } else {
      entities[id] = HaEntity.fromState(newState, areaId: _registryArea[id]);
    }
    notifyListeners();
  }

  Future<dynamic> _send(Map<String, dynamic> msg) {
    final channel = _channel;
    if (channel == null) return Future.error(StateError('not connected'));
    final id = _nextId++;
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    channel.sink.add(jsonEncode({...msg, 'id': id}));
    return completer.future;
  }

  Future<void> callService(
    String domain,
    String service,
    String entityId, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (status != HaStatus.connected) return;
    try {
      await _send({
        'type': 'call_service',
        'domain': domain,
        'service': service,
        'service_data': data,
        'target': {'entity_id': entityId},
      });
    } catch (e) {
      debugPrint('Home Assistant $domain.$service failed: $e');
    }
  }

  /// The on/off service for toggles, lock/unlock and open/close.
  Future<void> setOn(HaEntity e, bool on) {
    final service = switch (e.domain) {
      'lock' => on ? 'lock' : 'unlock',
      'cover' => on ? 'open_cover' : 'close_cover',
      'scene' => 'turn_on',
      _ => on ? 'turn_on' : 'turn_off',
    };
    return callService(e.domain, service, e.entityId);
  }

  Future<void> setBrightness(HaEntity e, int pct) =>
      callService('light', 'turn_on', e.entityId, {'brightness_pct': pct});

  Future<void> setTemperature(HaEntity e, num temperature) => callService(
    'climate',
    'set_temperature',
    e.entityId,
    {'temperature': temperature},
  );

  Future<void> setHvacMode(HaEntity e, String mode) =>
      callService('climate', 'set_hvac_mode', e.entityId, {'hvac_mode': mode});

  void _onClosed() {
    if (_channel == null) return;
    _close();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _setStatus(HaStatus.unreachable);
    _retry?.cancel();
    _retry = Timer(retryDelay, () {
      if (status == HaStatus.unreachable) _open();
    });
  }

  void _close() {
    _retry?.cancel();
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    for (final c in _pending.values) {
      c.completeError(StateError('connection closed'));
    }
    _pending.clear();
  }

  void _setStatus(HaStatus s) {
    status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }
}
