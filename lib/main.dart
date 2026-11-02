import 'package:flutter/material.dart';

void main() => runApp(const ClipNovaApp());

class ClipNovaApp extends StatelessWidget {
  const ClipNovaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClipNova',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D12),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text('ClipNova',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const Text('Edit like a pro',
                  style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 32),
              Row(children: [
                Expanded(child: _card(context, Icons.video_library, 'Video Editor')),
                const SizedBox(width: 16),
                Expanded(child: _card(context, Icons.photo, 'Photo Editor')),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, IconData icon, String label) {
    return InkWell(
      onTap: () => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$label - coming soon'))),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: const Color(0xFF7C4DFF)),
            const SizedBox(height: 12),
            Text(label),
          ],
        ),
      ),
    );
  }
}
