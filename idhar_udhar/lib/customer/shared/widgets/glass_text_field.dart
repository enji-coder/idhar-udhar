import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:idhar_udhar/customer/core/widgets/glass_text_field.dart' as core;

/// Shared text field variants for common input kinds.
enum AppTextFieldType {
  text,
  password,
  phone,
  email,
  search,
  multiline,
}

/// One reusable glass text field covering password, phone, email, search,
/// multiline, icons, and validation display.
///
/// Delegates rendering to core [GlassTextField].
class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.type = AppTextFieldType.text,
    this.leadingIcon,
    this.trailing,
    this.errorText,
    this.enabled = true,
    this.readOnly = false,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.inputFormatters,
    this.maxLength,
    this.textInputAction,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final AppTextFieldType type;
  final IconData? leadingIcon;
  final Widget? trailing;
  final String? errorText;
  final bool enabled;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final TextInputAction? textInputAction;

  IconData get _resolvedIcon {
    if (leadingIcon != null) {
      return leadingIcon!;
    }
    switch (type) {
      case AppTextFieldType.password:
        return Icons.lock_outline_rounded;
      case AppTextFieldType.phone:
        return Icons.phone_iphone_rounded;
      case AppTextFieldType.email:
        return Icons.mail_outline_rounded;
      case AppTextFieldType.search:
        return Icons.search_rounded;
      case AppTextFieldType.multiline:
        return Icons.notes_rounded;
      case AppTextFieldType.text:
        return Icons.edit_outlined;
    }
  }

  TextInputType get _keyboardType {
    switch (type) {
      case AppTextFieldType.password:
        return TextInputType.visiblePassword;
      case AppTextFieldType.phone:
        return TextInputType.phone;
      case AppTextFieldType.email:
        return TextInputType.emailAddress;
      case AppTextFieldType.search:
        return TextInputType.text;
      case AppTextFieldType.multiline:
        return TextInputType.multiline;
      case AppTextFieldType.text:
        return TextInputType.text;
    }
  }

  String? get _hint {
    if (hint != null) {
      return hint;
    }
    switch (type) {
      case AppTextFieldType.password:
        return 'Enter password';
      case AppTextFieldType.phone:
        return '10-digit mobile number';
      case AppTextFieldType.email:
        return 'name@example.com';
      case AppTextFieldType.search:
        return 'Search';
      case AppTextFieldType.multiline:
        return 'Write something…';
      case AppTextFieldType.text:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPassword = type == AppTextFieldType.password;
    final bool isMultiline = type == AppTextFieldType.multiline;

    return core.GlassTextField(
      controller: controller,
      focusNode: focusNode,
      label: label,
      hint: _hint,
      leadingIcon: _resolvedIcon,
      trailing: trailing,
      keyboardType: _keyboardType,
      textInputAction: textInputAction ??
          (isMultiline ? TextInputAction.newline : TextInputAction.done),
      obscureText: isPassword,
      enablePasswordToggle: isPassword,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: isMultiline ? 4 : 1,
      minLines: isMultiline ? 3 : null,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      errorText: errorText,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      autofillHints: switch (type) {
        AppTextFieldType.password => const [AutofillHints.password],
        AppTextFieldType.phone => const [AutofillHints.telephoneNumber],
        AppTextFieldType.email => const [AutofillHints.email],
        _ => null,
      },
    );
  }
}
