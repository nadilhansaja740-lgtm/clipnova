import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

const Map<String, List<double>> _vFilters = {
  'Normal': [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0],
  'B&W': [0.33,0.59,0.11,0,0, 0.33,0.59,0.11,0,0, 0.33,0.59,0.11,0,0, 0,0,0,1,0],
  'Warm': [1.1,0,0,0,10, 0,1,0,0,0, 0,0,0.9,0,-10, 0,0,0,1,0],
  'Cool': [0.9,0,0,0,-10, 0,1,0,0,0, 0,0,1.1,0,10, 0,0,0,1,0],
  'Vintage': [0.393,0.769,0.189,0,0, 0.349,0.686,0.168,0,0, 0.272,0.534,0.131,0,0, 0,0,0,1,0],
};

class ClipItem {
  final String path;
  final Duration total;
  Duration start;
  Duration end;
  double speed;
  bool muted;

  ClipItem(this.path, this.total,
      {Duration? start, Duration? end, this.speed = 1, this.muted = false})
      : start = start ?? Duration.zero,
        end = end ?? total;

  ClipItem copy() => ClipItem(path, total,
      start: start, end: end, speed: speed, muted: muted);
}

class TextItem {
  String text;
  Offset offset;
  TextItem(this.text, [this.offset = Offset.zero]);
}

class VideoEditorPage extends StatefulWidget {
  const VideoEditorPage({super.key});
  @override
  State<VideoEditorPage> createState() => _VideoEditorPageState();
}

class _VideoEditorPageState extends State<VideoEditorPage> {
  final List<ClipItem> _clips = [];
  final List<TextItem> _texts = [];
  final List<List<ClipItem>> _undo = [];
  final List<List<ClipItem>> _redo = [];
  int _sel = 0;
  int _filter = 0;
  bool _loading = false;
  VideoPlayerController? _c;
  BuildContext? _ctx;

  @override
  void dispose() {
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  void _snack(String m) {
    ScaffoldMessenger.of(_ctx ?? context)
        .showSnackBar(SnackBar(content: Text(m)));
  }

  // ---------- history ----------
  List<ClipItem> _snapshot() => _clips.map((c) => c.copy()).toList();

  void _push() {
    _undo.add(_snapshot());
    _redo.clear();
  }

  void _doUndo() {
    if (_undo.isEmpty) return;
    _redo.add(_snapshot());
    _restore(_undo.removeLast());
  }

  void _doRedo() {
    if (_redo.isEmpty) return;
    _undo.add(_snapshot());
    _restore(_redo.removeLast());
  }

  void _restore(List<ClipItem> list) {
    _clips
      ..clear()
      ..addAll(list);
    if (_clips.isEmpty) {
      _c?.removeListener(_tick);
      _c?.dispose();
      setState(() {
        _c = null;
        _sel = 0;
      });
    } else {
      if (_sel >= _clips.length) _sel = _clips.length - 1;
      _load(_sel);
    }
  }

  // ---------- player ----------
  Future<void> _load(int i, {bool play = false}) async {
    _loading = true;
    final old = _c;
    _c = null;
    if (mounted) setState(() {});
    old?.removeListener(_tick);
    await old?.dispose();
    final clip = _clips[i];
    final c = VideoPlayerController.file(File(clip.path));
    await c.initialize();
    await c.setVolume(clip.muted ? 0 : 1);
    await c.setPlaybackSpeed(clip.speed);
    await c.seekTo(clip.start);
    c.addListener(_tick);
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() {
      _sel = i;
      _c = c;
      _loading = false;
    });
    if (play) await c.play();
  }

  void _tick() {
    final c = _c;
    if (c == null || _loading || _sel >= _clips.length) return;
    final clip = _clips[_sel];
    if (c.value.isPlaying && c.value.position >= clip.end) {
      if (_sel < _clips.length - 1) {
        _load(_sel + 1, play: true);
        return;
      } else {
        c.pause();
        c.seekTo(clip.start);
      }
    }
    if (mounted) setState(() {});
  }

  void _togglePlay() {
    final c = _c;
    if (c == null || _sel >= _clips.length) return;
    final clip = _clips[_sel];
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (c.value.position >= clip.end || c.value.position < clip.start) {
        c.seekTo(clip.start);
      }
      c.play();
    }
  }

  Future<void> _addClip() async {
    final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    final tmp = VideoPlayerController.file(File(x.path));
    await tmp.initialize();
    final d = tmp.value.duration;
    await tmp.dispose();
    _push();
    _clips.add(ClipItem(x.path, d));
    await _load(_clips.length - 1);
  }

  // ---------- edit actions ----------
  void _split() {
    final c = _c;
    if (c == null || _sel >= _clips.length) return;
    final clip = _clips[_sel];
    final pos = c.value.position;
    const gap = Duration(milliseconds: 300);
    if (pos <= clip.start + gap || pos >= clip.end - gap) {
      _snack('Slider එකෙන් playhead එක clip එක මැදට ගන්න');
      return;
    }
    _push();
    final second = clip.copy()..start = pos;
    setState(() {
      clip.end = pos;
      _clips.insert(_sel + 1, second);
    });
  }

  void _delete() {
    if (_clips.isEmpty) return;
    _push();
    final idx = _sel;
    _clips.removeAt(idx);
    if (_clips.isEmpty) {
      _c?.removeListener(_tick);
      _c?.dispose();
      setState(() {
        _c = null;
        _sel = 0;
      });
    } else {
      _load(idx >= _clips.length ? _clips.length - 1 : idx);
    }
  }

  Future<void> _addText() async {
    final ctrl = TextEditingController();
    final t = await showDialog<String>(
      context: _ctx ?? context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add text'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Add')),
        ],
      ),
    );
    if (t != null && t.trim().isNotEmpty) {
      setState(() => _texts.add(TextItem(t.trim())));
    }
  }

  void _editSheet() {
    if (_clips.isEmpty) {
      _snack('මුලින්ම video එකක් add කරන්න');
      return;
    }
    showModalBottomSheet(
      context: _ctx ?? context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (sheetCtx) => StatefulBuilder(builder: (ctx, setSheet) {
        if (_sel >= _clips.length) return const SizedBox();
        final clip = _clips[_sel];
        final totalMs = clip.total.inMilliseconds.toDouble();
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Trim', style: TextStyle(fontWeight: FontWeight.bold)),
              RangeSlider(
                values: RangeValues(clip.start.inMilliseconds.toDouble(),
                    clip.end.inMilliseconds.toDouble()),
                min: 0,
                max: totalMs,
                onChangeStart: (_) => _push(),
                onChanged: (r) {
                  if (r.end - r.start < 300) return;
                  setState(() {
                    clip.start = Duration(milliseconds: r.start.round());
                    clip.end = Duration(milliseconds: r.end.round());
                  });
                  setSheet(() {});
                },
                onChangeEnd: (_) => _c?.seekTo(clip.start),
              ),
              const Text('Speed',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: [0.5, 1.0, 1.5, 2.0].map((s) {
                  return ChoiceChip(
                    label: Text('${s}x'),
                    selected: clip.speed == s,
                    onSelected: (_) {
                      _push();
                      clip.speed = s;
                      _c?.setPlaybackSpeed(s);
                      setState(() {});
                      setSheet(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.call_split),
                    label: const Text('Split'),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _split();
                    },
                  ),
                  TextButton.icon(
                    icon: Icon(clip.muted ? Icons.volume_off : Icons.volume_up),
                    label: Text(clip.muted ? 'Unmute' : 'Mute'),
                    onPressed: () {
                      _push();
                      clip.muted = !clip.muted;
                      _c?.setVolume(clip.muted ? 0 : 1);
                      setState(() {});
                      setSheet(() {});
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _delete();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  void _filterSheet() {
    showModalBottomSheet(
      context: _ctx ?? context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (sheetCtx) => StatefulBuilder(builder: (ctx, setSheet) {
        final names = _vFilters.keys.toList();
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < names.length; i++)
                ChoiceChip(
                  label: Text(names[i]),
                  selected: _filter == i,
                  onSelected: (_) {
                    setState(() => _filter = i);
                    setSheet(() {});
                  },
                ),
            ],
          ),
        );
      }),
    );
  }

  // ---------- helpers ----------
  Duration get _totalLen => _clips.fold<Duration>(
      Duration.zero, (a, c) => a + (c.end - c.start));

  Duration get _curPos {
    if (_clips.isEmpty || _c == null || _sel >= _clips.length) {
      return Duration.zero;
    }
    var d = Duration.zero;
    for (var i = 0; i < _sel; i++) {
      d += _clips[i].end - _clips[i].start;
    }
    final p = _c!.value.position - _clips[_sel].start;
    return d + (p.isNegative ? Duration.zero : p);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Builder(builder: (ctx) {
        _ctx = ctx;
        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: SafeArea(
            child: Column(children: [
              _topBar(ctx),
              Expanded(child: _preview()),
              _controls(),
              _timeline(),
              _toolbar(),
            ]),
          ),
        );
      }),
    );
  }

  Widget _topBar(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        IconButton(
            icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
        const Spacer(),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, foregroundColor: Colors.black),
          onPressed: () => _snack('Export ඊළඟ update එකෙන් එනවා'),
          child: const Text('Export',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _preview() {
    if (_clips.isEmpty) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _addClip,
          icon: const Icon(Icons.add),
          label: const Text('Video එකක් add කරන්න'),
        ),
      );
    }
    final c = _c;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final matrix = _vFilters.values.elementAt(_filter);
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColorFiltered(
                colorFilter: ColorFilter.matrix(matrix),
                child: VideoPlayer(c),
              ),
              for (final t in _texts)
                Center(
                  child: Transform.translate(
                    offset: t.offset,
                    child: GestureDetector(
                      onPanUpdate: (d) => setState(() => t.offset += d.delta),
                      child: Text(
                        t.text,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls() {
    final c = _c;
    final playing = c?.value.isPlaying ?? false;
    double min = 0, max = 1, val = 0;
    if (c != null && _clips.isNotEmpty && _sel < _clips.length) {
      final clip = _clips[_sel];
      min = clip.start.inMilliseconds.toDouble();
      max = clip.end.inMilliseconds.toDouble();
      val = c.value.position.inMilliseconds.toDouble();
      if (val < min) val = min;
      if (val > max) val = max;
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Text('${_fmt(_curPos)} / ${_fmt(_totalLen)}',
              style: const TextStyle(fontSize: 13)),
          const Spacer(),
          IconButton(
            iconSize: 38,
            icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
            onPressed: _togglePlay,
          ),
          const Spacer(),
          IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undo.isEmpty ? null : _doUndo),
          IconButton(
              icon: const Icon(Icons.redo),
              onPressed: _redo.isEmpty ? null : _doRedo),
        ]),
      ),
      Slider(
        value: val,
        min: min,
        max: max > min ? max : min + 1,
        onChanged: c == null
            ? null
            : (v) => c.seekTo(Duration(milliseconds: v.round())),
      ),
    ]);
  }

  Widget _clipBlock(int i) {
    final clip = _clips[i];
    final len = clip.end - clip.start;
    final w = math.max(
        70.0, math.min(300.0, len.inMilliseconds / 1000 * 40));
    final selected = i == _sel;
    return GestureDetector(
      onTap: () {
        if (i != _sel) _load(i);
      },
      child: Container(
        width: w,
        height: 56,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? Colors.white : Colors.transparent, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_outlined, size: 18),
            Text(
              clip.speed == 1
                  ? _fmt(len)
                  : '${_fmt(len)} • ${clip.speed}x',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeline() {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (var i = 0; i < _clips.length; i++) _clipBlock(i),
                GestureDetector(
                  onTap: _addClip,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: InkWell(
              onTap: () => _snack('Audio - coming soon'),
              child: Container(
                height: 36,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.add, size: 16),
                  SizedBox(width: 6),
                  Text('Add audio', style: TextStyle(fontSize: 13)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (var i = 0; i < _texts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onLongPress: () => setState(() => _texts.removeAt(i)),
                      child: Chip(
                        label: Text(_texts[i].text,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Add text'),
                  onPressed: _addText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 78,
        height: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    return Container(
      color: const Color(0xFF121212),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _tool(Icons.content_cut, 'Edit', _editSheet),
          _tool(Icons.music_note_outlined, 'Audio',
              () => _snack('Audio - coming soon')),
          _tool(Icons.text_fields, 'Text', _addText),
          _tool(Icons.star_border, 'Effects',
              () => _snack('Effects - coming soon')),
          _tool(Icons.layers_outlined, 'Overlay',
              () => _snack('Overlay - coming soon')),
          _tool(Icons.closed_caption_outlined, 'Captions',
              () => _snack('Captions - coming soon')),
          _tool(Icons.filter_vintage_outlined, 'Filters', _filterSheet),
        ]),
      ),
    );
  }
}
