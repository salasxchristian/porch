import 'package:flutter/material.dart';

/// Domains Porch knows how to show and control.
const supportedDomains = {
  'light',
  'switch',
  'fan',
  'input_boolean',
  'media_player',
  'climate',
  'lock',
  'cover',
  'scene',
};

/// Domains shown as a simple on/off switch.
const toggleDomains = {
  'light',
  'switch',
  'fan',
  'input_boolean',
  'media_player',
};

/// One Home Assistant entity with its current state.
class HaEntity {
  const HaEntity({
    required this.entityId,
    required this.state,
    this.attributes = const {},
    this.areaId,
  });

  final String entityId;
  final String state;
  final Map<String, dynamic> attributes;
  final String? areaId;

  String get domain => entityId.split('.').first;

  String get name => attributes['friendly_name'] as String? ?? entityId;

  bool get available => state != 'unavailable' && state != 'unknown';

  bool get isToggle => toggleDomains.contains(domain);

  bool get isOn => switch (domain) {
    'media_player' => !const {
      'off',
      'standby',
      'unavailable',
      'unknown',
    }.contains(state),
    'lock' => state == 'locked',
    'cover' => state == 'open' || state == 'opening',
    _ => state == 'on',
  };

  /// Lights that report anything other than on/off can be dimmed.
  bool get dimmable {
    if (domain != 'light') return false;
    final modes = attributes['supported_color_modes'];
    if (modes is List) return modes.any((m) => m != 'onoff');
    return attributes.containsKey('brightness');
  }

  /// Brightness from 1 to 100, or null when off or not dimmable.
  int? get brightnessPct {
    final b = attributes['brightness'];
    if (b is! num || b <= 0) return null;
    return (b * 100 / 255).round().clamp(1, 100);
  }

  num? get targetTemperature => attributes['temperature'] as num?;
  num? get currentTemperature => attributes['current_temperature'] as num?;
  String? get hvacAction => attributes['hvac_action'] as String?;
  List<String> get hvacModes =>
      (attributes['hvac_modes'] as List? ?? const []).cast<String>();

  String get stateLabel {
    if (!available) return 'Unavailable';
    switch (domain) {
      case 'lock':
        return switch (state) {
          'locked' => 'Locked',
          'unlocked' => 'Unlocked',
          'locking' => 'Locking',
          'unlocking' => 'Unlocking',
          'jammed' => 'Jammed',
          _ => _capitalize(state),
        };
      case 'cover':
        return _capitalize(state);
      case 'climate':
        final target = targetTemperature;
        final action = hvacAction;
        if (state == 'off') return 'Off';
        if (action == 'heating' && target != null) {
          return 'Heating to ${_deg(target)}';
        }
        if (action == 'cooling' && target != null) {
          return 'Cooling to ${_deg(target)}';
        }
        return target != null
            ? '${_capitalize(state)}, set to ${_deg(target)}'
            : _capitalize(state);
      case 'scene':
        return 'Scene';
    }
    if (!isOn) return 'Off';
    final pct = brightnessPct;
    return dimmable && pct != null ? 'On at $pct%' : 'On';
  }

  IconData get icon => switch (domain) {
    'light' => Icons.lightbulb_outline,
    'switch' => Icons.power_outlined,
    'fan' => Icons.air,
    'input_boolean' => Icons.toggle_on_outlined,
    'media_player' => Icons.tv,
    'climate' => Icons.thermostat,
    'lock' => isOn ? Icons.lock_outline : Icons.lock_open,
    'cover' => Icons.garage_outlined,
    'scene' => Icons.auto_awesome_outlined,
    _ => Icons.devices_other,
  };

  HaEntity copyWith({String? areaId}) => HaEntity(
    entityId: entityId,
    state: state,
    attributes: attributes,
    areaId: areaId ?? this.areaId,
  );

  factory HaEntity.fromState(Map<String, dynamic> json, {String? areaId}) {
    return HaEntity(
      entityId: json['entity_id'] as String,
      state: json['state'] as String? ?? 'unknown',
      attributes: (json['attributes'] as Map?)?.cast<String, dynamic>() ?? {},
      areaId: areaId,
    );
  }

  static String _deg(num t) =>
      '${t % 1 == 0 ? t.toInt() : t.toStringAsFixed(1)}°';

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

/// Short labels for the filter chips in Settings.
const domainGroups = <String, String>{
  'light': 'Lights',
  'switch': 'Switches',
  'climate': 'Climate',
  'lock': 'Locks',
  'cover': 'Doors',
  'scene': 'Scenes',
};

/// The filter group an entity falls under.
String groupOf(HaEntity e) => switch (e.domain) {
  'fan' || 'input_boolean' || 'media_player' => 'switch',
  final d => d,
};
