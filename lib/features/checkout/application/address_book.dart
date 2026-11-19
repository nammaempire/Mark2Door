import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../domain/address.dart';

/// The delivery addresses saved on this device and the one in use.
@immutable
class AddressBook {
  const AddressBook([this.addresses = const [], this.selectedIndex = 0]);

  final List<Address> addresses;
  final int selectedIndex;

  bool get isEmpty => addresses.isEmpty;

  /// The address the next order goes to; null when none is saved.
  Address? get selected => isEmpty
      ? null
      : addresses[selectedIndex.clamp(0, addresses.length - 1)];

  Map<String, dynamic> toMap() => {
        'items': [for (final a in addresses) a.toMap()],
        'selected': selectedIndex,
      };

  factory AddressBook.fromMap(Map<String, dynamic> map) {
    final items = [
      for (final raw in (map['items'] as List?) ?? const [])
        Address.fromMap(Map<String, dynamic>.from(raw as Map)),
    ];
    final selected = (map['selected'] as num?)?.toInt() ?? 0;
    return AddressBook(
      List.unmodifiable(items),
      items.isEmpty ? 0 : selected.clamp(0, items.length - 1),
    );
  }
}

/// Saved delivery addresses. Shoppers enter an address once; later orders
/// reuse it unless they pick or add another.
final addressBookProvider =
    NotifierProvider<AddressBookController, AddressBook>(
  AddressBookController.new,
);

/// The address in use, for screens that only show it.
final savedAddressProvider = Provider<Address?>(
  (ref) => ref.watch(addressBookProvider).selected,
);

class AddressBookController extends Notifier<AddressBook> {
  LocalStore get _store => ref.read(localStoreProvider);

  @override
  AddressBook build() {
    try {
      final saved = _store.readJson(LocalStore.addressBookKey);
      if (saved != null) return AddressBook.fromMap(saved);
      // Before several addresses were supported, one was stored on its own.
      final single = _store.readJson(LocalStore.addressKey);
      if (single != null) return AddressBook([Address.fromMap(single)]);
    } catch (_) {
      // Unreadable entry: start with an empty book.
    }
    return const AddressBook();
  }

  /// Saves [address] if it is new and makes it the one in use. An address
  /// that is already saved is selected instead of being stored twice.
  void use(Address address) {
    final existing = state.addresses.indexOf(address);
    if (existing >= 0) {
      _commit(AddressBook(state.addresses, existing));
    } else {
      _commit(
        AddressBook(
          List.unmodifiable([...state.addresses, address]),
          state.addresses.length,
        ),
      );
    }
  }

  void select(int index) {
    if (index < 0 || index >= state.addresses.length) return;
    _commit(AddressBook(state.addresses, index));
  }

  void replace(int index, Address address) {
    if (index < 0 || index >= state.addresses.length) return;
    final next = [...state.addresses]..[index] = address;
    _commit(AddressBook(List.unmodifiable(next), index));
  }

  void remove(int index) {
    if (index < 0 || index >= state.addresses.length) return;
    final next = [...state.addresses]..removeAt(index);
    final selected = state.selectedIndex;
    _commit(
      AddressBook(
        List.unmodifiable(next),
        // Keep pointing at the same address where possible.
        next.isEmpty
            ? 0
            : (index < selected ? selected - 1 : selected)
                .clamp(0, next.length - 1),
      ),
    );
  }

  void _commit(AddressBook book) {
    state = book;
    _store.writeJson(
      LocalStore.addressBookKey,
      book.isEmpty ? null : book.toMap(),
    );
  }
}
