import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';

/// Floating glass bottom navigation shell.
class HomeShellScreen extends StatelessWidget {
  const HomeShellScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadius.xxlAll,
              boxShadow: AppShadows.navFloat,
            ),
            child: GlassEffect(
              intensity: GlassIntensity.heavy,
              depth: GlassDepthLevel.hero,
              borderRadius: AppRadius.xxlAll,
              showShadow: false,
              showAmbientGlow: true,
              ambientColor: AppColors.orange,
              showInnerHighlight: true,
              borderWidth: 1.25,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    selected: navigationShell.currentIndex == 0,
                    onTap: () => _onTap(0),
                  ),
                  _NavItem(
                    icon: Icons.receipt_long_rounded,
                    label: 'Orders',
                    selected: navigationShell.currentIndex == 1,
                    onTap: () => _onTap(1),
                  ),
                  _NavItem(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Wallet',
                    selected: navigationShell.currentIndex == 2,
                    onTap: () => _onTap(2),
                  ),
                  _NavItem(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    selected: navigationShell.currentIndex == 3,
                    onTap: () => _onTap(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            gradient: selected
                ? LinearGradient(
                    colors: [
                      AppColors.orange.withValues(alpha: 0.34),
                      AppColors.orange.withValues(alpha: 0.16),
                    ],
                  )
                : null,
            border: selected
                ? Border.all(color: AppColors.orange.withValues(alpha: 0.55))
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.orange.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? AppColors.orange : AppColors.navyMuted,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: selected ? AppColors.orange : AppColors.navyMuted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
