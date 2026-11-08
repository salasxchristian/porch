import 'package:flutter/material.dart';

import '../ha/ha_client.dart';
import '../ha/ha_entity.dart';
import '../theme.dart';
import 'common.dart';

/// A card for a light, switch or similar. Its switch turns it on and off;
/// clicking the card calls [onOpen] when given, or toggles it otherwise.
class DeviceTile extends StatelessWidget {
  const DeviceTile({
    super.key,
    required this.entity,
    required this.area,
    required this.ha,
    this.onOpen,
  });

  final HaEntity entity;
  final String area;
  final HaClient ha;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    final on = entity.isOn && entity.available;
    void toggle() => ha.setOn(entity, !entity.isOn);
    return Material(
      color: on ? p.onSoft : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: on ? p.onBorder : p.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen ?? (entity.available ? toggle : null),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBox(icon: entity.icon, on: on),
                  const Spacer(),
                  ExcludeSemantics(
                    child: Switch(
                      value: entity.isOn,
                      onChanged: entity.available ? (_) => toggle() : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                entity.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$area | ${entity.stateLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: p.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thermostat with target temperature buttons.
class ClimateCard extends StatelessWidget {
  const ClimateCard({
    super.key,
    required this.entity,
    required this.ha,
    this.trailing,
    this.onOpen,
  });

  final HaEntity entity;
  final HaClient ha;
  final Widget? trailing;

  /// Called when the card itself (not one of its buttons) is clicked.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    final target = entity.targetTemperature;
    final step = entity.attributes['target_temp_step'] as num? ?? 1;
    final current = entity.currentTemperature;
    final action = entity.hvacAction;
    final low = entity.attributes['target_temp_low'] as num?;
    final high = entity.attributes['target_temp_high'] as num?;
    final headline = target != null
        ? '${_fmt(target)}°'
        : low != null && high != null
        ? '${_fmt(low)}° to ${_fmt(high)}°'
        : HaEntity.hvacLabel(entity.state);
    Widget roundButton(String label, String tooltip, VoidCallback? onTap) =>
        Tooltip(
          message: tooltip,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              backgroundColor: p.bg,
              textStyle: const TextStyle(fontSize: 22),
            ),
            child: Text(label, semanticsLabel: tooltip),
          ),
        );
    return PorchCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entity.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (action != null && action != 'idle' && action != 'off')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: p.pill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${action[0].toUpperCase()}${action.substring(1)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.pillInk,
                    ),
                  ),
                ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (target != null)
                roundButton(
                  '-',
                  'Lower temperature',
                  () => ha.setTemperature(entity, target - step),
                ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      headline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: target == null ? 30 : 44,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    if (current != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Inside now ${_fmt(current)}°',
                        style: TextStyle(fontSize: 13, color: p.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (target != null)
                roundButton(
                  '+',
                  'Raise temperature',
                  () => ha.setTemperature(entity, target + step),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(num t) =>
      t % 1 == 0 ? '${t.toInt()}' : t.toStringAsFixed(1);
}

/// Lock or garage door: state plus one action button.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.entity,
    required this.ha,
    this.trailing,
    this.onOpen,
  });

  final HaEntity entity;
  final HaClient ha;
  final Widget? trailing;

  /// Called when the card itself (not one of its buttons) is clicked.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    final isLock = entity.domain == 'lock';
    final label = isLock
        ? (entity.isOn ? 'Unlock' : 'Lock')
        : (entity.isOn ? 'Close' : 'Open');
    return PorchCard(
      onTap: onOpen,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(entity.icon, size: 20, color: p.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entity.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entity.stateLabel,
                  style: TextStyle(fontSize: 13, color: p.muted),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: entity.available
                ? () => ha.setOn(entity, !entity.isOn)
                : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              backgroundColor: p.bg,
            ),
            child: Text(label),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The right card for any non-toggle entity Porch shows on its own.
Widget controlCardFor(
  HaEntity e,
  HaClient ha, {
  Widget? trailing,
  VoidCallback? onOpen,
}) => switch (e.domain) {
  'climate' => ClimateCard(
    entity: e,
    ha: ha,
    trailing: trailing,
    onOpen: onOpen,
  ),
  _ => ActionCard(entity: e, ha: ha, trailing: trailing, onOpen: onOpen),
};

/// Domains that get their own card instead of a toggle tile.
const cardDomains = {'climate', 'lock', 'cover'};
