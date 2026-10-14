import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/dummy/rider_finance.dart';
import '../../data/models/rider_order.dart';
import '../../push/rider_accept_flow.dart';
import '../../push/rider_offer_alerts.dart';
import '../../push/rider_offer_diag.dart';
import '../../routing/rider_routes.dart';
import '../../state/rider_session.dart';
import '../../widgets/rider_order_alert.dart';

class IncomingOrderScreen extends ConsumerStatefulWidget {
  const IncomingOrderScreen({super.key});

  @override
  ConsumerState<IncomingOrderScreen> createState() =>
      _IncomingOrderScreenState();
}

class _IncomingOrderScreenState extends ConsumerState<IncomingOrderScreen> {
  RiderOrder? _order;
  RiderOffer? _sourceOffer;
  StreamSubscription<RiderOfferUserAction>? _actions;
  bool _expired = false;
  bool _loading = true;
  bool _submitting = false;
  bool _inLoad = false;
  bool _applyingAction = false;
  Timer? _leaveTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
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
      } on ApiException catch (error) {
        riderOfferLog(
          'order_details_failed',
          offerId: offer.offerId,
          reason: error.code,
        );
      } catch (error) {
        riderOfferLog(
          'order_details_failed',
          offerId: offer.offerId,
          reason: error.runtimeType.toString(),
        );
      }
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
      });
      riderOfferLog(
        'incoming_screen_ready',
        offerId: offer.offerId,
        reason: 'seconds_left=${mapped.decisionSeconds}',
      );
      await _applyPendingAction();
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
    _leaveTimer?.cancel();
    _actions?.cancel();
    super.dispose();
  }

  void _handleExpired() {
    if (mounted) {
      setState(() => _expired = true);
    } else {
      _expired = true;
    }
    unawaited(cancelRiderOfferAlert(_order?.offerId));
    if (_leaveTimer != null) {
      return;
    }
    _leaveTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _submitting) {
        return;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(RiderRoutes.dashboard);
      }
    });
  }

  Future<bool> _accept() async {
    final RiderOrder? order = _order;
    if (_expired || _submitting || order == null) {
      return false;
    }
    final DateTime? expiresAt = order.expiresAt;
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
      _handleExpired();
      return false;
    }
    if (!ref.read(riderSessionProvider).isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your profile must be approved before you can accept orders.',
          ),
        ),
      );
      return false;
    }
    if (riderIsSuspended(ref)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account suspended until COD Due is cleared.'),
        ),
      );
      return false;
    }
    if (!ref.read(riderOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Go online to accept delivery requests.'),
        ),
      );
      return false;
    }
    final String? offerId = order.offerId;
    if (offerId == null || offerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This order request is no longer available.'),
        ),
      );
      return false;
    }
    setState(() => _submitting = true);
    var acceptedOk = false;
    try {
      final RiderOffer active = _sourceOffer ??
          RiderOffer(
            offerId: offerId,
            orderId: order.backendOrderId ?? '',
            status: 'PENDING',
            createdAt: DateTime.now(),
            displayId: order.id,
            tripFare: order.tripAmount,
            distanceKm: order.distanceKm,
            estimatedDurationSeconds:
                order.estimatedMinutes > 0 ? order.estimatedMinutes * 60 : null,
          );
      final RiderOrder accepted = await loadOrderAfterAccept(
        api: ref.read(riderApiProvider),
        offer: active,
      );
      if (!mounted) {
        return false;
      }
      unawaited(cancelRiderOfferAlert(order.offerId));
      final String route = await publishAcceptedOrder(
        ref: ref,
        order: accepted,
      );
      if (!mounted) {
        return false;
      }
      acceptedOk = true;
      context.go(route);
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
        unawaited(ref.read(riderSessionProvider.notifier).refreshOffers());
      }
      return false;
    } finally {
      if (mounted && _submitting && !acceptedOk) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<bool> _reject() async {
    if (_submitting || _expired) {
      return false;
    }
    final String? offerId = _order?.offerId;
    if (offerId == null || offerId.isEmpty) {
      if (mounted) {
        context.pop();
      }
      return true;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(riderApiProvider).rejectOffer(offerId);
      unawaited(cancelRiderOfferAlert(offerId));
      if (mounted) {
        context.pop();
      }
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
        setState(() => _submitting = false);
      }
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reject this request. Try again.'),
          ),
        );
        setState(() => _submitting = false);
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canLeave = _expired || _order == null || _error != null;
    return PopScope(
      canPop: canLeave,
      child: Scaffold(
        backgroundColor: const Color(0xB3000000),
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _order == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error ?? 'No incoming orders right now.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: RiderIncomingOfferCard(
                          key: ValueKey<String>(_order!.offerId ?? _order!.id),
                          order: _order!,
                          onAccept: _accept,
                          onReject: _reject,
                          onExpired: _handleExpired,
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}
