import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/vehicle_info.dart';
import '../screens/dashboard/rider_dashboard_screen.dart';
import '../screens/earnings/rider_income_screen.dart';
import '../screens/onboarding/rider_terms_screen.dart';
import '../screens/orders/active_delivery_screen.dart';
import '../screens/orders/incoming_order_screen.dart';
import '../screens/orders/order_details_screen.dart';
import '../screens/orders/rider_history_screen.dart';
import '../screens/profile/rider_profile_screen.dart';
import '../screens/profile/rider_upi_details_screen.dart';
import '../screens/registration/documents_screen.dart';
import '../screens/registration/mobile_verification_screen.dart';
import '../screens/registration/otp_verification_screen.dart';
import '../screens/registration/permission_setup_screen.dart';
import '../screens/registration/registration_complete_screen.dart';
import '../screens/registration/registration_welcome_screen.dart';
import '../screens/registration/rider_bank_upi_screen.dart';
import '../screens/registration/rider_driver_details_screen.dart';
import '../screens/registration/rider_profile_setup_screen.dart';
import '../screens/registration/vehicle_details_screen.dart';
import '../screens/registration/vehicle_type_screen.dart';
import '../screens/registration/verification_status_screen.dart';
import '../screens/rider_login_screen.dart';
import '../screens/rider_splash_screen.dart';
import '../screens/settings/rider_settings_screen.dart';
import '../screens/wallet/rider_wallet_screen.dart';
import 'rider_otp_args.dart';
import 'rider_routes.dart';

CustomTransitionPage<void> _fadePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// Rider-only router. Splash + Login unchanged visually; onboarding + order flow added.
abstract final class RiderRouter {
  static final GoRouter config = GoRouter(
    initialLocation: RiderRoutes.splash,
    routes: <RouteBase>[
      GoRoute(
        path: RiderRoutes.splash,
        name: 'riderSplash',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RiderSplashScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.login,
        name: 'riderLogin',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RiderLoginScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.terms,
        name: 'riderTerms',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RiderTermsScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.registrationWelcome,
        name: 'riderRegistrationWelcome',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RegistrationWelcomeScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.mobileVerification,
        name: 'riderMobileVerification',
        pageBuilder: (context, state) {
          final mobile = state.extra as String?;
          return _fadePage(
            state: state,
            child: MobileVerificationScreen(initialMobile: mobile),
          );
        },
      ),
      GoRoute(
        path: RiderRoutes.otpVerification,
        name: 'riderOtpVerification',
        pageBuilder: (context, state) {
          final extra = state.extra;
          String? mobile;
          RiderAuthFlow flow = RiderAuthFlow.registration;
          if (extra is RiderOtpArgs) {
            mobile = extra.mobile;
            flow = extra.flow;
          } else if (extra is String) {
            mobile = extra;
          }
          return _fadePage(
            state: state,
            child: OtpVerificationScreen(mobile: mobile, flow: flow),
          );
        },
      ),
      GoRoute(
        path: RiderRoutes.profileSetup,
        name: 'riderProfileSetup',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RiderProfileSetupScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.vehicleType,
        name: 'riderVehicleType',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const VehicleTypeScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.vehicleDetails,
        name: 'riderVehicleDetails',
        pageBuilder: (context, state) {
          final extra = state.extra;
          final categoryName = extra is String
              ? extra
              : extra is RiderVehicleType
                  ? extra.label
                  : null;
          return _fadePage(
            state: state,
            child: VehicleDetailsScreen(
              vehicleType: extra is RiderVehicleType ? extra : RiderVehicleTypeX.fromLabel(categoryName),
              categoryName: categoryName,
            ),
          );
        },
      ),
      GoRoute(
        path: RiderRoutes.driverDetails,
        name: 'riderDriverDetails',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RiderDriverDetailsScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.documents,
        name: 'riderDocuments',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const DocumentsScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.bankUpi,
        name: 'riderBankUpi',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RiderBankUpiScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.verificationStatus,
        name: 'riderVerificationStatus',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const VerificationStatusScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.permissionSetup,
        name: 'riderPermissionSetup',
        pageBuilder: (context, state) {
          final continueToDashboard = state.extra != 'complete';
          return _fadePage(
            state: state,
            child: PermissionSetupScreen(
              continueToDashboard: continueToDashboard,
            ),
          );
        },
      ),
      GoRoute(
        path: RiderRoutes.registrationComplete,
        name: 'riderRegistrationComplete',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RegistrationCompleteScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.dashboard,
        name: 'riderDashboard',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RiderDashboardScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.incomingOrder,
        name: 'riderIncomingOrder',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const IncomingOrderScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.acceptConfirmation,
        name: 'riderAcceptConfirmation',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const AcceptConfirmationScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.orderDetails,
        name: 'riderOrderDetails',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const OrderDetailsScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.activeDelivery,
        name: 'riderActiveDelivery',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const ActiveDeliveryScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.profile,
        name: 'riderProfile',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RiderProfileScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.vehicleEdit,
        name: 'riderVehicleEdit',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const VehicleDetailsScreen(editMode: true),
        ),
      ),
      GoRoute(
        path: RiderRoutes.bankEdit,
        name: 'riderBankEdit',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RiderBankUpiScreen(editMode: true),
        ),
      ),
      GoRoute(
        path: RiderRoutes.upiDetails,
        name: 'riderUpiDetails',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RiderUpiDetailsScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.documentsReview,
        name: 'riderDocumentsReview',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const DocumentsScreen(reviewMode: true),
        ),
      ),
      GoRoute(
        path: RiderRoutes.wallet,
        name: 'riderWallet',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RiderWalletScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.income,
        name: 'riderIncome',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RiderIncomeScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.history,
        name: 'riderHistory',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RiderHistoryScreen(),
        ),
      ),
      GoRoute(
        path: RiderRoutes.settings,
        name: 'riderSettings',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RiderSettingsScreen(),
        ),
      ),
    ],
  );
}
