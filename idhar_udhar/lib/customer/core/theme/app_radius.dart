import 'package:flutter/material.dart';

/// Corner radius tokens matching reference screens.
abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double mdLg = 20;
  static const double lg = 24;
  static const double lgXl = 28;
  static const double xl = 32;
  static const double xxl = 40;
  static const double otp = 14;
  static const double pill = 999;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius mdLgAll = BorderRadius.all(Radius.circular(mdLg));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius lgXlAll = BorderRadius.all(Radius.circular(lgXl));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius otpAll = BorderRadius.all(Radius.circular(otp));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  static BorderRadius only({
    double topLeft = 0,
    double topRight = 0,
    double bottomLeft = 0,
    double bottomRight = 0,
  }) {
    return BorderRadius.only(
      topLeft: Radius.circular(topLeft),
      topRight: Radius.circular(topRight),
      bottomLeft: Radius.circular(bottomLeft),
      bottomRight: Radius.circular(bottomRight),
    );
  }
}
