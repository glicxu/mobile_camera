import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:test/test.dart';

void main() {
  test('portrait and landscape preserve the full camera frame', () {
    final portrait = fittedPreview(width: 390, height: 500, aspectRatio: 3 / 4);
    expect(
      [portrait.x, portrait.y, portrait.width, portrait.height],
      [7.5, 0, 375, 500],
    );
    final landscape = fittedPreview(
      width: 500,
      height: 300,
      aspectRatio: 4 / 3,
    );
    expect(
      [landscape.x, landscape.y, landscape.width, landscape.height],
      [50, 0, 400, 300],
    );
  });
  test('roll accounts for rotation, mirror and flat phone', () {
    expect(
      displayRollDegrees(
        gravityX: 0,
        gravityY: -1,
        rotation: 90,
        mirrored: false,
      ),
      closeTo(0, 0.001),
    );
    expect(
      displayRollDegrees(
        gravityX: -1,
        gravityY: 0,
        rotation: 0,
        mirrored: false,
      ),
      closeTo(0, 0.001),
    );
    expect(
      displayRollDegrees(
        gravityX: 1,
        gravityY: 0,
        rotation: 180,
        mirrored: false,
      ),
      closeTo(0, 0.001),
    );
    final back = displayRollDegrees(
      gravityX: 0.1,
      gravityY: -0.99,
      rotation: 90,
      mirrored: false,
    );
    expect(
      displayRollDegrees(
        gravityX: 0.1,
        gravityY: -0.99,
        rotation: 90,
        mirrored: true,
      ),
      -back,
    );
    expect(
      displayRollDegrees(
        gravityX: 0,
        gravityY: 0,
        rotation: 90,
        mirrored: true,
      ),
      0,
    );
  });
}
