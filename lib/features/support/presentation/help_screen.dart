import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/launchers.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../store/application/store_providers.dart';
import '../application/content_providers.dart';

/// Help and support: the admin's questions and answers, and a way to
/// write to the store.
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqs = ref.watch(faqsProvider);
    final email = ref.watch(storeSettingsProvider).supportEmail;
    final phone = ref.watch(currentUserProvider)?.phone ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Help and support')),
      body: Column(
        children: [
          Expanded(
            child: AsyncValueView(
              value: faqs,
              onRetry: () => ref.invalidate(faqsProvider),
              data: (items) => items.isEmpty
                  ? EmptyState(
                      icon: Icons.help_outline_rounded,
                      title: 'How can we help?',
                      message: email.isEmpty
                          ? 'Answers to common questions will appear here.'
                          : 'Write to us and we will get back to you.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
                          child: Text(
                            'Common questions',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        for (final faq in items)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            clipBehavior: Clip.antiAlias,
                            child: Theme(
                              // No divider lines inside the rounded card.
                              data: Theme.of(context).copyWith(
                                dividerColor: Colors.transparent,
                              ),
                              child: ExpansionTile(
                                title: Text(
                                  faq.question,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                childrenPadding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                expandedAlignment: Alignment.centerLeft,
                                children: [
                                  Text(
                                    faq.answer,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          if (email.isNotEmpty)
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Didn't find your answer?",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        key: const ValueKey('email-support-button'),
                        onPressed: () => Launchers.email(
                          context,
                          email,
                          subject: 'mart2door help ($phone)',
                        ),
                        icon: const Icon(Icons.mail_outline_rounded),
                        label: Text('Email $email'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
