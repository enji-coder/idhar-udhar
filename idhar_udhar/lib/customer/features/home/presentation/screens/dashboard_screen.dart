import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animations/animations.dart';
import '../../../../core/constants/asset_paths.dart';
import '../../../../core/data/mock/mock_data.dart';
import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/custom_dialog.dart';
import '../../../../shared/widgets/glass_container.dart';

/// Customer dashboard — aligned to attached sunset glass reference.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning,';
    }
    if (hour < 17) {
      return 'Good Afternoon,';
    }
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final String name = session.user?.name.trim().isNotEmpty == true
        ? session.user!.name.trim().split(' ').first
        : 'there';
    final Size size = MediaQuery.sizeOf(context);
    final bool compact = size.height < 720;
    final double hPad = Responsive.horizontalPadding(context);

    return CinematicBackground(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          hPad,
          AppSpacing.md,
          hPad,
          AppSpacing.giant + AppSpacing.xxl,
        ),
        child: Responsive.constrain(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeAnimation(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            name,
                            style: AppTextStyles.headingL.copyWith(
                              color: AppColors.navy,
                              fontSize: compact ? 26 : 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  MockData.locations[3].label,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.navy.withValues(alpha: 0.55),
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () {
                            final List<CustomerNotice> notices =
                                session.notices;
                            final String body = notices.isEmpty
                                ? 'No new notifications.'
                                : notices.first.body;
                            CustomDialog.show(
                              context: context,
                              title: notices.isEmpty
                                  ? 'Notifications'
                                  : notices.first.title,
                              message: body,
                              confirmLabel: 'OK',
                              cancelLabel: null,
                            );
                          },
                          child: GlassContainer(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            borderRadius: AppRadius.mdAll,
                            depth: GlassDepthLevel.subtle,
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.orange,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${session.notices.where((n) => !n.read).length.clamp(0, 9)}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),

              // Hero book card — reference layout
              SlideAnimation(
                child: GlassContainer(
                  hero: true,
                  showAmbientGlow: true,
                  ambientColor: AppColors.orange,
                  borderRadius: BorderRadius.circular(28),
                  padding: EdgeInsets.all(
                    compact ? AppSpacing.lg : AppSpacing.xl,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const TopLogo(height: 36),
                            const SizedBox(height: AppSpacing.md),
                            Text.rich(
                              TextSpan(
                                style: AppTextStyles.headingM.copyWith(
                                  color: AppColors.navy,
                                  fontSize: compact ? 20 : 22,
                                  height: 1.2,
                                ),
                                children: const [
                                  TextSpan(text: 'Need to send '),
                                  TextSpan(
                                    text: 'anything?',
                                    style: TextStyle(color: AppColors.orange),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'From documents to furniture, IDHAR UDHAR delivers it safely.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AnimatedPrimaryButton(
                              label: 'Book a Delivery',
                              height: compact ? 48 : 52,
                              onPressed: () {
                                ref
                                    .read(bookingDraftProvider.notifier)
                                    .beginNewBooking();
                                ref
                                    .read(bookingDraftProvider.notifier)
                                    .clearServiceFamily();
                                context.push(AppRoutes.bookPickup);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        width: (size.width * 0.28).clamp(96.0, 130.0),
                        child: FloatingAnimation(
                          child: SafeAssetImage(
                            path: AssetPaths.truck,
                            fit: BoxFit.contain,
                            height: compact ? 110 : 130,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
              Text(
                'Services',
                style: AppTextStyles.headingS.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _PrimaryService(
                      title: 'Two\nWheeler',
                      imagePath: AssetPaths.bike,
                      onTap: () {
                        ref.read(bookingDraftProvider.notifier).beginNewBooking();
                        ref
                            .read(bookingDraftProvider.notifier)
                            .setServiceFamily(ServiceFamily.twoWheeler);
                        context.push(AppRoutes.bookPickup);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _PrimaryService(
                      title: 'Three\nWheeler',
                      imagePath: AssetPaths.auto,
                      onTap: () {
                        ref.read(bookingDraftProvider.notifier).beginNewBooking();
                        ref
                            .read(bookingDraftProvider.notifier)
                            .setServiceFamily(ServiceFamily.threeWheeler);
                        context.push(AppRoutes.bookPickup);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _PrimaryService(
                      title: 'Truck',
                      imagePath: AssetPaths.truck,
                      onTap: () {
                        ref.read(bookingDraftProvider.notifier).beginNewBooking();
                        ref
                            .read(bookingDraftProvider.notifier)
                            .setServiceFamily(ServiceFamily.truck);
                        context.push(AppRoutes.bookPickup);
                      },
                    ),
                  ),
                ],
              ),

              SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
              if (session.orders.where((o) => o.isActive).isNotEmpty) ...[
                Text(
                  'Active Orders',
                  style: AppTextStyles.headingS.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                GlassContainer(
                  hero: true,
                  borderRadius: BorderRadius.circular(24),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      for (final MockOrder order
                          in session.orders.where((o) => o.isActive)) ...[
                        _RecentDeliveryRow(
                          order: order,
                          onTrack: () {
                            ref
                                .read(bookingDraftProvider.notifier)
                                .attachActive(order);
                            context.push(
                              '${AppRoutes.bookTracking}?id=${Uri.encodeComponent(order.id)}',
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
              ],
              Text(
                'Recent Deliveries',
                style: AppTextStyles.headingS.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GlassContainer(
                hero: true,
                borderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    for (int i = 0; i < session.orders.take(2).length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      _RecentDeliveryRow(
                        order: session.orders[i],
                        onTrack: () {
                          ref
                              .read(bookingDraftProvider.notifier)
                              .attachActive(session.orders[i]);
                          context.push(
                            '${AppRoutes.bookTracking}?id=${Uri.encodeComponent(session.orders[i].id)}',
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
              GlassContainer(
                hero: true,
                showAmbientGlow: true,
                ambientColor: AppColors.orange,
                borderRadius: BorderRadius.circular(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.navy,
                                height: 1.35,
                              ),
                              children: const [
                                TextSpan(text: 'Invite Friends & get up to '),
                                TextSpan(
                                  text: '₹200',
                                  style: TextStyle(
                                    color: AppColors.orange,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                  text: ' in wallet on their first delivery.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedPrimaryButton(
                              label: 'Invite Now',
                              width: 150,
                              height: 44,
                              showArrow: true,
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SafeAssetImage(
                      path: AssetPaths.invite,
                      width: 88,
                      height: 88,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryService extends StatelessWidget {
  const _PrimaryService({
    required this.title,
    required this.imagePath,
    required this.onTap,
  });

  final String title;
  final String imagePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: GlassContainer(
          depth: GlassDepthLevel.normal,
          borderRadius: AppRadius.lgAll,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              SizedBox(
                height: 72,
                child: SafeAssetImage(
                  path: imagePath,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentDeliveryRow extends StatelessWidget {
  const _RecentDeliveryRow({
    required this.order,
    required this.onTrack,
  });

  final MockOrder order;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final bool delivered = order.status == OrderStatus.delivered;

    return Row(
      children: [
        SafeAssetImage(
          path: order.vehicle.imagePath,
          width: 48,
          height: 48,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.routeLabel,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${order.id} · ₹${order.fare.toStringAsFixed(0)}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    delivered
                        ? Icons.check_circle_rounded
                        : Icons.local_shipping_rounded,
                    size: 14,
                    color: delivered ? AppColors.success : AppColors.info,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    order.statusLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: delivered ? AppColors.success : AppColors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onTrack,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.orange,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(
            'Track →',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.orange,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
