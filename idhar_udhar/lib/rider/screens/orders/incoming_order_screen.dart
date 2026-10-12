import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:intl/intl.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/dummy/rider_finance.dart';
import '../../data/models/rider_order.dart';
import '../../push/rider_offer_alerts.dart';
import '../../push/rider_offer_diag.dart';
import '../../routing/rider_routes.dart';
import '../../state/rider_session.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_secondary_button.dart';
import '../profile/rider_profile_screen.dart';

class IncomingOrderScreen extends ConsumerStatefulWidget {
  const IncomingOrderScreen({super.key});

  @override
  ConsumerState<IncomingOrderScreen> createState() =>
      _IncomingOrderScreenState();
}

class _IncomingOrderScreenState extends ConsumerState<IncomingOrderScreen> {
  RiderOrder? _order;
  RiderOffer? _sourceOffer;
  late int _secondsLeft;
  Timer? _timer;
  StreamSubscription<RiderOfferUserAction>? _actions;
  bool _expired = false;
  bool _loading = true;
  bool _submitting = false;
  bool _inLoad = false;
  bool _applyingAction = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _secondsLeft = 0;
    _actions = riderOfferUserActions.listen((_) {
      unawaited(_applyPendingAction());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    if (_inLoad) {
      return;
    }
    _inLoad = true;
    try {
      final String? targetId = riderOfferActionGate.pending?.offerId ??
          riderOfferLaunchOfferId;
      final bool loaded =
          await ref.read(riderSessionProvider.notifier).refreshOffers();
      final offers = ref.read(riderSessionProvider).offers;
      if (!mounted) {
        return;
      }
      if (!loaded && offers.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Could not load offers.';
        });
        return;
      }
      final RiderOffer? offer = _selectOffer(offers, targetId);
      if (offer == null) {
        _dropPending(targetId);
        riderOfferLaunchOfferId = null;
        riderOfferLaunchAction = null;
        setState(() {
          _loading = false;
          _order = null;
          _sourceOffer = null;
          _error = (targetId ?? '').trim().isEmpty
              ? 'No incoming orders right now.'
              : 'This order request is no longer available.';
        });
        return;
      }
      riderOfferLaunchOfferId = null;
      riderOfferLaunchAction = null;
      RiderOrder mapped = OrderMapper.toRiderOrder(offer: offer);
      try {
        final details = await ref.read(riderApiProvider).getOrder(offer.orderId);
        mapped = OrderMapper.toRiderOrder(offer: offer, order: details);
      } catch (_) {}
      if (!mounted) {
        return;
      }
      final bool alreadyExpired = mapped.expiresAt != null &&
          !mapped.expiresAt!.isAfter(DateTime.now());
      if (offer.status != 'PENDING' || alreadyExpired) {
        _dropPending(offer.offerId);
        unawaited(cancelRiderOfferAlert(offer.offerId));
        setState(() {
          _sourceOffer = offer;
          _loading = false;
          _secondsLeft = 0;
          if (offer.status != 'PENDING') {
            _order = null;
            _expired = false;
            _error = 'This order request is no longer available.';
          } else {
            _order = mapped;
            _expired = true;
            _error = null;
          }
        });
        return;
      }
      setState(() {
        _order = mapped;
        _sourceOffer = offer;
        _loading = false;
        _expired = false;
        _error = null;
        _secondsLeft = mapped.decisionSeconds;
      });
      riderOfferLog(
        'incoming_screen_ready',
        offerId: offer.offerId,
        reason: 'seconds_left=${mapped.decisionSeconds}',
      );
      await _applyPendingAction();
      if (!mounted || _expired || _submitting || _order?.expiresAt == null) {
        return;
      }
      final DateTime expiresAt = _order!.expiresAt!;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final int left = expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 86400);
        if (left <= 0) {
          _timer?.cancel();
          setState(() {
            _secondsLeft = 0;
            _expired = true;
          });
          unawaited(cancelRiderOfferAlert(_order?.offerId));
        } else {
          setState(() => _secondsLeft = left);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load offers.';
        });
      }
    } finally {
      _inLoad = false;
    }
    final RiderOfferUserAction? pending = riderOfferActionGate.pending;
    if (mounted &&
        _error == null &&
        pending != null &&
        _sourceOffer?.offerId != pending.offerId &&
        !_loading) {
      await _load();
    }
  }

  RiderOffer? _selectOffer(List<RiderOffer> offers, String? targetId) {
    final String id = (targetId ?? '').trim();
    if (id.isNotEmpty) {
      return riderOfferById(offers, id);
    }
    for (final RiderOffer candidate in offers) {
      if (candidate.status == 'PENDING') {
        return candidate;
      }
    }
    return offers.isEmpty ? null : offers.first;
  }

  void _dropPending(String? offerId) {
    final RiderOfferUserAction? pending = riderOfferActionGate.pending;
    final String id = (offerId ?? '').trim();
    if (pending != null && id.isNotEmpty && pending.offerId == id) {
      riderOfferActionGate.consume(pending);
    }
  }

  Future<void> _applyPendingAction() async {
    if (_applyingAction || _submitting || _loading || _order == null) {
      return;
    }
    final RiderOfferUserAction? action = riderOfferActionGate.pending;
    if (action == null) {
      return;
    }
    if (_sourceOffer?.offerId != action.offerId) {
      if (_inLoad) {
        return;
      }
      await _load();
      return;
    }
    if (_expired || _sourceOffer?.status != 'PENDING') {
      riderOfferActionGate.consume(action);
      return;
    }
    _applyingAction = true;
    riderOfferActionGate.consume(action);
    try {
      if (action.action == 'reject') {
        await _reject();
      } else if (action.action == 'accept') {
        await _accept();
      }
    } finally {
      _applyingAction = false;
    }
  }

  @override
  void dispose() {
    _actions?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  String get _timerLabel {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _accept() async {
    final RiderOrder? order = _order;
    if (_expired || _submitting || order == null) {
      return;
    }
    if (!ref.read(riderSessionProvider).isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your profile must be approved before you can accept orders.',
          ),
        ),
      );
      return;
    }
    if (riderIsSuspended(ref)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account suspended until COD Due is cleared.'),
        ),
      );
      return;
    }
    if (!ref.read(riderOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Go online to accept delivery requests.'),
        ),
      );
      return;
    }
    final String? offerId = order.offerId;
    if (offerId == null || offerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This order request is no longer available.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    var acceptedOk = false;
    try {
      final accepted =
          await ref.read(riderApiProvider).acceptOffer(offerId);
      if (!mounted) {
        return;
      }
      var details = accepted;
      if (accepted.orderId.isNotEmpty) {
        try {
          details =
              await ref.read(riderApiProvider).getOrder(accepted.orderId);
        } catch (_) {}
      }
      if (!mounted) {
        return;
      }
      _timer?.cancel();
      unawaited(cancelRiderOfferAlert(order.offerId));
      final RiderOffer active = _sourceOffer ??
          RiderOffer(
            offerId: offerId,
            orderId: order.backendOrderId ?? details.orderId,
            status: 'PENDING',
            createdAt: DateTime.now(),
            displayId: order.id,
            tripFare: order.tripAmount,
            distanceKm: order.distanceKm,
            estimatedDurationSeconds:
                order.estimatedMinutes > 0 ? order.estimatedMinutes * 60 : null,
          );
      ref.read(activeOrderProvider.notifier).state = OrderMapper.toRiderOrder(
        offer: acceptedOfferState(active: active, order: details),
        order: details,
      );
      ref.read(deliveryStatusProvider.notifier).state =
          DeliveryLifecycleStatus.accepted;
      acceptedOk = true;
      context.go(RiderRoutes.orderDetails);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
        unawaited(ref.read(riderSessionProvider.notifier).refreshOffers());
      }
    } finally {
      if (mounted && _submitting && !acceptedOk) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _reject() async {
    if (_submitting || _expired) {
      return;
    }
    final String? offerId = _order?.offerId;
    if (offerId == null || offerId.isEmpty) {
      _timer?.cancel();
      if (mounted) {
        context.pop();
      }
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(riderApiProvider).rejectOffer(offerId);
      unawaited(cancelRiderOfferAlert(offerId));
      _timer?.cancel();
      if (mounted) {
        context.pop();
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
        setState(() => _submitting = false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reject this request. Try again.'),
          ),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const RiderScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_order == null) {
      return RiderScaffold(
        appBar: AppBar(title: const Text('New order')),
        body: Center(child: Text(_error ?? 'No incoming orders right now.')),
      );
    }
    final RiderOrder order = _order!;
    final bool approved = ref.watch(riderSessionProvider).isApproved;
    final String? photoUrl = _httpPhotoUrl(
      ref.watch(riderProfileStateProvider).photoUrl,
    );
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return RiderScaffold(
      appBar: AppBar(
        title: const Text('New order'),
        automaticallyImplyLeading: false,
        actions: [
          if (photoUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: RiderSpacing.sm),
              child: Center(
                child: RiderProfileAvatar(photoUrl: photoUrl, radius: 16),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _submitting
                ? null
                : _expired
                    ? () => context.go(RiderRoutes.dashboard)
                    : _reject,
          ),
        ],
      ),
      bottom: _expired
          ? RiderSecondaryButton(
              label: 'Back to Dashboard',
              onPressed: () => context.go(RiderRoutes.dashboard),
            )
          : Row(
              children: [
                Expanded(
                  child: RiderSecondaryButton(
                    label: 'Reject',
                    destructive: true,
                    onPressed: _submitting || _expired ? null : _reject,
                  ),
                ),
                const SizedBox(width: RiderSpacing.md),
                Expanded(
                  flex: 2,
                  child: RiderPrimaryButton(
                    label: 'Accept',
                    enabled: approved && !_submitting && !_expired,
                    onPressed: approved && !_submitting && !_expired
                        ? _accept
                        : null,
                  ),
                ),
              ],
            ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (_expired ? RiderColors.error : RiderColors.primary)
                    .withValues(alpha: 0.12),
                border: Border.all(
                  color: _expired ? RiderColors.error : RiderColors.primary,
                  width: 3,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _expired ? '00:00' : _timerLabel,
                style: RiderTextStyles.heading.copyWith(
                  color: _expired ? RiderColors.error : RiderColors.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: RiderSpacing.md),
            Text(
              _expired ? 'Order Expired' : 'Incoming delivery request',
              style: RiderTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: RiderSpacing.md),
            Text(
              order.tripAmount > 0
                  ? currency.format(order.tripAmount)
                  : '—',
              style: RiderTextStyles.heading.copyWith(
                color: RiderColors.primary,
                fontSize: 40,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'Trip fare',
              style: RiderTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: RiderSpacing.xl),
            RiderGlassCard(
              child: Column(
                children: [
                  if ((order.crn ?? '').trim().isNotEmpty)
                    _InfoRow(
                      icon: Icons.tag_rounded,
                      label: 'CRN',
                      value: order.crn!.trim(),
                    ),
                  _InfoRow(
                    icon: Icons.store_mall_directory_rounded,
                    label: 'Pickup',
                    value: order.pickup,
                  ),
                  const Divider(height: RiderSpacing.xl),
                  _InfoRow(
                    icon: Icons.location_on_rounded,
                    label: 'Drop',
                    value: order.drop,
                  ),
                  if (order.receiverName.trim().isNotEmpty) ...[
                    const Divider(height: RiderSpacing.xl),
                    _InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Receiver',
                      value: order.receiverName.trim(),
                    ),
                  ],
                  if (order.receiverPhone.trim().isNotEmpty) ...[
                    const Divider(height: RiderSpacing.xl),
                    _InfoRow(
                      icon: Icons.phone_iphone_rounded,
                      label: 'Receiver contact',
                      value: order.receiverPhone.trim(),
                    ),
                  ],
                  if (order.vehicleName.trim().isNotEmpty) ...[
                    const Divider(height: RiderSpacing.xl),
                    _InfoRow(
                      icon: Icons.two_wheeler_rounded,
                      label: 'Vehicle',
                      value: order.vehicleName.trim(),
                    ),
                  ],
                  if (order.packageLabel.trim().isNotEmpty) ...[
                    const Divider(height: RiderSpacing.xl),
                    _InfoRow(
                      icon: Icons.inventory_2_outlined,
                      label: 'Package',
                      value: order.packageLabel.trim(),
                    ),
                  ],
                  const Divider(height: RiderSpacing.xl),
                  _InfoRow(
                    icon: Icons.route_rounded,
                    label: 'Distance',
                    value: order.distanceLabel,
                  ),
                  const Divider(height: RiderSpacing.xl),
                  _InfoRow(
                    icon: Icons.receipt_long_rounded,
                    label: 'Trip Fare',
                    value: order.tripAmount > 0
                        ? currency.format(order.tripAmount)
                        : '—',
                    emphasize: true,
                  ),
                  const Divider(height: RiderSpacing.xl),
                  _InfoRow(
                    icon: Icons.payments_rounded,
                    label: 'Your Earnings',
                    value: currency.format(order.estimatedEarnings),
                  ),
                  const Divider(height: RiderSpacing.xl),
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Customer Payment',
                    value: currency.format(order.customerResponsibility),
                  ),
                  const Divider(height: RiderSpacing.xl),
                  _InfoRow(
                    icon: Icons.person_pin_circle_outlined,
                    label: 'Receiver Payment',
                    value: currency.format(order.receiverResponsibility),
                  ),
                  const Divider(height: RiderSpacing.xl),
                  _InfoRow(
                    icon: Icons.credit_score_rounded,
                    label: 'Payment Status',
                    value: order.paymentStatusLabel,
                  ),
                  const Divider(height: RiderSpacing.xl),
                  _InfoRow(
                    icon: Icons.timer_outlined,
                    label: 'Estimated Time',
                    value: order.etaLabel,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: RiderColors.primary, size: 22),
        const SizedBox(width: RiderSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: RiderTextStyles.caption),
              const SizedBox(height: 2),
              Text(
                value,
                style: emphasize
                    ? RiderTextStyles.title.copyWith(color: RiderColors.primary)
                    : RiderTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String? _httpPhotoUrl(String? raw) {
  final String value = (raw ?? '').trim();
  final Uri? uri = Uri.tryParse(value);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  if (uri.host.isEmpty) {
    return null;
  }
  return value;
}
