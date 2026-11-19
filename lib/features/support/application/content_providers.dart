import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/content_repository.dart';

final faqsProvider = FutureProvider.autoDispose<List<Faq>>(
  (ref) => ref.watch(contentRepositoryProvider).fetchFaqs(),
);

final legalPageProvider =
    FutureProvider.autoDispose.family<LegalPage?, String>(
  (ref, id) => ref.watch(contentRepositoryProvider).fetchPage(id),
);
