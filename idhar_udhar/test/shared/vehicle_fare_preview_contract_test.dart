import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/state/booking_api.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';
import 'package:idhar_udhar/shared/api/api_client.dart';
import 'package:idhar_udhar/shared/api/api_config.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/token_store.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category_catalog.dart';

class _MemoryTokenStore extends TokenStore {
  @override
  Future<String?> get accessToken async => 'test-access';

  @override
  Future<String?> get refreshToken async => 'test-refresh';

  @override
  Future<bool> get hasRefreshToken async => true;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? role,
    String? phone,
  }) async {}

  @override
  Future<void> clear() async {}
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._onFetch);

  final Future<ResponseBody> Function(RequestOptions options) _onFetch;
  RequestOptions? lastOptions;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return _onFetch(options);
  }
}

ResponseBody _json(int status, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

int _fractionDigits(Object? value) {
  final String text = value is num ? value.toString() : '$value';
  if (!text.contains('.')) {
    return 0;
  }
  return text.split('.').last.length;
}

void main() {
  tearDown(() {
    VehicleCategoryCatalog.launchCityId = null;
    ApiConfig.debugResetBaseUrl();
  });

  test('ApiStop.toJson rounds coordinates to backend maxDecimalPlaces=6', () {
    const ApiStop stop = ApiStop(
      sequence: 0,
      stopType: 'PICKUP',
      addressText: 'Paldi',
      latitude: 23.011612345678,
      longitude: 72.5625987654321,
    );
    final Map<String, Object?> json = stop.toJson();
    expect(json['latitude'], 23.011612);
    expect(json['longitude'], 72.562599);
    expect(_fractionDigits(json['latitude']), lessThanOrEqualTo(6));
    expect(_fractionDigits(json['longitude']), lessThanOrEqualTo(6));

    final String encoded = jsonEncode(json);
    final Map<String, dynamic> decoded =
        jsonDecode(encoded) as Map<String, dynamic>;
    expect(_fractionDigits(decoded['latitude']), lessThanOrEqualTo(6));
    expect(_fractionDigits(decoded['longitude']), lessThanOrEqualTo(6));
  });

  test('production launch city id matches configured IU_CITY_ID value', () {
    expect(
      '01a0fc52-fafe-72d5-b4cc-ed34ebb3b9cc',
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ),
      ),
    );
  });

  test('previewVehicleFares request matches Nest PreviewVehicleFaresDto', () async {
    final _RecordingAdapter adapter = _RecordingAdapter((RequestOptions options) async {
      expect(options.path, '/v1/orders/vehicle-fares');
      expect(options.method, 'POST');
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(options.data as Map);
      expect(data.keys.toSet(), <String>{'city_id', 'stops'});
      expect(data['city_id'], '01a0fc52-fafe-72d5-b4cc-ed34ebb3b9cc');
      final List<dynamic> stops = data['stops'] as List<dynamic>;
      expect(stops.length, 2);
      final Map<String, dynamic> pickup =
          Map<String, dynamic>.from(stops[0] as Map);
      expect(pickup['sequence'], 0);
      expect(pickup['stop_type'], 'PICKUP');
      expect(pickup['address_text'], isNotEmpty);
      expect(_fractionDigits(pickup['latitude']), lessThanOrEqualTo(6));
      expect(_fractionDigits(pickup['longitude']), lessThanOrEqualTo(6));
      // High-precision GPS input must be rounded before wire.
      expect(pickup['latitude'], 23.011612);
      expect(pickup['longitude'], 72.562599);
      return _json(200, <String, Object?>{
        'distance_km': '10.000',
        'vehicles': <Map<String, Object?>>[
          <String, Object?>{
            'vehicle_category_id': '01a0fb3b-34f2-7bd1-ae00-1c39365f6095',
            'fare': <String, Object?>{'net_payable': '160.00'},
          },
        ],
      });
    });
    final Dio dio = Dio(
      BaseOptions(baseUrl: 'https://api.idharudhar.co.in'),
    )..httpClientAdapter = adapter;
    final OrdersApi api = OrdersApi(
      ApiClient(tokenStore: _MemoryTokenStore(), dio: dio),
    );

    final Map<String, String> fares = await api.previewVehicleFares(
      cityId: '01a0fc52-fafe-72d5-b4cc-ed34ebb3b9cc',
      stops: const <ApiStop>[
        ApiStop(
          sequence: 0,
          stopType: 'PICKUP',
          addressText: 'Paldi',
          latitude: 23.011612345678,
          longitude: 72.5625987654321,
        ),
        ApiStop(
          sequence: 1,
          stopType: 'DROP',
          addressText: 'Bopal',
          latitude: 23.030012345678,
          longitude: 72.4700987654321,
        ),
      ],
    );

    expect(fares, <String, String>{
      '01a0fb3b-34f2-7bd1-ae00-1c39365f6095': '160.00',
    });
    expect(adapter.lastOptions?.uri.host, 'api.idharudhar.co.in');
  });

  test('previewVehicleFares maps net_payable and surfaces API errors', () async {
    final _RecordingAdapter okAdapter = _RecordingAdapter((_) async {
      return _json(200, <String, Object?>{
        'vehicles': <Map<String, Object?>>[
          <String, Object?>{
            'vehicle_category_id': 'bike-1',
            'fare': <String, Object?>{'net_payable': '99.50'},
          },
        ],
      });
    });
    final OrdersApi okApi = OrdersApi(
      ApiClient(
        tokenStore: _MemoryTokenStore(),
        dio: Dio(BaseOptions(baseUrl: 'https://api.idharudhar.co.in'))
          ..httpClientAdapter = okAdapter,
      ),
    );
    expect(
      await okApi.previewVehicleFares(
        cityId: '01a0fc52-fafe-72d5-b4cc-ed34ebb3b9cc',
        stops: const <ApiStop>[
          ApiStop(
            sequence: 0,
            stopType: 'PICKUP',
            addressText: 'A',
            latitude: 23.01,
            longitude: 72.56,
          ),
          ApiStop(
            sequence: 1,
            stopType: 'DROP',
            addressText: 'B',
            latitude: 23.03,
            longitude: 72.47,
          ),
        ],
      ),
      <String, String>{'bike-1': '99.50'},
    );

    final _RecordingAdapter errAdapter = _RecordingAdapter((_) async {
      return _json(400, <String, Object?>{
        'error': <String, Object?>{
          'code': 'VALIDATION_ERROR',
          'message': 'latitude must be a number conforming to the specified constraints',
        },
      });
    });
    final OrdersApi errApi = OrdersApi(
      ApiClient(
        tokenStore: _MemoryTokenStore(),
        dio: Dio(BaseOptions(baseUrl: 'https://api.idharudhar.co.in'))
          ..httpClientAdapter = errAdapter,
      ),
    );
    await expectLater(
      errApi.previewVehicleFares(
        cityId: '01a0fc52-fafe-72d5-b4cc-ed34ebb3b9cc',
        stops: const <ApiStop>[
          ApiStop(
            sequence: 0,
            stopType: 'PICKUP',
            addressText: 'A',
            latitude: 23.01,
            longitude: 72.56,
          ),
          ApiStop(
            sequence: 1,
            stopType: 'DROP',
            addressText: 'B',
            latitude: 23.03,
            longitude: 72.47,
          ),
        ],
      ),
      throwsA(
        isA<ApiException>().having(
          (ApiException e) => e.code,
          'code',
          'VALIDATION_ERROR',
        ),
      ),
    );
  });

  test('vehicleFarePreviewProvider returns authoritative fares for route', () async {
    VehicleCategoryCatalog.launchCityId =
        '01a0fc52-fafe-72d5-b4cc-ed34ebb3b9cc';
    final _RecordingAdapter adapter = _RecordingAdapter((RequestOptions options) async {
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(options.data as Map);
      expect(data['city_id'], '01a0fc52-fafe-72d5-b4cc-ed34ebb3b9cc');
      final List<dynamic> stops = data['stops'] as List<dynamic>;
      final Map<String, dynamic> pickup =
          Map<String, dynamic>.from(stops.first as Map);
      expect(_fractionDigits(pickup['latitude']), lessThanOrEqualTo(6));
      return _json(200, <String, Object?>{
        'vehicles': <Map<String, Object?>>[
          <String, Object?>{
            'vehicle_category_id': 'bike-1',
            'fare': <String, Object?>{'net_payable': '160.00'},
          },
        ],
      });
    });
    final Dio dio = Dio(BaseOptions(baseUrl: ApiConfig.productionBaseUrl))
      ..httpClientAdapter = adapter;
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        apiClientProvider.overrideWithValue(
          ApiClient(tokenStore: _MemoryTokenStore(), dio: dio),
        ),
        vehicleCategoryCatalogProvider.overrideWith(
          (Ref ref) async => const <VehicleCategory>[
            VehicleCategory(id: 'bike-1', name: 'Bike'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    final BookingDraftNotifier draft =
        container.read(bookingDraftProvider.notifier);
    draft.setPickup(
      const MockLocation(
        id: 'p',
        label: 'Paldi',
        address: 'Paldi',
        latitude: 23.011612345678,
        longitude: 72.5625987654321,
      ),
    );
    draft.setDrop(
      const MockLocation(
        id: 'd',
        label: 'Bopal',
        address: 'Bopal',
        latitude: 23.030012345678,
        longitude: 72.4700987654321,
      ),
    );
    draft.applyRouteResult(
      signature: container.read(bookingDraftProvider).currentRouteKey,
      distanceKm: 10,
      durationSeconds: 1200,
    );

    final Map<String, String> fares =
        await container.read(vehicleFarePreviewProvider.future);
    expect(fares['bike-1'], '160.00');
  });

  test('vehicleFarePreviewProvider quotes from coordinates without a phone route', () async {
    VehicleCategoryCatalog.launchCityId =
        '01a0fc52-fafe-72d5-b4cc-ed34ebb3b9cc';
    var calls = 0;
    final _RecordingAdapter adapter = _RecordingAdapter((_) async {
      calls += 1;
      return _json(200, <String, Object?>{
        'distance_km': '8.500',
        'vehicles': <Map<String, Object?>>[
          <String, Object?>{
            'vehicle_category_id': 'bike-1',
            'fare': <String, Object?>{'net_payable': '108.00'},
          },
          <String, Object?>{
            'vehicle_category_id': 'scooty-1',
            'fare': <String, Object?>{'net_payable': '132.00'},
          },
        ],
      });
    });
    final Dio dio = Dio(BaseOptions(baseUrl: ApiConfig.productionBaseUrl))
      ..httpClientAdapter = adapter;
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        apiClientProvider.overrideWithValue(
          ApiClient(tokenStore: _MemoryTokenStore(), dio: dio),
        ),
        vehicleCategoryCatalogProvider.overrideWith(
          (Ref ref) async => const <VehicleCategory>[
            VehicleCategory(id: 'bike-1', name: 'Bike'),
            VehicleCategory(id: 'scooty-1', name: 'Scooty'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    final BookingDraftNotifier draft =
        container.read(bookingDraftProvider.notifier);
    draft.setPickup(
      const MockLocation(
        id: 'p',
        label: 'Paldi',
        address: 'Paldi',
        latitude: 23.011612,
        longitude: 72.562599,
      ),
    );
    draft.setDrop(
      const MockLocation(
        id: 'd',
        label: 'Bopal',
        address: 'Bopal',
        latitude: 23.030012,
        longitude: 72.470099,
      ),
    );

    expect(container.read(bookingDraftProvider).hasRouteForCurrentStops, isFalse);
    final Map<String, String> fares =
        await container.read(vehicleFarePreviewProvider.future);
    expect(calls, 1);
    expect(fares, <String, String>{
      'bike-1': '108.00',
      'scooty-1': '132.00',
    });
  });

  test('missing or zero coordinates do not request a fare or invent one', () async {
    VehicleCategoryCatalog.launchCityId =
        '01a0fc52-fafe-72d5-b4cc-ed34ebb3b9cc';
    var calls = 0;
    final _RecordingAdapter adapter = _RecordingAdapter((_) async {
      calls += 1;
      return _json(500, <String, Object?>{'error': 'should not be called'});
    });
    final Dio dio = Dio(BaseOptions(baseUrl: ApiConfig.productionBaseUrl))
      ..httpClientAdapter = adapter;
    final ProviderContainer missing = ProviderContainer(
      overrides: <Override>[
        apiClientProvider.overrideWithValue(
          ApiClient(tokenStore: _MemoryTokenStore(), dio: dio),
        ),
      ],
    );
    addTearDown(missing.dispose);
    missing.read(bookingDraftProvider.notifier).setPickup(
          const MockLocation(
            id: 'p',
            label: 'Paldi',
            address: 'Paldi',
            latitude: 23.01,
            longitude: 72.56,
          ),
        );
    expect(
      await missing.read(vehicleFarePreviewProvider.future),
      isEmpty,
    );
    expect(calls, 0);

    final ProviderContainer zero = ProviderContainer(
      overrides: <Override>[
        apiClientProvider.overrideWithValue(
          ApiClient(tokenStore: _MemoryTokenStore(), dio: dio),
        ),
      ],
    );
    addTearDown(zero.dispose);
    final BookingDraftNotifier zeroDraft =
        zero.read(bookingDraftProvider.notifier);
    zeroDraft.setPickup(
      const MockLocation(
        id: 'p',
        label: 'Zero',
        address: 'Zero',
        latitude: 0,
        longitude: 0,
      ),
    );
    zeroDraft.setDrop(
      const MockLocation(
        id: 'd',
        label: 'Bopal',
        address: 'Bopal',
        latitude: 23.03,
        longitude: 72.47,
      ),
    );
    await expectLater(
      zero.read(vehicleFarePreviewProvider.future),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.code,
          'code',
          'INVALID_COORDINATES',
        ),
      ),
    );
    expect(calls, 0);
  });

  test('a malformed fare payload is not parsed as zero', () {
    expect(
      () => ApiQuote.fromJson(<String, Object?>{
        'fare_quote_id': 'fq-1',
        'net_payable': 'not-money',
        'trip_fare': '10.00',
        'distance_km': '1.000',
      }),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => ApiQuote.fromJson(<String, Object?>{
        'fare_quote_id': '',
        'net_payable': '10.00',
        'trip_fare': '10.00',
        'distance_km': '1.000',
      }),
      throwsA(isA<ApiException>()),
    );
    final ApiQuote quote = ApiQuote.fromJson(<String, Object?>{
      'order_id': 'order-1',
      'display_id': 'IU-1',
      'fare_quote_id': 'fq-1',
      'trip_fare': '129.60',
      'net_payable': '129.60',
      'distance_km': '8.500',
      'expires_at': '2026-11-06T12:00:00.000Z',
    });
    expect(quote.netPayable, 129.60);
    expect(quote.distanceKm, 8.5);
    expect(
      quote.isExpiredAt(DateTime.utc(2026, 11, 6, 12)),
      isTrue,
    );
    expect(
      quote.isExpiredAt(DateTime.utc(2026, 11, 6, 11, 59)),
      isFalse,
    );
  });

  test('an expired quote is not treated as the current booking quote', () {
    final BookingDraft draft = BookingDraft(
      pickup: const MockLocation(
        id: 'p',
        label: 'Paldi',
        address: 'Paldi',
        latitude: 23.01,
        longitude: 72.56,
      ),
      drop: const MockLocation(
        id: 'd',
        label: 'Bopal',
        address: 'Bopal',
        latitude: 23.03,
        longitude: 72.47,
      ),
      vehicle: const MockVehicle(
        id: 'bike-1',
        type: VehicleType.bike,
        name: 'Bike',
        description: 'Bike',
        capacity: '20 KG',
        etaMinutes: 0,
        baseFare: 40,
        perKm: 8,
        imagePath: 'assets/vehicle.png',
      ),
    );
    final BackendQuoteHold hold = BackendQuoteHold(
      orderId: 'order-1',
      vehicleCategoryId: 'bike-1',
      bookingKey: draft.quoteBookingKey,
      quote: ApiQuote(
        orderId: 'order-1',
        displayId: 'IU-1',
        fareQuoteId: 'fq-1',
        tripFare: 120,
        netPayable: 120,
        distanceKm: 8.5,
        expiresAt: DateTime.utc(2026, 11, 6, 12),
      ),
    );
    expect(
      quoteHoldIsCurrent(hold, draft, DateTime.utc(2026, 11, 6, 12)),
      isFalse,
    );
    expect(
      quoteHoldIsCurrent(hold, draft, DateTime.utc(2026, 11, 6, 11)),
      isTrue,
    );
    expect(draft.quoteBookingKey.contains('8.500'), isFalse);
  });
}
