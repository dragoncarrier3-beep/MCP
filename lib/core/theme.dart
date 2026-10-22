import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// MPC brand tokens. Source: Mosaic Mobile App Developer Brief v1.0.
class Brand {
  static const navy = Color(0xFF0B2545);
  static const navy2 = Color(0xFF13315C);
  static const blue = Color(0xFF1F4E8C);
  static const bronze = Color(0xFFA67C3D);
  static const bronzeLight = Color(0xFFC9A266);
  static const bronzeDeep = Color(0xFF7A5A26);
  static const bronzeTint = Color(0xFFFBF3E6);
  static const bronzeBorder = Color(0xFFEAD7B6);
  static const bg = Color(0xFFF4F6F9);
  static const card = Color(0xFFFFFFFF);
  static const gain = Color(0xFF14804A);
  static const loss = Color(0xFFC0392B);
  static const gainBg = Color(0xFFE3F4EA);
  static const lossBg = Color(0xFFFBE7E5);
  static const muted = Color(0xFF6B7A90);
  static const cash = Color(0xFF8DA9C4);
}

/// Semantic palette that switches between light and dark.
@immutable
class Palette extends ThemeExtension<Palette> {
  final Color bg, card, text, muted, border, gain, loss, gainBg, lossBg, bronze, bronzeTint, bronzeBorder, navyCard, chip;
  const Palette({
    required this.bg,
    required this.card,
    required this.text,
    required this.muted,
    required this.border,
    required this.gain,
    required this.loss,
    required this.gainBg,
    required this.lossBg,
    required this.bronze,
    required this.bronzeTint,
    required this.bronzeBorder,
    required this.navyCard,
    required this.chip,
  });

  static const light = Palette(
    bg: Brand.bg,
    card: Brand.card,
    text: Brand.navy,
    muted: Brand.muted,
    border: Color(0xFFE4E9F0),
    gain: Brand.gain,
    loss: Brand.loss,
    gainBg: Brand.gainBg,
    lossBg: Brand.lossBg,
    bronze: Brand.bronze,
    bronzeTint: Brand.bronzeTint,
    bronzeBorder: Brand.bronzeBorder,
    navyCard: Brand.navy,
    chip: Color(0xFFEDF1F6),
  );

  /// Navy-based dark surfaces. No pure black.
  static const dark = Palette(
    bg: Color(0xFF071A33),
    card: Color(0xFF102A4C),
    text: Color(0xFFE8EEF6),
    muted: Color(0xFF9CADC4),
    border: Color(0xFF1E3D66),
    gain: Color(0xFF4CC38A),
    loss: Color(0xFFF07B6E),
    gainBg: Color(0xFF123D33),
    lossBg: Color(0xFF45232A),
    bronze: Brand.bronzeLight,
    bronzeTint: Color(0xFF2B2A2A),
    bronzeBorder: Color(0xFF5E4A2C),
    navyCard: Color(0xFF13315C),
    chip: Color(0xFF173659),
  );

  @override
  Palette copyWith() => this;
  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) => t < .5 ? this : (other as Palette? ?? this);
}

extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

const tabular = [FontFeature.tabularFigures()];

/// Set false in tests to avoid runtime font fetching.
bool useBrandFonts = true;

TextStyle inter({double? fontSize, FontWeight? fontWeight, Color? color, List<FontFeature>? fontFeatures, double? letterSpacing}) {
  final s = TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color, fontFeatures: fontFeatures, letterSpacing: letterSpacing);
  return useBrandFonts ? GoogleFonts.inter(textStyle: s) : s;
}

/// Tabular-figure style for all financial values.
TextStyle numStyle(double size, {FontWeight weight = FontWeight.w600, Color? color}) =>
    inter(fontSize: size, fontWeight: weight, color: color, fontFeatures: tabular, letterSpacing: -0.2);

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.light ? Palette.light : Palette.dark;
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Brand.navy,
      brightness: b,
      primary: b == Brightness.light ? Brand.navy : const Color(0xFFBFD2EC),
      secondary: Brand.bronze,
      surface: p.card,
    ),
    scaffoldBackgroundColor: p.bg,
  );
  final text = (useBrandFonts ? GoogleFonts.interTextTheme(base.textTheme) : base.textTheme).apply(bodyColor: p.text, displayColor: p.text);
  return base.copyWith(
    textTheme: text,
    extensions: [p],
    dividerColor: p.border,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: inter(fontSize: 16, fontWeight: FontWeight.w700, color: p.text),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: b == Brightness.light ? Brand.navy : const Color(0xFF1E3D66),
      contentTextStyle: inter(color: Colors.white, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Brand.bronze : null),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.bronze, width: 1.5)),
    ),
  );
}
