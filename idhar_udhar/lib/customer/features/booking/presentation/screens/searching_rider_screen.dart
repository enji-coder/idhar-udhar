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
import '../../../../core/state/booking_api.dart';
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
  String? _pollError;
  bool _noRiderHint = false;

  @override
  void initState() {
    super.initState();
    final order = ref.read(bookingDraftProvider).activeOrder;
    if (order?.backendOrderId != null) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        unawaited(_poll());
      });
      unawaited(_poll());
      // After ~2 minutes of searching with no assignment, show a soft hint.
      Future<void>.delayed(const Duration(seconds: 120), () {
        if (mounted && !_cancelled) {
          setState(() => _noRiderHint = true);
        }
      });
    }
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
      setState(() => _pollError = null);
      if (mapped.status == OrderStatus.cancelled) {
        _timer?.cancel();
        return;
      }
      if (mapped.status == OrderStatus.assigned ||
          mapped.status == OrderStatus.accepted ||
          mapped.status == OrderStatus.arriving) {
        _timer?.cancel();
        context.go(AppRoutes.bookRiderAssigned);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _pollError = error.message);
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
    ref.read(backendQuoteHoldProvider.notifier).state = null;
    context.go(AppRoutes.home);
  }

  void _goHome() {
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(bookingDraftProvider).activeOrder;
    final canCancel = order?.canCancel ?? true;
    final bool cancelled = order?.status == OrderStatus.cancelled;

    return GlassPageScaffold(
      bottom: canCancel && !cancelled
          ? SecondaryButton(
              label: 'Cancel request',
              onPressed: _cancel,
            )
          : cancelled
              ? AnimatedPrimaryButton(
                  label: 'Back to home',
                  onPressed: _goHome,
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
              Text(
                cancelled ? 'Request cancelled' : 'Finding your rider',
                style: AppTextStyles.headingM,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                cancelled
                    ? 'This booking was cancelled.'
                    : 'We\'re finding an available driver near you.',
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
                  cancelled
                      ? 'Cancelled'
                      : (order == null
                          ? 'Preparing your request'
                          : 'Looking for a driver'),
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
                if (!cancelled) ...[
                  const SizedBox(height: AppSpacing.md),
                  _SearchStep(
                    label: 'Searching',
                    active: true,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _SearchStep(
                    label: 'Matching',
                    active: order != null,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const _SearchStep(
                    label: 'Confirming',
                    active: false,
                  ),
                ],
                if (_pollError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _pollError!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_noRiderHint && !cancelled) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Still looking for an available driver. You can keep waiting or cancel and try again.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          );

          final Widget column = Column(
            children: [
              header,
              if (compact) ...[
                illustration,
                const SizedBox(height: AppSpacing.lg),
                if (!cancelled) const LoadingIndicator(width: 180),
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
                        if (!cancelled) const LoadingIndicator(width: 180),
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

class _SearchStep extends StatelessWidget {
  const _SearchStep({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          active ? Icons.radio_button_checked : Icons.radio_button_off,
          size: 16,
          color: active ? AppColors.orange : AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: active ? AppColors.orange : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
