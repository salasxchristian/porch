import 'dart:async';

import 'package:flutter/material.dart';

import '../ha/ha_client.dart';
import '../ha/ha_entity.dart';
import '../theme.dart';
import 'common.dart';

/// Opens the full controls for one Home Assistant entity.
Future<void> showDeviceDetails(
  BuildContext context,
  HaClient ha,
  String entityId,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => DeviceDetails(ha: ha, entityId: entityId),
  );
}

/// Every control Porch offers for one entity. Follows live state changes.
class DeviceDetails extends StatelessWidget {
  const DeviceDetails({super.key, required this.ha, required this.entityId});

  final HaClient ha;
  final String entityId;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListenableBuilder(
          listenable: ha,
          builder: (context, _) {
            final e = ha.entities[entityId];
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 24),
              child: e == null
                  ? _Missing(onClose: () => Navigator.pop(context))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(entity: e, ha: ha),
                        ..._controlsFor(e, ha),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  static List<Widget> _controlsFor(HaEntity e, HaClient ha) {
    if (!e.available) return const [];
    final controls = switch (e.domain) {
      'light' => _lightControls(e, ha),
      'climate' => _climateControls(e, ha),
      'fan' => _fanControls(e, ha),
      'media_player' => _mediaControls(e, ha),
      'cover' => _coverControls(e, ha),
      'lock' => _lockControls(e, ha),
      _ => const <Widget>[],
    };
    return [
      for (final c in controls) ...[const SizedBox(height: 24), c],
    ];
  }

  static List<Widget> _lightControls(HaEntity e, HaClient ha) {
    void turnOn(Map<String, dynamic> data) =>
        ha.callService('light', 'turn_on', e.entityId, data);
    final kelvinMin = e.attributes['min_color_temp_kelvin'] as num? ?? 2000;
    final kelvinMax = e.attributes['max_color_temp_kelvin'] as num? ?? 6500;
    final kelvin = e.attributes['color_temp_kelvin'] as num?;
    final effects = e.listAttr('effect_list');
    return [
      if (e.dimmable)
        _Labeled(
          'Brightness',
          child: CommitSlider(
            value: (e.brightnessPct ?? 0).toDouble(),
            min: 0,
            max: 100,
            label: (v) => '${v.round()}%',
            semanticLabel: 'Brightness',
            onCommit: (v) => v.round() == 0
                ? ha.setOn(e, false)
                : ha.setBrightness(e, v.round()),
          ),
        ),
      if (e.supportsColorTemp)
        _Labeled(
          'White temperature',
          trailing: const _Ends('Warm', 'Cool'),
          child: CommitSlider(
            value: (kelvin ?? (kelvinMin + kelvinMax) / 2).toDouble(),
            min: kelvinMin.toDouble(),
            max: kelvinMax.toDouble(),
            label: (v) => '${(v / 50).round() * 50}K',
            semanticLabel: 'White temperature',
            onCommit: (v) => turnOn({'color_temp_kelvin': v.round()}),
          ),
        ),
      if (e.supportsColor)
        _Labeled(
          'Color',
          child: _ColorSwatches(
            selected: e.attributes['color_mode'] == 'color_temp'
                ? null
                : e.attributes['hs_color'] as List?,
            onPick: (hue, sat) => turnOn({
              'hs_color': [hue, sat],
            }),
          ),
        ),
      if (effects.isNotEmpty)
        _Labeled(
          'Effect',
          child: _Choices(
            options: {for (final f in effects) f: f},
            selected: e.attributes['effect'] as String?,
            onSelect: (f) => turnOn({'effect': f}),
          ),
        ),
    ];
  }

  static List<Widget> _climateControls(HaEntity e, HaClient ha) {
    void call(String service, Map<String, dynamic> data) =>
        ha.callService('climate', service, e.entityId, data);
    final low = e.attributes['target_temp_low'] as num?;
    final high = e.attributes['target_temp_high'] as num?;
    final target = e.targetTemperature;
    final humidity = e.attributes['current_humidity'] as num?;
    final current = e.currentTemperature;
    return [
      if (target != null)
        _TempStepper(
          entity: e,
          label: 'Set to',
          value: target,
          onSet: (t) => call('set_temperature', {'temperature': t}),
        )
      else if (low != null && high != null)
        Row(
          children: [
            Expanded(
              child: _TempStepper(
                entity: e,
                label: 'Heat to',
                value: low,
                compact: true,
                onSet: (t) => call('set_temperature', {
                  'target_temp_low': t,
                  'target_temp_high': high,
                }),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TempStepper(
                entity: e,
                label: 'Cool to',
                value: high,
                compact: true,
                onSet: (t) => call('set_temperature', {
                  'target_temp_low': low,
                  'target_temp_high': t,
                }),
              ),
            ),
          ],
        ),
      if (current != null || humidity != null)
        _InsideNow(temperature: current, humidity: humidity),
      if (e.hvacModes.isNotEmpty)
        _Labeled(
          'Mode',
          child: _Choices(
            options: {for (final m in e.hvacModes) m: HaEntity.hvacLabel(m)},
            selected: e.state,
            onSelect: (m) => ha.setHvacMode(e, m),
          ),
        ),
      if (e.listAttr('fan_modes').isNotEmpty)
        _Labeled(
          'Fan',
          child: _Choices(
            options: {for (final m in e.listAttr('fan_modes')) m: _title(m)},
            selected: e.attributes['fan_mode'] as String?,
            onSelect: (m) => call('set_fan_mode', {'fan_mode': m}),
          ),
        ),
      if (e.listAttr('preset_modes').isNotEmpty)
        _Labeled(
          'Preset',
          child: _Choices(
            options: {for (final m in e.listAttr('preset_modes')) m: _title(m)},
            selected: e.attributes['preset_mode'] as String?,
            onSelect: (m) => call('set_preset_mode', {'preset_mode': m}),
          ),
        ),
    ];
  }

  static List<Widget> _fanControls(HaEntity e, HaClient ha) {
    void call(String service, Map<String, dynamic> data) =>
        ha.callService('fan', service, e.entityId, data);
    final percentage = e.attributes['percentage'] as num?;
    final step = e.attributes['percentage_step'] as num?;
    final oscillating = e.attributes['oscillating'] as bool?;
    return [
      if (e.attributes.containsKey('percentage'))
        _Labeled(
          'Speed',
          child: CommitSlider(
            value: (e.isOn ? percentage ?? 0 : 0).toDouble(),
            min: 0,
            max: 100,
            divisions: step != null && step > 0 ? (100 / step).round() : null,
            label: (v) => '${v.round()}%',
            semanticLabel: 'Speed',
            onCommit: (v) => v.round() == 0
                ? ha.setOn(e, false)
                : call('set_percentage', {'percentage': v.round()}),
          ),
        ),
      if (e.listAttr('preset_modes').isNotEmpty)
        _Labeled(
          'Preset',
          child: _Choices(
            options: {for (final m in e.listAttr('preset_modes')) m: _title(m)},
            selected: e.attributes['preset_mode'] as String?,
            onSelect: (m) => call('set_preset_mode', {'preset_mode': m}),
          ),
        ),
      if (oscillating != null)
        _SwitchRow(
          label: 'Oscillate',
          value: oscillating,
          onChanged: (v) => call('oscillate', {'oscillating': v}),
        ),
    ];
  }

  static List<Widget> _mediaControls(HaEntity e, HaClient ha) {
    void call(String service, [Map<String, dynamic> data = const {}]) =>
        ha.callService('media_player', service, e.entityId, data);
    final title = e.attributes['media_title'] as String?;
    final artist = e.attributes['media_artist'] as String?;
    final volume = e.attributes['volume_level'] as num?;
    final muted = e.attributes['is_volume_muted'] as bool? ?? false;
    final sources = e.listAttr('source_list');
    final playing = e.state == 'playing';
    return [
      if (e.isOn)
        _NowPlaying(
          title: title,
          artist: artist,
          playing: playing,
          onPrevious: () => call('media_previous_track'),
          onPlayPause: () => call('media_play_pause'),
          onNext: () => call('media_next_track'),
        ),
      if (e.isOn && volume != null)
        _Labeled(
          'Volume',
          child: Row(
            children: [
              IconButton(
                tooltip: muted ? 'Unmute' : 'Mute',
                onPressed: () =>
                    call('volume_mute', {'is_volume_muted': !muted}),
                icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
              ),
              Expanded(
                child: CommitSlider(
                  value: volume * 100,
                  min: 0,
                  max: 100,
                  label: (v) => '${v.round()}%',
                  semanticLabel: 'Volume',
                  onCommit: (v) => call('volume_set', {
                    'volume_level': double.parse((v / 100).toStringAsFixed(2)),
                  }),
                ),
              ),
            ],
          ),
        ),
      if (e.isOn && sources.isNotEmpty)
        _Labeled(
          'Source',
          child: _Choices(
            options: {for (final s in sources) s: s},
            selected: e.attributes['source'] as String?,
            onSelect: (s) => call('select_source', {'source': s}),
          ),
        ),
    ];
  }

  static List<Widget> _coverControls(HaEntity e, HaClient ha) {
    void call(String service, [Map<String, dynamic> data = const {}]) =>
        ha.callService('cover', service, e.entityId, data);
    final position = e.attributes['current_position'] as num?;
    return [
      Row(
        children: [
          Expanded(
            child: _BigButton(
              icon: Icons.arrow_upward,
              label: 'Open',
              selected: e.state == 'open',
              onPressed: () => call('open_cover'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _BigButton(
              icon: Icons.stop,
              label: 'Stop',
              onPressed: () => call('stop_cover'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _BigButton(
              icon: Icons.arrow_downward,
              label: 'Close',
              selected: e.state == 'closed',
              onPressed: () => call('close_cover'),
            ),
          ),
        ],
      ),
      if (position != null)
        _Labeled(
          'Position',
          trailing: const _Ends('Closed', 'Open'),
          child: CommitSlider(
            value: position.toDouble(),
            min: 0,
            max: 100,
            label: (v) => '${v.round()}% open',
            semanticLabel: 'Position',
            onCommit: (v) =>
                call('set_cover_position', {'position': v.round()}),
          ),
        ),
    ];
  }

  static List<Widget> _lockControls(HaEntity e, HaClient ha) => [
    Row(
      children: [
        Expanded(
          child: _BigButton(
            icon: Icons.lock_outline,
            label: 'Lock',
            selected: e.state == 'locked',
            onPressed: () => ha.setOn(e, true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BigButton(
            icon: Icons.lock_open,
            label: 'Unlock',
            selected: e.state == 'unlocked',
            onPressed: () => ha.setOn(e, false),
          ),
        ),
      ],
    ),
  ];

  static String _title(String s) {
    final words = s.replaceAll('_', ' ');
    return words.isEmpty
        ? words
        : '${words[0].toUpperCase()}${words.substring(1)}';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.entity, required this.ha});

  final HaEntity entity;
  final HaClient ha;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    final e = entity;
    return Row(
      children: [
        IconBox(icon: e.icon, on: e.isOn && e.available, size: 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${ha.areaName(e)} | ${e.stateLabel}',
                style: TextStyle(fontSize: 14, color: p.muted),
              ),
            ],
          ),
        ),
        if (e.isToggle)
          Switch(
            value: e.isOn,
            onChanged: e.available ? (on) => ha.setOn(e, on) : null,
          ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'This device is no longer in Home Assistant.',
            style: TextStyle(color: context.porch.muted),
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: onClose,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

/// A small heading above a control, with optional text on the right.
class _Labeled extends StatelessWidget {
  const _Labeled(this.label, {required this.child, this.trailing});

  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: p.muted,
              ),
            ),
            const Spacer(),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// "Warm ... Cool" style labels for the two ends of a slider.
class _Ends extends StatelessWidget {
  const _Ends(this.start, this.end);

  final String start;
  final String end;

  @override
  Widget build(BuildContext context) => Text(
    '$start to $end',
    style: TextStyle(fontSize: 13, color: context.porch.muted),
  );
}

/// A slider that only tells Home Assistant once the drag ends, and keeps
/// showing the new value until the update comes back.
class CommitSlider extends StatefulWidget {
  const CommitSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onCommit,
    required this.semanticLabel,
    this.divisions,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double) label;
  final ValueChanged<double> onCommit;
  final String semanticLabel;

  @override
  State<CommitSlider> createState() => _CommitSliderState();
}

class _CommitSliderState extends State<CommitSlider> {
  double? _local;
  Timer? _settle;

  @override
  void didUpdateWidget(CommitSlider old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _local = null;
  }

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = (_local ?? widget.value).clamp(widget.min, widget.max);
    return Semantics(
      label: widget.semanticLabel,
      child: Slider(
        value: value,
        min: widget.min,
        max: widget.max,
        divisions: widget.divisions,
        label: widget.label(value),
        onChanged: (v) {
          _settle?.cancel();
          setState(() => _local = v);
        },
        onChangeEnd: (v) {
          widget.onCommit(v);
          // Fall back to the real value if no update arrives.
          _settle = Timer(const Duration(seconds: 4), () {
            if (mounted) setState(() => _local = null);
          });
        },
      ),
    );
  }
}

/// Pill-shaped choices, one of them selected.
class _Choices extends StatelessWidget {
  const _Choices({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  /// Value to label.
  final Map<String, String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final MapEntry(key: value, value: label) in options.entries)
          ChoiceChip(
            label: Text(label),
            selected: value == selected,
            showCheckmark: false,
            onSelected: (_) => onSelect(value),
            backgroundColor: p.bg,
            selectedColor: p.accent,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: value == selected ? p.accentInk : p.ink,
            ),
            side: BorderSide(color: value == selected ? p.accent : p.strong),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          ),
      ],
    );
  }
}

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({required this.selected, required this.onPick});

  /// The light's current `hs_color`, or null when it's showing white.
  final List? selected;
  final void Function(double hue, double saturation) onPick;

  static const _swatches = [
    ('Red', 0.0),
    ('Orange', 28.0),
    ('Yellow', 50.0),
    ('Green', 120.0),
    ('Teal', 175.0),
    ('Blue', 220.0),
    ('Purple', 275.0),
    ('Pink', 325.0),
  ];

  bool _isSelected(double hue) {
    final hs = selected;
    if (hs == null || hs.length < 2) return false;
    final h = (hs[0] as num).toDouble();
    final s = (hs[1] as num).toDouble();
    final distance = (h - hue).abs() % 360;
    return s > 30 && (distance < 15 || distance > 345);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (name, hue) in _swatches)
          Tooltip(
            message: name,
            child: Semantics(
              button: true,
              selected: _isSelected(hue),
              label: name,
              child: InkWell(
                onTap: () => onPick(hue, 85),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isSelected(hue) ? p.ink : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HSVColor.fromAHSV(1, hue, 0.75, 1).toColor(),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TempStepper extends StatelessWidget {
  const _TempStepper({
    required this.entity,
    required this.label,
    required this.value,
    required this.onSet,
    this.compact = false,
  });

  final HaEntity entity;
  final String label;
  final num value;
  final ValueChanged<num> onSet;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    final step = entity.attributes['target_temp_step'] as num? ?? 1;
    final min = entity.attributes['min_temp'] as num?;
    final max = entity.attributes['max_temp'] as num?;
    final lower = value - step;
    final higher = value + step;
    Widget round(IconData icon, String tooltip, VoidCallback? onTap) =>
        IconButton.outlined(
          tooltip: tooltip,
          onPressed: onTap,
          iconSize: 22,
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: p.bg,
            side: BorderSide(color: p.strong),
          ),
          icon: Icon(icon),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          round(
            Icons.remove,
            '$label lower',
            min != null && lower < min ? null : () => onSet(lower),
          ),
          Expanded(
            child: Column(
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: p.muted)),
                const SizedBox(height: 2),
                Text(
                  '${_fmt(value)}°',
                  style: TextStyle(
                    fontSize: compact ? 32 : 48,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          round(
            Icons.add,
            '$label higher',
            max != null && higher > max ? null : () => onSet(higher),
          ),
        ],
      ),
    );
  }

  static String _fmt(num t) =>
      t % 1 == 0 ? '${t.toInt()}' : t.toStringAsFixed(1);
}

class _InsideNow extends StatelessWidget {
  const _InsideNow({this.temperature, this.humidity});

  final num? temperature;
  final num? humidity;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (temperature != null) '${_TempStepper._fmt(temperature!)}°',
      if (humidity != null) '${humidity!.round()}% humidity',
    ];
    return Text(
      'Inside now ${parts.join(' | ')}',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14, color: context.porch.muted),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        backgroundColor: selected ? p.accentSoft : p.bg,
        foregroundColor: selected ? p.link : p.ink,
        side: BorderSide(color: selected ? p.accent : p.strong),
      ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({
    required this.title,
    required this.artist,
    required this.playing,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
  });

  final String? title;
  final String? artist;
  final bool playing;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? 'Nothing playing',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (artist != null)
                  Text(
                    artist!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: p.muted),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Previous',
            onPressed: onPrevious,
            icon: const Icon(Icons.skip_previous),
          ),
          IconButton.filled(
            tooltip: playing ? 'Pause' : 'Play',
            onPressed: onPlayPause,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          ),
          IconButton(
            tooltip: 'Next',
            onPressed: onNext,
            icon: const Icon(Icons.skip_next),
          ),
        ],
      ),
    );
  }
}
