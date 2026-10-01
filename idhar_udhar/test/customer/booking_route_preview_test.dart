import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/widgets/booking_route_preview.dart';
import 'package:idhar_udhar/shared/maps/geo_point.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const GeoPoint pickup = GeoPoint(latitude: 23.0115, longitude: 72.5650);
  const GeoPoint drop = GeoPoint(latitude: 23.0300, longitude: 72.4720);
  const DisplayRoute route = DisplayRoute(
    points: <GeoPoint>[pickup, drop],
    distanceMeters: 12500,
    durationSeconds: 1080,
  );

  Future<void> pump(
    WidgetTester tester,
    List<GeoPoint> points,
    Future<DisplayRoute?> Function(List<GeoPoint> points) load,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: BookingRoutePreview(points: points, loadRoute: load),
          ),
        ),
      ),
    );
  }

  testWidgets('preview requests the real pickup and drop coordinates', (
    tester,
  ) async {
    List<GeoPoint>? requested;
    var calls = 0;
    await pump(tester, const <GeoPoint>[pickup, drop], (List<GeoPoint> points) async {
      calls += 1;
      requested = points;
      return route;
    });
    await tester.pump();

    expect(calls, 1);
    expect(requested?.first.latitude, pickup.latitude);
    expect(requested?.first.longitude, pickup.longitude);
    expect(requested?.last.latitude, drop.latitude);
    expect(requested?.last.longitude, drop.longitude);
    expect(find.text('Distance: 12.5 km'), findsOneWidget);
    expect(find.text('Approx. travel time: 18 min'), findsOneWidget);

    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('a failed route does not throw', (tester) async {
    await pump(tester, const <GeoPoint>[pickup, drop], (List<GeoPoint> points) async {
      throw StateError('route unavailable');
    });
    await tester.pump();

    expect(
      find.textContaining('Route details are unavailable'),
      findsOneWidget,
    );
    expect(find.textContaining('Distance:'), findsNothing);
  });
}
