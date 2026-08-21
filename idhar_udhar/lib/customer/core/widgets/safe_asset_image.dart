import 'package:flutter/material.dart';

/// Loads a bundled asset image; shows [fallback] if the file is missing or fails.
///
/// Use for production paths declared in [AssetPaths] that may not be on disk yet.
class SafeAssetImage extends StatelessWidget {
  const SafeAssetImage({
    required this.path,
    super.key,
    this.fallback,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.width,
    this.height,
  });

  final String path;
  final Widget? fallback;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) =>
          fallback ??
          SizedBox(
            width: width,
            height: height,
            child: const Icon(Icons.image_not_supported_outlined),
          ),
    );
  }
}
