import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/customer/core/routing/app_routes.dart';
import 'package:idhar_udhar/customer/features/support/presentation/screens/help_screen.dart';
import 'package:idhar_udhar/customer/features/support/presentation/screens/terms_privacy_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> open(WidgetTester tester, Widget screen) async {
    final GoRouter router = GoRouter(
      initialLocation: '/start',
      routes: <RouteBase>[
        GoRoute(
          path: '/start',
          builder: (BuildContext context, GoRouterState state) {
            return Scaffold(
              body: TextButton(
                onPressed: () => context.push('/page'),
                child: const Text('Open'),
              ),
            );
          },
        ),
        GoRoute(
          path: '/page',
          builder: (BuildContext context, GoRouterState state) => screen,
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('help questions and contact support open', (tester) async {
    await open(tester, const HelpScreen());
    expect(find.text('Help & Support'), findsOneWidget);

    await tester.tap(find.text('How do I book a delivery?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Select a pickup location'), findsOneWidget);

    await tester.tap(find.text('How is fare calculated?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('pricing rules'), findsOneWidget);
    expect(find.textContaining('Select a pickup location'), findsNothing);

    await tester.tap(find.text('Can I cancel an order?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('cancel option on the order screen'), findsOneWidget);

    await tester.tap(find.text('Contact support'));
    await tester.pumpAndSettle();
    expect(find.textContaining('info@idharudhar.co.in'), findsOneWidget);
    expect(find.textContaining('C-12 Floor 1206'), findsOneWidget);
    expect(find.textContaining('RAJYASH RISE'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('terms and privacy open and back returns', (tester) async {
    await open(tester, const TermsPrivacyScreen());
    expect(find.text('Terms & Privacy'), findsOneWidget);

    await tester.tap(find.text('Terms & Conditions'));
    await tester.pumpAndSettle();
    expect(find.textContaining('describing the parcel accurately'), findsOneWidget);
    expect(find.textContaining('info@idharudhar.co.in'), findsWidgets);

    await tester.tap(find.text('Terms & Conditions'));
    await tester.pumpAndSettle();
    final Finder privacy = find.text('Privacy Policy');
    await tester.ensureVisible(privacy);
    await tester.tap(privacy);
    await tester.pumpAndSettle();
    expect(find.textContaining('We collect the pickup and drop details'), findsOneWidget);
    expect(find.textContaining('info@idharudhar.co.in'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('profile route constant points at terms', (tester) async {
    expect(AppRoutes.terms, '/terms');
  });
}
