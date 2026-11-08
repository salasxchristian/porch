import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../cameras/camera_editor.dart';
import '../ha/ha_client.dart';
import '../ha/ha_entity.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'app_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageBody(
      children: [
        PageTitle('Settings'),
        SizedBox(height: 28),
        _Constrained(child: _DevicesSection()),
        SizedBox(height: 20),
        _Constrained(child: _AppearanceSection()),
        SizedBox(height: 20),
        _Constrained(child: _ConnectionSection()),
        SizedBox(height: 20),
        _Constrained(child: _CamerasSection()),
      ],
    );
  }
}

class _Constrained extends StatelessWidget {
  const _Constrained({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: child,
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title, this.description, {this.trailing});

  final String title;
  final String description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(description, style: TextStyle(fontSize: 14, color: p.muted)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _DevicesSection extends StatefulWidget {
  const _DevicesSection();

  @override
  State<_DevicesSection> createState() => _DevicesSectionState();
}

class _DevicesSectionState extends State<_DevicesSection> {
  String _query = '';
  String? _group;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.ha, scope.settings]),
      builder: (context, _) {
        final settings = scope.settings;
        final all = scope.ha.supported;
        final q = _query.toLowerCase();
        final visible = all.where((e) {
          if (_group != null && groupOf(e) != _group) return false;
          if (q.isEmpty) return true;
          return e.name.toLowerCase().contains(q) ||
              e.entityId.contains(q) ||
              scope.ha.areaName(e).toLowerCase().contains(q);
        }).toList();
        final shownCount = all
            .where((e) => settings.shown.contains(e.entityId))
            .length;
        return PorchCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
                child: _SectionHeading(
                  'Devices',
                  'Choose which Home Assistant devices appear in Porch. '
                      'Pinned devices also show on Home, where you can reorder them.',
                  trailing: scope.ha.status == HaStatus.connected
                      ? Text(
                          '$shownCount of ${all.length} shown',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: p.muted,
                          ),
                        )
                      : null,
                ),
              ),
              if (scope.ha.status != HaStatus.connected)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Text(
                    'Connect to Home Assistant below to see your devices.',
                    style: TextStyle(color: p.muted),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 280,
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: const InputDecoration(
                            hintText: 'Search devices',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                          ),
                        ),
                      ),
                      _FilterChip(
                        label: 'All',
                        selected: _group == null,
                        onTap: () => setState(() => _group = null),
                      ),
                      for (final entry in domainGroups.entries)
                        _FilterChip(
                          label: entry.value,
                          selected: _group == entry.key,
                          onTap: () => setState(() => _group = entry.key),
                        ),
                    ],
                  ),
                ),
                const _DeviceHeaderRow(),
                for (final e in visible)
                  _DeviceRow(
                    entity: e,
                    area: scope.ha.areaName(e),
                    shown: settings.shown.contains(e.entityId),
                    pinned: settings.pinned.contains(e.entityId),
                    settings: settings,
                  ),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No devices match.',
                      style: TextStyle(color: p.muted),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          backgroundColor: selected ? p.accent : p.surface,
          foregroundColor: selected ? p.accentInk : p.ink,
          side: BorderSide(color: selected ? p.accent : p.strong),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

const _areaWidth = 160.0;
const _showWidth = 120.0;
const _pinWidth = 120.0;

class _DeviceHeaderRow extends StatelessWidget {
  const _DeviceHeaderRow();

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: p.muted,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          Expanded(child: Text('DEVICE', style: style)),
          SizedBox(
            width: _areaWidth,
            child: Text('AREA', style: style),
          ),
          SizedBox(
            width: _showWidth,
            child: Text('SHOW IN PORCH', style: style),
          ),
          SizedBox(
            width: _pinWidth,
            child: Text('ON HOME', style: style),
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.entity,
    required this.area,
    required this.shown,
    required this.pinned,
    required this.settings,
  });

  final HaEntity entity;
  final String area;
  final bool shown;
  final bool pinned;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Opacity(
        opacity: shown ? 1 : 0.65,
        child: Row(
          children: [
            IconBox(icon: entity.icon, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entity.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    entity.entityId,
                    style: TextStyle(
                      fontSize: 12,
                      color: p.muted,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: _areaWidth,
              child: Text(area, style: TextStyle(color: p.muted)),
            ),
            SizedBox(
              width: _showWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Switch(
                  value: shown,
                  onChanged: (v) => settings.setShown(entity.entityId, v),
                ),
              ),
            ),
            SizedBox(
              width: _pinWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: shown
                      ? () => settings.setPinned(entity.entityId, !pinned)
                      : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    backgroundColor: pinned ? p.onSoft : Colors.transparent,
                    foregroundColor: pinned ? p.pillInk : p.muted,
                    side: BorderSide(color: pinned ? p.onBorder : p.strong),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: Icon(pinned ? Icons.star : Icons.star_border, size: 16),
                  label: Text(pinned ? 'Pinned' : 'Pin'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return PorchCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeading(
            'Appearance',
            "Pick a color theme, and light or dark. Automatic follows the "
                "computer's setting.",
            trailing: ListenableBuilder(
              listenable: settings,
              builder: (context, _) => SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined, size: 18),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined, size: 18),
                    label: Text('Dark'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined, size: 18),
                    label: Text('Automatic'),
                  ),
                ],
                selected: {settings.appearance},
                onSelectionChanged: (s) => settings.setAppearance(s.first),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: settings,
            builder: (context, _) {
              final dark = context.porch.isDark;
              return Row(
                children: [
                  for (final (i, palette) in PorchPalette.all.indexed) ...[
                    if (i > 0) const SizedBox(width: 14),
                    Expanded(
                      child: _ThemeCard(
                        palette: PorchPalette.byId(palette.id, dark: dark),
                        selected: settings.themeId == palette.id,
                        onTap: () => settings.setTheme(palette.id),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final PorchPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    final c = palette;
    Widget bar(Color color, {double? width, double height = 8}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: '${c.label} theme',
      child: Material(
        color: p.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? p.accent : p.border, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 96,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 70,
                          color: c.side,
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              bar(c.accent, width: 12, height: 12),
                              const SizedBox(height: 8),
                              bar(c.surface),
                              const SizedBox(height: 6),
                              bar(c.sideCard, width: 36),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            color: c.bg,
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: bar(c.onSoft, height: 30)),
                                    const SizedBox(width: 6),
                                    Expanded(child: bar(c.surface, height: 30)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                bar(c.accent, width: 46, height: 14),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected ? p.accent : p.muted,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionSection extends StatefulWidget {
  const _ConnectionSection();

  @override
  State<_ConnectionSection> createState() => _ConnectionSectionState();
}

class _ConnectionSectionState extends State<_ConnectionSection> {
  late final AppScope _scope = AppScope.of(context);
  late final _url = TextEditingController(text: _scope.settings.haUrl);
  late final _token = TextEditingController(text: _scope.settings.haToken);

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _scope.settings.setConnection(_url.text, _token.text);
    await _scope.ha.connect(_scope.settings.haUrl, _scope.settings.haToken);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    final ha = _scope.ha;
    return PorchCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: ha,
            builder: (context, _) =>
                _SectionHeading('Home Assistant', switch (ha.status) {
                  HaStatus.connected => 'Connected.',
                  HaStatus.connecting => 'Connecting...',
                  HaStatus.notConfigured =>
                    'Enter your server address and an access token.',
                  HaStatus.authFailed =>
                    'Home Assistant rejected the access token.',
                  HaStatus.unreachable =>
                    "Can't reach the server. Retrying every few seconds.",
                }),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _url,
                  decoration: const InputDecoration(
                    labelText: 'Server address',
                    hintText: 'http://homeassistant.local:8123',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _token,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Access token',
                    helperText: 'Create a long-lived access token in your Home Assistant profile.',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(
                onPressed: _save,
                child: const Text('Save and connect'),
              ),
              const SizedBox(width: 12),
              Text(
                'Saved on this computer only.',
                style: TextStyle(fontSize: 13, color: p.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CamerasSection extends StatelessWidget {
  const _CamerasSection();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).cameras;
    return PorchCard(
      padding: const EdgeInsets.all(24),
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final n = store.cameras.length;
          return _SectionHeading(
            'Cameras',
            '${n == 0 ? 'No' : n} camera${n == 1 ? '' : 's'}. '
                'Add, rename or remove RTSP cameras.',
            trailing: OutlinedButton(
              onPressed: () => showManageCameras(context, store),
              child: const Text('Manage cameras'),
            ),
          );
        },
      ),
    );
  }
}
