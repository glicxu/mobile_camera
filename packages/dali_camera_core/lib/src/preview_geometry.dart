import 'dart:math' as math;

/// The native preview and overlays both fit the complete oriented frame.
class PreviewRect {
  const PreviewRect(this.x, this.y, this.width, this.height);
  final double x;
  final double y;
  final double width;
  final double height;
}

PreviewRect fittedPreview({
  required double width,
  required double height,
  required double aspectRatio,
}) {
  if (width <= 0 || height <= 0 || aspectRatio <= 0) {
    return const PreviewRect(0, 0, 0, 0);
  }
  final fittedWidth = math.min(width, height * aspectRatio);
  final fittedHeight = fittedWidth / aspectRatio;
  return PreviewRect(
    (width - fittedWidth) / 2,
    (height - fittedHeight) / 2,
    fittedWidth,
    fittedHeight,
  );
}

double displayRollDegrees({
  required double gravityX,
  required double gravityY,
  required double rotation,
  required bool mirrored,
}) {
  if (math.sqrt(gravityX * gravityX + gravityY * gravityY) <= 0.15) return 0;
  var degrees =
      math.atan2(gravityX, -gravityY) * 180 / math.pi - (rotation - 90);
  while (degrees > 180) {
    degrees -= 360;
  }
  while (degrees < -180) {
    degrees += 360;
  }
  return mirrored ? -degrees : degrees;
}
