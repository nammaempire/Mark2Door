import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';

/// A customer's review of a product they bought: 1 to 5 stars and a few
/// words. One review per customer per product; writing again replaces it.
///
/// Firestore: `products/{productId}/reviews/{uid}`.
@immutable
class Review {
  const Review({
    required this.uid,
    required this.name,
    required this.rating,
    required this.text,
    required this.createdAt,
    this.orderId = '',
  });

  final String uid;

  /// The reviewer's name as shown to other customers.
  final String name;
  final int rating;
  final String text;
  final DateTime createdAt;

  /// The delivered order this purchase was part of.
  final String orderId;

  static const maxText = 300;

  factory Review.fromMap(String uid, Map<String, dynamic> map) => Review(
        uid: uid,
        name: (map['name'] as String? ?? '').trim(),
        rating: ((map['rating'] as num?)?.toInt() ?? 0).clamp(1, 5),
        text: (map['text'] as String? ?? '').trim(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['createdAt'] as num?)?.toInt() ?? 0,
        ),
        orderId: map['orderId'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'rating': rating,
        'text': text,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'orderId': orderId,
      };
}

/// The reviews of one product with their average.
@immutable
class ReviewSummary {
  const ReviewSummary(this.reviews);

  /// Newest first.
  final List<Review> reviews;

  int get count => reviews.length;

  double get average => reviews.isEmpty
      ? 0
      : reviews.fold(0, (sum, r) => sum + r.rating) / reviews.length;

  /// The review written by [uid], if any.
  Review? by(String uid) {
    for (final r in reviews) {
      if (r.uid == uid) return r;
    }
    return null;
  }
}

abstract interface class ReviewRepository {
  Future<List<Review>> fetch(String productId);

  /// Saves [review], replacing the same customer's earlier one.
  Future<void> save(String productId, Review review);
}

class FakeReviewRepository implements ReviewRepository {
  final Map<String, Map<String, Review>> _byProduct = {
    'p01': {
      'sample-1': Review(
        uid: 'sample-1',
        name: 'Ananya',
        rating: 5,
        text: 'Fresh and sweet. Came well packed.',
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      'sample-2': Review(
        uid: 'sample-2',
        name: 'Rahul',
        rating: 4,
        text: 'Good quality for the price.',
        createdAt: DateTime.now().subtract(const Duration(days: 9)),
      ),
    },
  };

  @override
  Future<List<Review>> fetch(String productId) async {
    final list = [...?_byProduct[productId]?.values]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> save(String productId, Review review) async {
    _byProduct.putIfAbsent(productId, () => {})[review.uid] = review;
  }
}

class FirestoreReviewRepository implements ReviewRepository {
  FirestoreReviewRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _reviews(String productId) =>
      _db.collection('products').doc(productId).collection('reviews');

  @override
  Future<List<Review>> fetch(String productId) async {
    final snap = await _reviews(productId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return [for (final d in snap.docs) Review.fromMap(d.id, d.data())];
  }

  @override
  Future<void> save(String productId, Review review) =>
      _reviews(productId).doc(review.uid).set(review.toMap());
}

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => Env.useFirebase
      ? FirestoreReviewRepository(FirebaseFirestore.instance)
      : FakeReviewRepository(),
);

/// Reviews of one product; refreshed after the shopper writes one.
final productReviewsProvider =
    FutureProvider.family<ReviewSummary, String>((ref, productId) async {
  final list = await ref.watch(reviewRepositoryProvider).fetch(productId);
  return ReviewSummary(list);
});
