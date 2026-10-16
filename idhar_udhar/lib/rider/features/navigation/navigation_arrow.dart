import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const double _arrowLogicalSize = 56;

/// Sharp north-pointing navigation arrow. [Marker.rotation] supplies heading.
Future<Uint8List> navigationArrowPng({double devicePixelRatio = 3}) async {
  final double ratio = devicePixelRatio.clamp(2, 4).toDouble();
  final int size = (_arrowLogicalSize * ratio).round();
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final double side = size.toDouble();
  final Offset center = Offset(side / 2, side / 2);

  canvas.drawCircle(
    center,
    side * 0.34,
    Paint()..color = const Color(0x5514A3C0),
  );
  canvas.drawCircle(
    center,
    side * 0.22,
    Paint()..color = const Color(0xCCFFFFFF),
  );

  final double tipY = side * 0.16;
  final double baseY = side * 0.78;
  final Path arrow = Path()
    ..moveTo(center.dx, tipY)
    ..lineTo(side * 0.78, baseY)
    ..lineTo(center.dx, side * 0.62)
    ..lineTo(side * 0.22, baseY)
    ..close();
  canvas.drawPath(
    arrow,
    Paint()
      ..color = const Color(0xFF0E8FA8)
      ..style = PaintingStyle.fill,
  );
  canvas.drawPath(
    arrow,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.045
      ..strokeJoin = StrokeJoin.round,
  );

  final ui.Image image = await recorder.endRecording().toImage(size, size);
  final ByteData? data = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<BitmapDescriptor> navigationArrowMarker({
  double devicePixelRatio = 3,
}) async {
  final Uint8List bytes = await navigationArrowPng(
    devicePixelRatio: devicePixelRatio,
  );
  return BitmapDescriptor.bytes(
    bytes,
    width: _arrowLogicalSize,
    height: _arrowLogicalSize,
  );
}
