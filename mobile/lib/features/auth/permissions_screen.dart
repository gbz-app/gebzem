import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Giriste izin ekrani — mikrofon, kamera ve bildirim izinleri tek seferde alinir.
/// Bir kez gosterilir (tercih kaydedilir), sonra ana ekrana gecilir.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  bool _busy = false;

  Future<void> _requestAll() async {
    setState(() => _busy = true);
    // Sirayla iste — sistem pencereleri ust uste binmesin
    await Permission.notification.request();
    await Permission.microphone.request();
    await Permission.camera.request();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_asked', true);

    if (mounted) {
      setState(() => _busy = false);
      widget.onDone();
    }
  }

  Future<void> _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_asked', true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Icon(LucideIcons.shieldCheck, size: 64, color: scheme.primary),
              const SizedBox(height: 20),
              Text('Gebzem\'e hos geldin',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'Uygulamanin duzgun calismasi icin birkac izin gerekiyor',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.outline),
              ),
              const SizedBox(height: 36),
              _permRow(
                icon: LucideIcons.bell,
                title: 'Bildirimler',
                subtitle: 'Yeni mesaj ve aramalardan haberdar ol',
                scheme: scheme,
              ),
              _permRow(
                icon: LucideIcons.mic,
                title: 'Mikrofon',
                subtitle: 'Sesli aramalar ve sesli mesajlar icin',
                scheme: scheme,
              ),
              _permRow(
                icon: LucideIcons.video,
                title: 'Kamera',
                subtitle: 'Goruntulu aramalar ve fotograf icin',
                scheme: scheme,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _requestAll,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Izin Ver ve Devam Et'),
              ),
              TextButton(
                onPressed: _busy ? null : _skip,
                child: Text('Simdilik atla', style: TextStyle(color: scheme.outline)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme scheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(subtitle, style: TextStyle(color: scheme.outline, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
