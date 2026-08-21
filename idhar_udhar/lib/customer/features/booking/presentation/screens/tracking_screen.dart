import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';
import '../cancel_trip_flow.dart';

class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key});

  static const List<OrderStatus> _timeline = <OrderStatus>[
    OrderStatus.accepted,
    OrderStatus.arriving,
    OrderStatus.pickup,
    OrderStatus.inTransit,
    OrderStatus.nearDestination,
    OrderStatus.delivered,
  ];

  static String _labelFor(OrderStatus status) {
    switch (status) {
      case OrderStatus.searching:
        return 'Searching for rider';
      case OrderStatus.assigned:
        return 'Rider assigned';
      case OrderStatus.accepted:
        return 'Rider accepted';
      case OrderStatus.arriving:
        return 'Rider arriving';
      case OrderStatus.pickup:
        return 'Parcel picked up';
      case OrderStatus.inTransit:
        return 'In transit';
      case OrderStatus.nearDestination:
        return 'Near destination';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.failed:
        return 'Receiver unavailable';
      case OrderStatus.atCompanyOffice:
        return 'Parcel at company office';
      case OrderStatus.resendRequested:
        return 'Resend requested';
    }
  }

  void _sync(WidgetRef ref, MockOrder order) {
    ref.read(sessionProvider.notifier).updateOrder(order);
  }

  MockOrder? _viewedOrder(BuildContext context, WidgetRef ref) {
    final String? id = GoRouterState.of(context).uri.queryParameters['id'];
    if (id != null && id.isNotEmpty) {
      final MockOrder? fromSession =
          ref.read(sessionProvider.notifier).orderById(id);
      if (fromSession != null) {
        return fromSession;
      }
    }
    return ref.read(bookingDraftProvider).activeOrder;
  }

  void _advance(BuildContext context, WidgetRef ref) {
    final MockOrder? order = _viewedOrder(context, ref);
    if (order == null) {
      return;
    }

    if (order.status != OrderStatus.nearDestination) {
      final MockOrder? updated = ref
          .read(bookingDraftProvider.notifier)
          .advanceDemoStatus(order: order);
      if (updated != null) {
        _sync(ref, updated);
        return;
      }
    }

    final email = ref.read(sessionProvider).user?.email ?? '';
    final MockOrder? delivered =
        ref.read(bookingDraftProvider.notifier).markDelivered(
              invoiceEmail: email,
              order: order,
            );
    if (delivered != null) {
      _sync(ref, delivered);
    }
    context.go(AppRoutes.bookCompleted);
  }

  String _demoLabel(OrderStatus? status) {
    if (status == OrderStatus.nearDestination) {
      return 'Mark Delivered (Demo)';
    }
    return 'Next status (Demo)';
  }

  int _timelineIndex(OrderStatus? status) {
    if (status == null) {
      return -1;
    }
    if (status == OrderStatus.assigned || status == OrderStatus.searching) {
      return 0;
    }
    return _timeline.indexOf(status);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = GoRouterState.of(context).uri.queryParameters['id'];
    MockOrder? order = ref.watch(bookingDraftProvider).activeOrder;
    if (id != null) {
      for (final MockOrder item in ref.watch(sessionProvider).orders) {
        if (item.id == id) {
          order = item;
          break;
        }
      }
    }
    final canCancel = order != null &&
        order.status != OrderStatus.delivered &&
        order.status != OrderStatus.cancelled;

    return GlassPageScaffold(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedPrimaryButton(
            label: _demoLabel(order?.status),
            onPressed: () => _advance(context, ref),
          ),
          if (canCancel) ...[
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Cancel Booking',
              onPressed: () async {
                final MockOrder? current = _viewedOrder(context, ref);
                if (current == null) return;
                final bool ok = await confirmCustomerCancellation(
                  context: context,
                  order: current,
                );
                if (!ok) return;
                final cancelled = ref
                    .read(bookingDraftProvider.notifier)
                    .cancelBooking(order: current);
                if (cancelled != null) {
                  ref.read(sessionProvider.notifier).updateOrder(cancelled);
                }
                if (context.mounted) context.go(AppRoutes.home);
              },
            ),
          ],
        ],
      ),
      child: ListView(
        children: [
          Row(
            children: [
              IuBackButton(onPressed: () => context.go(AppRoutes.home)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Live Tracking',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassContainer(
            hero: true,
            showAmbientGlow: true,
            ambientColor: AppColors.orange,
            child: Column(
              children: [
                AmbientGlow(
                  diameter: 220,
                  opacity: 0.3,
                  child: const SafeAssetImage(
                    path: AssetPaths.deliveryProgress,
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  order?.statusLabel ?? 'In transit',
                  style: AppTextStyles.headingS.copyWith(
                    color: AppColors.orange,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'ETA ${order?.etaMinutes ?? 18} min',
                  style: AppTextStyles.body,
                ),
                if (order?.id != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(order!.id, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status', style: AppTextStyles.headingS),
                const SizedBox(height: AppSpacing.md),
                ...List.generate(_timeline.length, (i) {
                  final step = _timeline[i];
                  final currentIndex = _timelineIndex(order?.status);
                  final reached = currentIndex >= i;
                  final active = order?.status == step ||
                      (i == 0 &&
                          (order?.status == OrderStatus.accepted ||
                              order?.status == OrderStatus.assigned));
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(
                          active
                              ? Icons.radio_button_checked
                              : (reached
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked),
                          size: 18,
                          color: active || reached
                              ? AppColors.orange
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _labelFor(step),
                            style: AppTextStyles.caption.copyWith(
                              color: active
                                  ? AppColors.orange
                                  : AppColors.textSecondary,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _point(
                  color: AppColors.orange,
                  title: 'Pickup',
                  subtitle: order?.pickup.address ?? '—',
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: Container(
                    width: 2,
                    height: 28,
                    color: AppColors.orange.withOpacity(0.35),
                  ),
                ),
                _point(
                  color: AppColors.navy,
                  title: 'Drop',
                  subtitle: order?.drop.address ?? '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassContainer(
            child: Row(
              children: [
                const SafeAssetImage(
                  path: AssetPaths.rider,
                  height: 56,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order?.rider?.name ?? 'Rider',
                        style: AppTextStyles.bodyMedium,
                      ),
                      Text(
                        order?.rider?.vehicleLabel ?? '',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.call_rounded, color: AppColors.orange),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _point({
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(subtitle, style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
