import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/models/rider_order.dart';
import '../push/rider_offer_rules.dart';
import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';

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
    if (seconds >= 60) {
      final String minutes = (seconds ~/ 60).toString().padLeft(2, '0');
      final String remain = (seconds % 60).toString().padLeft(2, '0');
      return '$minutes:$remain';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final RiderOrder order = widget.order;
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final bool actionsEnabled = !_expired && !_submitting;
    final String fare = order.tripAmount > 0
        ? currency.format(order.tripAmount)
        : 'Not provided';
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: RiderColors.textPrimary.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: RiderColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.local_shipping_rounded,
                                color: RiderColors.primary,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'IDHAR UDHAR Rider',
                                  style: RiderTextStyles.title.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'New Order Available!',
                                  style: RiderTextStyles.bodyMedium.copyWith(
                                    color: RiderColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: _expired
                                  ? RiderColors.error
                                  : RiderColors.primary,
                              borderRadius: RiderRadius.pillAll,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text(
                                _timerLabel,
                                style: RiderTextStyles.caption.copyWith(
                                  color: RiderColors.textOnPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _stop(
                        Icons.location_on_rounded,
                        RiderColors.success,
                        'Pickup',
                        _shown(order.pickup),
                      ),
                      const SizedBox(height: 12),
                      _stop(
                        Icons.location_on_rounded,
                        RiderColors.error,
                        'Drop',
                        _shown(order.drop),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Divider(height: 1, color: RiderColors.border),
                      ),
                      Row(
                        children: [
                          _stat(Icons.route_rounded, order.distanceLabel, 'Distance'),
                          _stat(Icons.schedule_rounded, order.etaLabel, 'Est. Time'),
                          _stat(Icons.currency_rupee_rounded, fare, 'Trip Fare'),
                        ],
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _message!,
                          style: RiderTextStyles.caption.copyWith(
                            color: RiderColors.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _actionButton(
                              label: 'Reject',
                              icon: Icons.close_rounded,
                              color: RiderColors.error,
                              onPressed: actionsEnabled
                                  ? () => unawaited(_run(widget.onReject))
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _actionButton(
                              label: _expired ? 'Expired' : 'Accept',
                              icon: Icons.check_rounded,
                              color: RiderColors.primary,
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
        ),
      ),
    );
  }

  static Widget _stop(IconData icon, Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: RiderTextStyles.caption),
              Text(value, style: RiderTextStyles.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _stat(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: RiderColors.primary, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: RiderTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: RiderTextStyles.caption,
          ),
        ],
      ),
    );
  }

  static Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final bool enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: RiderColors.textOnPrimary, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: RiderTextStyles.bodyMedium.copyWith(
                    color: RiderColors.textOnPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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

}
