import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';

/// Rider login / form field (teal glass language).
class RiderTextField extends StatelessWidget {
  const RiderTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onTap,
    this.errorText,
    this.maxLength,
    this.readOnly = false,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? label;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final String? errorText;
  final int? maxLength;
  final bool readOnly;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: RiderTextStyles.bodyMedium),
          const SizedBox(height: RiderSpacing.sm),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onTap: onTap,
          maxLength: maxLength,
          readOnly: readOnly,
          enabled: enabled,
          style: RiderTextStyles.bodyMedium,
          cursorColor: RiderColors.primary,
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: RiderTextStyles.hint,
            filled: true,
            fillColor: RiderColors.surface.withValues(alpha: 0.92),
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, color: RiderColors.primary),
            suffixIcon: suffixIcon,
            errorText: errorText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: RiderSpacing.lg,
              vertical: RiderSpacing.lg,
            ),
            border: OutlineInputBorder(
              borderRadius: RiderRadius.lgAll,
              borderSide: const BorderSide(color: RiderColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: RiderRadius.lgAll,
              borderSide: const BorderSide(color: RiderColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: RiderRadius.lgAll,
              borderSide:
                  const BorderSide(color: RiderColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: RiderRadius.lgAll,
              borderSide: const BorderSide(color: RiderColors.error),
            ),
          ),
        ),
      ],
    );
  }
}
