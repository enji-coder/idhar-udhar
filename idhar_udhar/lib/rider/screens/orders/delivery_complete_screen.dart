import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/local/rider_prefs.dart';
import '../../data/models/rider_order.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_text_styles.dart';

/// Shown only after the server has confirmed `DELIVERED`.
class DeliveryCompleteScreen extends ConsumerWidget {
  const DeliveryCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      const _ThankYouHero(),
                      const SizedBox(height: 22),
                      Text(
                        'Thank You!',
                        textAlign: TextAlign.center,
                        style: RiderTextStyles.heading.copyWith(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          color: RiderColors.secondary,
                          height: 1.05,
                        ),
                      ),
                      Container(
                        width: 92,
                        height: 4,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: RiderColors.warning,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'For Keeping Our\nCommunity Moving',
                        textAlign: TextAlign.center,
                        style: RiderTextStyles.title.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFF86EFAC),
                        size: 18,
                      ),
                      const SizedBox(height: 16),
                      const _QuoteCard(),
                      const SizedBox(height: 18),
                      const _BadgeRow(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _leave(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: RiderColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      textStyle: RiderTextStyles.button.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Go to Dashboard'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _leave(BuildContext context, WidgetRef ref) {
    ref.read(activeOrderProvider.notifier).state = null;
    ref.read(deliveryStatusProvider.notifier).state =
        DeliveryLifecycleStatus.accepted;
    rememberLiveOrderId(null);
    context.go(RiderRoutes.dashboard);
  }
}

class _ThankYouHero extends StatelessWidget {
  const _ThankYouHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 148,
            height: 148,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE7F6F1),
            ),
          ),
          const Icon(
            Icons.two_wheeler_rounded,
            size: 92,
            color: RiderColors.primary,
          ),
          Positioned(
            right: 78,
            top: 18,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF16A34A),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FBF7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '“Every delivery is not just a package, it\'s a smile, a need and a story.\n\n'
        'You make it happen!\nKeep going, you\'re doing great!”',
        textAlign: TextAlign.center,
        style: RiderTextStyles.body.copyWith(
          fontSize: 14,
          height: 1.4,
          color: RiderColors.textSecondary,
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth = constraints.maxWidth >= 520
            ? (constraints.maxWidth - 16) / 3
            : constraints.maxWidth;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 14,
          children: [
            SizedBox(
              width: itemWidth,
              child: const _Badge(
                icon: Icons.star_rounded,
                color: Color(0xFFF5B400),
                title: 'Great Ride!',
                body: 'This delivery is complete',
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: const _Badge(
                icon: Icons.person_rounded,
                color: RiderColors.primary,
                title: 'Keep Going',
                body: 'More deliveries, more rewards!',
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: const _Badge(
                icon: Icons.emoji_events_rounded,
                color: Color(0xFFE8A317),
                title: "You're Awesome",
                body: 'The community appreciates you!',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: RiderTextStyles.bodyMedium.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            textAlign: TextAlign.center,
            style: RiderTextStyles.caption.copyWith(fontSize: 11, height: 1.25),
          ),
        ],
      ),
    );
  }
}
