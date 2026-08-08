import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/api.dart';
import '../auth/auth_provider.dart';
import '../medya/medya_gorsel.dart';
import 'engellenenler.dart';
import 'profil_duzenle.dart';
import '../auth/permissions_screen.dart';
import '../calls/calls_tab.dart';
import '../chats/chats_screen.dart';
import '../live/live_tab.dart';
import '../rooms/rooms_tab.dart';
import '../sosyal/akis_ekrani.dart';
import '../sosyal/bildirimler_sayfasi.dart';
import '../sosyal/profil_sayfasi.dart';
import '../sosyal/takip_listesi.dart';

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

  // ⚠️ TURU 75 — 6 SEKME. Akis EN BASA konuldu (ana sayfa = akis; Instagram/
  //    Facebook deseni). Etiketler KISALTILDI: 6 hedefli NavigationBar'da
  //    360dp genislikte hedef basina ~60dp duser; "Sohbetler" (9 karakter)
  //    tasip kirpilirdi.
  // ⚠️ YAPMA: 7. sekme ekleme — etiketler okunmaz hale gelir.
  // ⚠️ YAPMA: sirayi degistirme; _index sabitleri (0=akis, 1=sohbet) ustune
  //    yazilmis kosullar var (AppBar gizleme, "yeni sohbet" dugmesi).
  static const _titles = ['Akış', 'Sohbetler', 'Aramalar', 'Odalar', 'Canlı', 'Profil'];

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
      // ⚠️ AKIS SEKMESI KENDI AppBar'INI CIZER (Reels + bildirim ikonlari orada).
      //    Burada da AppBar cizersek CIFT BASLIK olur.
      appBar: _index == 0
          ? null
          : AppBar(
              title: Text(_titles[_index]),
              actions: [
                // Sohbetler sekmesi: sag-ust + -> yeni sohbet (kisi ara).
                // Sohbet FILTRESI ChatsScreen icindeki arama kutusunda.
                if (_index == 1)
                  IconButton(
                    icon: const Icon(LucideIcons.plus),
                    tooltip: 'Yeni sohbet',
                    onPressed: () => context.push('/search'),
                  ),
              ],
            ),
      body: IndexedStack(
        index: _index,
        children: const [
          AkisEkrani(), // TURU 75 — ana sayfa akisi (gonderi + reels girisi)
          ChatsScreen(),
          CallsTab(),
          RoomsTab(), // SPACES (sesli oda) — kesfet + oda ac
          LiveTab(), // CANLI YAYIN — kesfet + yayin baslat
          _ProfileTab(),
        ],
      ),
      // ALT MENU sol/sag (ust kose) RADIUS (test turu 7): icerik zeminine karsi yuvarlak kose.
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          // ⚠️ Etiketler KISA (6 hedef) — bkz. _titles serhi.
          destinations: const [
            NavigationDestination(icon: Icon(LucideIcons.house), label: 'Akış'),
            NavigationDestination(icon: Icon(LucideIcons.messageCircle), label: 'Sohbet'),
            NavigationDestination(icon: Icon(LucideIcons.phone), label: 'Arama'),
            NavigationDestination(icon: Icon(LucideIcons.audioLines), label: 'Oda'),
            NavigationDestination(icon: Icon(LucideIcons.radioTower), label: 'Canlı'),
            NavigationDestination(icon: Icon(LucideIcons.user), label: 'Profil'),
          ],
        ),
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
        // TURU 74: gerçek profil fotoğrafı (varsa R2'den imzalı adresle).
        Center(
          child: Avatar(
            ad: (profile.valueOrNull?['name'] as String?) ?? '',
            mediaId: profile.valueOrNull?['avatar_media_id'] as String?,
            avatarUrl: (profile.valueOrNull?['avatar_url'] as String?) ?? '',
            cap: 96,
          ),
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
        ListTile(
          leading: const Icon(LucideIcons.circleUser),
          title: const Text('Profili düzenle'),
          subtitle: const Text('Ad, fotoğraf, hakkımda'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilDuzenleEkrani())),
        ),
        // ⚠️ TURU 74 — ENGELLENENLER. App Store 1.2 (UGC) engellemeyi şart koşuyor;
        //    engellemek kadar engeli GÖREBİLMEK ve KALDIRABİLMEK de gerekli
        //    (sohbet ekranına girmeden).
        // ⚠️ TURU 75 — KENDI SOSYAL PROFILIM. Kullanici kendi gonderilerini,
        //    takipci/takip sayilarini ve gizlilik ayarini BURADAN gorur.
        ListTile(
          leading: const Icon(LucideIcons.grid3x3),
          title: const Text('Gönderilerim ve profilim'),
          subtitle: const Text('Takipçiler, takip edilenler, paylaşımlar'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () {
            final id = (profile.valueOrNull?['id'] ?? '').toString();
            if (id.isEmpty) return;
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: id)));
          },
        ),
        ListTile(
          leading: const Icon(LucideIcons.bell),
          title: const Text('Bildirimler'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BildirimlerSayfasi())),
        ),
        ListTile(
          leading: const Icon(LucideIcons.userRoundCheck),
          title: const Text('Takip istekleri'),
          subtitle: const Text('Gizli hesapsan onay bekleyenler'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TakipIstekleri())),
        ),
        ListTile(
          leading: const Icon(LucideIcons.ban),
          title: const Text('Engellenen kişiler'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EngellenenlerEkrani())),
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
          title: Text('Çıkış yap', style: TextStyle(color: scheme.error)),
          onTap: () => ref.read(authProvider.notifier).logout(),
        ),
      ],
    );
  }
}
