import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Banner colour themes. Keys are stored in `banners/{id}.theme` and must
/// match `kBannerThemes` in the admin web.
const bannerColors = <String, List<Color>>{
  'green': [Color(0xFF1FA463), Color(0xFF0A6B40)],
  'orange': [Color(0xFFFF9D3C), Color(0xFFEE5A0B)],
  'purple': [Color(0xFF7C5CFF), Color(0xFF4B2FCB)],
  'blue': [Color(0xFF2F9BFF), Color(0xFF155FCB)],
  'pink': [Color(0xFFFF6FA3), Color(0xFFD42A6B)],
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

  List<Color> get colors => bannerColors[theme] ?? bannerColors['green']!;

  factory Promo.fromMap(Map<String, dynamic> map) => Promo(
        title: map['title'] as String? ?? '',
        subtitle: map['subtitle'] as String? ?? '',
        emoji: map['emoji'] as String? ?? '',
        theme: map['theme'] as String? ?? 'green',
        categoryId: map['categoryId'] as String? ?? '',
      );
}
