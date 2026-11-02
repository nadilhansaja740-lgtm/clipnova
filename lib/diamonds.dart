import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Diamonds extends ChangeNotifier {
  Diamonds._();
  static final Diamonds I = Diamonds._();

  // දවසකට බලන්න පුළුවන් ads ගාණ
  static const int maxAdsPerDay = 5;

  int count = 0;
  int adsToday = 0;

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    count = p.getInt('diamonds') ?? 0;
    if (p.getString('ads_day') == _today()) {
      adsToday = p.getInt('ads_today') ?? 0;
    } else {
      adsToday = 0;
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('diamonds', count);
    await p.setInt('ads_today', adsToday);
    await p.setString('ads_day', _today());
  }

  bool get canWatchAd => adsToday < maxAdsPerDay;

  Future<void> reward() async {
    count += 1;
    adsToday += 1;
    await _save();
    notifyListeners();
  }

  Future<bool> spend(int n) async {
    if (count < n) return false;
    count -= n;
    await _save();
    notifyListeners();
    return true;
  }
}

class _AdDialog extends StatefulWidget {
  const _AdDialog();
  @override
  State<_AdDialog> createState() => _AdDialogState();
}

class _AdDialogState extends State<_AdDialog> {
  int _left = 5;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left > 0) setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ad (test)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(60),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Test ad'),
          ),
          const SizedBox(height: 12),
          Text(_left > 0 ? 'තත්පර $_left ක් ඉන්න...' : 'ඉවරයි!'),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close')),
        if (_left <= 0)
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('+1 💎 ගන්න')),
      ],
    );
  }
}

/// Test rewarded ad. පස්සේ මේක real AdMob ad එකකින් replace කරනවා.
Future<bool> showRewardedAd(BuildContext context) async {
  if (!Diamonds.I.canWatchAd) return false;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AdDialog(),
  );
  if (ok == true) {
    await Diamonds.I.reward();
    return true;
  }
  return false;
}
