import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/presentation/auth_header.dart';
import '../application/pincode_controller.dart';
import '../data/service_area_repository.dart';

/// Gate that confirms we deliver to the shopper's pincode. Shown once after
/// login and again whenever they tap "change" on the home header.
class PincodeScreen extends ConsumerStatefulWidget {
  const PincodeScreen({super.key});

  @override
  ConsumerState<PincodeScreen> createState() => _PincodeScreenState();
}

class _PincodeScreenState extends ConsumerState<PincodeScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _controller =
      TextEditingController(text: ref.read(pincodeProvider) ?? '');
  bool _loading = false;
  String? _notServiceable;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_loading || !_formKey.currentState!.validate()) return;
    final pincode = _controller.text.trim();
    setState(() {
      _loading = true;
      _notServiceable = null;
    });
    try {
      final ok = await ref.read(pincodeProvider.notifier).trySet(pincode);
      if (!mounted) return;
      if (!ok) {
        setState(() => _notServiceable = pincode);
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.home);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not check that pincode. Try again.')),
      );
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
              const AuthHeader(compact: true),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Where should we deliver?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'mart2door delivers in selected areas. Enter your '
                        'pincode to check.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const ValueKey('pincode-field'),
                        controller: _controller,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: Validators.pincode,
                        onFieldSubmitted: (_) => _submit(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4,
                        ),
                        decoration: const InputDecoration(
                          hintText: '560034',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      if (_notServiceable != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          "Sorry, we don't deliver to $_notServiceable yet.",
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: LoadingLabel(
                          'Check availability',
                          loading: _loading,
                        ),
                      ),
                      if (!Env.useFirebase) ...[
                        const SizedBox(height: 20),
                        HintBanner(
                          'Sample-data mode: serviceable pincodes are '
                          '${FakeServiceAreaRepository.pincodes.join(', ')}.',
                        ),
                      ],
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
