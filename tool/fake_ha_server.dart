import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A small stand-in for Home Assistant's WebSocket API with a sample house.
/// Used by tests and by `dart run tool/fake_ha.dart` for local development.
class FakeHaServer {
  FakeHaServer({this.token = 'dev'});

  final String token;
  HttpServer? _server;
  final _subscriptions = <WebSocket, int>{};

  int get port => _server!.port;

  final areas = [
    {'area_id': 'living_room', 'name': 'Living room'},
    {'area_id': 'kitchen', 'name': 'Kitchen'},
    {'area_id': 'bedroom', 'name': 'Bedroom'},
    {'area_id': 'office', 'name': 'Office'},
    {'area_id': 'outside', 'name': 'Outside'},
    {'area_id': 'hallway', 'name': 'Hallway'},
    {'area_id': 'entry', 'name': 'Entry'},
    {'area_id': 'garage', 'name': 'Garage'},
  ];

  final devices = [
    {'id': 'dev_lamp', 'area_id': 'living_room'},
  ];

  /// entity_id -> registry entry. The floor lamp gets its area from its device.
  final registry = <String, Map<String, dynamic>>{
    'light.floor_lamp': {'device_id': 'dev_lamp'},
    'light.living_room_ceiling': {'area_id': 'living_room'},
    'switch.tv_power': {'area_id': 'living_room'},
    'light.kitchen_ceiling': {'area_id': 'kitchen'},
    'light.island_pendants': {'area_id': 'kitchen'},
    'light.bedside_lamp': {'area_id': 'bedroom'},
    'fan.bedroom_fan': {'area_id': 'bedroom'},
    'switch.space_heater': {'area_id': 'office'},
    'light.porch': {'area_id': 'outside'},
    'light.patio': {'area_id': 'outside'},
    'climate.thermostat': {'area_id': 'hallway'},
    'lock.front_door': {'area_id': 'entry'},
    'cover.garage_door': {'area_id': 'garage'},
    'switch.router_led': {'entity_category': 'config'},
    'media_player.living_room_tv': {'area_id': 'living_room'},
    'cover.bedroom_blinds': {'area_id': 'bedroom'},
  };

  final states = <String, Map<String, dynamic>>{
    'light.floor_lamp': _plain('Floor lamp', 'on', {
      'supported_color_modes': ['color_temp', 'hs'],
      'color_mode': 'color_temp',
      'brightness': 153,
      'color_temp_kelvin': 2700,
      'min_color_temp_kelvin': 2000,
      'max_color_temp_kelvin': 6500,
      'hs_color': [30.0, 50.0],
      'effect_list': ['None', 'Candle', 'Rainbow'],
      'effect': 'None',
    }),
    'light.living_room_ceiling': _light('Ceiling light', on: false),
    'switch.tv_power': _plain('TV', 'off'),
    'light.kitchen_ceiling': _light('Kitchen ceiling', on: false),
    'light.island_pendants': _light(
      'Island pendants',
      on: true,
      brightness: 102,
    ),
    'light.bedside_lamp': _light('Bedside lamp', on: false),
    'fan.bedroom_fan': _plain('Bedroom fan', 'off', {
      'percentage': 0,
      'percentage_step': 25,
      'preset_modes': ['breeze', 'sleep'],
      'oscillating': false,
    }),
    'media_player.living_room_tv': _plain('Living room TV', 'playing', {
      'media_title': 'Nature Documentary',
      'media_artist': 'Episode 3',
      'volume_level': 0.3,
      'is_volume_muted': false,
      'source_list': ['TV', 'HDMI 1', 'Apple TV'],
      'source': 'Apple TV',
    }),
    'cover.bedroom_blinds': _plain('Bedroom blinds', 'open', {
      'current_position': 60,
    }),
    'switch.space_heater': _plain('Space heater', 'off'),
    'light.porch': _light('Porch light', on: true, brightness: 255),
    'light.patio': _light('Patio lights', on: false, dimmable: false),
    'climate.thermostat': _plain('Thermostat', 'heat', {
      'temperature': 70,
      'current_temperature': 68,
      'hvac_action': 'heating',
      'hvac_modes': ['heat', 'cool', 'heat_cool', 'off'],
      'target_temp_step': 1,
      'min_temp': 50,
      'max_temp': 90,
      'current_humidity': 41,
      'fan_modes': ['auto', 'on'],
      'fan_mode': 'auto',
      'preset_modes': ['home', 'away', 'sleep'],
      'preset_mode': 'home',
    }),
    'lock.front_door': _plain('Front door', 'locked'),
    'cover.garage_door': _plain('Garage door', 'closed'),
    'scene.movie_night': _plain('Movie night', 'unknown'),
    'scene.good_morning': _plain('Good morning', 'unknown'),
    'switch.dehumidifier': _plain('Dehumidifier', 'off'),
    'switch.router_led': _plain('Router LED', 'on'),
    'sensor.outside_temperature': _plain('Outside temperature', '61'),
  };

  static Map<String, dynamic> _plain(
    String name,
    String state, [
    Map<String, dynamic> attrs = const {},
  ]) => {
    'state': state,
    'attributes': {'friendly_name': name, ...attrs},
  };

  static Map<String, dynamic> _light(
    String name, {
    required bool on,
    int? brightness,
    bool dimmable = true,
  }) => _plain(name, on ? 'on' : 'off', {
    'supported_color_modes': [dimmable ? 'brightness' : 'onoff'],
    if (on && dimmable) 'brightness': brightness ?? 255,
  });

  Future<void> start({int port = 0}) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen((request) async {
      if (request.uri.path != '/api/websocket') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      final ws = await WebSocketTransformer.upgrade(request);
      _serve(ws);
    });
  }

  Future<void> stop() async {
    for (final ws in _subscriptions.keys.toList()) {
      await ws.close();
    }
    await _server?.close(force: true);
  }

  void _serve(WebSocket ws) {
    void send(Map<String, dynamic> msg) => ws.add(jsonEncode(msg));
    void result(int id, Object? value) =>
        send({'id': id, 'type': 'result', 'success': true, 'result': value});
    var authed = false;
    send({'type': 'auth_required'});
    ws.listen((raw) {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      if (!authed) {
        if (msg['type'] == 'auth' && msg['access_token'] == token) {
          authed = true;
          send({'type': 'auth_ok'});
        } else {
          send({'type': 'auth_invalid', 'message': 'Invalid access token'});
          ws.close();
        }
        return;
      }
      final id = msg['id'] as int;
      switch (msg['type']) {
        case 'get_states':
          result(id, [
            for (final e in states.entries) {'entity_id': e.key, ...e.value},
          ]);
        case 'config/area_registry/list':
          result(id, areas);
        case 'config/device_registry/list':
          result(id, devices);
        case 'config/entity_registry/list':
          result(id, [
            for (final e in registry.entries) {'entity_id': e.key, ...e.value},
          ]);
        case 'subscribe_events':
          _subscriptions[ws] = id;
          result(id, null);
        case 'call_service':
          final target = (msg['target'] as Map)['entity_id'] as String;
          _apply(
            msg['domain'] as String,
            msg['service'] as String,
            target,
            (msg['service_data'] as Map?)?.cast<String, dynamic>() ?? {},
          );
          result(id, {
            'context': {'id': 'fake'},
          });
        default:
          send({
            'id': id,
            'type': 'result',
            'success': false,
            'error': {'code': 'unknown_command', 'message': 'Unknown command'},
          });
      }
    }, onDone: () => _subscriptions.remove(ws));
  }

  void _apply(
    String domain,
    String service,
    String id,
    Map<String, dynamic> data,
  ) {
    final current = states[id];
    if (current == null || domain == 'scene') return;
    var state = current['state'] as String;
    final attrs = {...(current['attributes'] as Map).cast<String, dynamic>()};
    switch (service) {
      case 'turn_on':
        state = domain == 'media_player' ? 'idle' : 'on';
        if (domain == 'light') {
          final pct = data['brightness_pct'] as num?;
          if (pct != null) {
            attrs['brightness'] = (pct * 255 / 100).round();
          } else {
            attrs['brightness'] ??= 255;
          }
          if (data['color_temp_kelvin'] != null) {
            attrs['color_temp_kelvin'] = data['color_temp_kelvin'];
            attrs['color_mode'] = 'color_temp';
          }
          if (data['hs_color'] != null) {
            attrs['hs_color'] = data['hs_color'];
            attrs['color_mode'] = 'hs';
          }
          if (data['effect'] != null) attrs['effect'] = data['effect'];
        }
        if (domain == 'fan' && (attrs['percentage'] ?? 0) == 0) {
          attrs['percentage'] = 50;
        }
      case 'turn_off':
        state = 'off';
        attrs.remove('brightness');
        if (domain == 'fan') attrs['percentage'] = 0;
      case 'set_percentage':
        final pct = data['percentage'] as num;
        attrs['percentage'] = pct;
        state = pct > 0 ? 'on' : 'off';
      case 'oscillate':
        attrs['oscillating'] = data['oscillating'];
      case 'set_preset_mode':
        attrs['preset_mode'] = data['preset_mode'];
      case 'set_fan_mode':
        attrs['fan_mode'] = data['fan_mode'];
      case 'volume_set':
        attrs['volume_level'] = data['volume_level'];
      case 'volume_mute':
        attrs['is_volume_muted'] = data['is_volume_muted'];
      case 'select_source':
        attrs['source'] = data['source'];
      case 'media_play_pause':
        state = state == 'playing' ? 'paused' : 'playing';
      case 'stop_cover':
        break;
      case 'set_cover_position':
        attrs['current_position'] = data['position'];
        state = (data['position'] as num) > 0 ? 'open' : 'closed';
      case 'lock':
        state = 'locked';
      case 'unlock':
        state = 'unlocked';
      case 'open_cover':
        state = 'open';
        if (attrs.containsKey('current_position')) {
          attrs['current_position'] = 100;
        }
      case 'close_cover':
        state = 'closed';
        if (attrs.containsKey('current_position')) {
          attrs['current_position'] = 0;
        }
      case 'set_temperature':
        for (final key in [
          'temperature',
          'target_temp_low',
          'target_temp_high',
        ]) {
          if (data.containsKey(key)) attrs[key] = data[key];
        }
      case 'set_hvac_mode':
        state = data['hvac_mode'] as String;
        attrs['hvac_action'] = state == 'off' ? 'off' : 'idle';
        if (state == 'heat_cool') {
          attrs['target_temp_low'] = attrs['temperature'] ?? 68;
          attrs['target_temp_high'] = 76;
          attrs.remove('temperature');
        } else if (!attrs.containsKey('temperature')) {
          attrs['temperature'] = attrs.remove('target_temp_low') ?? 70;
          attrs.remove('target_temp_high');
        }
    }
    setState(id, state, attrs);
  }

  /// Changes an entity and tells every subscribed client.
  void setState(String id, String state, [Map<String, dynamic>? attributes]) {
    final next = {
      'state': state,
      'attributes': attributes ?? states[id]!['attributes'],
    };
    states[id] = next;
    for (final MapEntry(key: ws, value: subId) in _subscriptions.entries) {
      ws.add(
        jsonEncode({
          'id': subId,
          'type': 'event',
          'event': {
            'event_type': 'state_changed',
            'data': {
              'entity_id': id,
              'new_state': {'entity_id': id, ...next},
            },
          },
        }),
      );
    }
  }
}
