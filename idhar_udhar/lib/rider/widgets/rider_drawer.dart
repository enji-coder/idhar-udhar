import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/dummy/dummy_rider_repository.dart';
import '../data/local/rider_prefs.dart';
import '../routing/rider_routes.dart';
import '../screens/profile/rider_profile_screen.dart';
import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';
import 'rider_logo_widget.dart';

class RiderDrawer extends ConsumerWidget {
  const RiderDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(riderProfileStateProvider);

    return Drawer(
      backgroundColor: RiderColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                RiderSpacing.lg,
                RiderSpacing.md,
                RiderSpacing.lg,
                RiderSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RiderLogoWidget(height: 40),
                  const SizedBox(height: RiderSpacing.md),
                  RiderProfileAvatar(photoUrl: profile.photoUrl, radius: 28),
                  const SizedBox(height: RiderSpacing.md),
                  Text(profile.name, style: RiderTextStyles.title),
                  Text(profile.mobile, style: RiderTextStyles.caption),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: RiderSpacing.sm),
                children: [
                  _item(
                    context,
                    Icons.person_outline_rounded,
                    'Profile',
                    RiderRoutes.profile,
                  ),
                  _item(
                    context,
                    Icons.two_wheeler_outlined,
                    'Vehicle Details',
                    RiderRoutes.vehicleEdit,
                  ),
                  _item(
                    context,
                    Icons.account_balance_outlined,
                    'Bank Details',
                    RiderRoutes.bankEdit,
                  ),
                  _item(
                    context,
                    Icons.currency_rupee_rounded,
                    'UPI Details',
                    RiderRoutes.upiDetails,
                  ),
                  _item(
                    context,
                    Icons.folder_outlined,
                    'Documents',
                    RiderRoutes.documentsReview,
                  ),
                  _item(
                    context,
                    Icons.bar_chart_rounded,
                    'Earnings',
                    RiderRoutes.income,
                  ),
                  _item(
                    context,
                    Icons.history_rounded,
                    'History',
                    RiderRoutes.history,
                  ),
                  _item(
                    context,
                    Icons.account_balance_wallet_outlined,
                    'Wallet',
                    RiderRoutes.wallet,
                  ),
                  _item(
                    context,
                    Icons.settings_outlined,
                    'Settings',
                    RiderRoutes.settings,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: RiderColors.error),
              title: Text(
                'Logout',
                style: RiderTextStyles.bodyMedium.copyWith(
                  color: RiderColors.error,
                ),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                await RiderPrefs.clearLoggedIn();
                if (context.mounted) context.go(RiderRoutes.login);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    return ListTile(
      leading: Icon(icon, color: RiderColors.primary),
      title: Text(label, style: RiderTextStyles.bodyMedium),
      onTap: () {
        Navigator.of(context).pop();
        context.push(route);
      },
    );
  }
}
