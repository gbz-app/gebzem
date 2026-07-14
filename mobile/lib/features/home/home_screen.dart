import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/api.dart';
import '../auth/auth_provider.dart';
import '../auth/permissions_screen.dart';
import '../calls/calls_tab.dart';
import '../chats/chats_screen.dart';

/// Ana kabuk: 5 sekmeli alt menu (ozellik-listesi.md'deki yapi)
/// Sohbetler aktif; Aramalar/Odalar/Canli sonraki fazlarda doluyor
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;
  bool? _permissionsAsked; // null = kontrol ediliyor

  static const _titles = ['Gebzem', 'Aramalar', 'Odalar', 'Canli', 'Profil'];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // "Sordum mu" isaretine DEGIL gercek izin durumuna bak: APK ustune guncellenince
    // SharedPreferences silinmedigi icin eski flag kaliyor ve izin ekrani bir daha
    // gelmiyordu. Izinlerden biri eksikse (ve kullanici "bir daha sorma" DEMEDIYSE)
    // izin ekranini goster; hepsi verilince gec.
    final mic = await Permission.microphone.status;
    final cam = await Permission.camera.status;
    final notif = await Permission.notification.status;
    final tamam = mic.isGranted && cam.isGranted && notif.isGranted;
    final kaliciRed = mic.isPermanentlyDenied ||
        cam.isPermanentlyDenied ||
        notif.isPermanentlyDenied;
    if (mounted) {
      setState(() => _permissionsAsked = tamam || kaliciRed);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ilk giriste izin ekrani (mikrofon, kamera, bildirim)
    if (_permissionsAsked == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_permissionsAsked == false) {
      return PermissionsScreen(
        onDone: () => setState(() => _permissionsAsked = true),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_index == 0)
            IconButton(icon: const Icon(LucideIcons.search), onPressed: () {
              // TODO Faz 1 sonu: sohbet arama
            }),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          ChatsScreen(),
          CallsTab(),
          _PhasePlaceholder(icon: LucideIcons.audioLines, text: 'Sesli odalar\nFaz 4\'te geliyor'),
          _PhasePlaceholder(icon: LucideIcons.radioTower, text: 'Canli yayinlar\nFaz 4\'te geliyor'),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(LucideIcons.messageCircle), label: 'Sohbetler'),
          NavigationDestination(icon: Icon(LucideIcons.phone), label: 'Aramalar'),
          NavigationDestination(icon: Icon(LucideIcons.audioLines), label: 'Odalar'),
          NavigationDestination(icon: Icon(LucideIcons.radioTower), label: 'Canli'),
          NavigationDestination(icon: Icon(LucideIcons.user), label: 'Profil'),
        ],
      ),
    );
  }
}

class _PhasePlaceholder extends StatelessWidget {
  const _PhasePlaceholder({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(text,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }
}

/// Kendi profilim (API'den)
final myProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ref.read(apiProvider).get('/users/me');
  return (res.data as Map).cast<String, dynamic>();
});

/// Faz 1 profil sekmesi: bilgiler + cikis (tam duzenleme Faz 2'de)
class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        CircleAvatar(
          radius: 48,
          child: Icon(LucideIcons.user, size: 48, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(height: 12),
        profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const SizedBox.shrink(),
          data: (p) => Column(
            children: [
              Text(p['name'] as String? ?? '',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              Text('@${p['username'] ?? ''}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(p['phone'] as String? ?? '',
                  style: TextStyle(color: scheme.outline, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const ListTile(
          leading: Icon(LucideIcons.circleUser),
          title: Text('Profil duzenleme'),
          subtitle: Text('Faz 2\'de geliyor'),
        ),
        ListTile(
          leading: const Icon(LucideIcons.coins),
          title: const Text('Jeton bakiyem'),
          subtitle: Text(profile.valueOrNull != null
              ? '${profile.valueOrNull!['coin_balance'] ?? 0} jeton'
              : '...'),
        ),
        const Divider(),
        ListTile(
          leading: Icon(LucideIcons.logOut, color: scheme.error),
          title: Text('Cikis yap', style: TextStyle(color: scheme.error)),
          onTap: () => ref.read(authProvider.notifier).logout(),
        ),
      ],
    );
  }
}
