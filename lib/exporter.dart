import 'dart:async';
import 'package:ffmpeg_kit_flutter_minimal/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_minimal/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_minimal/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class ExportResult {
  final String? path;
  final String? error;
  ExportResult.ok(this.path) : error = null;
  ExportResult.fail(this.error) : path = null;
}

String _s(double v) => v.toStringAsFixed(3);

Future<bool> _hasAudio(String path) async {
  try {
    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    if (info == null) return false;
    return info.getStreams().any((s) => s.getType() == 'audio');
  } catch (_) {
    return false;
  }
}

String _bitrate(int side) {
  if (side <= 480) return '2M';
  if (side <= 720) return '5M';
  if (side <= 1080) return '8M';
  if (side <= 1440) return '16M';
  return '35M';
}

Future<ExportResult> exportClips({
  required List<ClipItem> clips,
  required int shortSide,
  required void Function(double) onProgress,
}) async {
  if (clips.isEmpty) return ExportResult.fail('Clips නෑ');

  final ref = clips.first.size;
  int w, h;
  if (ref.width >= ref.height) {
    h = shortSide;
    w = (shortSide * ref.width / ref.height).round();
  } else {
    w = shortSide;
    h = (shortSide * ref.height / ref.width).round();
  }
  w = w - (w % 2);
  h = h - (h % 2);

  final dir = await getTemporaryDirectory();
  final out =
      '${dir.path}/clipnova_${DateTime.now().millisecondsSinceEpoch}.mp4';

  final inputs = <String>[];
  final filters = StringBuffer();
  final concatIn = StringBuffer();
  var idx = 0;
  var totalMs = 0.0;

  for (var i = 0; i < clips.length; i++) {
    final c = clips[i];
    final srcSec = (c.end - c.start).inMilliseconds / 1000.0;
    final outSec = srcSec / c.speed;
    totalMs += outSec * 1000;

    inputs.addAll([
      '-ss', _s(c.start.inMilliseconds / 1000.0),
      '-t', _s(srcSec),
      '-i', c.path,
    ]);
    final vi = idx;
    idx++;

    final useOwnAudio = !c.muted && await _hasAudio(c.path);
    int ai = vi;
    if (!useOwnAudio) {
      inputs.addAll([
        '-f', 'lavfi',
        '-t', _s(outSec),
        '-i', 'anullsrc=r=44100:cl=stereo',
      ]);
      ai = idx;
      idx++;
    }

    filters.write(
        '[$vi:v]setpts=PTS/${c.speed},scale=$w:$h:force_original_aspect_ratio=decrease,'
        'pad=$w:$h:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30[v$i];');
    if (useOwnAudio) {
      filters.write(
          '[$vi:a]atempo=${c.speed},aresample=44100,aformat=channel_layouts=stereo[a$i];');
    } else {
      filters.write(
          '[$ai:a]aresample=44100,aformat=channel_layouts=stereo[a$i];');
    }
    concatIn.write('[v$i][a$i]');
  }
  filters.write('${concatIn}concat=n=${clips.length}:v=1:a=1[outv][outa]');

  final br = _bitrate(shortSide);
  final attempts = <List<String>>[
    ['-c:v', 'h264_mediacodec', '-b:v', br],
    ['-c:v', 'mpeg4', '-b:v', br],
  ];

  String? lastErr;
  var cancelled = false;

  for (final codec in attempts) {
    final args = <String>[
      '-y',
      ...inputs,
      '-filter_complex', filters.toString(),
      '-map', '[outv]',
      '-map', '[outa]',
      ...codec,
      '-c:a', 'aac',
      '-b:a', '128k',
      '-movflags', '+faststart',
      out,
    ];

    final done = Completer<bool>();
    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        final rc = await session.getReturnCode();
        if (ReturnCode.isCancel(rc)) {
          cancelled = true;
        } else if (!ReturnCode.isSuccess(rc)) {
          final logs = await session.getAllLogsAsString() ?? '';
          lastErr = logs.length > 500
              ? logs.substring(logs.length - 500)
              : logs;
        }
        done.complete(ReturnCode.isSuccess(rc));
      },
      null,
      (stats) {
        final t = stats.getTime().toDouble();
        if (totalMs > 0) onProgress((t / totalMs).clamp(0.0, 1.0));
      },
    );

    final ok = await done.future;
    if (ok) return ExportResult.ok(out);
    if (cancelled) return ExportResult.fail('Cancelled');
  }
  return ExportResult.fail(lastErr ?? 'Export failed');
}
