import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/phone/native_dialer.dart';
import 'package:intl/intl.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/models/rider_order.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../profile/rider_profile_screen.dart';

class AcceptConfirmationScreen extends ConsumerWidget {
  const AcceptConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RiderOrder? order = ref.watch(activeOrderProvider);
    if (order == null) return const _NoActiveOrder();
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return RiderScaffold(
      bottom: RiderPrimaryButton(
        label: 'View Order Details',
        onPressed: () => context.push(RiderRoutes.orderDetails),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: RiderSpacing.xxl),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: RiderColors.success.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 48,
                color: RiderColors.success,
              ),
            ),
            const SizedBox(height: RiderSpacing.lg),
            Text('Order Accepted!', style: RiderTextStyles.heading),
            const SizedBox(height: RiderSpacing.sm),
            Text(
              'Head to pickup to start this delivery.',
              style: RiderTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: RiderSpacing.xl),
            RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order #${order.id}', style: RiderTextStyles.title),
                  if (order.crn != null && order.crn!.isNotEmpty)
                    Text('CRN ${order.crn}', style: RiderTextStyles.caption),
                  const SizedBox(height: RiderSpacing.md),
                  Text('Pickup', style: RiderTextStyles.caption),
                  Text(order.pickup, style: RiderTextStyles.bodyMedium),
                  const SizedBox(height: RiderSpacing.md),
                  Text('Drop', style: RiderTextStyles.caption),
                  Text(order.drop, style: RiderTextStyles.bodyMedium),
                  const SizedBox(height: RiderSpacing.md),
                  Text(
                    'Earnings ${currency.format(order.estimatedEarnings)}',
                    style: RiderTextStyles.bodyMedium.copyWith(
                      color: RiderColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
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

class OrderDetailsScreen extends ConsumerWidget {
  const OrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RiderOrder? order = ref.watch(activeOrderProvider);
    if (order == null) return const _NoActiveOrder();
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final String senderName = order.senderName.trim().isEmpty
        ? order.customerMaskedName
        : order.senderName;

    return RiderScaffold(
      padding: const EdgeInsets.fromLTRB(
        RiderSpacing.screenH,
        RiderSpacing.sm,
        RiderSpacing.screenH,
        RiderSpacing.sm,
      ),
      bottom: const _StartDeliveryButton(),
      body: Column(
        children: [
          _OrderHeader(
            title: 'CRM #${order.id}',
            photoUrl: _profilePhoto(
              ref.watch(riderProfileStateProvider).photoUrl,
            ),
            onBack: () => context.canPop()
                ? context.pop()
                : context.go(RiderRoutes.dashboard),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RouteCard(pickup: order.pickup, drop: order.drop),
                  const SizedBox(height: 12),
                  _TripStatsCard(
                    distance: order.distanceLabel,
                    eta: order.etaLabel,
                  ),
                  const SizedBox(height: 12),
                  _PaymentCard(
                    tripAmount: currency.format(order.tripAmount),
                    customerPayment:
                        currency.format(order.customerResponsibility),
                    receiverPayment:
                        currency.format(order.receiverResponsibility),
                    paymentStatus: order.paymentStatusLabel,
                    paymentLabel: order.paymentLabel,
                    paymentMethod: order.paymentMethod,
                  ),
                  const SizedBox(height: 12),
                  _ContactsCard(
                    senderName: senderName,
                    senderPhone: order.senderPhone,
                    receiverName: order.receiverName,
                    receiverPhone: order.receiverPhone,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartDeliveryButton extends StatelessWidget {
  const _StartDeliveryButton();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        RiderPrimaryButton(
          label: 'Start Delivery',
          onPressed: () => context.push(RiderRoutes.activeDelivery),
        ),
        const Positioned(
          right: 22,
          bottom: 8,
          child: IgnorePointer(
            child: Icon(
              Icons.auto_awesome,
              size: 13,
              color: Color(0xE6FFFFFF),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({
    required this.title,
    required this.onBack,
    this.photoUrl,
  });

  final String title;
  final VoidCallback onBack;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: 'Back',
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: RiderColors.textPrimary,
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: RiderTextStyles.title.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: RiderProfileAvatar(photoUrl: photoUrl, radius: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoActiveOrder extends StatelessWidget {
  const _NoActiveOrder();

  @override
  Widget build(BuildContext context) {
    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Order'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(RiderRoutes.dashboard),
        ),
      ),
      body: Center(
        child: Text(
          'No active order.',
          style: RiderTextStyles.caption,
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.pickup, required this.drop});

  final String pickup;
  final String drop;

  @override
  Widget build(BuildContext context) {
    return _OrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PendingChip(),
          const SizedBox(height: 16),
          _PickupStop(address: pickup),
          _StopRow(
            icon: Icons.location_on_rounded,
            title: 'Drop',
            address: drop,
          ),
        ],
      ),
    );
  }
}

class _PendingChip extends StatelessWidget {
  const _PendingChip();

  @override
  Widget build(BuildContext context) {
    const Color tone = Color(0xFFD9920A);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_rounded, size: 14, color: tone),
            const SizedBox(width: 4),
            Text(
              'Pickup pending',
              style: RiderTextStyles.caption.copyWith(
                color: tone,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickupStop extends StatelessWidget {
  const _PickupStop({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double textWidth = constraints.maxWidth - 34;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                width: 22,
                child: Column(
                  children: [
                    SizedBox(
                      height: 22,
                      width: 22,
                      child: Icon(
                        Icons.storefront_rounded,
                        size: 22,
                        color: RiderColors.primary,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 2),
                        child: _DottedRail(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: textWidth < 0 ? 0 : textWidth,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pickup', style: _OrderType.stopTitle),
                      const SizedBox(height: 2),
                      Text(address, style: _OrderType.stopBody),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.icon,
    required this.title,
    required this.address,
  });

  final IconData icon;
  final String title;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Icon(icon, size: 22, color: RiderColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _OrderType.stopTitle),
              const SizedBox(height: 2),
              Text(address, style: _OrderType.stopBody),
            ],
          ),
        ),
      ],
    );
  }
}

class _DottedRail extends StatelessWidget {
  const _DottedRail();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _DotPainter(),
      child: SizedBox.expand(),
    );
  }
}

class _DotPainter extends CustomPainter {
  const _DotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = RiderColors.primary.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    const double radius = 1.35;
    const double gap = 5.5;
    double y = radius;
    final double cx = size.width / 2;
    while (y < size.height - radius) {
      canvas.drawCircle(Offset(cx, y), radius, paint);
      y += gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TripStatsCard extends StatelessWidget {
  const _TripStatsCard({required this.distance, required this.eta});

  final String distance;
  final String eta;

  @override
  Widget build(BuildContext context) {
    return _OrderCard(
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              icon: Icons.u_turn_left_rounded,
              label: 'Distance',
              value: distance,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: RiderColors.border.withValues(alpha: 0.9),
          ),
          Expanded(
            child: _StatCell(
              icon: Icons.access_time_rounded,
              label: 'Estimated time',
              value: eta,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, color: RiderColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _OrderType.fieldLabel),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _OrderType.statValue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.tripAmount,
    required this.customerPayment,
    required this.receiverPayment,
    required this.paymentStatus,
    required this.paymentLabel,
    required this.paymentMethod,
  });

  final String tripAmount;
  final String customerPayment;
  final String receiverPayment;
  final String paymentStatus;
  final String paymentLabel;
  final RiderOrderPaymentMethod paymentMethod;

  @override
  Widget build(BuildContext context) {
    return _OrderCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _AmountCell(label: 'Trip Amount', value: tripAmount),
              ),
              Expanded(
                child: _AmountCell(
                  label: 'Customer Payment',
                  value: customerPayment,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _AmountCell(
                  label: 'Receiver Payment',
                  value: receiverPayment,
                  badge: paymentStatus.trim(),
                ),
              ),
              Expanded(
                child: _MethodCell(
                  label: 'Payment Method',
                  value: paymentLabel,
                  icon: _paymentIcon(paymentLabel, paymentMethod),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountCell extends StatelessWidget {
  const _AmountCell({
    required this.label,
    required this.value,
    this.badge = '',
  });

  final String label;
  final String value;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _OrderType.fieldLabel),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Text(value, style: _OrderType.amount),
            if (badge.isNotEmpty) _StatusBadge(label: badge),
          ],
        ),
      ],
    );
  }
}

class _MethodCell extends StatelessWidget {
  const _MethodCell({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _OrderType.fieldLabel),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(icon, size: 18, color: RiderColors.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _OrderType.methodValue,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final bool settled = _isSettled(label);
    final Color tone = settled ? RiderColors.success : const Color(0xFFE36A1B);
    final Color background =
        settled ? const Color(0xFFDCFCE7) : const Color(0xFFFFE8D2);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Text(
          label,
          style: RiderTextStyles.caption.copyWith(
            color: tone,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _ContactsCard extends StatelessWidget {
  const _ContactsCard({
    required this.senderName,
    required this.senderPhone,
    required this.receiverName,
    required this.receiverPhone,
  });

  final String senderName;
  final String senderPhone;
  final String receiverName;
  final String receiverPhone;

  @override
  Widget build(BuildContext context) {
    return _OrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contacts', style: _OrderType.sectionTitle),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ContactName(label: 'Sender', name: senderName),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ContactName(label: 'Receiver', name: receiverName),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CallButton(
                  label: 'Call Sender',
                  phone: senderPhone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CallButton(
                  label: 'Call Receiver',
                  phone: receiverPhone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactName extends StatelessWidget {
  const _ContactName({required this.label, required this.name});

  final String label;
  final String name;

  @override
  Widget build(BuildContext context) {
    final String shown = name.trim().isEmpty ? 'Not provided' : name.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _OrderType.fieldLabel),
        const SizedBox(height: 2),
        Text(shown, style: _OrderType.contactName),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({required this.label, required this.phone});

  final String label;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const StadiumBorder(
        side: BorderSide(color: RiderColors.primary, width: 1.2),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => openNativePhoneDialer(context, phone),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.call_rounded,
                  size: 16,
                  color: RiderColors.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RiderTextStyles.bodyMedium.copyWith(
                      color: RiderColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: RiderColors.primary.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

abstract final class _OrderType {
  static TextStyle get stopTitle => RiderTextStyles.bodyMedium.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle get stopBody => RiderTextStyles.body.copyWith(
        fontSize: 13.5,
        height: 1.35,
        color: RiderColors.textPrimary.withValues(alpha: 0.92),
      );

  static TextStyle get fieldLabel => RiderTextStyles.caption.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

  static TextStyle get statValue => RiderTextStyles.bodyMedium.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle get amount => RiderTextStyles.title.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.15,
      );

  static TextStyle get methodValue => RiderTextStyles.bodyMedium.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle get sectionTitle => RiderTextStyles.title.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle get contactName => RiderTextStyles.bodyMedium.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.25,
      );
}

IconData _paymentIcon(String label, RiderOrderPaymentMethod method) {
  final String value = label.toLowerCase();
  final bool hasCash =
      value.contains('cash') || method == RiderOrderPaymentMethod.cash;
  final bool hasOnline =
      value.contains('online') || method == RiderOrderPaymentMethod.online;
  if (hasCash && hasOnline) {
    return Icons.account_balance_wallet_outlined;
  }
  if (hasCash) {
    return Icons.payments_outlined;
  }
  return Icons.credit_card_rounded;
}

bool _isSettled(String label) {
  final String value = label.toUpperCase();
  return value.contains('PAID') && !value.contains('UNPAID');
}

String? _profilePhoto(String? raw) {
  final String value = (raw ?? '').trim();
  if (value.isEmpty) {
    return null;
  }
  return value;
}
