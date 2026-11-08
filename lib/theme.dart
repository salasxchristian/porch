import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// One color theme. Read it in widgets with `context.porch`.
@immutable
class PorchPalette extends ThemeExtension<PorchPalette> {
  const PorchPalette({
    required this.id,
    required this.label,
    required this.bg,
    required this.side,
    required this.sideCard,
    required this.surface,
    required this.border,
    required this.strong,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.on,
    required this.onInk,
    required this.onSoft,
    required this.onBorder,
    required this.muted,
    required this.ink,
    required this.navInk,
    required this.track,
    required this.neutral,
    required this.link,
    required this.pill,
    required this.pillInk,
    required this.dark,
    required this.darkCard,
    required this.darkLine,
    required this.darkMuted,
  });

  final String id;
  final String label;

  /// Page background.
  final Color bg;

  /// Sidebar background and the card inside it.
  final Color side;
  final Color sideCard;

  /// Cards and raised controls.
  final Color surface;
  final Color border;
  final Color strong;

  /// Main brand color, text on it, and a soft tint of it.
  final Color accent;
  final Color accentInk;
  final Color accentSoft;

  /// Anything that is switched on: icon fill, its ink, card tint and border.
  final Color on;
  final Color onInk;
  final Color onSoft;
  final Color onBorder;

  final Color muted;
  final Color ink;
  final Color navInk;

  /// Switch track when off.
  final Color track;

  /// Icon box behind an off device.
  final Color neutral;
  final Color link;

  /// Small status pill (e.g. "Heating").
  final Color pill;
  final Color pillInk;

  /// Full-size camera side panel.
  final Color dark;
  final Color darkCard;
  final Color darkLine;
  final Color darkMuted;

  static const sage = PorchPalette(
    id: 'sage',
    label: 'Sage',
    bg: Color(0xFFF6F1E8),
    side: Color(0xFFEDE5D6),
    sideCard: Color(0xFFE3DACA),
    surface: Color(0xFFFFFDF8),
    border: Color(0xFFE6DED0),
    strong: Color(0xFFDCD2C1),
    accent: Color(0xFF3E5C4B),
    accentInk: Color(0xFFFFF4E4),
    accentSoft: Color(0xFFE3EBE5),
    on: Color(0xFFFFB547),
    onInk: Color(0xFF3A2600),
    onSoft: Color(0xFFFFF3DC),
    onBorder: Color(0xFFF0D29A),
    muted: Color(0xFF4D5A52),
    ink: Color(0xFF1F2A24),
    navInk: Color(0xFF3B4740),
    track: Color(0xFFCFC6B6),
    neutral: Color(0xFFEDE6DA),
    link: Color(0xFF2F4A3B),
    pill: Color(0xFFFFF0D6),
    pillInk: Color(0xFF8A5A00),
    dark: Color(0xFF18211C),
    darkCard: Color(0xFF1F2B24),
    darkLine: Color(0xFF2C3A31),
    darkMuted: Color(0xFFCBC3B5),
  );

  static const blue = PorchPalette(
    id: 'blue',
    label: 'Pastel blue',
    bg: Color(0xFFEEF4FA),
    side: Color(0xFFDCE7F3),
    sideCard: Color(0xFFCDDCEC),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFD9E3EE),
    strong: Color(0xFFC5D3E3),
    accent: Color(0xFF3D6A97),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFDCE8F5),
    on: Color(0xFFFFD27A),
    onInk: Color(0xFF3A2A00),
    onSoft: Color(0xFFFFF6DD),
    onBorder: Color(0xFFF1DA9C),
    muted: Color(0xFF475669),
    ink: Color(0xFF1B2633),
    navInk: Color(0xFF33465B),
    track: Color(0xFFC2CEDB),
    neutral: Color(0xFFE3EAF2),
    link: Color(0xFF2E5A86),
    pill: Color(0xFFFFF2CC),
    pillInk: Color(0xFF7A5600),
    dark: Color(0xFF151C25),
    darkCard: Color(0xFF1C2531),
    darkLine: Color(0xFF2A3646),
    darkMuted: Color(0xFFC3CEDB),
  );

  static const lilac = PorchPalette(
    id: 'lilac',
    label: 'Lilac',
    bg: Color(0xFFF6F1FA),
    side: Color(0xFFEAE0F4),
    sideCard: Color(0xFFDDCFEC),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE6DCF0),
    strong: Color(0xFFD6C8E6),
    accent: Color(0xFF6A4C99),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFEDE4F7),
    on: Color(0xFFF4AFC4),
    onInk: Color(0xFF4A1426),
    onSoft: Color(0xFFFCE9EF),
    onBorder: Color(0xFFEFC2D0),
    muted: Color(0xFF594D66),
    ink: Color(0xFF29213A),
    navInk: Color(0xFF463A55),
    track: Color(0xFFD3C7DF),
    neutral: Color(0xFFEFE8F6),
    link: Color(0xFF5A3E87),
    pill: Color(0xFFFCE3EB),
    pillInk: Color(0xFF86304C),
    dark: Color(0xFF1D1726),
    darkCard: Color(0xFF251E31),
    darkLine: Color(0xFF352B44),
    darkMuted: Color(0xFFD3C8DF),
  );

  static const all = [sage, blue, lilac];

  static PorchPalette byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => sage);

  @override
  PorchPalette copyWith() => this;

  @override
  PorchPalette lerp(PorchPalette? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension PorchContext on BuildContext {
  PorchPalette get porch =>
      Theme.of(this).extension<PorchPalette>() ?? PorchPalette.sage;
}

/// [useGoogleFonts] is off in tests, which can't fetch fonts.
ThemeData buildPorchTheme(PorchPalette p, {bool useGoogleFonts = true}) {
  final scheme = ColorScheme.fromSeed(seedColor: p.accent).copyWith(
    primary: p.accent,
    onPrimary: p.accentInk,
    surface: p.surface,
    onSurface: p.ink,
    onSurfaceVariant: p.muted,
    outline: p.strong,
    outlineVariant: p.border,
  );
  final base = ThemeData(colorScheme: scheme);
  final textTheme = useGoogleFonts
      ? GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
      : base.textTheme;
  final pill = WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
  );
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    textTheme: textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    extensions: [p],
    dialogTheme: DialogThemeData(backgroundColor: p.surface),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        shape: pill,
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        shape: pill,
        foregroundColor: WidgetStatePropertyAll(p.ink),
        backgroundColor: WidgetStatePropertyAll(p.surface),
        side: WidgetStatePropertyAll(BorderSide(color: p.strong)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(p.link)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? p.accent : p.track,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      thumbColor: p.accent,
      inactiveTrackColor: p.track,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.strong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.strong),
      ),
    ),
  );
}
