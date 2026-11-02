import 'dart:ui';

class ClipItem {
  final String path;
  final Duration total;
  final Size size;
  Duration start;
  Duration end;
  double speed;
  bool muted;

  ClipItem(this.path, this.total, this.size,
      {Duration? start, Duration? end, this.speed = 1, this.muted = false})
      : start = start ?? Duration.zero,
        end = end ?? total;

  ClipItem copy() => ClipItem(path, total, size,
      start: start, end: end, speed: speed, muted: muted);
}

class TextItem {
  String text;
  Offset offset;
  TextItem(this.text, [this.offset = Offset.zero]);
}
