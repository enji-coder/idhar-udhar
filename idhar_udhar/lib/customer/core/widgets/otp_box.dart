import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/glass_effect.dart';

String _digitsOnly(String raw) => raw.replaceAll(RegExp(r'\D'), '');

/// Single OTP digit cell — visual only (input is handled by [OTPInputRow]).
class OTPBox extends StatelessWidget {
  const OTPBox({
    required this.digit,
    required this.focused,
    super.key,
    this.enabled = true,
    this.size = AppSpacing.otpBoxSize,
    this.onTap,
  });

  final String digit;
  final bool focused;
  final bool enabled;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool active = focused;
    final bool filled = digit.isNotEmpty;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: AppRadius.otpAll,
          boxShadow: active ? AppShadows.otpFocus : null,
        ),
        child: GlassEffect(
          depth: active ? GlassDepthLevel.normal : GlassDepthLevel.subtle,
          borderRadius: AppRadius.otpAll,
          showShadow: false,
          showInnerHighlight: true,
          showAmbientGlow: active,
          ambientColor: AppColors.orange,
          opacity: active ? 0.36 : 0.28,
          padding: EdgeInsets.zero,
          borderColor: active
              ? AppColors.orange
              : filled
                  ? AppColors.orangeSoft.withValues(alpha: 0.7)
                  : AppColors.borderGlassStrong,
          child: Center(
            child: Text(
              digit,
              textAlign: TextAlign.center,
              style: AppTextStyles.otp,
            ),
          ),
        ),
      ),
    );
  }
}

/// 4-box OTP row. Verification callback fires ONLY when all 4 digits exist.
///
/// Uses one real [TextField] (transparent) so typing, paste, and backspace
/// advance naturally — boxes are display-only and keep the existing look.
class OTPInputRow extends StatefulWidget {
  const OTPInputRow({
    super.key,
    this.length = 4,
    this.onCompleted,
    this.onChanged,
    this.enabled = true,
    this.autofocus = true,
  });

  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool autofocus;

  @override
  State<OTPInputRow> createState() => OTPInputRowState();
}

class OTPInputRowState extends State<OTPInputRow> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  bool _completedNotified = false;
  bool _didAutofocus = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode(debugLabel: 'otp_input');
    _controller.addListener(_onControllerTick);
    _focusNode.addListener(_onFocusTick);

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didAutofocus || !widget.enabled) {
          return;
        }
        _didAutofocus = true;
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant OTPInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerTick);
    _focusNode.removeListener(_onFocusTick);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerTick() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onFocusTick() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Combined OTP: only real digits, in order. Never treats 1 digit as complete.
  String get code {
    final String digits = _digitsOnly(_controller.text);
    if (digits.length <= widget.length) {
      return digits;
    }
    return digits.substring(0, widget.length);
  }

  bool get isComplete => code.length == widget.length;

  void clear({bool requestFocus = true}) {
    _completedNotified = false;
    _syncing = true;
    _controller.clear();
    _syncing = false;
    widget.onChanged?.call('');
    if (requestFocus && widget.enabled && mounted) {
      _focusNode.requestFocus();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _notify() {
    final String current = code;
    widget.onChanged?.call(current);

    // CRITICAL: only notify completion when EVERY box has a digit.
    if (isComplete) {
      if (!_completedNotified) {
        _completedNotified = true;
        widget.onCompleted?.call(current);
      }
    } else {
      _completedNotified = false;
    }
  }

  void _setCode(String raw, {int? cursor}) {
    final String digits = _digitsOnly(raw);
    final String clipped = digits.length > widget.length
        ? digits.substring(0, widget.length)
        : digits;
    final int offset = (cursor ?? clipped.length).clamp(0, clipped.length);
    _syncing = true;
    _controller.value = TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: offset),
    );
    _syncing = false;
    _notify();
  }

  void _onChanged(String value) {
    if (_syncing) {
      return;
    }
    final String digits = _digitsOnly(value);
    final String clipped = digits.length > widget.length
        ? digits.substring(0, widget.length)
        : digits;

    if (value != clipped || _controller.text != clipped) {
      _setCode(clipped);
      return;
    }
    _notify();
  }

  int get _activeIndex {
    final String current = code;
    if (!_focusNode.hasFocus) {
      return -1;
    }
    if (current.length >= widget.length) {
      return widget.length - 1;
    }
    return current.length;
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final double boxSize = (width / (widget.length + 3.2)).clamp(40.0, 56.0);
    final String current = code;
    final int activeIndex = _activeIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double available = constraints.maxWidth;
        const double gap = 8;
        final double computed =
            ((available - (gap * (widget.length - 1))) / widget.length)
                .clamp(36.0, 56.0);
        final double size = computed.isFinite ? computed : boxSize;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Visual boxes (identical styling). IgnorePointer so the real
            // TextField above receives taps / long-press paste.
            IgnorePointer(
              child: Row(
                children: List<Widget>.generate(widget.length, (index) {
                  final String digit =
                      index < current.length ? current[index] : '';
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == widget.length - 1 ? 0 : gap,
                    ),
                    child: OTPBox(
                      digit: digit,
                      focused: activeIndex == index,
                      enabled: widget.enabled,
                      size: size,
                    ),
                  );
                }),
              ),
            ),
            // Real input on top — transparent; drives typing / paste / backspace.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  enableSuggestions: false,
                  autocorrect: false,
                  enableInteractiveSelection: true,
                  showCursor: false,
                  style: AppTextStyles.otp.copyWith(
                    color: Colors.transparent,
                  ),
                  maxLength: widget.length,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  onChanged: _onChanged,
                  onTap: () {
                    final String currentCode = code;
                    if (currentCode.length == widget.length) {
                      // Full OTP → select all so paste/type replaces cleanly.
                      _controller.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: currentCode.length,
                      );
                    } else {
                      // Partial → caret at end so the next digit fills next box.
                      _controller.selection = TextSelection.collapsed(
                        offset: currentCode.length,
                      );
                    }
                  },
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: Colors.transparent,
                    isCollapsed: true,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
