import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';

import '../../core/data/mock/mock_models.dart';
import '../../core/state/booking_api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import 'glass_container.dart';

/// Shared formatters and layout widgets for customer order history & details.
abstract final class CustomerOrderFormat {
  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// API timestamps are UTC (`timestamptz` → ISO-8601 with `Z`).
  /// `DateTime.hour` on a UTC value is the UTC hour, so convert once to the
  /// device zone (IST on customer phones) before reading calendar fields.
  static String dateTime(DateTime value) {
    final DateTime local = value.toLocal();
    final int h = local.hour;
    final int hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final String period = h >= 12 ? 'PM' : 'AM';
    final String minute = local.minute.toString().padLeft(2, '0');
    return '${local.day.toString().padLeft(2, '0')} '
        '${_months[local.month - 1]} ${local.year}, '
        '$hour12:$minute $period';
  }

  /// Real stop address from the API. Generic mapper fallbacks are not locations.
  static String? locationText(String? raw) {
    final String value = (raw ?? '').trim();
    if (value.isEmpty) {
      return null;
    }
    switch (value.toLowerCase()) {
      case 'pickup':
      case 'drop':
      case 'select location':
        return null;
      default:
        return value;
    }
  }

  static String displayLocation({
    String? stopAddress,
    String? mappedAddress,
  }) {
    return locationText(stopAddress) ??
        locationText(mappedAddress) ??
        'Address unavailable';
  }

  static String currency(double amount) {
    final bool whole = amount == amount.roundToDouble();
    return whole
        ? '₹${amount.toStringAsFixed(0)}'
        : '₹${amount.toStringAsFixed(1)}';
  }

  static String? contactLine(String? name, String? phone) {
    final String n = (name ?? '').trim();
    final String p = (phone ?? '').trim();
    if (n.isEmpty && p.isEmpty) {
      return null;
    }
    if (n.isNotEmpty && p.isNotEmpty) {
      return '$n · $p';
    }
    return n.isNotEmpty ? n : p;
  }

  static ApiStop? firstStop(ApiOrder? order, String type) {
    if (order == null) {
      return null;
    }
    return order.stops
        .where((ApiStop stop) => stop.stopType == type)
        .sorted((ApiStop a, ApiStop b) => a.sequence.compareTo(b.sequence))
        .firstOrNull;
  }

  static String? vehicleRegistration(ApiOrder? server, MockOrder order) {
    final String? fromServer =
        server?.assignedRider?.vehicleRegistration?.trim();
    if (fromServer != null && fromServer.isNotEmpty) {
      return fromServer;
    }
    final String label = order.rider?.vehicleLabel.trim() ?? '';
    if (label.isEmpty) {
      return null;
    }
    final List<String> parts = label
        .split('·')
        .map((String part) => part.trim())
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 2) {
      final String last = parts.last;
      if (RegExp(r'[A-Za-z0-9-]{4,}').hasMatch(last)) {
        return last;
      }
    }
    return null;
  }

  static String riderDisplayName(MockOrder order, ApiOrder? server) {
    final String? fromServer = server?.assignedRider?.name?.trim();
    if (fromServer != null && fromServer.isNotEmpty) {
      return fromServer;
    }
    final String? riderId = order.riderId;
    if (riderId == null || riderId.isEmpty) {
      return 'Rider not assigned';
    }
    final String name = order.rider?.name.trim() ?? '';
    if (name.isNotEmpty && name != 'Your rider') {
      return name;
    }
    return 'Rider assigned';
  }

  static String? riderPhone(MockOrder order, ApiOrder? server) {
    final String? fromServer = server?.assignedRider?.phone?.trim();
    if (fromServer != null && fromServer.isNotEmpty) {
      return fromServer;
    }
    final String phone = order.rider?.phone.trim() ?? '';
    return phone.isEmpty ? null : phone;
  }

  static Color statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.danger;
      case OrderStatus.failed:
      case OrderStatus.atCompanyOffice:
        return AppColors.warning;
      case OrderStatus.resendRequested:
        return AppColors.info;
      default:
        return AppColors.orange;
    }
  }

  static IconData statusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return Icons.check_rounded;
      case OrderStatus.cancelled:
        return Icons.close_rounded;
      default:
        return Icons.local_shipping_outlined;
    }
  }
}

class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({
    required this.label,
    required this.status,
    super.key,
  });

  final String label;
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = CustomerOrderFormat.statusColor(status);
    final TextStyle style = AppTextStyles.caption.copyWith(
      color: color,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxText = constraints.maxWidth.isFinite
            ? (constraints.maxWidth - 28).clamp(0, constraints.maxWidth).toDouble()
            : 220.0;
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: AppRadius.pillAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CustomerOrderFormat.statusIcon(status),
                size: 14,
                color: color,
              ),
              const SizedBox(width: AppSpacing.xxs),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxText),
                child: Text(
                  label.toUpperCase(),
                  style: style,
                  softWrap: true,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class OrderRouteTimeline extends StatelessWidget {
  const OrderRouteTimeline({
    required this.pickupAddress,
    required this.dropAddress,
    super.key,
    this.pickupContact,
    this.dropContact,
    this.compact = false,
  });

  final String? pickupContact;
  final String pickupAddress;
  final String? dropContact;
  final String dropAddress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.greyLight.withValues(alpha: 0.65),
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        children: [
          _RoutePoint(
            icon: Icons.arrow_upward_rounded,
            iconColor: AppColors.success,
            contact: pickupContact,
            address: pickupAddress,
            showConnector: true,
          ),
          _RoutePoint(
            icon: Icons.arrow_downward_rounded,
            iconColor: AppColors.danger,
            contact: dropContact,
            address: dropAddress,
            showConnector: false,
          ),
        ],
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({
    required this.icon,
    required this.iconColor,
    required this.address,
    required this.showConnector,
    this.contact,
  });

  final IconData icon;
  final Color iconColor;
  final String? contact;
  final String address;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 14, color: AppColors.white),
                ),
                if (showConnector)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: CustomPaint(
                        painter: _DashedLinePainter(
                          color: AppColors.greyDark.withValues(alpha: 0.55),
                        ),
                        size: const Size(2, double.infinity),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showConnector ? AppSpacing.md : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (contact != null && contact!.isNotEmpty)
                    Text(
                      contact!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (contact != null && contact!.isNotEmpty)
                    const SizedBox(height: AppSpacing.xxs),
                  Text(
                    address,
                    style: (contact == null || contact!.isEmpty)
                        ? AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.35,
                          )
                        : AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const double dash = 4;
    const double gap = 3;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OrderFareRow extends StatelessWidget {
  const OrderFareRow({
    required this.label,
    required this.value,
    super.key,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = emphasize
        ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)
        : AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary);
    final TextStyle valueStyle = emphasize
        ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)
        : AppTextStyles.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

class OrderSectionTitle extends StatelessWidget {
  const OrderSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: AppTextStyles.headingS.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}

/// Compact CTA sized to the label so "Book Again" is never ellipsized.
class OrderBookAgainButton extends StatelessWidget {
  const OrderBookAgainButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.pillAll,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppGradients.primaryCta,
            borderRadius: AppRadius.pillAll,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              'Book Again',
              maxLines: 1,
              softWrap: false,
              style: AppTextStyles.button.copyWith(fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}

/// Order list card with optional server enrichment for stops & vehicle reg.
class OrderHistoryCard extends ConsumerWidget {
  const OrderHistoryCard({
    required this.order,
    required this.onTap,
    required this.onBookAgain,
    super.key,
  });

  final MockOrder order;
  final VoidCallback onTap;
  final VoidCallback onBookAgain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? serverId = order.backendOrderId;
    final ApiOrder? serverOrder = serverId == null
        ? null
        : ref.watch(orderServerViewProvider(serverId)).asData?.value;

    final ApiStop? pickupStop =
        CustomerOrderFormat.firstStop(serverOrder, 'PICKUP');
    final ApiStop? dropStop =
        CustomerOrderFormat.firstStop(serverOrder, 'DROP');

    final String? vehicleReg =
        CustomerOrderFormat.vehicleRegistration(serverOrder, order);
    final String riderName = CustomerOrderFormat.riderDisplayName(order, serverOrder);
    final String? riderPhone = CustomerOrderFormat.riderPhone(order, serverOrder);
    final String crnText = (order.crn != null && order.crn!.trim().isNotEmpty)
        ? order.crn!.trim()
        : (serverOrder?.crn?.trim().isNotEmpty == true
            ? serverOrder!.crn!.trim()
            : '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.xlAll,
        onTap: onTap,
        child: GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SafeAssetImage(
                    path: order.vehicle.imagePath,
                    height: 52,
                    width: 52,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.vehicle.name,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          CustomerOrderFormat.dateTime(order.createdAt),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CustomerOrderFormat.currency(order.fare),
                        style: AppTextStyles.headingS.copyWith(
                          color: AppColors.navyDeep,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.navyMuted.withValues(alpha: 0.8),
                        size: 22,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              OrderRouteTimeline(
                compact: true,
                pickupAddress: CustomerOrderFormat.displayLocation(
                  stopAddress: pickupStop?.addressText,
                  mappedAddress: order.pickup.address,
                ),
                dropAddress: CustomerOrderFormat.displayLocation(
                  stopAddress: dropStop?.addressText,
                  mappedAddress: order.drop.address,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (crnText.isNotEmpty)
                _MetaLine(
                  label: 'CRN',
                  value: crnText,
                ),
              if (vehicleReg != null)
                _MetaLine(label: 'Vehicle', value: vehicleReg),
              _MetaLine(label: 'Rider', value: riderName),
              if (riderPhone != null)
                _MetaLine(
                  label: 'Contact',
                  value: riderPhone,
                  trailing: Icon(
                    Icons.phone_in_talk_outlined,
                    size: 16,
                    color: AppColors.orange,
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OrderStatusPill(
                        label: order.statusLabel,
                        status: order.status,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OrderBookAgainButton(onPressed: onBookAgain),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '$label:',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
