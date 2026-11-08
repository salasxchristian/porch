import 'package:flutter/material.dart';

import '../theme.dart';

/// A rounded surface with a hairline border.
class PorchCard extends StatelessWidget {
  const PorchCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? p.border),
      ),
      child: child,
    );
  }
}

/// The rounded square behind a device icon, filled when the device is on.
class IconBox extends StatelessWidget {
  const IconBox({
    super.key,
    required this.icon,
    this.on = false,
    this.size = 40,
  });

  final IconData icon;
  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: on ? p.on : p.neutral,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.5, color: on ? p.onInk : p.muted),
    );
  }
}

/// Large page title with an optional line above it.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.overline});

  final String title;
  final String? overline;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (overline != null) ...[
          Text(
            overline!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: p.muted,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Scrolling page body with the standard padding.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(44, 36, 44, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// A friendly empty or not-ready message with one action.
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return PorchCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          IconBox(icon: icon, size: 48),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: p.muted)),
              ],
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// The app icon drawn in the current theme's colors.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.porch;
    return CustomPaint(
      size: Size.square(size),
      painter: _LogoPainter(p.accent, p.on),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.accent, this.dot);

  final Color accent;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 512;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(115 * s)),
      Paint()..color = accent,
    );
    final house = Path()
      ..moveTo(156 * s, 238 * s)
      ..lineTo(256 * s, 154 * s)
      ..lineTo(356 * s, 238 * s)
      ..lineTo(356 * s, 358 * s)
      ..lineTo(156 * s, 358 * s)
      ..close();
    canvas.drawPath(
      house,
      Paint()
        ..color = const Color(0xFFFFF4E4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 32 * s
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(256 * s, 286 * s), 34 * s, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.accent != accent || old.dot != dot;
}
