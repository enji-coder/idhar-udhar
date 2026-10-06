import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';

import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_api.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/custom_snack_bar.dart';
import '../../../../shared/widgets/customer_order_ui.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(sessionProvider.notifier).refreshOrders());
    });
  }

  Future<void> _bookAgain(MockOrder order) async {
    final String id = order.apiId;
    try {
      final ApiOrder source = await ref.read(ordersApiProvider).getById(id);
      final notifier = ref.read(bookingDraftProvider.notifier);
      notifier.beginNewBooking();
      ref.read(backendQuoteHoldProvider.notifier).state = null;
      final List<ApiStop> pickups = source.stops
          .where((ApiStop stop) => stop.stopType == 'PICKUP')
          .toList(growable: false);
      final List<ApiStop> drops = source.stops
          .where((ApiStop stop) => stop.stopType == 'DROP')
          .toList(growable: false);
      if (pickups.isNotEmpty) {
        final ApiStop stop = pickups.first;
        notifier.setPickup(
          MockLocation(
            id: 'again_pickup',
            label: 'Pickup',
            address: stop.addressText,
            latitude: stop.latitude,
            longitude: stop.longitude,
          ),
        );
      }
      if (drops.isNotEmpty) {
        final ApiStop stop = drops.first;
        notifier.setDrop(
          MockLocation(
            id: 'again_drop',
            label: 'Drop',
            address: stop.addressText,
            latitude: stop.latitude,
            longitude: stop.longitude,
          ),
        );
        if ((stop.contactName ?? '').trim().isNotEmpty &&
            (stop.contactPhone ?? '').trim().isNotEmpty) {
          notifier.setReceiver(
            name: stop.contactName!.trim(),
            mobile: stop.contactPhone!.trim(),
          );
        }
      }
      if (source.vehicleCategoryId != null &&
          source.vehicleCategoryId!.isNotEmpty) {
        notifier.setCategory(source.vehicleCategoryId!);
      }
      if (source.packageWeightKg != null && source.packageWeightKg! > 0) {
        notifier.setWeight(source.packageWeightKg!);
      }
      if (!mounted) {
        return;
      }
      unawaited(context.push(AppRoutes.bookVehicle));
    } on ApiException catch (error) {
      if (mounted) {
        CustomSnackBar.error(context, error.message);
      }
    }
  }

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
                          // action: AnimatedPrimaryButton(
                          //   label: 'Book Now',
                          //   onPressed: () {
                          //     ref
                          //         .read(bookingDraftProvider.notifier)
                          //         .beginNewBooking();
                          //     ref
                          //         .read(backendQuoteHoldProvider.notifier)
                          //         .state = null;
                          //     context.push(AppRoutes.bookVehicle);
                          //   },
                          // ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: orders.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final MockOrder order = orders[index];
                          return OrderHistoryCard(
                            order: order,
                            onTap: () => context.push(
                              AppRoutes.orderDetailsPath(order.apiId),
                            ),
                            onBookAgain: () => unawaited(_bookAgain(order)),
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
