import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:idhar_udhar/shared/business/business.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';
import 'package:idhar_udhar/shared/format/inr_format.dart';
import 'package:intl/intl.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/location/rider_location_publisher.dart';
import '../../data/dummy/rider_finance.dart';
import '../../data/local/rider_permissions.dart';
import '../../data/models/recent_activity.dart';
import '../../data/models/rider_announcement.dart';
import '../../data/models/rider_earnings.dart';
import '../../data/models/rider_order.dart';
import '../../features/orders/rider_order_board_providers.dart';
import '../../features/wallet/wallet_topup_checkout.dart';
import '../../push/rider_accept_flow.dart';
import '../../push/rider_offer_rules.dart';
import '../../routing/rider_routes.dart';
import '../../screens/earnings/rider_income_screen.dart';
import '../../screens/orders/rider_history_screen.dart';
import '../../screens/orders/rider_ledger_screen.dart';
import '../../screens/profile/rider_profile_screen.dart';
import '../../screens/wallet/rider_wallet_screen.dart';
import '../../state/rider_onboarding.dart';
import '../../state/rider_session.dart';
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
import 'rider_active_delivery_section.dart';

/// Dashboard-only: ~1pt smaller than shared Rider text styles.
TextStyle _d(TextStyle style) {
  final size = style.fontSize;
  if (size == null) return style;
  return style.copyWith(fontSize: size - 1);
}

const EdgeInsets _dashCardPad = EdgeInsets.all(RiderSpacing.xl - 1);
const double _dashElevation = 10;

/// Main rider shell: Home / Orders / Ledger / Earnings / Profile.
class RiderDashboardScreen extends ConsumerStatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  ConsumerState<RiderDashboardScreen> createState() =>
      _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends ConsumerState<RiderDashboardScreen>
    with WidgetsBindingObserver {
  int _tab = 0;
  final Set<int> _visitedTabs = <int>{0};
  Timer? _offerPoll;
  RiderLocationPublisher? _locationPublisher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshRiderRunningDeliveries(ref);
      unawaited(() async {
        await ref.read(riderSessionProvider.notifier).refreshProfile();
        if (!mounted) return;
        final session = ref.read(riderSessionProvider);
        final blocked = riderHomeBlockRoute(
          profileReady: session.profileReady,
          profileComplete: session.profileComplete,
          missingFields: session.missingFields,
        );
        if (blocked != null) {
          await riderEnterAfterAuth(context, ref);
        }
      }());
      unawaited(ref.read(riderSessionProvider.notifier).refreshWallet());
      unawaited(ref.read(riderSessionProvider.notifier).refreshOffers());
      unawaited(ref.read(riderSessionProvider.notifier).refreshNotices());
      // Secondary path when FCM is delayed; keep under the 30s offer window.
      _offerPoll = Timer.periodic(const Duration(seconds: 4), (_) {
        final session = ref.read(riderSessionProvider);
        if (!session.isAuthenticated || !session.isApproved) {
          return;
        }
        _syncLocationPublishing();
        if (session.onlineStatus != 'ONLINE') {
          return;
        }
        unawaited(ref.read(riderSessionProvider.notifier).refreshOffers());
      });
      _syncLocationPublishing();
    });
  }

  /// Nearest-rider dispatch reads the location store. GPS is published while
  /// the rider is online, not only during an active delivery.
  void _syncLocationPublishing() {
    final bool online =
        ref.read(riderSessionProvider).onlineStatus == 'ONLINE';
    if (!online) {
      _locationPublisher?.stop();
      _locationPublisher = null;
      return;
    }
    _locationPublisher ??= RiderLocationPublisher(
      location: ref.read(deviceLocationServiceProvider),
      api: ref.read(riderApiProvider),
      tokens: ref.read(tokenStoreProvider),
    );
    unawaited(_locationPublisher!.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offerPoll?.cancel();
    _locationPublisher?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshRiderRunningDeliveries(ref);
    }
  }

  Widget _shellTab(int index, Widget child) {
    if (!_visitedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RiderSessionState>(riderSessionProvider, (previous, next) {
      if (previous?.onlineStatus != next.onlineStatus) {
        _syncLocationPublishing();
      }
    });
    return Scaffold(
      backgroundColor: RiderColors.background,
      drawer: const RiderDrawer(),
      body: RiderBackground(
        child: SafeArea(
          child: IndexedStack(
            index: _tab,
            children: [
              _shellTab(0, const _HomeTab()),
              _shellTab(1, const RiderHistoryScreen(showAppBar: false)),
              _shellTab(2, const RiderLedgerScreen(showAppBar: false)),
              _shellTab(3, const RiderIncomeScreen(showAppBar: false)),
              _shellTab(4, const RiderProfileScreen(showAppBar: false)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (int i) {
          setState(() {
            _tab = i;
            _visitedTabs.add(i);
          });
          if (i == 0) {
            refreshRiderRunningDeliveries(ref);
          }
        },
        backgroundColor: RiderColors.surfaceGlass,
        indicatorColor: RiderColors.primary.withValues(alpha: 0.15),
        labelBehavior: MediaQuery.sizeOf(context).width < 400
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
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon:
                Icon(Icons.menu_book_rounded, color: RiderColors.primary),
            label: 'Ledger',
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
    final profile = ref.watch(riderProfileStateProvider);
    final bool approved = ref.watch(riderSessionProvider).isApproved;
    final String approval =
        ref.watch(riderSessionProvider).approvalStatus ?? 'PENDING';
    final String greetingName =
        profile.name.trim().isEmpty ? 'Rider' : profile.firstName;
    final earnings =
        ref.watch(riderApiEarningsProvider).value ?? RiderEarnings.empty;
    final activity = ref.watch(riderDeliveryHistoryProvider);
    final List<RiderOffer> offers = ref.watch(riderSessionProvider).offers;
    RiderOffer? pendingOffer;
    for (final RiderOffer offer in offers) {
      if (offer.status == 'PENDING') {
        pendingOffer = offer;
        break;
      }
    }
    final RiderOrder? order = pendingOffer == null
        ? null
        : OrderMapper.toRiderOrder(offer: pendingOffer);
    final notices = ref.watch(riderSessionProvider).notices;
    final announcements = <RiderAnnouncement>[
      for (final notice in notices)
        RiderAnnouncement(
          kind: RiderAnnouncementKind.update,
          title: notice.title,
          body: notice.body,
          dateLabel:
              DateFormat('d MMM, h:mm a').format(notice.createdAt.toLocal()),
        ),
    ];
    final online = ref.watch(riderOnlineProvider);
    final wallet = ref.watch(riderWalletBalanceProvider);
    final codDue = ref.watch(riderCodDueProvider);
    final String moneyStatus = ref.watch(riderOperationalStatusProvider);
    final double rechargeToResume = ref.watch(riderRechargeToResumeProvider);
    final double walletFloor = ref.watch(riderWalletSuspendFloorProvider);
    final lastSettlement = ref.watch(riderLastSettlementProvider);
    final bool walletHold = moneyStatus == 'SUSPENDED_FOR_WALLET';
    final bool suspended = walletHold ||
        moneyStatus == 'SUSPENDED_FOR_COD' ||
        CodEngine.isSuspended(codDue);
    final currency = inrFormat;
    final walletCurrency = inrFormat;

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
                greeting: '${_greeting()}, $greetingName 👋',
                online: online,
                photoUrl: profile.photoUrl,
                onNotifications: () {
                  final unread =
                      notices.where((n) => n.readAt == null).length;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: RiderColors.secondary,
                      content: Text(
                        unread == 0
                            ? 'No unread notifications'
                            : '$unread unread notification${unread == 1 ? '' : 's'}',
                        style: _d(RiderTextStyles.bodyMedium).copyWith(
                          color: RiderColors.textOnPrimary,
                        ),
                      ),
                    ),
                  );
                  context.push(RiderRoutes.notifications);
                },
              ),
              const SizedBox(height: RiderSpacing.lg),
              if (!approved) ...[
                RiderGlassCard(
                  elevation: _dashElevation,
                  padding: _dashCardPad,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verification $approval',
                        style: _d(RiderTextStyles.title),
                      ),
                      const SizedBox(height: RiderSpacing.sm),
                      Text(
                        'Go Online and accepting deliveries stay locked until approval.',
                        style: _d(RiderTextStyles.caption),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.push(RiderRoutes.verificationStatus),
                        child: Text(
                          'View verification status',
                          style: _d(RiderTextStyles.bodyMedium).copyWith(
                            color: RiderColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: RiderSpacing.lg),
              ],
              _DutyStatusCard(
                online: approved && online,
                enabled: approved,
                onToggle: () async {
                  if (!approved) return;
                  final bool next = !online;
                  try {
                    await ref
                        .read(riderSessionProvider.notifier)
                        .setOnline(next);
                  } on ApiException catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error.message)),
                    );
                  }
                },
              ),
              const RiderActiveDeliverySection(),
              if (approved && online && !suspended && order != null) ...[
                const SizedBox(height: RiderSpacing.md),
                _IncomingOrderCard(
                  order: order,
                  currency: currency,
                  onReject: () {
                    unawaited(() async {
                      final String? offerId = order.offerId;
                      if (offerId == null || offerId.isEmpty) {
                        return;
                      }
                      try {
                        await ref.read(riderApiProvider).rejectOffer(offerId);
                        await ref
                            .read(riderSessionProvider.notifier)
                            .refreshOffers();
                      } on ApiException catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.message)),
                        );
                      }
                    }());
                  },
                  onAccept: () async {
                      if (!ref.read(riderSessionProvider).isApproved) {
                        if (!context.mounted) return;
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
                        if (!context.mounted) return;
                        final String hold = ref.read(riderOperationalStatusProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              hold == 'SUSPENDED_FOR_WALLET'
                                  ? 'Wallet is ${formatInr(ref.read(riderWalletBalanceProvider))}. Add at least ${formatInr(ref.read(riderRechargeToResumeProvider))} to resume.'
                                  : 'Account suspended until COD Due is cleared.',
                            ),
                          ),
                        );
                        return;
                      }
                      if (!ref.read(riderOnlineProvider)) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Go online to accept delivery requests.',
                            ),
                          ),
                        );
                        return;
                      }
                      final String? offerId = order.offerId;
                      if (offerId == null || offerId.isEmpty) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Open the full order request to accept.',
                            ),
                          ),
                        );
                        return;
                      }
                      try {
                        final RiderOrder accepted = await loadOrderAfterAccept(
                          api: ref.read(riderApiProvider),
                          offer: pendingOffer!,
                        );
                        if (!context.mounted) return;
                        final String route = await publishAcceptedOrder(
                          ref: ref,
                          order: accepted,
                        );
                        if (!context.mounted) return;
                        context.go(route);
                      } on ApiException catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.message)),
                        );
                        unawaited(
                          ref.read(riderSessionProvider.notifier).refreshOffers(),
                        );
                      }
                  },
                ),
              ],
              if (suspended) ...[
                const SizedBox(height: RiderSpacing.md),
                RiderGlassCard(
                  elevation: _dashElevation,
                  padding: _dashCardPad,
                  child: Text(
                    walletHold
                        ? 'Service is paused. Wallet balance is ${formatInr(wallet)} (limit ${formatInr(walletFloor)}). Add at least ${formatInr(rechargeToResume)} with Add Money to resume.'
                        : 'Account suspended. COD Due is ${formatInr(codDue)} (limit ${formatInr(100)}). Add money to clear COD Due before accepting rides.',
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
                  onConfirm: (amount) async {
                    try {
                      final walletApi = ref.read(walletApiProvider);
                      final session = await walletApi.beginTopUp(amount);
                      final RiderWalletTopUpFeedback feedback =
                          await finishRiderWalletTopUpCheckout(
                        walletApi: walletApi,
                        session: session,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(feedback.message)),
                        );
                      }
                      if (feedback.refreshImmediately) {
                        ref.invalidate(riderWalletLedgerProvider);
                        await ref
                            .read(riderSessionProvider.notifier)
                            .refreshWallet();
                      }
                      final int later = feedback.delayedRefreshes;
                      if (later > 0) {
                        unawaited(refreshWalletAfterTopUp(
                          times: later,
                          refresh: () => ref
                              .read(riderSessionProvider.notifier)
                              .refreshWallet(),
                        ));
                      }
                    } on ApiException catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.message)),
                        );
                      }
                    }
                  },
                ),
                onWithdraw: () {
                  final bank = ref.read(riderBankProvider);
                  unawaited(showRiderWalletAmountSheet(
                  context: context,
                  ref: ref,
                  title: 'Withdraw Money',
                  confirmLabel: 'Withdraw',
                  maxAmount: wallet,
                  upiSaved: bank.upiOnServer,
                  bankSaved: bank.bankOnServer,
                  onWithdraw: (amount, payoutMethod) async {
                    await ref.read(walletApiProvider).withdraw(
                          amount: amount,
                          payoutMethod: payoutMethod,
                        );
                    await ref
                        .read(riderSessionProvider.notifier)
                        .refreshWallet();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Withdrawal requested. Funds are held until processed.',
                          ),
                        ),
                      );
                    }
                  },
                  ),
                );
                },
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
                    if (activity.isEmpty)
                      Text(
                        'No recent activity yet',
                        style: _d(RiderTextStyles.caption),
                      )
                    else
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
    required this.photoUrl,
    required this.onNotifications,
  });

  final String greeting;
  final bool online;
  final String? photoUrl;
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
        _HeaderAvatar(photoUrl: photoUrl),
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

/// Signed profile photo from GET /v1/rider/profile/picture (`download_url`).
/// A missing, local, or failed URL keeps the original header avatar.
class _HeaderAvatar extends ConsumerStatefulWidget {
  const _HeaderAvatar({this.photoUrl});

  final String? photoUrl;

  @override
  ConsumerState<_HeaderAvatar> createState() => _HeaderAvatarState();
}

class _HeaderAvatarState extends ConsumerState<_HeaderAvatar> {
  String? _url;
  bool _refreshing = false;

  Widget get _fallback => CircleAvatar(
        radius: 23,
        backgroundColor: RiderColors.primary.withValues(alpha: 0.15),
        child: const Icon(Icons.person_rounded, color: RiderColors.primary),
      );

  @override
  void initState() {
    super.initState();
    _url = _httpUrl(widget.photoUrl);
  }

  @override
  void didUpdateWidget(covariant _HeaderAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _refreshing = false;
      _url = _httpUrl(widget.photoUrl);
    }
  }

  static String? _httpUrl(String? raw) {
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

  Future<void> _refreshOnce() async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    try {
      final picture = await ref.read(profilesApiProvider).riderProfilePicture();
      final String? next = _httpUrl(picture?.downloadUrl);
      if (!mounted) {
        return;
      }
      setState(() => _url = next != null && next != _url ? next : null);
    } catch (_) {
      if (mounted) {
        setState(() => _url = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? url = _url;
    if (url == null) {
      return _fallback;
    }
    return ClipOval(
      child: Image.network(
        url,
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return _fallback;
        },
        errorBuilder: (_, __, ___) {
          if (!_refreshing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(_refreshOnce());
            });
          }
          return _fallback;
        },
      ),
    );
  }
}

class _DutyStatusCard extends StatelessWidget {
  const _DutyStatusCard({
    required this.online,
    required this.onToggle,
    required this.enabled,
  });

  final bool online;
  final VoidCallback onToggle;
  final bool enabled;

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
                      !enabled
                          ? 'Locked until verification is approved.'
                          : online
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
                    value: enabled && online,
                    activeTrackColor: RiderColors.success,
                    onChanged: enabled ? (_) => onToggle() : null,
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

class _IncomingOrderCard extends StatefulWidget {
  const _IncomingOrderCard({
    required this.order,
    required this.currency,
    required this.onReject,
    required this.onAccept,
  });

  final RiderOrder order;
  final NumberFormat currency;
  final VoidCallback onReject;
  final Future<void> Function() onAccept;

  @override
  State<_IncomingOrderCard> createState() => _IncomingOrderCardState();
}

class _IncomingOrderCardState extends State<_IncomingOrderCard> {
  Timer? _timer;
  int? _secondsLeft;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _bind(widget.order.expiresAt);
  }

  @override
  void didUpdateWidget(covariant _IncomingOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.offerId != widget.order.offerId ||
        oldWidget.order.expiresAt != widget.order.expiresAt) {
      _bind(widget.order.expiresAt);
    }
  }

  void _bind(DateTime? expiresAt) {
    _timer?.cancel();
    _secondsLeft = offerSecondsRemaining(expiresAt, DateTime.now());
    if (expiresAt == null || _secondsLeft == 0) {
      return;
    }
    final DateTime deadline = expiresAt;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final int? left = offerSecondsRemaining(deadline, DateTime.now());
      if (!mounted) {
        return;
      }
      setState(() => _secondsLeft = left);
      if (left == null || left <= 0) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String? get _countdownLabel {
    final int? left = _secondsLeft;
    if (left == null) {
      return null;
    }
    final String minutes = (left ~/ 60).toString().padLeft(2, '0');
    final String seconds = (left % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _accept() async {
    if (_accepting) {
      return;
    }
    setState(() => _accepting = true);
    try {
      await widget.onAccept();
    } finally {
      if (mounted) {
        setState(() => _accepting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final RiderOrder order = widget.order;
    final NumberFormat currency = widget.currency;
    final VoidCallback onReject = widget.onReject;
    final bool expired = _secondsLeft == 0;
    final String? countdown = _countdownLabel;
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
                  if (countdown != null)
                    Padding(
                      padding: const EdgeInsets.only(right: RiderSpacing.sm),
                      child: Text(
                        countdown,
                        style: _d(RiderTextStyles.title).copyWith(
                          fontSize: 15,
                          color: expired ? RiderColors.error : RiderColors.primary,
                        ),
                      ),
                    ),
                  const RiderStatusChip(
                    label: 'NEW',
                    tone: RiderChipTone.warning,
                  ),
                ],
              ),
              const SizedBox(height: RiderSpacing.md),
              if ((order.crn ?? '').trim().isNotEmpty) ...[
                _miniRow('CRN', order.crn!.trim(), Icons.tag_rounded),
                const SizedBox(height: RiderSpacing.sm),
              ],
              _miniRow('Pickup', order.pickup, Icons.store_mall_directory_rounded),
              const SizedBox(height: RiderSpacing.sm),
              _miniRow('Drop', order.drop, Icons.location_on_rounded),
              if (order.receiverName.trim().isNotEmpty) ...[
                const SizedBox(height: RiderSpacing.sm),
                _miniRow(
                  'Receiver',
                  order.receiverName.trim(),
                  Icons.person_outline_rounded,
                ),
              ],
              const SizedBox(height: RiderSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.distanceLabel,
                      style: _d(RiderTextStyles.caption),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      currency.format(order.tripAmount),
                      style: _d(RiderTextStyles.bodyMedium).copyWith(
                        color: RiderColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      order.etaLabel,
                      style: _d(RiderTextStyles.caption),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RiderSpacing.xs),
              Text(
                'Trip Fare ${currency.format(order.tripAmount)} · Your Earnings ${currency.format(order.estimatedEarnings)}',
                style: _d(RiderTextStyles.caption),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: RiderSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: RiderSecondaryButton(
                      label: 'Reject',
                      destructive: true,
                      onPressed: expired ? null : onReject,
                    ),
                  ),
                  const SizedBox(width: RiderSpacing.md),
                  Expanded(
                    flex: 2,
                    child: RiderPrimaryButton(
                      label: expired ? 'Expired' : 'Accept',
                      enabled: !expired && !_accepting,
                      onPressed: expired || _accepting
                          ? null
                          : () => unawaited(_accept()),
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
                tone: item.status.startsWith('Pending')
                    ? RiderChipTone.warning
                    : RiderChipTone.success,
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

