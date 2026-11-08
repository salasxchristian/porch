import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../ha/ha_client.dart';
import '../ha/ha_entity.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/device_widgets.dart';

/// Every shown device, one room at a time.
class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  String? _room;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = context.porch;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.ha, scope.settings]),
      builder: (context, _) {
        final ha = scope.ha;
        final byRoom = <String, List<HaEntity>>{};
        for (final id in scope.settings.shown) {
          final e = ha.entities[id];
          if (e == null || e.domain == 'scene') continue;
          byRoom.putIfAbsent(ha.areaName(e), () => []).add(e);
        }
        final rooms = byRoom.keys.toList()
          ..sort(
            (a, b) => a == 'Other'
                ? 1
                : b == 'Other'
                ? -1
                : a.compareTo(b),
          );
        for (final list in byRoom.values) {
          list.sort((a, b) => a.name.compareTo(b.name));
        }
        if (rooms.isEmpty) {
          return PageBody(
            children: [
              const PageTitle('Rooms'),
              const SizedBox(height: 28),
              NoticeCard(
                icon: Icons.lightbulb_outline,
                title: 'No devices yet',
                message: ha.status == HaStatus.connected
                    ? 'Choose which Home Assistant devices to show in Settings.'
                    : 'Connect Home Assistant in Settings to see your rooms.',
                actionLabel: 'Open Settings',
                onAction: () => scope.page.value = PorchPage.settings,
              ),
            ],
          );
        }
        final room = rooms.contains(_room) ? _room! : rooms.first;
        final entities = byRoom[room]!;
        final rows = entities.where((e) => e.domain != 'climate').toList();
        final climates = entities.where((e) => e.domain == 'climate').toList();
        final onToggles = rows.where((e) => e.isToggle && e.isOn).toList();

        final list = PorchCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        room,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (onToggles.isNotEmpty)
                      OutlinedButton(
                        onPressed: () {
                          for (final e in onToggles) {
                            ha.setOn(e, false);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          backgroundColor: p.bg,
                        ),
                        child: const Text('Turn all off'),
                      ),
                  ],
                ),
              ),
              for (final e in rows)
                _DeviceRow(key: ValueKey(e.entityId), entity: e, ha: ha),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Text(
                    'Only climate controls in this room.',
                    style: TextStyle(color: p.muted),
                  ),
                ),
            ],
          ),
        );

        return PageBody(
          children: [
            const PageTitle('Rooms'),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in rooms)
                  _RoomTab(
                    label: r,
                    count: byRoom[r]!.where((e) => e.isToggle && e.isOn).length,
                    selected: r == room,
                    onTap: () => setState(() => _room = r),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, box) {
                if (climates.isEmpty) return list;
                final side = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final c in climates) ...[
                      ClimateCard(entity: c, ha: ha),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
                if (box.maxWidth < 900) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [list, const SizedBox(height: 24), side],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: list),
                    const SizedBox(width: 24),
                    SizedBox(width: 320, child: side),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _RoomTab extends StatelessWidget {
  const _RoomTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
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
          backgroundColor: selected ? p.accent : p.surface,
          foregroundColor: selected ? p.accentInk : p.ink,
          side: BorderSide(color: selected ? p.accent : p.strong),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: Text(count > 0 ? '$label  $count on' : label),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({super.key, required this.entity, required this.ha});

  final HaEntity entity;
  final HaClient ha;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    final e = entity;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          IconBox(icon: e.icon, on: e.isToggle && e.isOn, size: 44),
          const SizedBox(width: 16),
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  e.stateLabel,
                  style: TextStyle(fontSize: 13, color: p.muted),
                ),
              ],
            ),
          ),
          Expanded(
            child: e.dimmable
                ? _BrightnessSlider(entity: e, ha: ha)
                : const SizedBox(),
          ),
          const SizedBox(width: 12),
          if (e.isToggle)
            Switch(
              value: e.isOn,
              onChanged: e.available ? (v) => ha.setOn(e, v) : null,
            )
          else
            OutlinedButton(
              onPressed: e.available ? () => ha.setOn(e, !e.isOn) : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                backgroundColor: p.bg,
              ),
              child: Text(
                e.domain == 'lock'
                    ? (e.isOn ? 'Unlock' : 'Lock')
                    : (e.isOn ? 'Close' : 'Open'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Keeps the thumb where it is while dragging, and sends the value on release.
class _BrightnessSlider extends StatefulWidget {
  const _BrightnessSlider({required this.entity, required this.ha});

  final HaEntity entity;
  final HaClient ha;

  @override
  State<_BrightnessSlider> createState() => _BrightnessSliderState();
}

class _BrightnessSliderState extends State<_BrightnessSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    final value = _dragging ?? (widget.entity.brightnessPct ?? 0).toDouble();
    return Row(
      children: [
        Text(
          'Brightness',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: p.muted,
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0, 100),
            max: 100,
            label: '${value.round()}%',
            semanticFormatterCallback: (v) => '${v.round()}%',
            onChanged: widget.entity.available && widget.entity.isOn
                ? (v) => setState(() => _dragging = v)
                : null,
            onChangeEnd: (v) {
              setState(() => _dragging = null);
              final pct = v.round();
              if (pct == 0) {
                widget.ha.setOn(widget.entity, false);
              } else {
                widget.ha.setBrightness(widget.entity, pct);
              }
            },
          ),
        ),
      ],
    );
  }
}
