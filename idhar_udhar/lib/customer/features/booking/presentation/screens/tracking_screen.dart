import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';
import '../cancel_trip_flow.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  static const List<OrderStatus> _timeline = <OrderStatus>[
    OrderStatus.accepted,
    OrderStatus.arriving,
    OrderStatus.pickup,
    OrderStatus.inTransit,
    OrderStatus.nearDestination,
    OrderStatus.delivered,
  ];

  DisplayRoute? _route;
  String? _routeKey;
  Timer? _pollTimer;
  bool _refreshing = false;
  GeoPoint? _riderPoint;
  bool _riderStale = false;

  static String _labelFor(OrderStatus status) {
    switch (status) {
      case OrderStatus.searching:
        return 'Searching for rider';
      case OrderStatus.assigned:
        return 'Rider assigned';
      case OrderStatus.accepted:
        return 'Rider accepted';
      case OrderStatus.arriving:
        return 'Rider arriving';
      case OrderStatus.pickup:
        return 'Parcel picked up';
      case OrderStatus.inTransit:
        return 'In transit';
      case OrderStatus.nearDestination:
        return 'Near destination';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.failed:
        return 'Receiver unavailable';
      case OrderStatus.atCompanyOffice:
        return 'Parcel at company office';
      case OrderStatus.resendRequested:
        return 'Resend requested';
    }
  }

  void _sync(MockOrder order) {
    ref.read(sessionProvider.notifier).updateOrder(order);
    ref.read(bookingDraftProvider.notifier).attachActive(order);
  }

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_refreshFromServer());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshFromServer());
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  MockOrder? _viewedOrder() {
    final String? id = GoRouterState.of(context).uri.queryParameters['id'];
    if (id != null && id.isNotEmpty) {
      final MockOrder? fromSession =
          ref.read(sessionProvider.notifier).orderById(id);
      if (fromSession != null) {
        return fromSession;
      }
    }
    return ref.read(bookingDraftProvider).activeOrder;
  }

  Future<void> _refreshFromServer() async {
    if (_refreshing || !mounted) {
      return;
    }
    final MockOrder? order = _viewedOrder();
    final String? apiId = order?.backendOrderId;
    if (apiId == null || apiId.isEmpty) {
      return;
    }
    _refreshing = true;
    try {
      final latest = await ref.read(ordersApiProvider).getById(apiId);
      if (!mounted) {
        return;
      }
      final mapped = OrderMapper.toMockOrder(
        latest,
        vehicle: order?.vehicle,
      );
      _sync(mapped);
      await _refreshRiderLocation(apiId);
      if (mapped.status == OrderStatus.delivered) {
        _pollTimer?.cancel();
        context.go(AppRoutes.bookCompleted);
      }
    } catch (_) {
      // Keep last known status; next poll retries.
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refreshRiderLocation(String apiId) async {
    try {
      final loc = await ref.read(ordersApiProvider).riderLocation(apiId);
      if (!mounted) {
        return;
      }
      setState(() {
        if (loc == null) {
          _riderPoint = null;
          _riderStale = true;
        } else {
          _riderPoint = GeoPoint(
            latitude: loc.latitude,
            longitude: loc.longitude,
          );
          _riderStale = loc.stale;
        }
      });
    } catch (_) {
      // Keep last rider pin; status poll remains authoritative.
    }
  }

  int _timelineIndex(OrderStatus? status) {
    if (status == null) {
      return -1;
    }
    if (status == OrderStatus.assigned || status == OrderStatus.searching) {
      return 0;
    }
    return _timeline.indexOf(status);
  }

  Future<void> _loadRoute(MockOrder? order) async {
    final GeoPoint? pickup = _pointOf(order?.pickup);
    final GeoPoint? drop = _pointOf(order?.drop);
    if (pickup == null || drop == null) {
      return;
    }
    final String key =
        '${pickup.latitude},${pickup.longitude}>${drop.latitude},${drop.longitude}';
    if (key == _routeKey) {
      return;
    }
    _routeKey = key;
    final DisplayRoute? route = await ref.read(routesServiceProvider).compute(
          origin: pickup,
          destination: drop,
          intermediates: order?.extraDrops
                  .map(_pointOf)
                  .whereType<GeoPoint>()
                  .toList(growable: false) ??
              const <GeoPoint>[],
        );
    if (!mounted) {
      return;
    }
    setState(() => _route = route);
  }

  GeoPoint? _pointOf(MockLocation? loc) {
    if (loc?.latitude == null || loc?.longitude == null) {
      return null;
    }
    return GeoPoint(latitude: loc!.latitude!, longitude: loc.longitude!);
  }

  @override
  Widget build(BuildContext context) {
    final String? id = GoRouterState.of(context).uri.queryParameters['id'];
    MockOrder? order = ref.watch(bookingDraftProvider).activeOrder;
    if (id != null) {
      for (final MockOrder item in ref.watch(sessionProvider).orders) {
        if (item.id == id) {
          order = item;
          break;
        }
      }
    }
    final canCancel = order != null &&
        order.status != OrderStatus.delivered &&
        order.status != OrderStatus.cancelled;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRoute(order);
    });

    final GeoPoint? pickup = _pointOf(order?.pickup);
    final GeoPoint? drop = _pointOf(order?.drop);
    final List<MapMarkerSpec> markers = <MapMarkerSpec>[
      if (pickup != null)
        MapMarkerSpec(
          id: 'pickup',
          point: pickup,
          hue: BitmapDescriptor.hueOrange,
          title: 'Pickup',
          snippet: order?.pickup.address ?? '',
        ),
      if (drop != null)
        MapMarkerSpec(
          id: 'drop',
          point: drop,
          hue: BitmapDescriptor.hueAzure,
          title: 'Drop',
          snippet: order?.drop.address ?? '',
        ),
      if (_riderPoint != null)
        MapMarkerSpec(
          id: 'rider',
          point: _riderPoint!,
          hue: BitmapDescriptor.hueGreen,
          title: _riderStale ? 'Rider (last known)' : 'Rider',
          snippet: order?.rider?.name ?? 'Partner',
        ),
    ];

    return GlassPageScaffold(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedPrimaryButton(
            label: order?.status == OrderStatus.delivered
                ? 'View summary'
                : 'Refresh status',
            onPressed: () {
              if (order?.status == OrderStatus.delivered) {
                context.go(AppRoutes.bookCompleted);
                return;
              }
              unawaited(_refreshFromServer());
            },
          ),
          if (canCancel) ...[
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Cancel Booking',
              onPressed: () async {
                final MockOrder? current = _viewedOrder();
                if (current == null) return;
                final bool ok = await confirmCustomerCancellation(
                  context: context,
                  order: current,
                );
                if (!ok) return;
                final String? apiId = current.backendOrderId;
                if (apiId != null && apiId.isNotEmpty) {
                  try {
                    final latest =
                        await ref.read(ordersApiProvider).cancel(apiId);
                    final mapped = OrderMapper.toMockOrder(
                      latest,
                      vehicle: current.vehicle,
                    );
                    ref.read(sessionProvider.notifier).updateOrder(mapped);
                    ref.read(bookingDraftProvider.notifier).attachActive(mapped);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not cancel on the server.'),
                        ),
                      );
                    }
                    return;
                  }
                }
                if (context.mounted) context.go(AppRoutes.home);
              },
            ),
          ],
        ],
      ),
      child: ListView(
        children: [
          Row(
            children: [
              IuBackButton(onPressed: () => context.go(AppRoutes.home)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Live Tracking',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          EmbeddedGoogleMap(
            height: 200,
            initial: pickup ?? drop ?? MapsDefaults.cityCenter,
            markers: markers,
            route: _route?.points ?? const <GeoPoint>[],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            order?.statusLabel ?? 'In transit',
            style: AppTextStyles.headingS.copyWith(
              color: AppColors.orange,
            ),
          ),
          if (_route != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Road ${_route!.distanceLabel} · ${_route!.etaLabel}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          Text(
            'Status updates when your rider advances the delivery.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (order != null &&
              order.displayId != null &&
              order.displayId!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              order.displayId!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status', style: AppTextStyles.headingS),
                const SizedBox(height: AppSpacing.md),
                ...List.generate(_timeline.length, (i) {
                  final step = _timeline[i];
                  final currentIndex = _timelineIndex(order?.status);
                  final reached = currentIndex >= i;
                  final active = order?.status == step ||
                      (i == 0 &&
                          (order?.status == OrderStatus.accepted ||
                              order?.status == OrderStatus.assigned));
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(
                          active
                              ? Icons.radio_button_checked
                              : (reached
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked),
                          size: 18,
                          color: active || reached
                              ? AppColors.orange
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _labelFor(step),
                            style: AppTextStyles.caption.copyWith(
                              color: active
                                  ? AppColors.orange
                                  : AppColors.textSecondary,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _point(
                  color: AppColors.orange,
                  title: 'Pickup',
                  subtitle: order?.pickup.address ?? '—',
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: Container(
                    width: 2,
                    height: 28,
                    color: AppColors.orange.withValues(alpha: 0.35),
                  ),
                ),
                _point(
                  color: AppColors.navy,
                  title: 'Drop',
                  subtitle: order?.drop.address ?? '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassContainer(
            child: Row(
              children: [
                const SafeAssetImage(
                  path: AssetPaths.rider,
                  height: 56,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order?.rider?.name ?? 'Your rider',
                        style: AppTextStyles.bodyMedium,
                      ),
                      Text(
                        order?.rider?.vehicleLabel ?? '',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.call_rounded, color: AppColors.orange),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _point({
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(subtitle, style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
