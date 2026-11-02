import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoEditorPage extends StatefulWidget {
  const PhotoEditorPage({super.key});
  @override
  State<PhotoEditorPage> createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends State<PhotoEditorPage> {
  File? _image;
  double _brightness = 0, _contrast = 1, _saturation = 1;
  int _turns = 0, _filter = 0;

  static const _filters = <String, List<double>>{
    'Normal': [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0],
    'B&W': [0.33,0.59,0.11,0,0, 0.33,0.59,0.11,0,0, 0.33,0.59,0.11,0,0, 0,0,0,1,0],
    'Warm': [1.1,0,0,0,10, 0,1,0,0,0, 0,0,0.9,0,-10, 0,0,0,1,0],
    'Cool': [0.9,0,0,0,-10, 0,1,0,0,0, 0,0,1.1,0,10, 0,0,0,1,0],
    'Vintage': [0.393,0.769,0.189,0,0, 0.349,0.686,0.168,0,0, 0.272,0.534,0.131,0,0, 0,0,0,1,0],
  };

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _image = File(x.path));
  }

  List<double> _sat(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    return [
      r*(1-s)+s, g*(1-s), b*(1-s), 0, 0,
      r*(1-s), g*(1-s)+s, b*(1-s), 0, 0,
      r*(1-s), g*(1-s), b*(1-s)+s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _cb(double c, double br) {
    final o = 128 * (1 - c) + br * 255;
    return [c,0,0,0,o, 0,c,0,0,o, 0,0,c,0,o, 0,0,0,1,0];
  }

  Widget _slider(String label, double v, double min, double max,
      ValueChanged<double> f) {
    return Row(children: [
      SizedBox(width: 90, child: Text(label)),
      Expanded(child: Slider(value: v, min: min, max: max, onChanged: f)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final names = _filters.keys.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Editor'),
        actions: [
          IconButton(icon: const Icon(Icons.photo_library), onPressed: _pick),
          IconButton(
            icon: const Icon(Icons.rotate_right),
            onPressed: () => setState(() => _turns++),
          ),
        ],
      ),
      body: _image == null
          ? Center(
              child: ElevatedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Photo එකක් තෝරන්න'),
              ),
            )
          : Column(children: [
              Expanded(
                child: Center(
                  child: RotatedBox(
                    quarterTurns: _turns,
                    child: ColorFiltered(
                      colorFilter:
                          ColorFilter.matrix(_cb(_contrast, _brightness)),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(_sat(_saturation)),
                        child: ColorFiltered(
                          colorFilter:
                              ColorFilter.matrix(_filters[names[_filter]]!),
                          child: Image.file(_image!),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: names.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(names[i]),
                      selected: _filter == i,
                      onSelected: (_) => setState(() => _filter = i),
                    ),
                  ),
                ),
              ),
              _slider('Brightness', _brightness, -0.5, 0.5,
                  (v) => setState(() => _brightness = v)),
              _slider('Contrast', _contrast, 0.5, 1.5,
                  (v) => setState(() => _contrast = v)),
              _slider('Saturation', _saturation, 0, 2,
                  (v) => setState(() => _saturation = v)),
              const SizedBox(height: 12),
            ]),
    );
  }
}
