import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../support/data/content_repository.dart';
import '../domain/app_user.dart';
import 'auth_header.dart';
import 'otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Ticked by the shopper: they accept the terms and privacy policy.
  bool _agreed = false;
  bool _agreeError = false;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_loading || !_formKey.currentState!.validate()) return;
    if (!_agreed) {
      // The OTP is sent only after the shopper accepts the two pages.
      setState(() => _agreeError = true);
      return;
    }

    final phone = '${AppConfig.countryCode}${_phoneController.text.trim()}';
    setState(() => _loading = true);
    try {
      final verificationId =
          await ref.read(authRepositoryProvider).sendOtp(phone);
      if (!mounted) return;
      context.push(
        Routes.otp,
        extra: OtpArgs(phone: phone, verificationId: verificationId),
      );
    } on AuthFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              const AuthHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Log in or sign up with your mobile number',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Mobile number',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const ValueKey('phone-field'),
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        autofillHints: const [
                          AutofillHints.telephoneNumberNational,
                        ],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: Validators.phone,
                        onFieldSubmitted: (_) => _submit(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                        decoration: const InputDecoration(
                          hintText: '98765 43210',
                          prefixIcon: _CountryPrefix(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: LoadingLabel('Get OTP', loading: _loading),
                      ),
                      const SizedBox(height: 16),
                      _LegalLinks(
                        agreed: _agreed,
                        showError: _agreeError && !_agreed,
                        onChanged: (v) => setState(() {
                          _agreed = v;
                          _agreeError = false;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountryPrefix extends StatelessWidget {
  const _CountryPrefix();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 16, right: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppConfig.countryCode,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(width: 10),
          SizedBox(
            height: 22,
            child: VerticalDivider(width: 1, color: AppColors.border),
          ),
        ],
      ),
    );
  }
}

/// The checkbox "I agree to the Terms and conditions and Privacy policy",
/// where both names open the page the store has published. It has to be
/// ticked before an OTP is sent.
class _LegalLinks extends StatelessWidget {
  const _LegalLinks({
    required this.agreed,
    required this.showError,
    required this.onChanged,
  });

  final bool agreed;
  final bool showError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const plain = TextStyle(
      fontSize: 12,
      height: 1.5,
      color: AppColors.textMuted,
    );
    Widget link(String key, String label, String pageId) => InkWell(
          key: ValueKey(key),
          onTap: () => context.push(Routes.publicLegal(pageId)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Text(
              label,
              style: plain.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primary,
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Checkbox(
                key: const ValueKey('agree-checkbox'),
                value: agreed,
                isError: showError,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => onChanged(!agreed),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('I agree to the ', style: plain),
                      ),
                    ),
                    link(
                      'login-terms-link',
                      'Terms and conditions',
                      LegalPage.termsId,
                    ),
                    const Text(' and ', style: plain),
                    link(
                      'login-privacy-link',
                      'Privacy policy',
                      LegalPage.privacyId,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (showError)
          const Padding(
            key: ValueKey('agree-error'),
            padding: EdgeInsets.only(left: 42, top: 2),
            child: Text(
              'Tick the box to accept and continue.',
              style: TextStyle(fontSize: 12, color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}
