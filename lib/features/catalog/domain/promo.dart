import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Banner colour themes. Keys are stored in `banners/{id}.theme` and must
/// match `kBannerThemes` in the admin web.
const bannerColors = <String, List<Color>>{
  'maroon': [Color(0xFFA3203F), Color(0xFF5A0A1C)],
  'rose': [Color(0xFFE0607B), Color(0xFFA8243F)],
  'plum': [Color(0xFF8E2A5B), Color(0xFF55103A)],
  'berry': [Color(0xFFC2185B), Color(0xFF7A0F3A)],
  'coral': [Color(0xFFF0766A), Color(0xFFC23B4E)],
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
  });

  final String title;
  final String subtitle;
  final String emoji;
  final String theme;

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
      );
}
