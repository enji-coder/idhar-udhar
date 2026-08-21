import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/status_chip.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _filter = 'All';

  bool _matches(MockOrder order) {
    switch (_filter) {
      case 'Active':
        return order.isActive;
      case 'Completed':
        return order.status == OrderStatus.delivered;
      case 'Cancelled':
        return order.status == OrderStatus.cancelled;
      case 'Failed':
        return order.status == OrderStatus.failed ||
            order.status == OrderStatus.atCompanyOffice ||
            order.status == OrderStatus.resendRequested;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders =
        ref.watch(sessionProvider).orders.where(_matches).toList();

    return CinematicBackground(
      child: Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.horizontalPadding(context),
            AppSpacing.md,
            Responsive.horizontalPadding(context),
            AppSpacing.giant,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Orders',
                style: AppTextStyles.headingM.copyWith(color: AppColors.white),
              ),
              const SizedBox(height: AppSpacing.lg),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Active', 'Completed', 'Failed', 'Cancelled']
                      .map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: StatusChip(
                            label: f,
                            selected: _filter == f,
                            onTap: () => setState(() => _filter = f),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: orders.isEmpty
                    ? GlassContainer(
                        hero: true,
                        child: EmptyState(
                          title: 'No orders yet',
                          subtitle: 'Book a delivery to see it here.',
                          action: AnimatedPrimaryButton(
                            label: 'Book Now',
                            onPressed: () =>
                                context.push(AppRoutes.bookPickup),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: orders.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: AppRadius.xlAll,
                              onTap: () => context.push(
                                AppRoutes.orderDetailsPath(order.id),
                              ),
                              child: GlassContainer(
                                child: Row(
                                  children: [
                                    SafeAssetImage(
                                      path: order.vehicle.imagePath,
                                      height: 64,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(order.id,
                                              style: AppTextStyles.bodyMedium),
                                          Text(
                                            '${order.routeLabel}',
                                            style: AppTextStyles.caption,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            order.statusLabel,
                                            style: AppTextStyles.caption
                                                .copyWith(
                                              color: AppColors.orange,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (order.invoiceSent)
                                            Text(
                                              'Invoice available',
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₹${order.fare.toStringAsFixed(0)}',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
      ),
    );
  }
}
