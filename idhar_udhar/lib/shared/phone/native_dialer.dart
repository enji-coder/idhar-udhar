import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the device phone app with [raw] filled in. Does not place the call.
Future<void> openNativePhoneDialer(BuildContext context, String? raw) async {
  final String? number = _dialable(raw);
  if (number == null) {
    _message(
      context,
      (raw == null || raw.trim().isEmpty)
          ? 'Phone number is not available.'
          : 'This phone number cannot be used.',
    );
    return;
  }
  final Uri uri = Uri.parse('tel:$number');
  try {
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      _message(context, 'Could not open the phone dialer.');
    }
  } catch (_) {
    if (context.mounted) {
      _message(context, 'Could not open the phone dialer.');
    }
  }
}

String? _dialable(String? raw) {
  final String compact = (raw ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
  if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(compact)) {
    return null;
  }
  return compact;
}

void _message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
