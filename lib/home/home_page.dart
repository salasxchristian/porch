import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../cameras/cameras_page.dart';
import '../ha/ha_client.dart';
import '../ha/ha_entity.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/device_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static String greeting(DateTime now) => now.hour < 12
      ? 'Good morning'
      : now.hour < 17
      ? 'Good afternoon'
      : 'Good evening';

  static String dateLine(DateTime now) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = context.porch;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.ha, scope.settings, scope.cameras]),
      builder: (context, _) {
        final ha = scope.ha;
        final settings = scope.settings;
        final now = DateTime.now();
        final pinned = [for (final id in settings.pinned) ?ha.entities[id]];
        final tiles = pinned.where((e) => e.isToggle).toList();
        final cards = pinned
            .where((e) => cardDomains.contains(e.domain))
            .toList();
        final shown = [for (final id in settings.shown) ?ha.entities[id]];
        final scenes = shown.where((e) => e.domain == 'scene').toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        final lightsOn = shown
            .where((e) => e.domain == 'light' && e.isOn)
            .toList();
        final cameras = scope.cameras.cameras;

        return PageBody(
          children: [
            Wrap(
              spacing: 20,
              runSpacing: 16,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                PageTitle(
                  HomePage.greeting(now),
                  overline: HomePage.dateLine(now),
                ),
                if (_editing)
                  Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Drag cards to reorder, or use the arrows.',
                        style: TextStyle(color: p.muted),
                      ),
                      FilledButton(
                        onPressed: () => setState(() => _editing = false),
                        child: const Text('Done'),
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final s in scenes)
                        OutlinedButton(
                          onPressed: () => ha.setOn(s, true),
                          child: Text(s.name),
                        ),
                      if (lightsOn.isNotEmpty)
                        FilledButton(
                          onPressed: () {
                            for (final l in lightsOn) {
                              ha.setOn(l, false);
                            }
                          },
                          child: const Text('All lights off'),
                        ),
                      if (pinned.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _editing = true),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit home'),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 32),
            if (!settings.hasConnection) ...[
              NoticeCard(
                icon: Icons.home_outlined,
                title: 'Connect Home Assistant',
                message: 'Add your server address and token to control lights and devices.',
                actionLabel: 'Open Settings',
                onAction: () => scope.page.value = PorchPage.settings,
              ),
              const SizedBox(height: 32),
            ],
            if (cameras.isNotEmpty) ...[
              SectionTitle(
                'Cameras',
                trailing: TextButton(
                  onPressed: () => scope.page.value = PorchPage.cameras,
                  child: const Text('See all cameras'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final (i, cam) in cameras.take(3).indexed) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CameraTile(
                          camera: cam,
                          onOpen: () =>
                              CamerasPage.openCamera(context, cam, cameras),
                        ),
                      ),
                    ),
                  ],
                  for (var i = cameras.length; i < 3; i++) ...[
                    const SizedBox(width: 16),
                    const Expanded(child: SizedBox()),
                  ],
                ],
              ),
              const SizedBox(height: 36),
            ],
            if (settings.hasConnection)
              LayoutBuilder(
                builder: (context, box) {
                  final devices = _DevicesSection(
                    tiles: tiles,
                    editing: _editing,
                    ha: ha,
                    settings: settings,
                    onlyNotices: pinned.isEmpty,
                  );
                  if (cards.isEmpty) return devices;
                  final side = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, e) in cards.indexed) ...[
                        if (i > 0) const SizedBox(height: 12),
                        controlCardFor(
                          e,
                          ha,
                          trailing: _editing
                              ? _UnpinButton(entity: e, settings: settings)
                              : null,
                        ),
                      ],
                    ],
                  );
                  if (box.maxWidth < 980) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [devices, const SizedBox(height: 28), side],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: devices),
                      const SizedBox(width: 28),
                      SizedBox(
                        width: 320,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 46),
                          child: side,
                        ),
                      ),
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

class _DevicesSection extends StatelessWidget {
  const _DevicesSection({
    required this.tiles,
    required this.editing,
    required this.ha,
    required this.settings,
    required this.onlyNotices,
  });

  final List<HaEntity> tiles;
  final bool editing;
  final HaClient ha;
  final AppSettings settings;
  final bool onlyNotices;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    final scope = AppScope.of(context);
    final onCount = tiles.where((e) => e.isOn).length;
    if (onlyNotices) {
      return NoticeCard(
        icon: Icons.star_border,
        title: 'Nothing on Home yet',
        message: ha.status == HaStatus.connected
            ? 'Pin the devices you use most in Settings and they will show up here.'
            : 'Waiting for Home Assistant to connect.',
        actionLabel: 'Choose devices',
        onAction: () => scope.page.value = PorchPage.settings,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Lights and devices',
          trailing: Text(
            onCount == 0 ? 'Everything is off' : '$onCount on',
            style: TextStyle(color: p.muted),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, box) {
            const gap = 12.0;
            final cols = (box.maxWidth / 230).floor().clamp(1, 4);
            final width = (box.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (i, e) in tiles.indexed)
                  SizedBox(
                    width: width,
                    child: editing
                        ? _EditableTile(
                            entity: e,
                            area: ha.areaName(e),
                            width: width,
                            previous: i > 0 ? tiles[i - 1] : null,
                            next: i < tiles.length - 1 ? tiles[i + 1] : null,
                            settings: settings,
                          )
                        : DeviceTile(entity: e, area: ha.areaName(e), ha: ha),
                  ),
                if (editing)
                  SizedBox(
                    width: width,
                    height: 128,
                    child: OutlinedButton.icon(
                      onPressed: () => scope.page.value = PorchPage.settings,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: p.link,
                        side: BorderSide(color: p.strong, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add devices in Settings'),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A pinned tile in edit mode: drag it onto another tile, or use the arrows.
class _EditableTile extends StatelessWidget {
  const _EditableTile({
    required this.entity,
    required this.area,
    required this.width,
    required this.previous,
    required this.next,
    required this.settings,
  });

  final HaEntity entity;
  final String area;
  final double width;
  final HaEntity? previous;
  final HaEntity? next;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    Widget card({bool highlight = false}) => Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 14),
      decoration: BoxDecoration(
        color: highlight ? p.accentSoft : p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlight ? p.accent : p.strong, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.drag_indicator, color: p.muted),
              const Spacer(),
              _SmallIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Move ${entity.name} earlier',
                onPressed: previous == null
                    ? null
                    : () => settings.movePinned(
                        entity.entityId,
                        previous!.entityId,
                      ),
              ),
              _SmallIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Move ${entity.name} later',
                onPressed: next == null
                    ? null
                    : () =>
                          settings.movePinned(entity.entityId, next!.entityId),
              ),
              _SmallIconButton(
                icon: Icons.close,
                tooltip: 'Remove ${entity.name} from Home',
                onPressed: () => settings.setPinned(entity.entityId, false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconBox(icon: entity.icon, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entity.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(area, style: TextStyle(fontSize: 13, color: p.muted)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != entity.entityId,
      onAcceptWithDetails: (d) => settings.movePinned(d.data, entity.entityId),
      builder: (context, candidates, _) => Draggable<String>(
        data: entity.entityId,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: width,
            child: Opacity(opacity: 0.9, child: card()),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: card()),
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: card(highlight: candidates.isNotEmpty),
        ),
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          backgroundColor: p.bg,
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _UnpinButton extends StatelessWidget {
  const _UnpinButton({required this.entity, required this.settings});

  final HaEntity entity;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => _SmallIconButton(
    icon: Icons.close,
    tooltip: 'Remove ${entity.name} from Home',
    onPressed: () => settings.setPinned(entity.entityId, false),
  );
}
