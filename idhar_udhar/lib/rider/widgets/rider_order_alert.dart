import 'dart:async';

import 'package:flutter/material.dart';

import '../assets/rider_assets.dart';
import '../data/models/rider_order.dart';
import '../push/rider_offer_alerts.dart';
import '../theme/rider_text_styles.dart';

const Color _offerNavy = Color(0xFF203860);
const Color _offerOrange = Color(0xFFE85820);
const Color _offerGreen = Color(0xFF1F9D55);
const Color _offerRed = Color(0xFFE23B3B);
const Color _offerPanel = Color(0xFFF4F6FA);
const Color _offerLabel = Color(0xFF8B95A5);
const Color _offerValue = Color(0xFF1B2433);
const Color _offerCity = Color(0xFF98A2B3);

/// Centered incoming-offer dialog. It is only visible while the Rider app is
/// in front. It does not draw over other apps.
abstract final class RiderOrderAlert {
  static Future<void> show(
    BuildContext context, {
    required RiderOrder order,
    required Future<String?> Function() onAccept,
    required Future<String?> Function() onReject,
    void Function()? onExpired,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'New delivery',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      pageBuilder: (BuildContext dialogContext, _, __) {
        return _RiderOfferDialog(
          order: order,
          onAccept: onAccept,
          onReject: onReject,
          onExpired: onExpired,
        );
      },
    );
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
  bool _closed = false;
  Timer? _leaveTimer;

  Future<bool> _accept() async {
    final String? error = await widget.onAccept();
    if (!mounted || _closed) {
      return false;
    }
    if (error != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(error)),
      );
      return false;
    }
    _closed = true;
    Navigator.of(context).pop();
    return true;
  }

  Future<bool> _reject() async {
    final String? error = await widget.onReject();
    if (!mounted || _closed) {
      return false;
    }
    if (error != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(error)),
      );
      return false;
    }
    _closed = true;
    Navigator.of(context).pop();
    return true;
  }

  void _expired() {
    widget.onExpired?.call();
    if (_leaveTimer != null || _closed) {
      return;
    }
    _leaveTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _closed) {
        return;
      }
      _closed = true;
      Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _leaveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: RiderIncomingOfferCard(
            key: ValueKey<String>(widget.order.offerId ?? widget.order.id),
            order: widget.order,
            onAccept: _accept,
            onReject: _reject,
            onExpired: _expired,
          ),
        ),
      ),
    );
  }
}

/// The incoming-offer card used by the foreground dialog and the
/// full-screen offer route. Countdown follows [RiderOrder.expiresAt].
class RiderIncomingOfferCard extends StatefulWidget {
  const RiderIncomingOfferCard({
    required this.order,
    required this.onAccept,
    required this.onReject,
    this.onExpired,
    super.key,
  });

  final RiderOrder order;
  final Future<bool> Function() onAccept;
  final Future<bool> Function() onReject;
  final VoidCallback? onExpired;

  @override
  State<RiderIncomingOfferCard> createState() => _RiderIncomingOfferCardState();
}

class _RiderIncomingOfferCardState extends State<RiderIncomingOfferCard> {
  Timer? _timer;
  int? _secondsLeft;
  bool _expired = false;
  bool _busy = false;
  bool _fired = false;
  bool _expiryNotified = false;

  @override
  void initState() {
    super.initState();
    final DateTime? expiresAt = widget.order.expiresAt;
    _secondsLeft = offerSecondsRemaining(expiresAt, DateTime.now());
    _expired = expiresAt != null && _secondsLeft == 0;
    if (_expired) {
      unawaited(endRiderOfferSound(widget.order.offerId));
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyExpired());
      return;
    }
    unawaited(
      beginRiderOfferSound(
        offerId: widget.order.offerId ?? '',
        expiresAtRaw: expiresAt?.toIso8601String(),
      ),
    );
    unawaited(setRiderOfferScreenAwake(true));
    if (expiresAt == null) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _busy) {
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
        unawaited(playRiderOfferTick());
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
    unawaited(endRiderOfferSound(widget.order.offerId));
    unawaited(setRiderOfferScreenAwake(false));
    super.dispose();
  }

  Future<void> _run(Future<bool> Function() action) async {
    if (_busy || _expired || _fired) {
      return;
    }
    final DateTime? expiresAt = widget.order.expiresAt;
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
      setState(() {
        _expired = true;
        _secondsLeft = 0;
      });
      _notifyExpired();
      return;
    }
    _fired = true;
    setState(() => _busy = true);
    final bool done = await action();
    if (!mounted) {
      return;
    }
    if (done) {
      _timer?.cancel();
      return;
    }
    setState(() {
      _busy = false;
      _fired = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final RiderOrder order = widget.order;
    final OfferAreaCity pickup = offerAreaCity(order.pickup);
    final OfferAreaCity drop = offerAreaCity(order.drop);
    final bool actionsEnabled = !_expired && !_busy;
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x2E1B2433),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Center(
                        child: Column(
                          children: [
                            const _OfferLogo(),
                            const SizedBox(height: 2),
                            Text.rich(
                              TextSpan(
                                style: RiderTextStyles.title.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  height: 1.1,
                                ),
                                children: const <InlineSpan>[
                                  TextSpan(
                                    text: 'IDHAR',
                                    style: TextStyle(color: _offerOrange),
                                  ),
                                  TextSpan(
                                    text: ' UDHAR',
                                    style: TextStyle(color: _offerNavy),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _OfferTimer(
                        label: _timerLabel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _offerPanel,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: _PlaceColumn(
                              iconColor: _offerGreen,
                              label: 'Pickup Location',
                              area: _shown(pickup.area),
                              city: pickup.city,
                            ),
                          ),
                          const VerticalDivider(
                            width: 12,
                            thickness: 1,
                            color: Color(0xFFE3E8EF),
                          ),
                          Expanded(
                            child: _PlaceColumn(
                              iconColor: _offerRed,
                              label: 'Drop Location',
                              area: _shown(drop.area),
                              city: drop.city,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Stat(
                      icon: Icons.location_on_outlined,
                      value: order.distanceLabel,
                      label: 'Distance',
                    ),
                    _Stat(
                      icon: Icons.access_time_outlined,
                      value: order.etaLabel,
                      label: 'ETA',
                    ),
                    _Stat(
                      icon: Icons.currency_rupee_outlined,
                      value: _fare(order.tripAmount),
                      label: 'Trip Fare',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _OfferActionButton(
                        label: 'Reject',
                        filled: false,
                        enabled: actionsEnabled,
                        onPressed: actionsEnabled
                            ? () => unawaited(_run(widget.onReject))
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _OfferActionButton(
                        label: 'Accept',
                        filled: true,
                        enabled: actionsEnabled,
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
    );
  }

  String get _timerLabel {
    if (widget.order.expiresAt == null || _secondsLeft == null) {
      return '—';
    }
    return '${_secondsLeft}s';
  }

  static String _shown(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? '—' : trimmed;
  }

  static String _fare(double amount) {
    if (!amount.isFinite || amount <= 0) {
      return '—';
    }
    return 'Rs. ${amount.round()}';
  }
}

class _OfferLogo extends StatelessWidget {
  const _OfferLogo();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'IDHAR UDHAR',
      image: true,
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 0.82,
          child: Image.asset(
            RiderAssets.logo,
            width: 96,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const SizedBox(width: 72, height: 72),
          ),
        ),
      ),
    );
  }
}

class _OfferTimer extends StatelessWidget {
  const _OfferTimer({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.access_time_rounded, color: _offerOrange, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: RiderTextStyles.title.copyWith(
            color: _offerOrange,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _PlaceColumn extends StatelessWidget {
  const _PlaceColumn({
    required this.iconColor,
    required this.label,
    required this.area,
    required this.city,
  });

  final Color iconColor;
  final String label;
  final String area;
  final String city;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.location_on_rounded, color: iconColor, size: 18),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: RiderTextStyles.caption.copyWith(
            color: _offerLabel,
            fontSize: 11,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          area,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: RiderTextStyles.bodyMedium.copyWith(
            color: _offerValue,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        if (city.isNotEmpty)
          Text(
            ', $city',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RiderTextStyles.caption.copyWith(
              color: _offerCity,
              fontSize: 12,
              height: 1.25,
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: _offerNavy, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RiderTextStyles.bodyMedium.copyWith(
              color: _offerNavy,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: RiderTextStyles.caption.copyWith(
              color: _offerLabel,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferActionButton extends StatelessWidget {
  const _OfferActionButton({
    required this.label,
    required this.filled,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color foreground = filled ? Colors.white : _offerRed;
    final Color background = filled ? _offerNavy : Colors.white;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: filled
              ? BorderSide.none
              : const BorderSide(color: _offerRed, width: 1.4),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 52,
            child: Center(
              child: Text(
                label,
                style: RiderTextStyles.button.copyWith(
                  color: foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
