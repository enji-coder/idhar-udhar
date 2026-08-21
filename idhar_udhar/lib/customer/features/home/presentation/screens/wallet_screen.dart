import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_copy.dart';
import '../../../../core/data/mock/mock_data.dart';
import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/custom_snack_bar.dart';
import '../../../../shared/widgets/glass_container.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  String? _selectedPaymentId;
  bool _showMethods = false;

  IconData _iconFor(WalletPaymentMethodKind kind) {
    switch (kind) {
      case WalletPaymentMethodKind.googlePay:
      case WalletPaymentMethodKind.phonePe:
      case WalletPaymentMethodKind.paytm:
        return Icons.account_balance_wallet_outlined;
      case WalletPaymentMethodKind.netBanking:
        return Icons.account_balance_outlined;
      case WalletPaymentMethodKind.creditCard:
      case WalletPaymentMethodKind.debitCard:
        return Icons.credit_card_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(sessionProvider).walletBalance;
    final Map<String, List<WalletPaymentOption>> grouped = {};
    for (final option in MockData.walletPaymentOptions) {
      grouped.putIfAbsent(option.group, () => <WalletPaymentOption>[]).add(option);
    }

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
            Text(
              'Wallet',
              style: AppTextStyles.headingM.copyWith(color: AppColors.white),
            ),
            const SizedBox(height: AppSpacing.xl),
            GlassCard(
              hero: true,
              showAmbientGlow: true,
              ambientColor: AppColors.orange,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available balance',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '₹${balance.toStringAsFixed(0)}',
                    style: AppTextStyles.headingXL.copyWith(
                      color: AppColors.orange,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedPrimaryButton(
                    label: _showMethods ? 'Close payment options' : 'Add Money',
                    onPressed: () {
                      setState(() => _showMethods = !_showMethods);
                    },
                  ),
                ],
              ),
            ),
            if (_showMethods) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Top-up method', style: AppTextStyles.headingS),
              const SizedBox(height: AppSpacing.md),
              ...grouped.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          entry.key,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...entry.value.map((option) {
                          final bool selected =
                              _selectedPaymentId == option.id;
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: AppRadius.mdAll,
                                onTap: () {
                                  setState(
                                    () => _selectedPaymentId = option.id,
                                  );
                                  CustomSnackBar.show(
                                    context,
                                    message:
                                        '${option.label} selected (demo — no payment processed)',
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.sm,
                                    horizontal: AppSpacing.sm,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _iconFor(option.kind),
                                        color: AppColors.orange,
                                        size: 20,
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Text(
                                          option.label,
                                          style: AppTextStyles.bodyMedium,
                                        ),
                                      ),
                                      Icon(
                                        selected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        color: selected
                                            ? AppColors.orange
                                            : AppColors.navyMuted,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }),
              GlassContainer(
                depth: GlassDepthLevel.subtle,
                child: Text(
                  AppCopy.walletDemoPaymentNote,
                  style: AppTextStyles.caption,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text('Transactions', style: AppTextStyles.headingS),
            const SizedBox(height: AppSpacing.md),
            ...MockData.walletTxns.map((txn) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: GlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: txn.isCredit
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.orange.withValues(alpha: 0.15),
                        child: Icon(
                          txn.isCredit
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          color: txn.isCredit
                              ? AppColors.success
                              : AppColors.orange,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(txn.title, style: AppTextStyles.bodyMedium),
                            Text(
                              '${txn.date.day}/${txn.date.month}/${txn.date.year}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${txn.isCredit ? '+' : '-'}₹${txn.amount.toStringAsFixed(0)}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: txn.isCredit
                              ? AppColors.success
                              : AppColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (!_showMethods)
              GlassContainer(
                depth: GlassDepthLevel.subtle,
                child: Text(
                  AppCopy.walletDemoPaymentNote,
                  style: AppTextStyles.caption,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
