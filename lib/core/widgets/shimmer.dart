import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Sweeps a soft highlight across its [child] while content loads.
///
/// The child is a "skeleton": plain [SkeletonBox] shapes laid out like the
/// content that is on its way. The highlight is painted only where the
/// child paints, so cards and gaps keep their shape.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  static const _base = Color(0xFFF3DCE1);
  static const _highlight = Color(0xFFFFF7F9);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) {
            // Travels from fully left of the child to fully right of it.
            final t = _controller.value * 3 - 1;
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(t - 1, -0.3),
                end: Alignment(t + 1, 0.3),
                colors: const [_base, _highlight, _base],
                stops: const [0.25, 0.5, 0.75],
              ).createShader(bounds),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// One placeholder shape inside a [Shimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 10,
  });

  /// A line of text.
  const SkeletonBox.line({super.key, this.width, this.height = 12})
      : radius = 6;

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Any opaque colour: the shimmer repaints it.
        color: AppColors.border,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// White card that holds skeleton shapes, matching the app's real cards.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.child, this.padding = 12});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Shimmer(child: child),
    );
  }
}

/// Placeholder for one product card.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SkeletonCard(
      padding: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 124, width: double.infinity, radius: 14),
          SizedBox(height: 18),
          SkeletonBox.line(width: 54, height: 10),
          SizedBox(height: 8),
          SkeletonBox.line(width: 120, height: 14),
          SizedBox(height: 8),
          SkeletonBox.line(width: 46),
          SizedBox(height: 10),
          SkeletonBox.line(width: 70, height: 16),
        ],
      ),
    );
  }
}

/// Two-column grid of product placeholders, as a sliver.
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          mainAxisExtent: 244,
        ),
        itemCount: count,
        itemBuilder: (context, i) => const ProductCardSkeleton(),
      ),
    );
  }
}

/// Horizontal row of product placeholders.
class ProductRailSkeleton extends StatelessWidget {
  const ProductRailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 276,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) =>
            const SizedBox(width: 156, child: ProductCardSkeleton()),
      ),
    );
  }
}

/// Placeholder for the home banner carousel.
class BannerSkeleton extends StatelessWidget {
  const BannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 180,
      child: Padding(
        padding: EdgeInsets.fromLTRB(21, 0, 21, 22),
        child: Shimmer(
          child: SkeletonBox(width: double.infinity, radius: 24),
        ),
      ),
    );
  }
}

/// Placeholder for the "Shop by category" strip.
class CategoryStripSkeleton extends StatelessWidget {
  const CategoryStripSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => const SizedBox(
          width: 78,
          child: Column(
            children: [
              SkeletonBox(width: 72, height: 72, radius: 22),
              SizedBox(height: 8),
              SkeletonBox.line(width: 54, height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder for a list of cards: orders, addresses and similar.
class CardListSkeleton extends StatelessWidget {
  const CardListSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => const _SkeletonCard(
        padding: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox.line(width: 110, height: 16),
                Spacer(),
                SkeletonBox(width: 76, height: 24, radius: 12),
              ],
            ),
            SizedBox(height: 10),
            SkeletonBox.line(width: 140, height: 10),
            SizedBox(height: 14),
            SkeletonBox.line(width: double.infinity),
            SizedBox(height: 8),
            SkeletonBox.line(width: 180),
            SizedBox(height: 14),
            SkeletonBox(width: double.infinity, height: 36, radius: 12),
          ],
        ),
      ),
    );
  }
}

/// Placeholder for a detail page: large picture, title, then text blocks.
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.3,
              child: SkeletonBox(width: double.infinity, radius: 28),
            ),
            SizedBox(height: 22),
            SkeletonBox.line(width: 220, height: 24),
            SizedBox(height: 10),
            SkeletonBox.line(width: 70),
            SizedBox(height: 16),
            SkeletonBox.line(width: 130, height: 24),
            SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: SkeletonBox(height: 70, radius: 16)),
                SizedBox(width: 10),
                Expanded(child: SkeletonBox(height: 70, radius: 16)),
                SizedBox(width: 10),
                Expanded(child: SkeletonBox(height: 70, radius: 16)),
              ],
            ),
            SizedBox(height: 24),
            SkeletonBox.line(width: 160, height: 16),
            SizedBox(height: 12),
            SkeletonBox.line(width: double.infinity),
            SizedBox(height: 8),
            SkeletonBox.line(width: double.infinity),
            SizedBox(height: 8),
            SkeletonBox.line(width: 200),
          ],
        ),
      ),
    );
  }
}
