import 'package:flutter/material.dart';
import 'package:idhar_udhar/shared/phone/native_dialer.dart';

import '../../data/models/rider_order.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_text_styles.dart';

/// Contact + failed-delivery actions opened from the drop-nav prompt card.
///
/// Does not change status by itself; [onMarkUnavailable] starts the existing
/// confirmation dialog in the active delivery screen.
class ReceiverActionSheet extends StatelessWidget {
  const ReceiverActionSheet({
    required this.order,
    required this.onMarkUnavailable,
    super.key,
  });

  final RiderOrder order;
  final VoidCallback onMarkUnavailable;

  @override
  Widget build(BuildContext context) {
    final String senderName = order.senderName.trim().isEmpty
        ? order.customerMaskedName
        : order.senderName;
    final String senderPhone = order.senderPhone.trim().isEmpty
        ? order.customerMaskedPhone
        : order.senderPhone;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHeader(receiverPhone: order.receiverPhone),
              const SizedBox(height: 12),
              _ContactCard(
                title: 'Sender',
                badge: 'Shipper',
                badgeColor: const Color(0xFFD6E8FF),
                badgeTextColor: const Color(0xFF1D4ED8),
                avatarColor: const Color(0xFF3B82F6),
                name: senderName,
                phone: senderPhone,
                locationLabel: 'Pickup Location',
                location: order.pickup,
              ),
              const SizedBox(height: 10),
              _ContactCard(
                title: 'Receiver',
                badge: 'Customer',
                badgeColor: const Color(0xFFEDE4FF),
                badgeTextColor: const Color(0xFF6D28D9),
                avatarColor: const Color(0xFFEC4899),
                name: order.receiverName,
                phone: order.receiverPhone,
                locationLabel: 'Drop Location',
                location: order.drop,
              ),
              const SizedBox(height: 12),
              _OrderMeta(order: order),
              const SizedBox(height: 16),
              _UnavailableButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onMarkUnavailable();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.receiverPhone});

  final String receiverPhone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          color: RiderColors.textPrimary,
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Text(
            'Contact Details',
            style: RiderTextStyles.title.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Call receiver',
          onPressed: () => openNativePhoneDialer(context, receiverPhone),
          icon: const Icon(Icons.call_rounded),
          color: RiderColors.primary,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.title,
    required this.badge,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.avatarColor,
    required this.name,
    required this.phone,
    required this.locationLabel,
    required this.location,
  });

  final String title;
  final String badge;
  final Color badgeColor;
  final Color badgeTextColor;
  final Color avatarColor;
  final String name;
  final String phone;
  final String locationLabel;
  final String location;

  @override
  Widget build(BuildContext context) {
    final String shownName = name.trim().isEmpty ? '—' : name.trim();
    final String shownPhone = phone.trim().isEmpty ? '—' : phone.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RiderColors.border.withValues(alpha: 0.85)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: avatarColor,
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: _SheetType.caption),
                      const SizedBox(height: 1),
                      Text(shownName, style: _SheetType.name),
                      const SizedBox(height: 1),
                      Text(shownPhone, style: _SheetType.phone),
                      const SizedBox(height: 6),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Text(
                            badge,
                            style: _SheetType.caption.copyWith(
                              color: badgeTextColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _CallPill(phone: phone),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 10, bottom: 8),
              child: Divider(height: 1, color: RiderColors.border),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: RiderColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(locationLabel, style: _SheetType.caption),
                      const SizedBox(height: 1),
                      Text(location, style: _SheetType.body),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CallPill extends StatelessWidget {
  const _CallPill({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final bool enabled = phone.trim().isNotEmpty;
    return OutlinedButton.icon(
      onPressed: enabled ? () => openNativePhoneDialer(context, phone) : null,
      icon: const Icon(Icons.call_rounded, size: 16),
      label: const Text('Call'),
      style: OutlinedButton.styleFrom(
        foregroundColor: RiderColors.primary,
        disabledForegroundColor: RiderColors.hint,
        backgroundColor: Colors.white,
        minimumSize: const Size(78, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        side: BorderSide(
          color: enabled ? RiderColors.primary : RiderColors.border,
        ),
        shape: const StadiumBorder(),
        textStyle: RiderTextStyles.bodyMedium.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OrderMeta extends StatelessWidget {
  const _OrderMeta({required this.order});

  final RiderOrder order;

  @override
  Widget build(BuildContext context) {
    final String fare = order.tripAmount > 0
        ? '₹${order.tripAmount.toStringAsFixed(order.tripAmount == order.tripAmount.roundToDouble() ? 0 : 2)}'
        : '—';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: _MetaCell(
                icon: Icons.inventory_2_outlined,
                label: 'Order ID',
                value: order.id,
              ),
            ),
            Expanded(
              child: _MetaCell(
                icon: Icons.local_shipping_outlined,
                label: 'Items',
                value: order.packageLabel.trim().isEmpty
                    ? 'Parcel'
                    : order.packageLabel.trim(),
              ),
            ),
            Expanded(
              child: _MetaCell(
                icon: Icons.currency_rupee_rounded,
                label: 'Trip fare',
                value: fare,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: RiderColors.primary),
        const SizedBox(height: 4),
        Text(label, style: _SheetType.caption),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: _SheetType.metaValue,
        ),
      ],
    );
  }
}

class _UnavailableButton extends StatelessWidget {
  const _UnavailableButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: RiderColors.primary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: RiderColors.primary, width: 1.2),
          shape: const StadiumBorder(),
          textStyle: RiderTextStyles.bodyMedium.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: const Text('Receiver Unavailable'),
      ),
    );
  }
}

abstract final class _SheetType {
  static TextStyle get caption => RiderTextStyles.caption.copyWith(
        fontSize: 12,
        height: 1.25,
      );

  static TextStyle get name => RiderTextStyles.bodyMedium.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );

  static TextStyle get phone => RiderTextStyles.body.copyWith(
        fontSize: 13,
        height: 1.3,
        color: RiderColors.textSecondary,
      );

  static TextStyle get body => RiderTextStyles.body.copyWith(
        fontSize: 13,
        height: 1.35,
      );

  static TextStyle get metaValue => RiderTextStyles.bodyMedium.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );
}
