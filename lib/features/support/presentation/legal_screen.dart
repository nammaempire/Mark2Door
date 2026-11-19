import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../application/content_providers.dart';
import '../data/content_repository.dart';

/// Terms and conditions or the privacy policy, as written by the admin.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.pageId});

  /// [LegalPage.termsId] or [LegalPage.privacyId].
  final String pageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(legalPageProvider(pageId));
    final title = LegalPage.titleOf(pageId);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AsyncValueView(
        value: page,
        onRetry: () => ref.invalidate(legalPageProvider(pageId)),
        data: (p) => p == null
            ? EmptyState(
                icon: Icons.description_outlined,
                title: '$title not available',
                message: 'The store has not published this page yet.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  if (p.updatedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Last updated ${formatOrderDate(p.updatedAt!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  SelectableText(
                    p.body,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
