import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';
import '../../../../shared/widgets/rider_card.dart';
import '../cancel_trip_flow.dart';

class RiderAssignedScreen extends ConsumerWidget {
  const RiderAssignedScreen({super.key});

  static final RegExp _emailRegex = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );

  Future<void> _continueAfterRider(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final user = ref.read(sessionProvider).user;
    if (user == null || !user.hasEmail) {
      final String? email = await _promptEmail(context);
      if (email == null || email.isEmpty) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      ref.read(sessionProvider.notifier).setEmail(email);
    }

    ref.read(bookingDraftProvider.notifier).acceptRider();
    final order = ref.read(bookingDraftProvider).activeOrder;
    if (order != null) {
      ref.read(sessionProvider.notifier).updateOrder(order);
    }
    if (!context.mounted) {
      return;
    }
    context.go(AppRoutes.bookTracking);
  }

  Future<String?> _promptEmail(BuildContext context) {
    final controller = TextEditingController();
    String? error;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
                vertical: AppSpacing.xxxl,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.warmWhite,
                  borderRadius: AppRadius.xlAll,
                  border: Border.all(color: AppColors.borderGlassStrong),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Email required',
                        style: AppTextStyles.headingM,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Add your email to continue this booking and receive the invoice.',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      GlassTextField(
                        controller: controller,
                        label: 'Email',
                        hint: 'name@example.com',
                        leadingIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        errorText: error,
                        onChanged: (_) {
                          if (error != null) {
                            setLocal(() => error = null);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      AnimatedPrimaryButton(
                        label: 'Save & Continue',
                        onPressed: () {
                          final String value = controller.text.trim();
                          if (value.isEmpty) {
                            setLocal(() => error = 'Email is required');
                            return;
                          }
                          if (!_emailRegex.hasMatch(value)) {
                            setLocal(
                              () => error = 'Enter a valid email address',
                            );
                            return;
                          }
                          Navigator.of(dialogContext).pop(value);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SecondaryButton(
                        label: 'Cancel',
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(null),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _cancelBooking(BuildContext context, WidgetRef ref) async {
    final order = ref.read(bookingDraftProvider).activeOrder;
    if (order == null) return;
    final bool ok = await confirmCustomerCancellation(
      context: context,
      order: order,
    );
    if (!ok) return;
    final cancelled =
        ref.read(bookingDraftProvider.notifier).cancelBooking();
    if (cancelled != null) {
      ref.read(sessionProvider.notifier).updateOrder(cancelled);
    }
    ref.read(bookingDraftProvider.notifier).reset();
    if (context.mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(bookingDraftProvider).activeOrder;
    final rider = order?.rider;
    final canCancel = order?.canCancel ?? false;

    return GlassPageScaffold(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedPrimaryButton(
            label: 'Track Delivery',
            onPressed: () => _continueAfterRider(context, ref),
          ),
          if (canCancel) ...[
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Cancel Booking',
              onPressed: () => _cancelBooking(context, ref),
            ),
          ],
        ],
      ),
      child: ListView(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IuBackButton(onPressed: () => context.go(AppRoutes.home)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Rider assigned',
            style: AppTextStyles.headingM,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your partner is on the way to pickup',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: AmbientGlow(
              diameter: 240,
              opacity: 0.3,
              child: const SafeAssetImage(
                path: AssetPaths.rider,
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (rider != null)
            RiderCard(
              name: rider.name,
              vehicleLabel: rider.vehicleLabel,
              rating: rider.rating,
              subtitle:
                  '${rider.trips} trips · ETA ${order?.etaMinutes ?? 12} min',
              avatar: const SafeAssetImage(
                path: AssetPaths.rider,
                height: 48,
                fit: BoxFit.contain,
              ),
              onCall: () {},
              onMessage: () {},
            ),
          const SizedBox(height: AppSpacing.lg),
          GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order ${order?.id ?? ''}', style: AppTextStyles.headingS),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${order?.pickup.address ?? ''}\n→ ${order?.drop.address ?? ''}',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Fare ₹${order?.fare.toStringAsFixed(0) ?? '—'}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.orange,
                    fontWeight: FontWeight.w700,
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
