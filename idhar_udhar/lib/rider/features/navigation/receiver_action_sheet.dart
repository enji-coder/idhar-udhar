import 'package:flutter/material.dart';
import 'package:idhar_udhar/shared/phone/native_dialer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/rider_order.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
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
        padding: const EdgeInsets.fromLTRB(
          RiderSpacing.screenH,
          RiderSpacing.md,
          RiderSpacing.screenH,
          RiderSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: RiderColors.textPrimary,
                  ),
                  Expanded(
                    child: Text(
                      'Contact Details',
                      style: RiderTextStyles.heading.copyWith(fontSize: 20),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Call receiver',
                    onPressed: () => openNativePhoneDialer(
                      context,
                      order.receiverPhone,
                    ),
                    icon: const Icon(Icons.call_rounded),
                    color: RiderColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: RiderSpacing.md),
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
              const SizedBox(height: RiderSpacing.md),
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
              const SizedBox(height: RiderSpacing.lg),
              Material(
                color: const Color(0xFFF0F7F5),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RiderSpacing.md,
                    vertical: RiderSpacing.md,
                  ),
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
                          value: order.tripAmount > 0
                              ? '₹${order.tripAmount.toStringAsFixed(order.tripAmount == order.tripAmount.roundToDouble() ? 0 : 2)}'
                              : '—',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: RiderSpacing.lg),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onMarkUnavailable();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RiderColors.textPrimary,
                    side: const BorderSide(color: RiderColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: const Text('Receiver Unavailable'),
                ),
              ),
            ],
          ),
        ),
      ),
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
    return Material(
      color: RiderColors.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(RiderSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: RiderSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: RiderTextStyles.caption),
                      Text(shownName, style: RiderTextStyles.title),
                      Text(shownPhone, style: RiderTextStyles.body),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: RiderTextStyles.caption.copyWith(
                            color: badgeTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        onPressed: phone.trim().isEmpty
                            ? null
                            : () => openNativePhoneDialer(context, phone),
                        icon: const Icon(Icons.call_rounded, size: 16),
                        label: const Text('Call'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: RiderColors.primary,
                          side: const BorderSide(color: RiderColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        onPressed: phone.trim().isEmpty
                            ? null
                            : () {
                                _openWhatsApp(context, phone);
                              },
                        icon: const Icon(Icons.chat_rounded, size: 16),
                        label: const Text('WhatsApp'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: RiderColors.primary,
                          side: const BorderSide(color: RiderColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: RiderSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: RiderColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(locationLabel, style: RiderTextStyles.caption),
                      Text(location, style: RiderTextStyles.body),
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
        Icon(icon, size: 18, color: RiderColors.primary),
        const SizedBox(height: 4),
        Text(label, style: RiderTextStyles.caption),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: RiderTextStyles.bodyMedium.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

Future<void> _openWhatsApp(BuildContext context, String phone) async {
  final String digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) {
    return;
  }
  final Uri uri = Uri.parse('https://wa.me/$digits');
  try {
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp could not be opened.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp could not be opened.')),
      );
    }
  }
}
