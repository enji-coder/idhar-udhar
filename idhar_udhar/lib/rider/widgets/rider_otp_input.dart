import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';

/// Six-digit OTP entry with focus-friendly boxes.
class RiderOtpInput extends StatefulWidget {
  const RiderOtpInput({
    required this.onCompleted,
    super.key,
    this.length = 6,
    this.onChanged,
    this.errorText,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final String? errorText;

  @override
  State<RiderOtpInput> createState() => _RiderOtpInputState();
}

class _RiderOtpInputState extends State<RiderOtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _controllers = List<TextEditingController>.generate(
      widget.length,
      (_) => TextEditingController(),
    );
    _nodes = List<FocusNode>.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _value => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      _paste(value);
      return;
    }
    if (value.isNotEmpty && index < widget.length - 1) {
      _nodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    final code = _value;
    widget.onChanged?.call(code);
    if (code.length == widget.length) {
      widget.onCompleted(code);
    }
  }

  void _paste(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < widget.length; i++) {
      _controllers[i].text = i < digits.length ? digits[i] : '';
    }
    final focusIndex =
        digits.length >= widget.length ? widget.length - 1 : digits.length;
    _nodes[focusIndex.clamp(0, widget.length - 1)].requestFocus();
    final code = _value;
    widget.onChanged?.call(code);
    if (code.length == widget.length) {
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const double gap = RiderSpacing.sm;
            final double boxW =
                ((constraints.maxWidth - gap * (widget.length - 1)) /
                        widget.length)
                    .clamp(40.0, 56.0);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List<Widget>.generate(widget.length, (i) {
                return SizedBox(
                  width: boxW,
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _nodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: RiderTextStyles.title,
                    cursorColor: RiderColors.primary,
                    maxLength: 1,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(1),
                    ],
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: RiderColors.surface.withValues(alpha: 0.92),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: RiderSpacing.lg,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: RiderRadius.mdAll,
                        borderSide:
                            const BorderSide(color: RiderColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: RiderRadius.mdAll,
                        borderSide:
                            const BorderSide(color: RiderColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: RiderRadius.mdAll,
                        borderSide: const BorderSide(
                          color: RiderColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (v) => _onChanged(i, v),
                  ),
                );
              }),
            );
          },
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: RiderSpacing.sm),
          Text(
            widget.errorText!,
            style: RiderTextStyles.caption.copyWith(color: RiderColors.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
