import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Banner colour themes. Keys are stored in `banners/{id}.theme` and must
/// match `kBannerThemes` in the admin web.
const bannerColors = <String, List<Color>>{
  // Brand reds and pinks.
  'maroon': [Color(0xFFA3203F), Color(0xFF5A0A1C)],
  'rose': [Color(0xFFE0607B), Color(0xFFA8243F)],
  'plum': [Color(0xFF8E2A5B), Color(0xFF55103A)],
  'berry': [Color(0xFFC2185B), Color(0xFF7A0F3A)],
  'coral': [Color(0xFFF0766A), Color(0xFFC23B4E)],
  'crimson': [Color(0xFFE53935), Color(0xFF9B1B1B)],
  'pink': [Color(0xFFF06292), Color(0xFFC2185B)],
  // Warm.
  'sunset': [Color(0xFFFF8A4C), Color(0xFFE0425A)],
  'orange': [Color(0xFFFF9838), Color(0xFFD9580F)],
  'amber': [Color(0xFFF2A91E), Color(0xFFC96F08)],
  'gold': [Color(0xFFD9A63A), Color(0xFF94661A)],
  'chocolate': [Color(0xFF8D5B43), Color(0xFF4E2C1E)],
  // Greens.
  'lime': [Color(0xFF8BC34A), Color(0xFF4F8A1D)],
  'green': [Color(0xFF43A862), Color(0xFF1B6B3A)],
  'forest': [Color(0xFF2E7D5B), Color(0xFF12402F)],
  'teal': [Color(0xFF26A69A), Color(0xFF0E6B62)],
  // Blues.
  'aqua': [Color(0xFF29B6D8), Color(0xFF0B7397)],
  'sky': [Color(0xFF4FA8F0), Color(0xFF1E66C2)],
  'blue': [Color(0xFF3F7BE0), Color(0xFF1C3F99)],
  'navy': [Color(0xFF34497A), Color(0xFF15203F)],
  // Purples.
  'indigo': [Color(0xFF5C6BC0), Color(0xFF2C3690)],
  'violet': [Color(0xFF8E5BD9), Color(0xFF512A9E)],
  'grape': [Color(0xFFAB47BC), Color(0xFF6A1B7A)],
  // Neutrals.
  'slate': [Color(0xFF607D8B), Color(0xFF30424B)],
  'charcoal': [Color(0xFF4A4A52), Color(0xFF1D1D22)],
};

/// A promo banner on the home page (`banners/{id}`).
@immutable
class Promo {
  const Promo({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.theme,
    required this.categoryId,
    this.layout = 'classic',
  });

  final String title;
  final String subtitle;
  final String emoji;
  final String theme;

  /// Design key; see `bannerLayouts` in `banner_art.dart`. Chosen in the
  /// admin web and stored in `banners/{id}.layout`.
  final String layout;

  /// Category opened when the banner is tapped.
  final String categoryId;

  /// Unknown or legacy theme keys fall back to maroon.
  List<Color> get colors => bannerColors[theme] ?? bannerColors['maroon']!;

  factory Promo.fromMap(Map<String, dynamic> map) => Promo(
        title: map['title'] as String? ?? '',
        subtitle: map['subtitle'] as String? ?? '',
        emoji: map['emoji'] as String? ?? '',
        theme: map['theme'] as String? ?? 'maroon',
        categoryId: map['categoryId'] as String? ?? '',
        layout: map['layout'] as String? ?? 'classic',
      );
}
