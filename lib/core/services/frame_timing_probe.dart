import 'dart:async';
import 'dart:io';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const frameProbeEnabled = String.fromEnvironment('MD3FREE_FRAME_LOG') != '';
final frameProbeBlur = ValueNotifier<bool>(true);

/// Opt-in local performance capture. No frames or files are collected in a
/// normal build; use --dart-define=MD3FREE_FRAME_LOG=<absolute CSV path> for QA.
void installFrameTimingProbe() {
  const path = String.fromEnvironment('MD3FREE_FRAME_LOG');
  if (path.isEmpty) return;
  final sink = File(path).openWrite();
  sink.writeln('time_ms,build_us,raster_us,total_us,blur,cache_bytes');
  HardwareKeyboard.instance.addHandler((event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f12) {
      frameProbeBlur.value = !frameProbeBlur.value;
      return true;
    }
    return false;
  });
  SchedulerBinding.instance.addTimingsCallback((frames) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final frame in frames) {
      sink.writeln(
        '$now,${frame.buildDuration.inMicroseconds},'
        '${frame.rasterDuration.inMicroseconds},${frame.totalSpan.inMicroseconds},'
        '${frameProbeBlur.value},${frame.layerCacheBytes + frame.pictureCacheBytes}',
      );
    }
    unawaited(sink.flush());
  });
}
