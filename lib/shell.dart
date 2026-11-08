import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'cameras/cameras_page.dart';
import 'ha/ha_client.dart';
import 'home/home_page.dart';
import 'rooms/rooms_page.dart';
import 'settings/settings_page.dart';
import 'theme.dart';
import 'update/updater.dart';
import 'widgets/common.dart';

/// Sidebar plus the page it selects. Pages are rebuilt on each switch so
/// camera streams on a page stop when you leave it.
class PorchShell extends StatelessWidget {
  const PorchShell({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      body: ValueListenableBuilder(
        valueListenable: scope.page,
        builder: (context, page, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Sidebar(page: page, onSelect: (p) => scope.page.value = p),
            Expanded(
              child: switch (page) {
                PorchPage.home => const HomePage(),
                PorchPage.cameras => const CamerasPage(),
                PorchPage.rooms => const RoomsPage(),
                PorchPage.settings => const SettingsPage(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.page, required this.onSelect});

  final PorchPage page;
  final ValueChanged<PorchPage> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    Widget item(PorchPage target, IconData icon, String label) => _NavItem(
      icon: icon,
      label: label,
      selected: page == target,
      onTap: () => onSelect(target),
    );
    return Container(
      width: 240,
      color: p.side,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 24),
            child: Row(
              children: [
                LogoMark(),
                SizedBox(width: 12),
                Text(
                  'Porch',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          item(PorchPage.home, Icons.home_outlined, 'Home'),
          const SizedBox(height: 6),
          item(PorchPage.cameras, Icons.videocam_outlined, 'Cameras'),
          const SizedBox(height: 6),
          item(PorchPage.rooms, Icons.lightbulb_outline, 'Rooms'),
          const Spacer(),
          const _UpdateCard(),
          item(PorchPage.settings, Icons.tune, 'Settings'),
          const SizedBox(height: 10),
          const _ConnectionCard(),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? p.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        elevation: selected ? 0.5 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: selected ? p.accent : p.navInk),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? p.ink : p.navInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard();

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    final ha = AppScope.of(context).ha;
    return ListenableBuilder(
      listenable: ha,
      builder: (context, _) {
        final (label, ok) = switch (ha.status) {
          HaStatus.connected => ('Connected', true),
          HaStatus.connecting => ('Connecting', false),
          HaStatus.notConfigured => ('Not set up', false),
          HaStatus.authFailed => ('Token rejected', false),
          HaStatus.unreachable => ('Can\'t reach it. Retrying.', false),
        };
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.sideCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ok ? p.accent : null,
                  border: ok ? null : Border.all(color: p.muted, width: 2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Home Assistant',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(label, style: TextStyle(fontSize: 12, color: p.muted)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Offers a newer version when one is out, and shows the download.
class _UpdateCard extends StatelessWidget {
  const _UpdateCard();

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    final updater = AppScope.of(context).updater;
    return ListenableBuilder(
      listenable: updater,
      builder: (context, _) {
        final release = updater.latest;
        if (release == null ||
            !const {
              UpdateState.available,
              UpdateState.downloading,
              UpdateState.installing,
            }.contains(updater.state)) {
          return const SizedBox();
        }
        final (title, detail) = switch (updater.state) {
          UpdateState.downloading => (
            'Downloading update',
            '${(updater.progress * 100).round()}%',
          ),
          UpdateState.installing => (
            'Installing update',
            'Porch will close and reopen.',
          ),
          _ => ('Update available', 'Porch ${release.version}'),
        };
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.onSoft,
              border: Border.all(color: p.onBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.system_update_alt, size: 18, color: p.pillInk),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(detail, style: TextStyle(fontSize: 12, color: p.muted)),
                const SizedBox(height: 10),
                if (updater.state == UpdateState.available)
                  FilledButton(
                    onPressed: updater.install,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(updater.installsInApp ? 'Install' : 'Get it'),
                  )
                else
                  LinearProgressIndicator(
                    value: updater.state == UpdateState.downloading
                        ? updater.progress
                        : null,
                    color: p.accent,
                    backgroundColor: p.track,
                    borderRadius: BorderRadius.circular(4),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
