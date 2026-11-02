import 'package:flutter/material.dart';
import 'photo_editor.dart';
import 'video_editor.dart';

void main() => runApp(const ClipNovaApp());

class ClipNovaApp extends StatelessWidget {
  const ClipNovaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClipNova',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
            primary: Colors.black, surface: Colors.white),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
            primary: Colors.white, surface: Colors.black),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  static const _titles = ['Edit', 'Templates', 'AI Lab', 'Library', 'Me'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tab == 0
          ? const HomeTab()
          : Center(child: Text('${_titles[_tab]} - coming soon')),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.content_cut), label: 'Edit'),
          NavigationDestination(
              icon: Icon(Icons.view_carousel_outlined), label: 'Templates'),
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined), label: 'AI Lab'),
          NavigationDestination(
              icon: Icon(Icons.folder_outlined), label: 'Library'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Me'),
        ],
      ),
    );
  }
}

class _Tool {
  final IconData icon;
  final String label;
  final bool opensPhoto;
  const _Tool(this.icon, this.label, {this.opensPhoto = false});
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  static const _tools = <_Tool>[
    _Tool(Icons.movie_filter_outlined, 'AutoCut'),
    _Tool(Icons.face_retouching_natural, 'Retouch', opensPhoto: true),
    _Tool(Icons.auto_awesome_outlined, 'AI generator'),
    _Tool(Icons.photo_library_outlined, 'Photo tools', opensPhoto: true),
    _Tool(Icons.videocam_outlined, 'Shoot and record'),
    _Tool(Icons.auto_fix_high, 'Auto enhance', opensPhoto: true),
    _Tool(Icons.crop_original, 'Cover maker'),
    _Tool(Icons.closed_caption_outlined, 'Auto captions'),
    _Tool(Icons.person_remove_outlined, 'Remove background'),
    _Tool(Icons.add_photo_alternate_outlined, 'AI photo editor',
        opensPhoto: true),
    _Tool(Icons.cloud_outlined, 'Space'),
    _Tool(Icons.storefront_outlined, 'Marketing tools'),
  ];

  void _soon(BuildContext context, String name) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$name - coming soon')));
  }

  void _openPhoto(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const PhotoEditorPage()));
  }

  void _openVideo(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const VideoEditorPage()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F5);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          Row(
            children: [
              const Text('ClipNova',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _soon(context, 'Search'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Video create',
              style: TextStyle(fontSize: 15, color: Colors.grey)),
          const SizedBox(height: 4),
          const Text('Get started',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _bigCard(
                  icon: Icons.add,
                  label: 'New video',
                  bg: cs.primary,
                  fg: cs.surface,
                  onTap: () => _openVideo(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _bigCard(
                  icon: Icons.image_outlined,
                  label: 'Edit photo',
                  bg: grey,
                  fg: cs.primary,
                  onTap: () => _openPhoto(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.0,
            children: _tools.map((t) {
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () =>
                    t.opensPhoto ? _openPhoto(context) : _soon(context, t.label),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t.icon, size: 32),
                    const SizedBox(height: 10),
                    Text(t.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _bigCard({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: fg),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
  }
}
