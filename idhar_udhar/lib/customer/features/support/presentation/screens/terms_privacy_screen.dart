import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

class TermsPrivacyScreen extends StatefulWidget {
  const TermsPrivacyScreen({super.key});

  @override
  State<TermsPrivacyScreen> createState() => _TermsPrivacyScreenState();
}

class _LegalSection {
  const _LegalSection({required this.title, required this.body});

  final String title;
  final String body;
}

class _TermsPrivacyScreenState extends State<TermsPrivacyScreen> {
  static const String _contact =
      'C-12 Floor 1206\n'
      'RAJYASH RISE, B/S VISHALA, NR APMC MARKET\n'
      'NARAYAN NAGAR\n'
      'Ahmedabad\n'
      '380007\n'
      'Email: info@idharudhar.co.in';

  static const List<_LegalSection> _sections = <_LegalSection>[
    _LegalSection(
      title: 'Terms & Conditions',
      body:
          'These terms apply when you use the IDHAR UDHAR customer app to request a delivery.\n\n'
          'You are responsible for the pickup and drop details you enter, including the address and contact information. You are also responsible for describing the parcel accurately, including what it contains and any size or weight details the app asks for.\n\n'
          'Do not send items that are illegal, unsafe, or otherwise not allowed to be carried. IDHAR UDHAR may refuse a delivery that cannot be carried safely or lawfully.\n\n'
          'Delivery is available where the service is offered and a rider can be assigned. A request does not guarantee that a rider will be available.\n\n'
          'The fare shown for your trip is the amount payable for that delivery. You agree to pay the fare according to the payment option you choose in the app.\n\n'
          'Cancellation depends on the delivery status. When cancellation is available, use the cancel option on the order screen. The app shows the cancellation rule that applies at that stage.\n\n'
          'After you confirm a booking, IDHAR UDHAR assigns an available delivery partner to collect the parcel from the pickup location and deliver it to the drop location.\n\n'
          'IDHAR UDHAR is not liable for loss or delay caused by incorrect address or parcel details that you provide, or by events outside the delivery shown in the app. Nothing in these terms limits liability that cannot legally be limited.\n\n'
          'You are responsible for the account you use, including keeping access to your mobile number. Do not misuse the service or interfere with another customer’s booking.\n\n'
          'IDHAR UDHAR may change the service or these terms. The terms shown in the app are the terms that apply when you use the service.\n\n'
          'Contact\n'
          '$_contact',
    ),
    _LegalSection(
      title: 'Privacy Policy',
      body:
          'This policy describes how the IDHAR UDHAR customer app uses information to provide deliveries.\n\n'
          'We collect the account and contact details you provide, such as your name and mobile number, and an email address if you add one.\n\n'
          'We collect the pickup and drop details you enter for a delivery, including addresses and location pins you choose, and the parcel details you submit for that booking.\n\n'
          'If you allow location access, the app uses your device location to help you choose a pickup or drop. The app also uses the information needed to run on your device, such as keeping you signed in.\n\n'
          'We use this information to create and manage your booking, show the fare, assign a delivery partner, and support the delivery.\n\n'
          'Pickup, drop, and parcel details needed to complete the delivery are shared with the assigned delivery partner. Information is also shared with service providers only where that is needed to operate the booking, such as storing your account and processing a payment you choose in the app.\n\n'
          'Payment details you submit for a fare are used to collect that payment. Do not send payment information in a support message.\n\n'
          'We take reasonable care to protect account and delivery information against unauthorized access. No method of storage or transmission can be guaranteed to be completely secure.\n\n'
          'We keep delivery and account information for as long as it is needed to provide the service, handle a support request, and keep the records the booking requires.\n\n'
          'You may contact us to ask about the information held for your account or to ask for a correction.\n\n'
          'Contact\n'
          '$_contact',
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
                  'Terms & Privacy',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          for (int index = 0; index < _sections.length; index++)
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
                            Expanded(
                              child: Text(
                                _sections[index].title,
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
                            _sections[index].body,
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
