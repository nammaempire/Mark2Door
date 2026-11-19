# mart2door — customer app

Hyperlocal grocery app for Android, built with Flutter. This is the customer
app; the delivery app and admin web will live beside it in the same parent
folder and share the same Firebase project.

## Run it

```bash
flutter pub get
flutter run
```

The app uses Firebase by default. To try it without a backend, run
`flutter run --dart-define=USE_FIREBASE=false` for **sample-data mode**:

| What          | Sample-data value                                   |
| ------------- | --------------------------------------------------- |
| Login         | any valid 10-digit mobile number                    |
| OTP           | `123456`                                            |
| Pincodes      | 560001, 560034, 560038, 560068, 560102              |
| Online payment| a test sheet where you pick success / fail / pending|

Orders placed in sample-data mode are kept in memory and reset on restart.
Login, pincode, cart and saved address persist on the device.

## Screens

Splash → Login → OTP → Pincode check → Shop (search, categories, products)
→ Product detail → Cart → Checkout → Payment → Success / Failed / Pending
→ Orders → Order detail (live status timeline) → Account.

## Project structure

```
lib/
  main.dart, app.dart
  core/
    config/      Env flags (dart-define) and business rules
    providers.dart   Composition root: picks sample-data or Firebase classes
    router/      go_router routes + auth/pincode redirect
    storage/     SharedPreferences wrapper
    theme/, utils/, widgets/
  features/<feature>/
    domain/        immutable models
    data/          repository interface + Fake and Firebase implementations
    application/   Riverpod controllers / providers
    presentation/  screens and widgets
test/
  cart_test.dart       unit tests (money, validators, cart rules)
  app_flow_test.dart   end-to-end journeys on sample data
```

UI code depends only on repository interfaces, so switching from sample data
to Firebase changes nothing outside `core/providers.dart`.

## Connect Firebase

1. Create a Firebase project; enable **Authentication → Phone** and
   **Cloud Firestore**.
2. In this folder run:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This adds `android/app/google-services.json` and the Gradle plugin.
3. Add your debug and release **SHA-1 and SHA-256** fingerprints in the
   Firebase console (phone auth on Android will not work without them).
4. Run with Firebase switched on:
   ```bash
   flutter run --dart-define=USE_FIREBASE=true
   ```

### Firestore collections

| Collection                | Fields                                                                 |
| ------------------------- | ---------------------------------------------------------------------- |
| `categories/{id}`         | `name`, `icon` (fruits, dairy, staples, snacks, beverages, household)   |
| `products/{id}`           | `name`, `categoryId`, `unit`, `pricePaise`, `mrpPaise`, `imageUrls` (up to 5; `imageUrl` is the first), `description`, `inStock` |
| `service_areas/{pincode}` | `active: true`                                                          |
| `banners/{id}`            | `title`, `subtitle`, `emoji`, `theme`, `layout`, `categoryId`, `active`, `sortOrder` |
| `settings/store`          | `deliveryFeePaise`, `freeDeliveryThresholdPaise`, `deliveryEtaMinutes`, `handlingFeeEnabled`, `handlingFeePaise`, `rainFeeEnabled`, `rainFeePaise` |
| `orders/{id}`             | `userId`, `items[]`, totals in paise (incl. `handlingFeePaise`, `rainFeePaise`), `address`, `paymentMethod`, `paymentStatus` (`pending`, `paid`, `failed`, `refunded`), `status`, `createdAt`, `etaAt` |

All money is stored as integer **paise**. The orders list needs a composite
index on `orders (userId ASC, createdAt DESC)`; Firestore prints a link to
create it the first time the query runs.

Order `status` moves `placed → accepted → pickedUp → delivered` (or
`cancelled`). The delivery app and admin web update it; the customer's order
page follows it live.

`etaAt` (epoch milliseconds) is the estimated delivery time. The customer
app sets it to order time + the admin's delivery-time setting (30 minutes
by default); the
delivery app should overwrite it with a live estimate once a rider is on the
way. Order history and order details show it as a countdown.

Categories, banners and delivery settings are managed from the admin web
(`../mart2door_admin`). Until the admin saves settings, the defaults in
`AppConfig` apply. When an order has a rider assigned, the order page shows
the rider's name and phone (`riderName`, `riderPhone`).

**Security rules are not included yet.** Before launch, restrict `orders` so
a user can only read and create their own, and make catalogue and service
areas read-only for customers.

## Connect Razorpay

```bash
flutter run --dart-define=USE_FIREBASE=true --dart-define=RAZORPAY_KEY=rzp_test_xxxxx
```

Before accepting real money, create the Razorpay order and verify the
payment signature on a server (a Cloud Function), then mark the order paid
from there. The app currently trusts the client callback, which is fine for
test mode only. See the note in
`lib/features/checkout/data/payment_gateway.dart`.

## Tests

```bash
flutter test
```
# Mark2Door
