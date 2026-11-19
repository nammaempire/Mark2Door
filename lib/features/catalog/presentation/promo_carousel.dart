import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/promo.dart';
import 'banner_art.dart';

/// Auto-advancing banner carousel with page dots.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key, required this.promos});

  final List<Promo> promos;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  Timer? _autoPlay;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _autoPlay = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients || widget.promos.length < 2) return;
      _controller.animateToPage(
        (_page + 1) % widget.promos.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoPlay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 172,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.promos.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              // Bottom room so the card's shadow is not clipped by the pager.
              padding: const EdgeInsets.fromLTRB(5, 0, 5, 14),
              child: _PromoCard(promo: widget.promos[i], index: i),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.promos.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? context.palette.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promo, required this.index});

  final Promo promo;

  /// Position in the carousel; picks the themed gradient in rotation.
  final int index;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);
    final themed = context.palette.bannerColors;
    final colors =
        themed == null ? promo.colors : themed[index % themed.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: context.palette.elevation,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          BannerArt(
            title: promo.title,
            subtitle: promo.subtitle,
            emoji: promo.emoji,
            colors: colors,
            layout: promo.layout,
          ),
          // The whole card is the tap target, whichever design is drawn.
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: () => context.push(Routes.category(promo.categoryId)),
            ),
          ),
        ],
      ),
    );
  }
}
