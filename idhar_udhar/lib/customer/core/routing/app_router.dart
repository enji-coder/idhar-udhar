import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/otp_verification_screen.dart';
import '../../features/authentication/presentation/screens/profile_setup_screen.dart';
import '../../features/booking/presentation/screens/booking_summary_screen.dart';
import '../../features/booking/presentation/screens/delivery_completed_screen.dart';
import '../../features/booking/presentation/screens/drop_location_screen.dart';
import '../../features/booking/presentation/screens/order_details_screen.dart';
import '../../features/booking/presentation/screens/package_details_screen.dart';
import '../../features/booking/presentation/screens/pickup_location_screen.dart';
import '../../features/booking/presentation/screens/rider_assigned_screen.dart';
import '../../features/booking/presentation/screens/searching_rider_screen.dart';
import '../../features/booking/presentation/screens/tracking_screen.dart';
import '../../features/booking/presentation/screens/vehicle_selection_screen.dart';
import '../../features/home/presentation/screens/dashboard_screen.dart';
import '../../features/home/presentation/screens/home_shell_screen.dart';
import '../../features/home/presentation/screens/orders_screen.dart';
import '../../features/home/presentation/screens/profile_screen.dart';
import '../../features/home/presentation/screens/wallet_screen.dart';
import '../../features/location_permission/presentation/screens/location_permission_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/saved_addresses_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/support/presentation/screens/help_screen.dart';
import 'app_routes.dart';
import 'route_transitions.dart';

/// Application router — full customer UI demo flow.
abstract final class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final GoRouter config = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: AppRoutes.splash,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        pageBuilder: (context, state) {
          return RouteTransitions.fadeThrough(
            key: state.pageKey,
            child: const SplashScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) {
          return RouteTransitions.fadeThrough(
            key: state.pageKey,
            child: const LoginScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.otp,
        name: 'otp',
        pageBuilder: (context, state) {
          final String phone = state.uri.queryParameters['phone'] ?? '';
          return RouteTransitions.sharedAxisHorizontal(
            key: state.pageKey,
            child: OtpVerificationScreen(phoneNumber: phone),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        name: 'profileSetup',
        pageBuilder: (context, state) {
          return RouteTransitions.sharedAxisHorizontal(
            key: state.pageKey,
            child: const ProfileSetupScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.locationPermission,
        name: 'locationPermission',
        pageBuilder: (context, state) {
          return RouteTransitions.fadeThrough(
            key: state.pageKey,
            child: const LocationPermissionScreen(),
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                name: 'dashboard',
                pageBuilder: (context, state) {
                  return RouteTransitions.fadeThrough(
                    key: state.pageKey,
                    child: const DashboardScreen(),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.orders,
                name: 'orders',
                pageBuilder: (context, state) {
                  return RouteTransitions.fadeThrough(
                    key: state.pageKey,
                    child: const OrdersScreen(),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.wallet,
                name: 'wallet',
                pageBuilder: (context, state) {
                  return RouteTransitions.fadeThrough(
                    key: state.pageKey,
                    child: const WalletScreen(),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                name: 'profile',
                pageBuilder: (context, state) {
                  return RouteTransitions.fadeThrough(
                    key: state.pageKey,
                    child: const ProfileScreen(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.home,
        redirect: (context, state) => AppRoutes.dashboard,
      ),
      GoRoute(
        path: AppRoutes.bookPickup,
        name: 'bookPickup',
        pageBuilder: (context, state) => RouteTransitions.fadeThrough(
          key: state.pageKey,
          child: const PickupLocationScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.bookDrop,
        name: 'bookDrop',
        pageBuilder: (context, state) => RouteTransitions.fadeThrough(
          key: state.pageKey,
          child: const DropLocationScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.bookVehicle,
        name: 'bookVehicle',
        pageBuilder: (context, state) => RouteTransitions.fadeThrough(
          key: state.pageKey,
          child: const VehicleSelectionScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.bookPackage,
        name: 'bookPackage',
        pageBuilder: (context, state) => RouteTransitions.fadeThrough(
          key: state.pageKey,
          child: const PackageDetailsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.bookSummary,
        name: 'bookSummary',
        pageBuilder: (context, state) => RouteTransitions.fadeThrough(
          key: state.pageKey,
          child: const BookingSummaryScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.bookSearching,
        name: 'bookSearching',
        pageBuilder: (context, state) => RouteTransitions.fadeThrough(
          key: state.pageKey,
          child: const SearchingRiderScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.bookRiderAssigned,
        name: 'bookRiderAssigned',
        pageBuilder: (context, state) => RouteTransitions.fadeThrough(
          key: state.pageKey,
          child: const RiderAssignedScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.bookTracking,
        name: 'bookTracking',
        pageBuilder: (context, state) => RouteTransitions.fadeThrough(
          key: state.pageKey,
          child: const TrackingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.bookCompleted,
        name: 'bookCompleted',
        pageBuilder: (context, state) => RouteTransitions.fadeThrough(
          key: state.pageKey,
          child: const DeliveryCompletedScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.orderDetails,
        name: 'orderDetails',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return RouteTransitions.fadeThrough(
            key: state.pageKey,
            child: OrderDetailsScreen(orderId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        name: 'profileEdit',
        pageBuilder: (context, state) => RouteTransitions.fadeThrough(
          key: state.pageKey,
          child: const EditProfileScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.savedAddresses,
        name: 'savedAddresses',
        pageBuilder: (context, state) => RouteTransitions.fadeThrough(
          key: state.pageKey,
          child: const SavedAddressesScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.help,
        name: 'help',
        pageBuilder: (context, state) => RouteTransitions.fadeThrough(
          key: state.pageKey,
          child: const HelpScreen(),
        ),
      ),
    ],
  );
}
