import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';

import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/animations/animations.dart';
import '../../../../core/constants/asset_paths.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/state/session_provider.dart';
import '../cancel_trip_flow.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

class SearchingRiderScreen extends ConsumerStatefulWidget {
  const SearchingRiderScreen({super.key});

  @override
  ConsumerState<SearchingRiderScreen> createState() =>
      _SearchingRiderScreenState();
}

class _SearchingRiderScreenState extends ConsumerState<SearchingRiderScreen> {
  Timer? _timer;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    final order = ref.read(bookingDraftProvider).activeOrder;
    if (order?.backendOrderId != null) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        unawaited(_poll());
      });
      unawaited(_poll());
      return;
    }
    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _cancelled) {
        return;
      }
      ref.read(bookingDraftProvider.notifier).assignRider();
      final MockOrder? assigned = ref.read(bookingDraftProvider).activeOrder;
      if (assigned != null) {
        ref.read(sessionProvider.notifier).updateOrder(assigned);
      }
      context.go(AppRoutes.bookRiderAssigned);
    });
  }

  Future<void> _poll() async {
    if (!mounted || _cancelled) {
      return;
    }
    final order = ref.read(bookingDraftProvider).activeOrder;
    final String? id = order?.backendOrderId;
    if (id == null) {
      return;
    }
    try {
      final latest = await ref.read(ordersApiProvider).getById(id);
      if (!mounted || _cancelled) {
        return;
      }
      final mapped = OrderMapper.toMockOrder(
        latest,
        vehicle: order?.vehicle,
      );
      ref.read(bookingDraftProvider.notifier).attachActive(mapped);
      ref.read(sessionProvider.notifier).updateOrder(mapped);
      if (mapped.status == OrderStatus.assigned ||
          mapped.status == OrderStatus.accepted ||
          mapped.status == OrderStatus.arriving) {
        _timer?.cancel();
        context.go(AppRoutes.bookRiderAssigned);
      }
    } catch (_) {
      // Keep searching UI; next poll retries.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    final order = ref.read(bookingDraftProvider).activeOrder;
    if (order != null) {
      final bool ok = await confirmCustomerCancellation(
        context: context,
        order: order,
      );
      if (!ok || !mounted) return;
    }
    _cancelled = true;
    _timer?.cancel();
    final String? apiId = order?.backendOrderId ?? order?.id;
    if (order?.backendOrderId != null && apiId != null) {
      try {
        final latest = await ref.read(ordersApiProvider).cancel(apiId);
        if (mounted) {
          ref.read(sessionProvider.notifier).updateOrder(
                OrderMapper.toMockOrder(latest, vehicle: order?.vehicle),
              );
        }
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
        }
      }
    }
    final cancelled =
        ref.read(bookingDraftProvider.notifier).cancelBooking();
    if (cancelled != null) {
      ref.read(sessionProvider.notifier).updateOrder(cancelled);
    }
    ref.read(bookingDraftProvider.notifier).reset();
    context.go(AppRoutes.home);
  }

  void _goHome() {
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(bookingDraftProvider).activeOrder;
    final canCancel = order?.canCancel ?? true;

    return GlassPageScaffold(
      bottom: canCancel
          ? SecondaryButton(
              label: 'Cancel Booking',
              onPressed: _cancel,
            )
          : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double height = constraints.maxHeight;
          final bool compact = height < 720;
          final double imageHeight = compact ? 140.0 : 220.0;
          final double glowDiameter = compact ? 180.0 : 260.0;
          final double topGap = compact ? AppSpacing.md : AppSpacing.xxl;

          final Widget header = Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IuBackButton(onPressed: _goHome),
              ),
              SizedBox(height: topGap),
              Text('Finding your rider', style: AppTextStyles.headingM),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Matching a nearby IDHAR UDHAR partner…',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          );

          final Widget illustration = Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: FloatingAnimation(
              child: AmbientGlow(
                diameter: glowDiameter,
                opacity: 0.35,
                child: SafeAssetImage(
                  path: AssetPaths.searchingRider,
                  height: imageHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );

          final Widget statusCard = GlassContainer(
            hero: true,
            showAmbientGlow: true,
            ambientColor: AppColors.orange,
            child: Column(
              children: [
                Text(
                  order?.id ?? 'Preparing order',
                  style: AppTextStyles.headingS,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  order == null
                      ? 'Hang tight'
                      : '${order.pickup.label} → ${order.drop.label}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  order?.statusLabel ?? 'Searching for rider',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.orange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );

          final Widget column = Column(
            children: [
              header,
              if (compact) ...[
                illustration,
                const SizedBox(height: AppSpacing.lg),
                const LoadingIndicator(width: 180),
                const SizedBox(height: AppSpacing.lg),
                statusCard,
                SizedBox(height: topGap),
              ] else ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        illustration,
                        const SizedBox(height: AppSpacing.xxl),
                        const LoadingIndicator(width: 180),
                      ],
                    ),
                  ),
                ),
                statusCard,
                SizedBox(height: topGap),
              ],
            ],
          );

          if (compact) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: height),
                child: column,
              ),
            );
          }

          return ClipRect(child: column);
        },
      ),
    );
  }
}
