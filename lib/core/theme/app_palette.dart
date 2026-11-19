import 'package:flutter/material.dart';

/// Brand colours for surfaces and cards. Widgets read them with
/// `context.palette`, so a future re-skin (or a per-screen variation)
/// means supplying a different palette through the theme, not editing
/// widgets.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.primarySoft,
    required this.background,
    required this.cardShadow,
    this.cardColors,
    this.artColors,
    this.bannerColors,
    this.stripColors,
  });

  /// The approved mart2door look: maroon primary on a light pink page,
  /// cards in a very light pink with a small maroon-tinted shadow.
  static const brand = AppPalette(
    primary: Color(0xFF800020),
    primaryLight: Color(0xFF9F1D3F),
    primaryDark: Color(0xFF5A0A1C),
    primarySoft: Color(0xFFF9DFE5),
    background: Color(0xFFFFF0F3),
    cardShadow: Color(0x24800020),
    cardColors: [Color(0xFFFFFFFF), Color(0xFFFFF7F9)],
    artColors: [Color(0xFFFFF5F7), Color(0xFFFDE5EA)],
    stripColors: [Color(0xFFD9506C), Color(0xFF9A1B38)],
  );

  final Color primary;

  /// Lighter end of header gradients.
  final Color primaryLight;
  final Color primaryDark;

  /// Tint for selected chips and navigation indicators.
  final Color primarySoft;

  /// Page background.
  final Color background;

  /// Drop-shadow colour that gives cards their elevation.
  final Color cardShadow;

  /// Top-to-bottom wash for product cards. Null => per-category colours.
  final List<Color>? cardColors;

  /// Gradient behind product and category artwork. Null => per-category.
  final List<Color>? artColors;

  /// Gradients for promo banners, used in rotation. Null => each banner's
  /// own colour theme from the admin.
  final List<List<Color>>? bannerColors;

  /// Gradient for the free-delivery strip. Null => the orange accent.
  final List<Color>? stripColors;

  /// Small elevation shared by every card.
  List<BoxShadow> get elevation => [
        BoxShadow(
          color: cardShadow,
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];

  /// [base] re-coloured with this palette, for scoping to part of the tree.
  ThemeData applyTo(ThemeData base) => base.copyWith(
        extensions: [this],
        scaffoldBackgroundColor: background,
        colorScheme: base.colorScheme.copyWith(primary: primary),
        navigationBarTheme:
            base.navigationBarTheme.copyWith(indicatorColor: primarySoft),
      );

  @override
  AppPalette copyWith({
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? primarySoft,
    Color? background,
    Color? cardShadow,
    List<Color>? cardColors,
    List<Color>? artColors,
    List<List<Color>>? bannerColors,
    List<Color>? stripColors,
  }) =>
      AppPalette(
        primary: primary ?? this.primary,
        primaryLight: primaryLight ?? this.primaryLight,
        primaryDark: primaryDark ?? this.primaryDark,
        primarySoft: primarySoft ?? this.primarySoft,
        background: background ?? this.background,
        cardShadow: cardShadow ?? this.cardShadow,
        cardColors: cardColors ?? this.cardColors,
        artColors: artColors ?? this.artColors,
        bannerColors: bannerColors ?? this.bannerColors,
        stripColors: stripColors ?? this.stripColors,
      );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    // Gradient lists switch at the midpoint; single colours blend smoothly.
    final lists = t < 0.5 ? this : other;
    return AppPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      background: Color.lerp(background, other.background, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      cardColors: lists.cardColors,
      artColors: lists.artColors,
      bannerColors: lists.bannerColors,
      stripColors: lists.stripColors,
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// The palette in force here.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.brand;
}
