import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/business/business.dart';
import 'package:intl/intl.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/dummy/rider_finance.dart';
import '../../data/models/recent_activity.dart';
import '../../data/models/rider_announcement.dart';
import '../../data/models/rider_order.dart';
import '../../routing/rider_routes.dart';
import '../../screens/earnings/rider_income_screen.dart';
import '../../screens/orders/rider_history_screen.dart';
import '../../screens/profile/rider_profile_screen.dart';
import '../../screens/wallet/rider_wallet_screen.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_background.dart';
import '../../widgets/rider_drawer.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_secondary_button.dart';
import '../../widgets/rider_section_header.dart';
import '../../widgets/rider_stat_card.dart';

/// Dashboard-only: ~1pt smaller than shared Rider text styles.
TextStyle _d(TextStyle style) {
  final size = style.fontSize;
  if (size == null) return style;
  return style.copyWith(fontSize: size - 1);
}

const EdgeInsets _dashCardPad = EdgeInsets.all(RiderSpacing.xl - 1);
const double _dashElevation = 10;

/// Main rider shell: Home / Orders / History / Earnings / Profile.
class RiderDashboardScreen extends ConsumerStatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  ConsumerState<RiderDashboardScreen> createState() =>
      _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends ConsumerState<RiderDashboardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiderColors.background,
      drawer: const RiderDrawer(),
      body: RiderBackground(
        child: SafeArea(
          child: IndexedStack(
            index: _tab,
            children: const [
              _HomeTab(),
              _OrdersTab(),
              RiderHistoryScreen(showAppBar: false),
              RiderIncomeScreen(showAppBar: false),
              RiderProfileScreen(showAppBar: false),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: RiderColors.surfaceGlass,
        indicatorColor: RiderColors.primary.withValues(alpha: 0.15),
        labelBehavior: MediaQuery.sizeOf(context).width < 360
            ? NavigationDestinationLabelBehavior.onlyShowSelected
            : NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: RiderColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon:
                Icon(Icons.receipt_long_rounded, color: RiderColors.primary),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon:
                Icon(Icons.history_rounded, color: RiderColors.primary),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(
              Icons.account_balance_wallet_rounded,
              color: RiderColors.primary,
            ),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon:
                Icon(Icons.person_rounded, color: RiderColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(dummyRiderRepositoryProvider);
    final profile = ref.watch(riderProfileStateProvider);
    final earnings = repo.getEarnings();
    final activity = repo.getRecentActivity();
    final announcements = repo.getAnnouncements();
    final order = repo.getIncomingOrder();
    final online = ref.watch(riderOnlineProvider);
    final wallet = ref.watch(riderWalletBalanceProvider);
    final codDue = ref.watch(riderCodDueProvider);
    final lastSettlement = ref.watch(riderLastSettlementProvider);
    final suspended = CodEngine.isSuspended(codDue);
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final walletCurrency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            RiderSpacing.screenH,
            RiderSpacing.md,
            RiderSpacing.screenH,
            RiderSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DashboardHeader(
                greeting: '${_greeting()}, ${profile.firstName} 👋',
                online: online,
                onNotifications: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: RiderColors.secondary,
                      content: Text(
                        'No new notifications (demo)',
                        style: _d(RiderTextStyles.bodyMedium).copyWith(
                          color: RiderColors.textOnPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: RiderSpacing.lg),
              _DutyStatusCard(
                online: online,
                onToggle: () {
                  ref.read(riderOnlineProvider.notifier).state = !online;
                },
              ),
              if (online && !suspended) ...[
                const SizedBox(height: RiderSpacing.md),
                _IncomingOrderCard(
                  order: order,
                  currency: currency,
                  onReject: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: RiderColors.secondary,
                        content: Text(
                          'Order rejected (demo)',
                          style: _d(RiderTextStyles.bodyMedium).copyWith(
                            color: RiderColors.textOnPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                  onAccept: () {
                    if (riderIsSuspended(ref)) return;
                    ref.read(activeOrderProvider.notifier).state = order;
                    ref.read(deliveryStatusProvider.notifier).state =
                        DeliveryLifecycleStatus.accepted;
                    context.push(RiderRoutes.acceptConfirmation);
                  },
                ),
              ],
              if (suspended) ...[
                const SizedBox(height: RiderSpacing.md),
                RiderGlassCard(
                  elevation: _dashElevation,
                  padding: _dashCardPad,
                  child: Text(
                    'Account suspended. COD Due is ₹${codDue.toStringAsFixed(0)} (limit ₹100). Add money to clear COD Due before accepting rides.',
                    style: _d(RiderTextStyles.bodyMedium),
                  ),
                ),
              ],
              const SizedBox(height: RiderSpacing.md),
              RiderGlassCard(
                elevation: _dashElevation,
                padding: _dashCardPad,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's Earnings", style: _d(RiderTextStyles.caption)),
                    const SizedBox(height: RiderSpacing.sm),
                    Text(
                      currency.format(earnings.todayAmount),
                      style: _d(RiderTextStyles.display).copyWith(fontSize: 33),
                    ),
                    const SizedBox(height: RiderSpacing.xs),
                    Text(
                      '+${earnings.yesterdayChangePercent}% from yesterday',
                      style: _d(RiderTextStyles.caption).copyWith(
                        color: RiderColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: RiderSpacing.md),
              _WalletHighlightCard(
                balanceLabel: walletCurrency.format(wallet),
                codDueLabel: walletCurrency.format(codDue),
                settlementLabel: lastSettlement == null ||
                        lastSettlement.settledAgainstCod <= 0
                    ? null
                    : 'Last settlement ${walletCurrency.format(lastSettlement.settledAgainstCod)} from ${walletCurrency.format(lastSettlement.grossEarning)}',
                onAddMoney: () => showRiderWalletAmountSheet(
                  context: context,
                  ref: ref,
                  title: 'Add Money',
                  confirmLabel: 'Add',
                  onConfirm: (amount) => applyRiderRecharge(ref, amount),
                ),
                onWithdraw: () => showRiderWalletAmountSheet(
                  context: context,
                  ref: ref,
                  title: 'Withdraw Money',
                  confirmLabel: 'Withdraw',
                  maxAmount: wallet,
                  onConfirm: (amount) {
                    ref.read(riderWalletBalanceProvider.notifier).state =
                        (wallet - amount).clamp(0, double.infinity);
                  },
                ),
              ),
              const SizedBox(height: RiderSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: RiderStatCard(
                      label: 'Completed Orders',
                      value: '${earnings.completedOrders}',
                      icon: Icons.inventory_2_outlined,
                      elevation: _dashElevation,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: RiderSpacing.md),
                  Expanded(
                    child: RiderStatCard(
                      label: 'Online Time',
                      value: _formatDuration(earnings.onlineDuration),
                      icon: Icons.schedule_rounded,
                      elevation: _dashElevation,
                      compact: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RiderSpacing.md),
              RiderStatCard(
                label: 'Rating',
                value: '${profile.rating.toStringAsFixed(1)} ★',
                icon: Icons.star_rounded,
                subtitle: 'Customer rating',
                elevation: _dashElevation,
                compact: true,
              ),
              const SizedBox(height: RiderSpacing.md),
              _AnnouncementsCard(items: announcements),
              const SizedBox(height: RiderSpacing.md),
              RiderGlassCard(
                elevation: _dashElevation,
                padding: _dashCardPad,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RiderSectionHeader(title: 'Recent activity'),
                    const SizedBox(height: RiderSpacing.md),
                    for (var i = 0; i < activity.length; i++) ...[
                      _ActivityRow(item: activity[i], currency: currency),
                      if (i < activity.length - 1)
                        const Divider(height: RiderSpacing.xl),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.greeting,
    required this.online,
    required this.onNotifications,
  });

  final String greeting;
  final bool online;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Menu',
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: const Icon(
            Icons.menu_rounded,
            color: RiderColors.textPrimary,
          ),
        ),
        CircleAvatar(
          radius: 23,
          backgroundColor: RiderColors.primary.withValues(alpha: 0.15),
          child: const Icon(Icons.person_rounded, color: RiderColors.primary),
        ),
        const SizedBox(width: RiderSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: _d(RiderTextStyles.heading).copyWith(fontSize: 17),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              RiderStatusChip(
                label: online ? 'ONLINE' : 'OFFLINE',
                tone: online ? RiderChipTone.success : RiderChipTone.neutral,
                icon: online ? Icons.circle : Icons.circle_outlined,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: onNotifications,
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: RiderColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DutyStatusCard extends StatelessWidget {
  const _DutyStatusCard({
    required this.online,
    required this.onToggle,
  });

  final bool online;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return RiderGlassCard(
      elevation: _dashElevation,
      padding: _dashCardPad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                online ? Icons.wifi_tethering_rounded : Icons.wifi_off_rounded,
                color: online ? RiderColors.success : RiderColors.offline,
              ),
              const SizedBox(width: RiderSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      online ? "You're Online" : "You're Offline",
                      style: _d(RiderTextStyles.title).copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      online
                          ? 'Looking for new orders...'
                          : 'Go Online to receive new orders.',
                      style: _d(RiderTextStyles.caption),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    online ? 'ONLINE' : 'OFFLINE',
                    style: _d(RiderTextStyles.caption).copyWith(
                      fontWeight: FontWeight.w700,
                      color: online ? RiderColors.success : RiderColors.offline,
                    ),
                  ),
                  Switch(
                    value: online,
                    activeTrackColor: RiderColors.success,
                    onChanged: (_) => onToggle(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncomingOrderCard extends StatelessWidget {
  const _IncomingOrderCard({
    required this.order,
    required this.currency,
    required this.onReject,
    required this.onAccept,
  });

  final RiderOrder order;
  final NumberFormat currency;
  final VoidCallback onReject;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 8,
      shadowColor: RiderColors.primary.withValues(alpha: 0.16),
      borderRadius: RiderRadius.xlAll,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: RiderRadius.xlAll,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFE8F8F5),
              Colors.white,
            ],
          ),
          border: Border.all(
            color: RiderColors.primary.withValues(alpha: 0.14),
          ),
        ),
        child: Padding(
          padding: _dashCardPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'New Delivery Request',
                      style: _d(RiderTextStyles.title).copyWith(fontSize: 15),
                    ),
                  ),
                  const RiderStatusChip(
                    label: 'NEW',
                    tone: RiderChipTone.warning,
                  ),
                ],
              ),
              const SizedBox(height: RiderSpacing.md),
              _miniRow('Pickup', order.pickup, Icons.store_mall_directory_rounded),
              const SizedBox(height: RiderSpacing.sm),
              _miniRow('Drop', order.drop, Icons.location_on_rounded),
              const SizedBox(height: RiderSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${order.distanceKm} km',
                      style: _d(RiderTextStyles.caption),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      currency.format(order.estimatedEarnings),
                      style: _d(RiderTextStyles.bodyMedium).copyWith(
                        color: RiderColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${order.estimatedMinutes} min',
                      style: _d(RiderTextStyles.caption),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RiderSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: RiderSecondaryButton(
                      label: 'Reject',
                      destructive: true,
                      onPressed: onReject,
                    ),
                  ),
                  const SizedBox(width: RiderSpacing.md),
                  Expanded(
                    flex: 2,
                    child: RiderPrimaryButton(
                      label: 'Accept',
                      onPressed: onAccept,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RiderSpacing.sm),
              TextButton(
                onPressed: () => context.push(RiderRoutes.incomingOrder),
                child: Text(
                  'Open full order alert',
                  style: _d(RiderTextStyles.caption).copyWith(
                    color: RiderColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: RiderColors.primary),
        const SizedBox(width: RiderSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _d(RiderTextStyles.caption)),
              Text(value, style: _d(RiderTextStyles.bodyMedium)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, required this.currency});

  final RecentActivityItem item;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order #${item.orderId}', style: _d(RiderTextStyles.bodyMedium)),
              const SizedBox(height: 2),
              Text(item.routeLabel, style: _d(RiderTextStyles.caption)),
              const SizedBox(height: 4),
              RiderStatusChip(
                label: item.status,
                tone: RiderChipTone.success,
                icon: Icons.check_circle_outline_rounded,
              ),
            ],
          ),
        ),
        Text(
          currency.format(item.amount),
          style: _d(RiderTextStyles.bodyMedium).copyWith(
            color: RiderColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(dummyRiderRepositoryProvider).getRecentActivity();
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(RiderSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Orders', style: _d(RiderTextStyles.heading)),
          const SizedBox(height: RiderSpacing.sm),
          Text(
            'Recent completed deliveries',
            style: _d(RiderTextStyles.caption),
          ),
          const SizedBox(height: RiderSpacing.xl),
          for (final item in activity) ...[
            RiderGlassCard(
              elevation: _dashElevation,
              padding: _dashCardPad,
              child: _ActivityRow(item: item, currency: currency),
            ),
            const SizedBox(height: RiderSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _WalletHighlightCard extends StatelessWidget {
  const _WalletHighlightCard({
    required this.balanceLabel,
    required this.codDueLabel,
    required this.onAddMoney,
    required this.onWithdraw,
    this.settlementLabel,
  });

  final String balanceLabel;
  final String codDueLabel;
  final String? settlementLabel;
  final VoidCallback onAddMoney;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 12,
      shadowColor: RiderColors.secondary.withValues(alpha: 0.38),
      borderRadius: RiderRadius.xlAll,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: RiderRadius.xlAll,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              RiderColors.secondary,
              RiderColors.primary,
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.28),
          ),
        ),
        child: Padding(
          padding: _dashCardPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: RiderRadius.smAll,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: RiderColors.textOnPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: RiderSpacing.md),
                  Expanded(
                    child: Text(
                      'Wallet',
                      style: _d(RiderTextStyles.bodyMedium).copyWith(
                        color: RiderColors.textOnPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RiderSpacing.md),
              Text(
                'Current Balance',
                style: _d(RiderTextStyles.caption).copyWith(
                  color: RiderColors.textOnPrimary.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: RiderSpacing.xs),
              Text(
                balanceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _d(RiderTextStyles.display).copyWith(
                  fontSize: 33,
                  color: RiderColors.textOnPrimary,
                ),
              ),
              const SizedBox(height: RiderSpacing.sm),
              Text(
                'COD Due $codDueLabel',
                style: _d(RiderTextStyles.caption).copyWith(
                  color: RiderColors.textOnPrimary.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (settlementLabel != null) ...[
                const SizedBox(height: RiderSpacing.xs),
                Text(
                  settlementLabel!,
                  style: _d(RiderTextStyles.caption).copyWith(
                    color: RiderColors.textOnPrimary.withValues(alpha: 0.82),
                  ),
                ),
              ],
              const SizedBox(height: RiderSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _WalletActionButton(
                      label: 'Add Money',
                      filled: true,
                      onPressed: onAddMoney,
                    ),
                  ),
                  const SizedBox(width: RiderSpacing.md),
                  Expanded(
                    child: _WalletActionButton(
                      label: 'Withdraw',
                      filled: false,
                      onPressed: onWithdraw,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletActionButton extends StatelessWidget {
  const _WalletActionButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled
          ? RiderColors.textOnPrimary
          : Colors.white.withValues(alpha: 0.12),
      borderRadius: RiderRadius.pillAll,
      child: InkWell(
        borderRadius: RiderRadius.pillAll,
        onTap: onPressed,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: RiderRadius.pillAll,
            border: filled
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.7)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _d(RiderTextStyles.bodyMedium).copyWith(
              color: filled ? RiderColors.primary : RiderColors.textOnPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementsCard extends StatefulWidget {
  const _AnnouncementsCard({required this.items});

  final List<RiderAnnouncement> items;

  @override
  State<_AnnouncementsCard> createState() => _AnnouncementsCardState();
}

class _AnnouncementsCardState extends State<_AnnouncementsCard> {
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!mounted) return;
        setState(() => _page = (_page + 1) % widget.items.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  IconData _icon(RiderAnnouncementKind kind) {
    switch (kind) {
      case RiderAnnouncementKind.incentive:
        return Icons.emoji_events_outlined;
      case RiderAnnouncementKind.referral:
        return Icons.group_add_rounded;
      case RiderAnnouncementKind.bonus:
        return Icons.card_giftcard_rounded;
      case RiderAnnouncementKind.weekend:
        return Icons.weekend_outlined;
      case RiderAnnouncementKind.opportunity:
        return Icons.local_shipping_outlined;
      case RiderAnnouncementKind.update:
        return Icons.campaign_outlined;
      case RiderAnnouncementKind.policy:
        return Icons.policy_outlined;
    }
  }

  Color _badgeColor(String badge) {
    switch (badge.toUpperCase()) {
      case 'NEW':
        return RiderColors.primary;
      case 'BONUS':
        return RiderColors.warning;
      case 'INCENTIVE':
        return RiderColors.success;
      default:
        return RiderColors.secondary;
    }
  }

  void _showDetails(RiderAnnouncement item) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: RiderColors.surface,
          shape: RoundedRectangleBorder(borderRadius: RiderRadius.lgAll),
          title: Text(item.title, style: RiderTextStyles.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.body, style: RiderTextStyles.body),
                if (item.dateLabel != null) ...[
                  const SizedBox(height: RiderSpacing.md),
                  Text(item.dateLabel!, style: RiderTextStyles.caption),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: RiderTextStyles.bodyMedium.copyWith(
                  color: RiderColors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final current = items[_page.clamp(0, items.length - 1)];
    final badge = current.badge;
    final badgeColor = badge == null ? null : _badgeColor(badge);

    return Material(
      color: Colors.transparent,
      elevation: _dashElevation,
      shadowColor: RiderColors.primary.withValues(alpha: 0.28),
      borderRadius: RiderRadius.xlAll,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: RiderRadius.xlAll,
          color: RiderColors.surfaceGlass,
          border: Border.all(
            color: RiderColors.primary.withValues(alpha: 0.28),
          ),
        ),
        child: ClipRRect(
          borderRadius: RiderRadius.xlAll,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: RiderColors.primary, width: 5),
              ),
            ),
            child: Padding(
              padding: _dashCardPad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.campaign_rounded,
                        color: RiderColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: RiderSpacing.sm),
                      Expanded(
                        child: Text(
                          'Company Announcement',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _d(RiderTextStyles.caption).copyWith(
                            fontWeight: FontWeight.w700,
                            color: RiderColors.primary,
                          ),
                        ),
                      ),
                      if (badge != null && badgeColor != null)
                        Padding(
                          padding: const EdgeInsets.only(left: RiderSpacing.sm),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: RiderSpacing.sm,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.14),
                              borderRadius: RiderRadius.pillAll,
                              border: Border.all(
                                color: badgeColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              badge,
                              style: _d(RiderTextStyles.caption).copyWith(
                                color: badgeColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: Column(
                      key: ValueKey<int>(_page),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: RiderColors.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: RiderRadius.smAll,
                              ),
                              child: Icon(
                                _icon(current.kind),
                                color: RiderColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: RiderSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    current.title,
                                    style: _d(RiderTextStyles.bodyMedium)
                                        .copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    current.body,
                                    style: _d(RiderTextStyles.caption),
                                  ),
                                  if (current.dateLabel != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      current.dateLabel!,
                                      style: _d(RiderTextStyles.caption)
                                          .copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: RiderColors.secondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: RiderSpacing.sm),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _showDetails(current),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: RiderSpacing.sm,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'View Details →',
                              style: _d(RiderTextStyles.caption).copyWith(
                                color: RiderColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (items.length > 1) ...[
                    const SizedBox(height: RiderSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < items.length; i++)
                          GestureDetector(
                            onTap: () => setState(() => _page = i),
                            child: Container(
                              width: i == _page ? 16 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: RiderRadius.pillAll,
                                color: i == _page
                                    ? RiderColors.primary
                                    : RiderColors.primary
                                        .withValues(alpha: 0.25),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

