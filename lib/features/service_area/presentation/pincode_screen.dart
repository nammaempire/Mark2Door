import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/presentation/auth_header.dart';
import '../application/pincode_controller.dart';

/// Asks where the shopper wants delivery. Shown once after login and again
/// whenever they tap the pincode on the home header. Any valid pincode is
/// accepted; the home page says so if we do not deliver there yet.
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_loading || !_formKey.currentState!.validate()) return;
    final pincode = _controller.text.trim();
    setState(() => _loading = true);
    // Saving the pincode makes the router re-check its routes. When this
    // page was opened from inside the app it is closed first, because a
    // re-check that is still running would put the closed page back.
    final pincodes = ref.read(pincodeProvider.notifier);
    final router = GoRouter.of(context);
    try {
      if (router.canPop()) {
        router.pop();
        await pincodes.set(pincode);
      } else {
        await pincodes.set(pincode);
        router.go(Routes.home);
      }
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
                        'Enter your pincode to see the store. mart2door '
                        'delivers in selected areas.',
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
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: LoadingLabel('Continue', loading: _loading),
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
