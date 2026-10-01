import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpTopic {
  const _HelpTopic({
    required this.title,
    required this.icon,
    required this.answer,
  });

  final String title;
  final IconData icon;
  final String answer;
}

class _HelpScreenState extends State<HelpScreen> {
  static const List<_HelpTopic> _topics = <_HelpTopic>[
    _HelpTopic(
      title: 'How do I book a delivery?',
      icon: Icons.local_shipping_outlined,
      answer:
          'Select a pickup location, then select a drop location. '
          'Enter the delivery details the screen asks for, and select a vehicle. '
          'Review the fare and trip details, then confirm the booking.',
    ),
    _HelpTopic(
      title: 'How is fare calculated?',
      icon: Icons.payments_outlined,
      answer:
          'The fare is calculated for your trip from the pickup and drop locations, '
          'including the distance between them, the vehicle you select, and the '
          'pricing rules that apply to that trip. The fare shown before you confirm '
          'is the amount for that delivery.',
    ),
    _HelpTopic(
      title: 'Can I cancel an order?',
      icon: Icons.cancel_outlined,
      answer:
          'Cancellation depends on the delivery status. When cancellation is available, '
          'use the cancel option on the order screen. The app shows whether you can '
          'cancel at that stage and any cancellation rule that applies.',
    ),
    _HelpTopic(
      title: 'Contact support',
      icon: Icons.support_agent_rounded,
      answer:
          'Company address\n'
          'C-12 Floor 1206\n'
          'RAJYASH RISE, B/S VISHALA, NR APMC MARKET\n'
          'NARAYAN NAGAR\n'
          'Ahmedabad\n'
          '380007\n\n'
          'Official email\n'
          'info@idharudhar.co.in',
    ),
  ];

  int? _openIndex;

  @override
  Widget build(BuildContext context) {
    return GlassPageScaffold(
      child: ListView(
        children: [
          Row(
            children: [
              const IuBackButton(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Help & Support',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('We’re here for you', style: AppTextStyles.headingS),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (int index = 0; index < _topics.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: AppRadius.lgAll,
                  onTap: () => setState(() {
                    _openIndex = _openIndex == index ? null : index;
                  }),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    borderRadius: AppRadius.lgAll,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_topics[index].icon, color: AppColors.orange),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                _topics[index].title,
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                            Icon(
                              _openIndex == index
                                  ? Icons.expand_less_rounded
                                  : Icons.chevron_right_rounded,
                              color: AppColors.navy,
                            ),
                          ],
                        ),
                        if (_openIndex == index) ...[
                          const SizedBox(height: AppSpacing.md),
                          SelectableText(
                            _topics[index].answer,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
