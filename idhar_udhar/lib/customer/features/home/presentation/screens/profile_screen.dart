import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/custom_dialog.dart';
import '../../../../shared/widgets/glass_container.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await CustomDialog.show(
      context: context,
      title: 'Log out?',
      message: 'You will need to verify your mobile number again to sign in.',
      confirmLabel: 'Log out',
      cancelLabel: 'Cancel',
    );
    if (confirmed == true && context.mounted) {
      await ref.read(sessionProvider.notifier).logout();
      if (context.mounted) {
        context.go(AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    final String? email =
        user?.hasEmail == true ? user!.email.trim() : null;

    return CinematicBackground(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Responsive.horizontalPadding(context),
          AppSpacing.md,
          Responsive.horizontalPadding(context),
          AppSpacing.giant,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TopLogo(height: 40),
            const SizedBox(height: AppSpacing.xl),
            GlassCard(
              hero: true,
              showAmbientGlow: true,
              ambientColor: AppColors.orange,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.softPeach,
                    child: Text(
                      (user?.name.isNotEmpty == true ? user!.name[0] : 'U')
                          .toUpperCase(),
                      style: AppTextStyles.headingM.copyWith(
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name.isNotEmpty == true
                              ? user!.name
                              : 'Customer',
                          style: AppTextStyles.headingS,
                        ),
                        Text(
                          user?.phone ?? '—',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (email != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push(AppRoutes.profileEdit),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _tile(
              icon: Icons.email_outlined,
              title: email == null ? 'Add email for invoicing' : 'Email for invoicing',
              subtitle: email,
              onTap: () => context.push(AppRoutes.profileEdit),
            ),
            _tile(
              icon: Icons.bookmark_border_rounded,
              title: 'Saved locations',
              onTap: () => context.push(AppRoutes.savedAddresses),
            ),
            _tile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              onTap: () => context.push(AppRoutes.notifications),
            ),
            _tile(
              icon: Icons.help_outline_rounded,
              title: 'Help & Support',
              onTap: () => context.push(AppRoutes.help),
            ),
            _tile(
              icon: Icons.description_outlined,
              title: 'Terms & Privacy',
              onTap: () {},
            ),
            const SizedBox(height: AppSpacing.xxl),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => _confirmLogout(context, ref),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
                child: Text(
                  'Log out',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: onTap,
          child: GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.lg),
            borderRadius: AppRadius.lgAll,
            child: Row(
              children: [
                Icon(icon, color: AppColors.orange),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.bodyMedium),
                      if (subtitle != null && subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
