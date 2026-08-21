import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/dummy/rider_finance.dart';
import '../../data/models/rider_order.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_secondary_button.dart';

class IncomingOrderScreen extends ConsumerStatefulWidget {
  const IncomingOrderScreen({super.key});

  @override
  ConsumerState<IncomingOrderScreen> createState() =>
      _IncomingOrderScreenState();
}

class _IncomingOrderScreenState extends ConsumerState<IncomingOrderScreen> {
  late RiderOrder _order;
  late int _secondsLeft;
  Timer? _timer;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _order = ref.read(dummyRiderRepositoryProvider).getIncomingOrder();
    _secondsLeft = _order.decisionSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        setState(() {
          _secondsLeft = 0;
          _expired = true;
        });
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timerLabel {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _accept() {
    if (_expired) return;
    if (riderIsSuspended(ref)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account suspended until COD Due is cleared.'),
        ),
      );
      return;
    }
    _timer?.cancel();
    ref.read(activeOrderProvider.notifier).state = _order;
    ref.read(deliveryStatusProvider.notifier).state =
        DeliveryLifecycleStatus.accepted;
    context.push(RiderRoutes.acceptConfirmation);
  }

  void _reject() {
    _timer?.cancel();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return RiderScaffold(
      appBar: AppBar(
        title: const Text('New order'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _reject,
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
                    onPressed: _reject,
                  ),
                ),
                const SizedBox(width: RiderSpacing.md),
                Expanded(
                  flex: 2,
                  child: RiderPrimaryButton(
                    label: 'Accept',
                    onPressed: _accept,
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
            const SizedBox(height: RiderSpacing.xl),
            RiderGlassCard(
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.store_mall_directory_rounded,
                    label: 'Pickup',
                    value: _order.pickup,
                  ),
                  const Divider(height: RiderSpacing.xl),
                  _InfoRow(
                    icon: Icons.location_on_rounded,
                    label: 'Drop',
                    value: _order.drop,
                  ),
                  const Divider(height: RiderSpacing.xl),
                  _InfoRow(
                    icon: Icons.route_rounded,
                    label: 'Distance',
                    value: '${_order.distanceKm} km',
                  ),
                  const Divider(height: RiderSpacing.xl),
                  _InfoRow(
                    icon: Icons.payments_rounded,
                    label: 'Estimated Earnings',
                    value: currency.format(_order.estimatedEarnings),
                    emphasize: true,
                  ),
                  const Divider(height: RiderSpacing.xl),
                  _InfoRow(
                    icon: Icons.receipt_long_rounded,
                    label: 'Trip Amount',
                    value: currency.format(_order.tripAmount),
                  ),
                  const Divider(height: RiderSpacing.xl),
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Customer Payment',
                    value: currency.format(_order.customerResponsibility),
                  ),
                  const Divider(height: RiderSpacing.xl),
                  _InfoRow(
                    icon: Icons.person_pin_circle_outlined,
                    label: 'Receiver Payment',
                    value: currency.format(_order.receiverResponsibility),
                  ),
                  const Divider(height: RiderSpacing.xl),
                  _InfoRow(
                    icon: Icons.credit_score_rounded,
                    label: 'Payment Status',
                    value: _order.paymentStatusLabel,
                  ),
                  const Divider(height: RiderSpacing.xl),
                  _InfoRow(
                    icon: Icons.timer_outlined,
                    label: 'Estimated Time',
                    value: '${_order.estimatedMinutes} min',
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
