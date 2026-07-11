import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
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

  static const _titles = ['Gebzem', 'Aramalar', 'Odalar', 'Canli', 'Profil'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_index == 0)
            IconButton(icon: const Icon(Icons.search), onPressed: () {
              // TODO Faz 1 sonu: sohbet arama
            }),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          ChatsScreen(),
          _PhasePlaceholder(icon: Icons.call, text: 'Sesli ve goruntulu aramalar\nFaz 3\'te geliyor'),
          _PhasePlaceholder(icon: Icons.spatial_audio_off, text: 'Sesli odalar\nFaz 4\'te geliyor'),
          _PhasePlaceholder(icon: Icons.live_tv, text: 'Canli yayinlar\nFaz 4\'te geliyor'),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Sohbetler'),
          NavigationDestination(icon: Icon(Icons.call_outlined), selectedIcon: Icon(Icons.call), label: 'Aramalar'),
          NavigationDestination(icon: Icon(Icons.spatial_audio_off_outlined), selectedIcon: Icon(Icons.spatial_audio_off), label: 'Odalar'),
          NavigationDestination(icon: Icon(Icons.live_tv_outlined), selectedIcon: Icon(Icons.live_tv), label: 'Canli'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
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

/// Faz 1 profil sekmesi: bilgiler + cikis (tam ekran Faz 2'de)
class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        CircleAvatar(
          radius: 48,
          child: Icon(Icons.person, size: 48, color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        const SizedBox(height: 24),
        const ListTile(
          leading: Icon(Icons.badge_outlined),
          title: Text('Profil duzenleme'),
          subtitle: Text('Faz 2\'de geliyor'),
        ),
        const ListTile(
          leading: Icon(Icons.toll_outlined),
          title: Text('Jeton bakiyem'),
          subtitle: Text('Kayit bonusu: 100 jeton'),
        ),
        const Divider(),
        ListTile(
          leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
          title: Text('Cikis yap', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          onTap: () => ref.read(authProvider.notifier).logout(),
        ),
      ],
    );
  }
}
