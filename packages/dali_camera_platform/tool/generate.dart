import 'dart:io';

Future<void> main() async {
  final result = await Process.start(Platform.resolvedExecutable, [
    'run',
    'pigeon',
    '--input',
    'pigeons/camera_api.dart',
  ], mode: ProcessStartMode.inheritStdio);
  if (await result.exitCode != 0) {
    exitCode = 1;
    return;
  }
  for (final path in [
    'lib/src/camera_api.g.dart',
    'android/src/main/kotlin/com/dalicamera/dali_camera_platform/CameraApi.g.kt',
    'ios/dali_camera_platform/Sources/dali_camera_platform/CameraApi.g.swift',
  ]) {
    final file = File(path);
    final lines = file
        .readAsLinesSync()
        .map((line) => line.trimRight())
        .join('\n');
    file.writeAsStringSync('$lines\n');
  }
}
