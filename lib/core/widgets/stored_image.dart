import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/env.dart';

/// A photo from the store (a product, a category), kept on the phone
/// after its first download. It then shows at once, with no mobile data
/// used, each time the app is opened, until the store replaces it.
///
/// [decodeWidth] is the widest the picture is shown, in screen pixels:
/// the photo is decoded no larger than that, so a long list of thumbnails
/// uses little memory however big the original photos are.
class StoredImage extends StatelessWidget {
  const StoredImage(
    this.url, {
    super.key,
    required this.placeholder,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.decodeWidth = 400,
    this.semanticLabel,
  });

  final String url;

  /// Shown while the photo loads.
  final Widget placeholder;

  /// Shown when the photo cannot be loaded.
  final Widget fallback;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int decodeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final pixels =
        (decodeWidth * MediaQuery.devicePixelRatioOf(context)).round();
    // Tests have no phone storage to keep photos in.
    if (Env.runningTests) {
      return Image.network(
        url,
        fit: fit,
        width: width,
        height: height,
        semanticLabel: semanticLabel,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder,
      );
    }
    final image = CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: pixels,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => fallback,
    );
    return semanticLabel == null
        ? image
        : Semantics(label: semanticLabel, image: true, child: image);
  }
}
