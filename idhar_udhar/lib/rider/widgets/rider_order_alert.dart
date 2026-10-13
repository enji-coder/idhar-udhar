import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/models/rider_order.dart';
import '../push/rider_offer_rules.dart';
import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';
import 'rider_glass_card.dart';
import 'rider_primary_button.dart';
import 'rider_secondary_button.dart';

/// Centered incoming-offer dialog. It is only visible while the Rider app is
/// in front. It does not draw over other apps.
abstract final class RiderOrderAlert {
  static Future<void> show(
    BuildContext context, {
    required RiderOrder order,
    required Future<String?> Function() onAccept,
    required Future<String?> Function() onReject,
    void Function()? onExpired,
    bool playFallbackSound = false,
  }) {
    if (playFallbackSound) {
      unawaited(_fallbackSound());
    }
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'New delivery',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      pageBuilder: (context, animation, secondary) {
        return _RiderOfferDialog(
          order: order,
          onAccept: onAccept,
          onReject: onReject,
          onExpired: onExpired,
        );
      },
    );
  }

  static Future<void> _fallbackSound() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Sound and haptics are optional when the channel alert already played.
    }
  }
}

class _RiderOfferDialog extends StatefulWidget {
  const _RiderOfferDialog({
    required this.order,
    required this.onAccept,
    required this.onReject,
    required this.onExpired,
  });

  final RiderOrder order;
  final Future<String?> Function() onAccept;
  final Future<String?> Function() onReject;
  final void Function()? onExpired;

  @override
  State<_RiderOfferDialog> createState() => _RiderOfferDialogState();
}

class _RiderOfferDialogState extends State<_RiderOfferDialog> {
  Timer? _timer;
  late int? _secondsLeft;
  bool _expired = false;
  bool _submitting = false;
  bool _expiryNotified = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final DateTime? expiresAt = widget.order.expiresAt;
    _secondsLeft = offerSecondsRemaining(expiresAt, DateTime.now());
    _expired = expiresAt != null && _secondsLeft == 0;
    if (_expired) {
      _notifyExpired();
      return;
    }
    if (expiresAt == null) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _submitting) {
        return;
      }
      final int? left = offerSecondsRemaining(expiresAt, DateTime.now());
      if (left == null || left <= 0) {
        _timer?.cancel();
        setState(() {
          _secondsLeft = 0;
          _expired = true;
        });
        _notifyExpired();
      } else {
        setState(() => _secondsLeft = left);
      }
    });
  }

  void _notifyExpired() {
    if (_expiryNotified) {
      return;
    }
    _expiryNotified = true;
    widget.onExpired?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    if (_submitting || _expired) {
      return;
    }
    setState(() {
      _submitting = true;
      _message = null;
    });
    final String? error = await action();
    if (!mounted) {
      return;
    }
    if (error == null) {
      _timer?.cancel();
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _message = error;
    });
  }

  String get _timerLabel {
    if (widget.order.expiresAt == null || _secondsLeft == null) {
      return '—';
    }
    final int seconds = _secondsLeft!;
    final String minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final String remain = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remain';
  }

  @override
  Widget build(BuildContext context) {
    final RiderOrder order = widget.order;
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final bool actionsEnabled = !_expired && !_submitting;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(RiderSpacing.screenH),
          child: Material(
            color: Colors.transparent,
            child: RiderGlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_rounded,
                        color: RiderColors.primary,
                      ),
                      const SizedBox(width: RiderSpacing.sm),
                      Expanded(
                        child: Text(
                          'New delivery request',
                          style: RiderTextStyles.title,
                        ),
                      ),
                      Text(
                        _timerLabel,
                        style: RiderTextStyles.title.copyWith(
                          color: _expired
                              ? RiderColors.error
                              : RiderColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  _line('Pickup', _shown(order.pickup)),
                  const SizedBox(height: RiderSpacing.sm),
                  _line('Drop', _shown(order.drop)),
                  const SizedBox(height: RiderSpacing.sm),
                  _line(
                    'Trip fare',
                    order.tripAmount > 0
                        ? currency.format(order.tripAmount)
                        : 'Not provided',
                  ),
                  const SizedBox(height: RiderSpacing.sm),
                  _line('Distance', order.distanceLabel),
                  const SizedBox(height: RiderSpacing.sm),
                  _line('Time', order.etaLabel),
                  if (_message != null) ...[
                    const SizedBox(height: RiderSpacing.md),
                    Text(
                      _message!,
                      style: RiderTextStyles.caption.copyWith(
                        color: RiderColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: RiderSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: RiderSecondaryButton(
                          label: 'Reject',
                          destructive: true,
                          onPressed: actionsEnabled
                              ? () => unawaited(_run(widget.onReject))
                              : null,
                        ),
                      ),
                      const SizedBox(width: RiderSpacing.md),
                      Expanded(
                        flex: 2,
                        child: RiderPrimaryButton(
                          label: _expired ? 'Expired' : 'Accept',
                          onPressed: actionsEnabled
                              ? () => unawaited(_run(widget.onAccept))
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _shown(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? 'Not provided' : trimmed;
  }

  static Widget _line(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: RiderTextStyles.caption),
        Text(value, style: RiderTextStyles.bodyMedium),
      ],
    );
  }
}
