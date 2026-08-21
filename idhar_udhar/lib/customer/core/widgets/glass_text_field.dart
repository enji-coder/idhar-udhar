import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/glass_effect.dart';

/// Rounded glass text field with leading icon, focus glow, and password toggle.
///
/// Focus visuals rebuild beside a stable [TextField] sibling so the first tap
/// focuses + opens the keyboard immediately (no second tap).
class GlassTextField extends StatefulWidget {
  const GlassTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.leadingIcon,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enablePasswordToggle = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.borderRadius,
    this.height,
    this.blurSigma,
    this.fillOpacity,
    this.transparentBackground = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final IconData? leadingIcon;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enablePasswordToggle;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final BorderRadius? borderRadius;
  final double? height;
  final double? blurSigma;
  final double? fillOpacity;

  /// When true, no glass/fill behind the field (border + focus only).
  /// Opt-in per call site — default keeps existing glass look elsewhere.
  final bool transparentBackground;

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  FocusNode? _internalFocus;
  bool _obscured = true;

  FocusNode get _focus => widget.focusNode ?? _internalFocus!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _internalFocus = FocusNode();
    }
    _obscured = widget.obscureText;
  }

  @override
  void dispose() {
    _internalFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError =
        widget.errorText != null && widget.errorText!.isNotEmpty;
    final BorderRadius radius = widget.borderRadius ?? AppRadius.mdLgAll;
    final double? fieldHeight = widget.maxLines == 1
        ? (widget.height ?? AppSpacing.inputHeight)
        : null;

    // Stable TextField — kept as ListenableBuilder.child so focus glow rebuilds
    // never remount it (that remount was causing the double-tap-to-edit bug).
    final Widget field = TextField(
      controller: widget.controller,
      focusNode: _focus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText:
          widget.enablePasswordToggle ? _obscured : widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      maxLines: widget.obscureText || widget.enablePasswordToggle
          ? 1
          : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      autofillHints: widget.autofillHints,
      textCapitalization: widget.textCapitalization,
      style: AppTextStyles.bodyMedium,
      cursorColor: AppColors.orange,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.transparent,
        hintText: widget.hint,
        hintStyle: AppTextStyles.body.copyWith(
          color: AppColors.navyMuted.withValues(alpha: 0.75),
        ),
        counterText: '',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        prefixIcon: widget.leadingIcon == null
            ? null
            : Icon(
                widget.leadingIcon,
                color: AppColors.orange,
                size: AppSpacing.iconMd,
              ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        suffixIcon: widget.enablePasswordToggle
            ? IconButton(
                onPressed: () {
                  setState(() => _obscured = !_obscured);
                },
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.navyMuted,
                  size: AppSpacing.iconMd,
                ),
              )
            : widget.trailing == null
                ? null
                : UnconstrainedBox(child: widget.trailing),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
        ],
        ListenableBuilder(
          listenable: _focus,
          child: field,
          builder: (context, child) {
            final bool focused = _focus.hasFocus;
            final Color borderColor = hasError
                ? AppColors.danger
                : focused
                    ? AppColors.orange.withValues(alpha: 0.9)
                    : AppColors.white.withValues(alpha: 0.55);
            final double borderWidth = focused ? 1.5 : 1.15;

            if (widget.transparentBackground) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                height: fieldHeight,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: radius,
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                child: child,
              );
            }

            final Widget glass = IgnorePointer(
              child: GlassEffect(
                depth: focused
                    ? GlassDepthLevel.normal
                    : GlassDepthLevel.subtle,
                blurSigma: widget.blurSigma ?? (focused ? 18 : 14),
                opacity: widget.fillOpacity ?? (focused ? 0.36 : 0.28),
                borderRadius: radius,
                showShadow: false,
                showInnerHighlight: true,
                showAmbientGlow: focused && !hasError,
                ambientColor: AppColors.orange,
                borderWidth: borderWidth,
                padding: EdgeInsets.zero,
                borderColor: borderColor,
                child: const SizedBox.expand(),
              ),
            );

            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: fieldHeight,
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow:
                    focused && !hasError ? AppShadows.inputFocus : null,
              ),
              // Glass visuals sit behind the TextField (IgnorePointer) so
              // focus-driven GlassEffect rebuilds cannot steal the first tap
              // or drop the IME connection.
              child: fieldHeight != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        glass,
                        child!,
                      ],
                    )
                  : Stack(
                      children: [
                        Positioned.fill(child: glass),
                        child!,
                      ],
                    ),
            );
          },
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.errorText!,
            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}
