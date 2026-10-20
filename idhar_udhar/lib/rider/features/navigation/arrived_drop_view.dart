import 'package:flutter/material.dart';

import '../../theme/rider_colors.dart';
import '../../theme/rider_text_styles.dart';

/// Arrived-at-drop presentation. Actions are supplied by the active trip.
class ArrivedDropView extends StatefulWidget {
  const ArrivedDropView({
    required this.orderTitle,
    required this.pickup,
    required this.drop,
    required this.packageLabel,
    required this.distanceLabel,
    required this.etaLabel,
    required this.onMenu,
    required this.onNavigate,
    required this.onReceiverUnavailable,
    required this.onArrived,
    this.primaryEnabled = true,
    this.onBack,
    super.key,
  });

  final String orderTitle;
  final String pickup;
  final String drop;
  final String packageLabel;
  final String distanceLabel;
  final String etaLabel;
  final VoidCallback onMenu;
  final VoidCallback onNavigate;
  final VoidCallback onReceiverUnavailable;
  final VoidCallback? onArrived;
  final bool primaryEnabled;
  final VoidCallback? onBack;

  @override
  State<ArrivedDropView> createState() => _ArrivedDropViewState();
}

class _ArrivedDropViewState extends State<ArrivedDropView> {
  bool _detailsOpen = false;

  @override
  Widget build(BuildContext context) {
    final String title = widget.orderTitle.trim().isEmpty
        ? 'Arrived at Drop'
        : 'Order ${widget.orderTitle.trim()}';
    final String item = widget.packageLabel.trim().isEmpty
        ? '—'
        : widget.packageLabel.trim();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(title: title, onMenu: widget.onMenu, onBack: widget.onBack),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const _DropBanner(),
                    const SizedBox(height: 12),
                    _StopPair(pickup: widget.pickup, drop: widget.drop),
                    const SizedBox(height: 12),
                    _StatsRow(
                      packageLabel: item,
                      distanceLabel: widget.distanceLabel,
                      etaLabel: widget.etaLabel,
                    ),
                    const SizedBox(height: 12),
                    _OrderDetailsCard(
                      open: _detailsOpen,
                      orderId: widget.orderTitle.trim().isEmpty
                          ? '—'
                          : widget.orderTitle.trim(),
                      item: item,
                      pickup: widget.pickup,
                      drop: widget.drop,
                      onToggle: () => setState(() => _detailsOpen = !_detailsOpen),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            _ReceiverPrompt(onTap: widget.onReceiverUnavailable),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: widget.onNavigate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: RiderColors.primary,
                  side: const BorderSide(color: RiderColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Start navigation to drop'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: widget.primaryEnabled ? widget.onArrived : null,
              style: FilledButton.styleFrom(
                backgroundColor: RiderColors.primary,
                foregroundColor: RiderColors.textOnPrimary,
                disabledBackgroundColor:
                    RiderColors.primary.withValues(alpha: 0.4),
                minimumSize: const Size.fromHeight(64),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: RiderTextStyles.button.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.check_circle_rounded, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'ARRIVED AT DROP LOCATION',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Complete the delivery',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xE6FFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.inventory_2_outlined, size: 20),
                  Icon(Icons.chevron_right_rounded, size: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onMenu,
    this.onBack,
  });

  final String title;
  final VoidCallback onMenu;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: RiderColors.textPrimary,
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: RiderTextStyles.title.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Order details',
            onPressed: onMenu,
            icon: const Icon(Icons.menu_rounded),
            color: RiderColors.textPrimary,
          ),
        ],
      ),
    );
  }
}

class _DropBanner extends StatelessWidget {
  const _DropBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _card,
      child: Row(
        children: [
          const Icon(
            Icons.location_on_rounded,
            color: RiderColors.primary,
            size: 26,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Drop Location',
              style: RiderTextStyles.title.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: RiderColors.primary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE5F6EF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(width: 4),
                Text(
                  'Arrived',
                  style: RiderTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StopPair extends StatelessWidget {
  const _StopPair({required this.pickup, required this.drop});

  final String pickup;
  final String drop;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StopCard(
            icon: Icons.warehouse_rounded,
            iconColor: RiderColors.primary,
            title: 'Pickup',
            address: pickup,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StopCard(
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: 'Drop',
            address: drop,
          ),
        ),
      ],
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.address,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String address;

  @override
  Widget build(BuildContext context) {
    final String shown = address.trim().isEmpty ? '—' : address.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: RiderTextStyles.bodyMedium.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            shown,
            style: RiderTextStyles.caption.copyWith(
              fontSize: 12,
              height: 1.35,
              color: RiderColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.packageLabel,
    required this.distanceLabel,
    required this.etaLabel,
  });

  final String packageLabel;
  final String distanceLabel;
  final String etaLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: _card,
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              icon: Icons.inventory_2_outlined,
              label: 'Package',
              value: packageLabel,
            ),
          ),
          const _Divider(),
          Expanded(
            child: _Stat(
              icon: Icons.location_on_outlined,
              label: 'Distance',
              value: _approx(distanceLabel),
            ),
          ),
          const _Divider(),
          Expanded(
            child: _Stat(
              icon: Icons.schedule_rounded,
              label: 'Est. Time',
              value: etaLabel.trim().isEmpty ? '—' : etaLabel.trim(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
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
        Icon(icon, size: 20, color: RiderColors.primary),
        const SizedBox(height: 4),
        Text(label, style: RiderTextStyles.caption.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: RiderTextStyles.bodyMedium.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 42, color: const Color(0xFFE3EEEC));
  }
}

class _OrderDetailsCard extends StatelessWidget {
  const _OrderDetailsCard({
    required this.open,
    required this.orderId,
    required this.item,
    required this.pickup,
    required this.drop,
    required this.onToggle,
  });

  final bool open;
  final String orderId;
  final String item;
  final String pickup;
  final String drop;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _card,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: RiderColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: RiderColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Order Details',
                      style: RiderTextStyles.title.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: RiderColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  _DetailLine(label: 'Order ID', value: orderId),
                  _DetailLine(label: 'Item', value: item),
                  _DetailLine(
                    label: 'Pickup',
                    value: pickup.trim().isEmpty ? '—' : pickup.trim(),
                  ),
                  _DetailLine(
                    label: 'Drop',
                    value: drop.trim().isEmpty ? '—' : drop.trim(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: RiderTextStyles.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: RiderTextStyles.bodyMedium.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiverPrompt extends StatelessWidget {
  const _ReceiverPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Receiver Not Available? Tap Here',
      child: Material(
        color: const Color(0xFFFFF4E8),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE0C2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_in_talk_rounded,
                    color: Color(0xFFE37B12),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receiver not available?',
                        style: RiderTextStyles.title.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Open contact and info to call the sender or receiver and get more details.',
                        style: RiderTextStyles.caption.copyWith(
                          fontSize: 12,
                          height: 1.3,
                          color: const Color(0xFF9A5B16),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFE37B12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _approx(String value) {
  final String text = value.trim();
  if (text.isEmpty || text == '—') {
    return '—';
  }
  return text.startsWith('~') ? text : '~ $text';
}

BoxDecoration get _card => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x140F3D3E),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    );
