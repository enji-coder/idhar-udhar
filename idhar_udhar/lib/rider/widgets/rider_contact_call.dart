import 'package:flutter/material.dart';
import 'package:idhar_udhar/shared/phone/native_dialer.dart';

import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';

/// Sender or receiver name plus a native-dialer call action.
class RiderContactCall extends StatelessWidget {
  const RiderContactCall({
    required this.label,
    required this.name,
    required this.phone,
    super.key,
  });

  final String label;
  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final String shown = name.trim().isEmpty ? 'Not provided' : name.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: RiderTextStyles.caption),
        const SizedBox(height: RiderSpacing.xs),
        Text(shown, style: RiderTextStyles.title),
        const SizedBox(height: RiderSpacing.md),
        OutlinedButton.icon(
          onPressed: () => openNativePhoneDialer(context, phone),
          icon: const Icon(Icons.call_rounded),
          label: Text('Call $label'),
          style: OutlinedButton.styleFrom(
            foregroundColor: RiderColors.primary,
            side: const BorderSide(color: RiderColors.primary),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }
}
