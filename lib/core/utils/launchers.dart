import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hand-offs to other apps. Each shows a message if the phone has nothing
/// that can handle the request.
abstract final class Launchers {
  /// Opens the email app with a new message to [address].
  static Future<void> email(
    BuildContext context,
    String address, {
    String subject = '',
  }) =>
      _open(
        context,
        Uri(
          scheme: 'mailto',
          path: address,
          query: subject.isEmpty
              ? null
              : 'subject=${Uri.encodeComponent(subject)}',
        ),
        "Couldn't open an email app. Write to $address.",
      );

  /// Opens WhatsApp ready to send [text] to a contact the shopper picks.
  static Future<void> shareOnWhatsApp(BuildContext context, String text) =>
      _open(
        context,
        Uri.https('wa.me', '/', {'text': text}),
        "Couldn't open WhatsApp. The message was copied instead.",
        fallbackCopy: text,
      );

  static Future<void> copy(
    BuildContext context,
    String text, {
    required String confirmation,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(confirmation)));
  }

  static Future<void> _open(
    BuildContext context,
    Uri uri,
    String failure, {
    String? fallbackCopy,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (ok) return;
    if (fallbackCopy != null) {
      await Clipboard.setData(ClipboardData(text: fallbackCopy));
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failure)));
  }
}
