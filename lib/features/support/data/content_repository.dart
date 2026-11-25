import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// A question and answer on the help page (`faqs/{id}`).
@immutable
class Faq {
  const Faq({required this.question, required this.answer});

  final String question;
  final String answer;
}

/// Terms and conditions or the privacy policy (`pages/{id}`).
@immutable
class LegalPage {
  const LegalPage({required this.body, this.updatedAt});

  static const termsId = 'terms';
  static const privacyId = 'privacy';

  static String titleOf(String id) =>
      id == privacyId ? 'Privacy policy' : 'Terms and conditions';

  final String body;
  final DateTime? updatedAt;
}

/// Help and legal text, written by the admin in the admin web.
abstract interface class ContentRepository {
  /// In the admin's order.
  Future<List<Faq>> fetchFaqs();

  /// Null when the admin has not written the page, or has deleted it.
  Future<LegalPage?> fetchPage(String id);
}

class FakeContentRepository implements ContentRepository {
  @override
  Future<List<Faq>> fetchFaqs() async => const [
        Faq(
          question: 'How long does delivery take?',
          answer: 'Most orders arrive within the time shown at the top of '
              'the home page.',
        ),
        Faq(
          question: 'How do I pay?',
          answer: 'Pay online at checkout, or with cash when your order '
              'arrives.',
        ),
      ];

  @override
  Future<LegalPage?> fetchPage(String id) async => LegalPage(
        body: 'Sample ${LegalPage.titleOf(id).toLowerCase()} text.',
      );
}

class FirestoreContentRepository implements ContentRepository {
  FirestoreContentRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<List<Faq>> fetchFaqs() async {
    final snap = await _db.collection('faqs').orderBy('sortOrder').get();
    return [
      for (final d in snap.docs)
        // Questions written for the delivery app are not shown here.
        if (d.data()['app'] != 'delivery')
          Faq(
            question: d.data()['question'] as String? ?? '',
            answer: d.data()['answer'] as String? ?? '',
          ),
    ];
  }

  @override
  Future<LegalPage?> fetchPage(String id) async {
    final data = (await _db.collection('pages').doc(id).get()).data();
    final body = (data?['body'] as String? ?? '').trim();
    if (body.isEmpty) return null;
    final updated = (data?['updatedAt'] as num?)?.toInt();
    return LegalPage(
      body: body,
      updatedAt:
          updated == null ? null : DateTime.fromMillisecondsSinceEpoch(updated),
    );
  }
}
