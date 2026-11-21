import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/location/location_service.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/application/auth_providers.dart';
import '../../profile/application/customer_name.dart';
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
      name: ref.read(customerNameProvider),
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
    MapPin? pin,
  })  : pin = ValueNotifier(pin),
        name = TextEditingController(text: name),
        phone = TextEditingController(text: phone),
        line1 = TextEditingController(text: line1),
        landmark = TextEditingController(text: landmark),
        pincode = TextEditingController(text: pincode);

  /// Starts from [address], or from the shopper's [name], login [phone]
  /// and current [pincode] for a new one.
  factory AddressFields.from(
    Address? address, {
    required String phone,
    required String pincode,
    String name = '',
  }) =>
      AddressFields(
        name: address?.name ?? name,
        phone: address?.phone ?? phone.replaceFirst(AppConfig.countryCode, ''),
        line1: address?.line1 ?? '',
        landmark: address?.landmark ?? '',
        pincode: address?.pincode ?? pincode,
        pin: address != null && address.hasPin
            ? (lat: address.lat!, lng: address.lng!)
            : null,
      );

  /// The spot pinned with "Use my current location"; null until pinned.
  final ValueNotifier<MapPin?> pin;

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
        lat: pin.value?.lat,
        lng: pin.value?.lng,
      );

  void dispose() {
    pin.dispose();
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
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PinLocation(pin: fields.pin, keyPrefix: keyPrefix),
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

/// "Use my current location": saves where the phone is as the exact spot
/// for this address, so the delivery partner's map goes to the door and
/// not to a guess from the typed address. Optional.
class _PinLocation extends ConsumerStatefulWidget {
  const _PinLocation({required this.pin, required this.keyPrefix});

  final ValueNotifier<MapPin?> pin;
  final String keyPrefix;

  @override
  ConsumerState<_PinLocation> createState() => _PinLocationState();
}

class _PinLocationState extends ConsumerState<_PinLocation> {
  bool _busy = false;
  String? _error;

  Future<void> _pin() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final at = await ref.read(locationServiceProvider).current();
      if (!mounted) return;
      widget.pin.value = at;
    } on LocationFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MapPin?>(
      valueListenable: widget.pin,
      builder: (context, pin, _) {
        if (pin != null) {
          return Container(
            key: ValueKey('${widget.keyPrefix}location-pinned'),
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(
              color: AppColors.successSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: AppColors.success),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Location pinned for the delivery partner',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
                TextButton(
                  key: ValueKey('${widget.keyPrefix}remove-pin-button'),
                  onPressed: () => widget.pin.value = null,
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              key: ValueKey('${widget.keyPrefix}pin-location-button'),
              onPressed: _busy ? null : _pin,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
              label: Text(
                _busy ? 'Finding your location' : 'Use my current location',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _error ??
                  'Optional. Tap while you are at this address, so the '
                      'delivery partner is guided to the exact spot.',
              style: TextStyle(
                fontSize: 12,
                color: _error == null ? AppColors.textMuted : AppColors.danger,
              ),
            ),
          ],
        );
      },
    );
  }
}
