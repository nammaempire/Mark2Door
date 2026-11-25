import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../auth/application/auth_providers.dart';
import '../orders/domain/order.dart';
import '../profile/application/customer_name.dart';
import 'reviews.dart';

const _star = Color(0xFFF5A623);

/// Five stars, [value] of them filled. With [onChanged] they can be
/// tapped to choose a rating.
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.value,
    this.size = 16,
    this.onChanged,
    this.keyPrefix = 'star',
  });

  final num value;
  final double size;
  final ValueChanged<int>? onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            key: ValueKey('$keyPrefix-$i'),
            onTap: onChanged == null ? null : () => onChanged!(i),
            child: Padding(
              padding: EdgeInsets.all(onChanged == null ? 0 : 4),
              child: Icon(
                value >= i
                    ? Icons.star_rounded
                    : value >= i - 0.5
                        ? Icons.star_half_rounded
                        : Icons.star_outline_rounded,
                size: size,
                color: _star,
              ),
            ),
          ),
      ],
    );
  }
}

/// "Ratings and reviews" on the product page: the average, how many, and
/// what customers wrote. Says so when there are none yet.
class ProductReviews extends ConsumerWidget {
  const ProductReviews({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(productReviewsProvider(productId)).valueOrNull;
    if (summary == null) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('product-reviews'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        const Text(
          'Ratings and reviews',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        if (summary.count == 0)
          const Text(
            'No reviews yet. Customers who buy this can review it from '
            'their order.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          )
        else ...[
          Row(
            children: [
              Text(
                summary.average.toStringAsFixed(1),
                key: const ValueKey('review-average'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StarRow(value: summary.average, size: 18),
                  Text(
                    summary.count == 1
                        ? '1 review'
                        : '${summary.count} reviews',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final r in summary.reviews.take(10))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.name.isEmpty ? 'mart2door customer' : r.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      StarRow(value: r.rating, size: 14),
                    ],
                  ),
                  if (r.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        r.text,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// On a delivered order, next to each item: "Review" opens the review
/// sheet; once written it shows the stars given and can be edited.
class ReviewItemButton extends ConsumerWidget {
  const ReviewItemButton({super.key, required this.order, required this.item});

  final Order order;
  final OrderItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid ?? '';
    final mine = ref
        .watch(productReviewsProvider(item.productId))
        .valueOrNull
        ?.by(uid);
    return TextButton(
      key: ValueKey('review-${item.productId}'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _ReviewSheet(order: order, item: item, existing: mine),
      ),
      child: mine == null
          ? const Text('Write a review')
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StarRow(value: mine.rating, size: 14),
                const SizedBox(width: 6),
                const Text('Edit'),
              ],
            ),
    );
  }
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({
    required this.order,
    required this.item,
    required this.existing,
  });

  final Order order;
  final OrderItem item;
  final Review? existing;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  late int _rating = widget.existing?.rating ?? 0;
  late final _text = TextEditingController(text: widget.existing?.text ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_rating == 0) {
      setState(() => _error = 'Tap a star to rate this product.');
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final name = ref.read(customerNameProvider).trim();
    try {
      await ref.read(reviewRepositoryProvider).save(
            widget.item.productId,
            Review(
              uid: user.uid,
              // First name only: it is shown to other customers.
              name: name.isEmpty
                  ? widget.order.address.name.trim().split(' ').first
                  : name.split(' ').first,
              rating: _rating,
              text: _text.text.trim(),
              createdAt: DateTime.now(),
              orderId: widget.order.id,
            ),
          );
      ref.invalidate(productReviewsProvider(widget.item.productId));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Thanks. Your review is posted.')),
        );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not post your review. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Review ${widget.item.name}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Other customers will see your first name, stars and words.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Center(
            child: StarRow(
              value: _rating,
              size: 38,
              keyPrefix: 'review-star',
              onChanged: (v) => setState(() {
                _rating = v;
                _error = null;
              }),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('review-text'),
            controller: _text,
            maxLength: Review.maxText,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Your review (optional)',
              hintText: 'How was the quality?',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                key: const ValueKey('review-error'),
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          FilledButton(
            key: const ValueKey('review-submit'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Posting' : 'Post review'),
          ),
        ],
      ),
    );
  }
}
