import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/application/auth_providers.dart';
import '../../service_area/application/pincode_controller.dart';
import '../application/address_book.dart';
import '../domain/address.dart';

/// Opens the list of saved addresses so the shopper can pick, edit, delete
/// or add one. The choice is applied to [addressBookProvider] directly.
Future<void> showAddressPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => const _AddressPickerSheet(),
  );
}

/// Opens the address form. Returns the entered address, or null when the
/// sheet is dismissed.
Future<Address?> showAddressForm(BuildContext context, {Address? initial}) {
  return showModalBottomSheet<Address>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _AddressFormSheet(initial: initial),
  );
}

class _AddressPickerSheet extends ConsumerWidget {
  const _AddressPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(addressBookProvider);
    final controller = ref.read(addressBookProvider.notifier);

    Future<void> addNew() async {
      final address = await showAddressForm(context);
      if (address == null) return;
      controller.use(address);
      if (context.mounted) Navigator.of(context).pop();
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Deliver to',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: book.addresses.length,
                separatorBuilder: (_, __) =>
                    const Divider(indent: 16, endIndent: 16),
                itemBuilder: (context, i) {
                  final address = book.addresses[i];
                  final selected = i == book.selectedIndex;
                  return ListTile(
                    key: ValueKey('saved-address-$i'),
                    onTap: () {
                      controller.select(i);
                      Navigator.of(context).pop();
                    },
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color:
                          selected ? AppColors.primary : AppColors.textMuted,
                    ),
                    title: Text(
                      address.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('${address.singleLine}\n${address.phone}'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit address',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () async {
                            final edited = await showAddressForm(
                              context,
                              initial: address,
                            );
                            if (edited != null) controller.replace(i, edited);
                          },
                        ),
                        IconButton(
                          key: ValueKey('delete-address-$i'),
                          tooltip: 'Delete address',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => controller.remove(i),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: OutlinedButton.icon(
                key: const ValueKey('add-address-button'),
                onPressed: addNew,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add new address'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressFormSheet extends ConsumerStatefulWidget {
  const _AddressFormSheet({this.initial});

  final Address? initial;

  @override
  ConsumerState<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final AddressFields _fields;

  @override
  void initState() {
    super.initState();
    _fields = AddressFields.from(
      widget.initial,
      phone: ref.read(currentUserProvider)?.phone ?? '',
      pincode: ref.read(pincodeProvider) ?? '',
    );
  }

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_fields.toAddress());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the form above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                  child: Text(
                    widget.initial == null ? 'New address' : 'Edit address',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                AddressFormFields(
                  fields: _fields,
                  keyPrefix: 'new-',
                  showPincode: true,
                ),
                const SizedBox(height: 4),
                FilledButton(
                  key: const ValueKey('save-address-button'),
                  onPressed: _save,
                  child: const Text('Save address'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Text controllers for one address, shared by the first-order form on the
/// checkout page and the add/edit sheet.
class AddressFields {
  AddressFields({
    String name = '',
    String phone = '',
    String line1 = '',
    String landmark = '',
    String pincode = '',
  })  : name = TextEditingController(text: name),
        phone = TextEditingController(text: phone),
        line1 = TextEditingController(text: line1),
        landmark = TextEditingController(text: landmark),
        pincode = TextEditingController(text: pincode);

  /// Starts from [address], or from the shopper's login [phone] and
  /// current [pincode] for a new one.
  factory AddressFields.from(
    Address? address, {
    required String phone,
    required String pincode,
  }) =>
      AddressFields(
        name: address?.name ?? '',
        phone: address?.phone ?? phone.replaceFirst(AppConfig.countryCode, ''),
        line1: address?.line1 ?? '',
        landmark: address?.landmark ?? '',
        pincode: address?.pincode ?? pincode,
      );

  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController line1;
  final TextEditingController landmark;
  final TextEditingController pincode;

  Address toAddress({String? pincodeOverride}) => Address(
        name: name.text.trim(),
        phone: phone.text.trim(),
        line1: line1.text.trim(),
        landmark: landmark.text.trim(),
        pincode: pincodeOverride ?? pincode.text.trim(),
      );

  void dispose() {
    name.dispose();
    phone.dispose();
    line1.dispose();
    landmark.dispose();
    pincode.dispose();
  }
}

/// The address inputs. Must sit inside a [Form] to be validated.
class AddressFormFields extends StatelessWidget {
  const AddressFormFields({
    super.key,
    required this.fields,
    this.keyPrefix = '',
    this.showPincode = false,
  });

  final AddressFields fields;

  /// Distinguishes the sheet's fields from the checkout page's.
  final String keyPrefix;
  final bool showPincode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _field(
          key: 'name-field',
          controller: fields.name,
          label: 'Full name',
          validator: Validators.required('your name'),
          capitalization: TextCapitalization.words,
          autofill: AutofillHints.name,
        ),
        _field(
          key: 'address-phone-field',
          controller: fields.phone,
          label: 'Mobile number',
          validator: Validators.phone,
          keyboard: TextInputType.phone,
          formatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        _field(
          key: 'line1-field',
          controller: fields.line1,
          label: 'House / flat, street, area',
          validator: Validators.required('your address'),
          capitalization: TextCapitalization.sentences,
          autofill: AutofillHints.streetAddressLine1,
        ),
        _field(
          key: 'landmark-field',
          controller: fields.landmark,
          label: 'Landmark (optional)',
          capitalization: TextCapitalization.sentences,
        ),
        if (showPincode)
          _field(
            key: 'address-pincode-field',
            controller: fields.pincode,
            label: 'Pincode',
            validator: Validators.pincode,
            keyboard: TextInputType.number,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
          ),
      ],
    );
  }

  Widget _field({
    required String key,
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    TextCapitalization capitalization = TextCapitalization.none,
    String? autofill,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey('$keyPrefix$key'),
        controller: controller,
        validator: validator,
        keyboardType: keyboard,
        inputFormatters: formatters,
        textCapitalization: capitalization,
        textInputAction: TextInputAction.next,
        autofillHints: autofill == null ? null : [autofill],
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
