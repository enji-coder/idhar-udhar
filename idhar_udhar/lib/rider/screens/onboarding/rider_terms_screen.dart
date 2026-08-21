import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/local/rider_prefs.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';

/// First-launch Terms & Conditions. Dummy/UI content — not legally reviewed.
class RiderTermsScreen extends StatefulWidget {
  const RiderTermsScreen({super.key});

  @override
  State<RiderTermsScreen> createState() => _RiderTermsScreenState();
}

class _RiderTermsScreenState extends State<RiderTermsScreen> {
  final ScrollController _scroll = ScrollController();
  bool _reachedEnd = false;
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkIfFits());
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_reachedEnd || !_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0 || _scroll.offset >= max - 24) {
      setState(() => _reachedEnd = true);
    }
  }

  void _checkIfFits() {
    if (!mounted || !_scroll.hasClients) return;
    if (_scroll.position.maxScrollExtent <= 0) {
      setState(() => _reachedEnd = true);
    }
  }

  Future<void> _continue() async {
    if (!_agreed || !_reachedEnd) return;
    await RiderPrefs.setTermsAccepted();
    await RiderPrefs.setInitialSetupComplete();
    if (!mounted) return;
    context.go(RiderRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        automaticallyImplyLeading: false,
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Opacity(
            opacity: _reachedEnd ? 1 : 0.45,
            child: CheckboxListTile(
              value: _agreed,
              onChanged: _reachedEnd
                  ? (v) => setState(() => _agreed = v ?? false)
                  : null,
              activeColor: RiderColors.primary,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'I have read and agree to the Terms & Conditions',
                style: RiderTextStyles.bodyMedium,
              ),
            ),
          ),
          if (!_reachedEnd)
            Padding(
              padding: const EdgeInsets.only(bottom: RiderSpacing.sm),
              child: Text(
                'Scroll to the end to enable acceptance.',
                style: RiderTextStyles.caption.copyWith(
                  color: RiderColors.warning,
                ),
              ),
            ),
          RiderPrimaryButton(
            label: 'Continue',
            enabled: _reachedEnd && _agreed,
            onPressed: _continue,
          ),
        ],
      ),
      body: RiderGlassCard(
        padding: const EdgeInsets.all(RiderSpacing.lg),
        child: Scrollbar(
          controller: _scroll,
          child: ListView(
            controller: _scroll,
            children: [
              Text(
                'IDHAR UDHAR Rider Partner Terms',
                style: RiderTextStyles.title,
              ),
              const SizedBox(height: RiderSpacing.sm),
              Text(
                'This is sample onboarding content for product demonstration. '
                'It is not legally reviewed company terms.',
                style: RiderTextStyles.caption.copyWith(
                  color: RiderColors.warning,
                ),
              ),
              const SizedBox(height: RiderSpacing.lg),
              for (final section in _kTermsSections) ...[
                Text(section.title, style: RiderTextStyles.bodyMedium),
                const SizedBox(height: RiderSpacing.sm),
                Text(section.body, style: RiderTextStyles.caption),
                const SizedBox(height: RiderSpacing.lg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsSection {
  const _TermsSection(this.title, this.body);
  final String title;
  final String body;
}

const List<_TermsSection> _kTermsSections = <_TermsSection>[
  _TermsSection(
    '1. Delivery rider responsibilities',
    'You agree to accept, pick up, and deliver assigned orders professionally, '
        'on time, and in accordance with in-app instructions. You must keep the '
        'app available while online and update order status accurately.',
  ),
  _TermsSection(
    '2. Account usage',
    'Your rider account is personal. Do not share login details, allow another '
        'person to deliver under your account, or create multiple accounts. You '
        'are responsible for activity on your account.',
  ),
  _TermsSection(
    '3. Document authenticity',
    'All identity, vehicle, licence, and bank documents you submit must be '
        'genuine, current, and belong to you (or be lawfully authorised). '
        'Forged, expired, or misleading documents may lead to rejection or '
        'suspension.',
  ),
  _TermsSection(
    '4. Vehicle responsibility',
    'You must hold a valid licence, registration, and insurance for the '
        'vehicle used for deliveries. You are responsible for roadworthiness, '
        'traffic rules, parking, and any fines or incidents while delivering.',
  ),
  _TermsSection(
    '5. Customer interaction',
    'Treat customers with courtesy. Do not harass, discriminate, or request '
        'personal favours. Follow delivery instructions and protect customer '
        'privacy, including addresses and contact details shown in the app.',
  ),
  _TermsSection(
    '6. Delivery responsibilities',
    'Handle parcels with care. Do not open, use, or tamper with shipments. '
        'Report damaged, missing, or refused deliveries promptly through the app. '
        'Cash-on-delivery amounts must be settled as instructed.',
  ),
  _TermsSection(
    '7. Earnings and incentives',
    'Displayed earnings, incentives, and bonuses are estimates until completed '
        'and verified. Incentive rules may change. Taxes, if applicable, are '
        'your responsibility. This demo does not process real payouts.',
  ),
  _TermsSection(
    '8. App usage',
    'Use the Rider app only for authorised delivery work. Do not misuse maps, '
        'order alerts, or overlay features. Keep the app updated and do not '
        'interfere with its security or location accuracy.',
  ),
  _TermsSection(
    '9. Privacy',
    'We collect account, location, device, document, and delivery activity '
        'data needed to operate rider services. Location is used for navigation '
        'and assignment while you are on duty. Do not copy or share customer data.',
  ),
  _TermsSection(
    '10. Account suspension',
    'Accounts may be paused or closed for policy breaches, poor reliability, '
        'safety issues, fake documents, or inactivity. You may lose access to '
        'orders during a review. Dummy accounts in this demo are not live.',
  ),
  _TermsSection(
    '11. Fraud and misuse',
    'Fake GPS, fake deliveries, collusion, document fraud, incentive abuse, '
        'or charge manipulation is prohibited and may result in permanent '
        'removal and reporting where required by law.',
  ),
  _TermsSection(
    '12. Safety',
    'Ride safely, wear appropriate protection, and do not use the phone while '
        'driving. Decline work that feels unsafe. Emergency situations should '
        'be handled with local authorities first.',
  ),
  _TermsSection(
    '13. Acceptance of terms',
    'By checking the box and continuing, you confirm that you have read these '
        'sample terms and agree to follow them while using the IDHAR UDHAR '
        'Rider demo application. Scroll complete.',
  ),
];
