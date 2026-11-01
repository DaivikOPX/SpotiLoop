import 'dart:ui';

/// SpotiLoop design system · "Loop Studio"
/// Dark, audio-hardware inspired. One accent (Spotify green), two
/// functional marker tones (emerald Point A / coral Point B).
/// Mirrors the CSS tokens of the web build (index.html).
class SpotiTheme {
  // Canvas + surfaces (elevation tiers)
  static const Color bg = Color(0xFF05070A);
  static const Color surface1 = Color(0xFF0B0E14);
  static const Color surface2 = Color(0xFF10141B);
  static const Color surface3 = Color(0xFF171C25);

  // Hairlines
  static const Color stroke = Color(0x12FFFFFF); // ~7% white
  static const Color strokeStrong = Color(0x24FFFFFF); // ~14% white

  // Text
  static const Color textStrong = Color(0xFFF2F5F9);
  static const Color muted = Color(0xFF8A93A6);
  static const Color faint = Color(0xFF5A6478);

  // Accent
  static const Color green = Color(0xFF1ED760);
  static const Color greenDeep = Color(0xFF169C46);
  static const Color onGreen = Color(0xFF04140B);
  static const Color greenTint = Color(0x1A1ED760); // ~10%
  static const Color greenStroke = Color(0x661ED760); // ~40%

  // Markers
  static const Color pointA = Color(0xFF00E676);
  static const Color pointB = Color(0xFFFF4757);
  static const Color pointATint = Color(0x1A00E676);
  static const Color pointBTint = Color(0x1AFF4757);

  // Radii
  static const double cardRadius = 20;
  static const double insetRadius = 14;
}
