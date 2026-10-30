/// Length text with an explicit unit, compared in centimetre thousandths.
///
/// A bare number is not centimetres. A "long, wide, high" sentence is parsed
/// by [parseLabeledBoxThousandths] and is not reduced to one limit, because a
/// booking sends a single parcel size.
int? parseSingleSizeThousandths(String? raw) {
  if (raw == null) {
    return null;
  }
  final RegExpMatch? match = RegExp(
    r'^(\d+(?:\.\d+)?)\s*(mm|cm|m|ft|feet|inches|inch|in)$',
    caseSensitive: false,
  ).firstMatch(raw.trim());
  if (match == null) {
    return null;
  }
  return _lengthThousandths(match.group(1)!, match.group(2)!);
}

double? parseSingleSizeLimitCm(String? raw) {
  final int? thousandths = parseSingleSizeThousandths(raw);
  if (thousandths == null) {
    return null;
  }
  return thousandths / 1000;
}

class LabeledBoxThousandths {
  const LabeledBoxThousandths({
    required this.length,
    required this.width,
    required this.height,
  });

  final int length;
  final int width;
  final int height;

  double get lengthCm => length / 1000;
  double get widthCm => width / 1000;
  double get heightCm => height / 1000;
}

LabeledBoxThousandths? parseLabeledBoxThousandths(String? raw) {
  if (raw == null) {
    return null;
  }
  final RegExpMatch? match = RegExp(
    r'^(\d+(?:\.\d+)?)\s*(mm|cm|m|ft|feet|inches|inch|in)\s+long,\s*'
    r'(\d+(?:\.\d+)?)\s*(mm|cm|m|ft|feet|inches|inch|in)\s+wide,\s*'
    r'(\d+(?:\.\d+)?)\s*(mm|cm|m|ft|feet|inches|inch|in)\s+high$',
    caseSensitive: false,
  ).firstMatch(raw.trim());
  if (match == null) {
    return null;
  }
  final int? length = _lengthThousandths(match.group(1)!, match.group(2)!);
  final int? width = _lengthThousandths(match.group(3)!, match.group(4)!);
  final int? height = _lengthThousandths(match.group(5)!, match.group(6)!);
  if (length == null || width == null || height == null) {
    return null;
  }
  return LabeledBoxThousandths(length: length, width: width, height: height);
}

int? _lengthThousandths(String coefficient, String unit) {
  final int? perUnit = switch (unit.toLowerCase()) {
    'mm' => 100,
    'cm' => 1000,
    'm' => 100000,
    'ft' || 'feet' => 30480,
    'in' || 'inch' || 'inches' => 2540,
    _ => null,
  };
  if (perUnit == null) {
    return null;
  }
  final RegExpMatch? parts = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(coefficient);
  if (parts == null) {
    return null;
  }
  final String fraction = parts.group(2) ?? '';
  if (fraction.length > 6) {
    return null;
  }
  final int scale = _pow10(fraction.length);
  final int numerator = int.parse(parts.group(1)!) * scale +
      (fraction.isEmpty ? 0 : int.parse(fraction));
  if (numerator <= 0) {
    return null;
  }
  final int product = numerator * perUnit;
  if (product % scale != 0) {
    return null;
  }
  final int thousandths = product ~/ scale;
  if (thousandths <= 0) {
    return null;
  }
  return thousandths;
}

int _pow10(int exponent) {
  var value = 1;
  for (var i = 0; i < exponent; i++) {
    value *= 10;
  }
  return value;
}
