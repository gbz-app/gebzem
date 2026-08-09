import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/api.dart';
import '../auth/auth_provider.dart';
import '../medya/medya_gorsel.dart';
import 'engellenenler.dart';
import 'profil_duzenle.dart';
import '../auth/permissions_screen.dart';
import '../calls/calls_tab.dart';
import '../chats/chats_provider.dart';
import '../chats/chats_screen.dart';
import '../ilan/ilan_ekranlari.dart';
import '../isletme/isletme_duzenle.dart';
import '../live/live_tab.dart';
import '../rooms/rooms_tab.dart';
import '../sosyal/akis_ekrani.dart';
import '../sosyal/bildirimler_sayfasi.dart';
import '../sosyal/kesfet_ekrani.dart';
import '../sosyal/profil_sayfasi.dart';
import '../sosyal/reels_sayfasi.dart';
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

  // ⚠️⚠️ TURU 76 — SEKME DUZENI YENIDEN KURULDU (kullanici emri: "alt menude
  //    arama olmali: anasayfa, arama, mesaj, profil, reels, canli yayin").
  //
  //    ESKI: Akis · Sohbet · Arama(CAGRI) · Oda · Canli · Profil
  //    YENI: Anasayfa · Ara(PROFIL ARAMA) · Reels · Mesaj · Canli · Profil
  //
  // ⚠️ "ARAMA" KELIME CAKISMASI: kullanici "aramadan kastim normal profil
  //    arama instagram gibi" dedi. Alt menudeki `Ara` artik SOSYAL ARAMA.
  //    CAGRI GECMISI SILINMEDI — `Mesaj` sekmesinin ustundeki segmente tasindi.
  // ⚠️ SESLI ODALAR da SILINMEDI — `Canli` sekmesinin segmentine tasindi.
  //    ⚠️ YAPMA: bu iki ekrani kaldirma; ikisi de calisir durumda ve
  //       `mesgulMu` muhafizlari (`oda_` / `yayin_`) onlara bagli.
  // ⚠️ YAPMA: 7. sekme ekleme — 360dp ekranda hedef basina ~60dp duser,
  //    etiketler kirpilir.
  static const _titles = [
    'Anasayfa',
    'Ara',
    'Reels',
    'Mesaj',
    'Canlı',
    'Profil',
  ];

  // ⚠️ Sekme indeksleri SABIT olarak yazilir — build icinde ciplak sayi
  //    kullanmak, sira degisince sessizce yanlis ekran acar.
  static const _akis = 0;
  static const _ara = 1;
  static const _reels = 2;

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
    final kaliciRed =
        mic.isPermanentlyDenied ||
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
      // ⚠️ AKIS, ARA ve REELS KENDI ust duzenlerini cizer — ust AppBar OLMAZ.
      //    Akista bolme secici + bildirim ikonu kendi seridinde; ARA'da ustte
      //    zaten arama kutusu var ("Ara" baslikli bir cubuk hem gereksiz yer
      //    kaplar hem Instagram deseninden sapar); reels tam ekran video.
      // ⚠️ AppBar'i olmayan sekmeler KENDI `SafeArea`sini koymak ZORUNDA
      //    (yoksa icerik durum cubugunun ALTINA girer).
      appBar: (_index == _akis || _index == _ara || _index == _reels)
          ? null
          // ⚠️⚠️ TURU 76b — AppBar'DAKI "+" KALDIRILDI (kullanici bulgusu:
          //    "grup olusturma nerede?").
          //    Ekranda IKI TANE "+" vardi ve FARKLI IS YAPIYORLARDI:
          //      · ust (AppBar) "+"  -> DOGRUDAN kisi arama, grup secenegi YOK
          //      · alt (FAB)    "+"  -> secenek sheet'i: "Yeni sohbet | Yeni grup"
          //    Ust "+" hem daha once eklenmisti hem daha gorunurdu; kullanici
          //    ona basip "grup olusturma yok" sonucuna vardi. Yani ozellik
          //    KODDA VARDI ama ULASILAMIYORDU — bu projenin tekrar eden
          //    "olu dogmus ozellik" sinifinin arayuz karsiligi.
          // ⚠️ TEK GIRIS: FAB (`chats_screen._yeniSecenek`). Iki giris noktasi
          //    KACINILMAZ OLARAK DRIFT EDER (turu 72b/H dersi).
          // ⚠️ YAPMA: buraya tekrar "+" ekleme; yeni bir sohbet eylemi
          //    gerekiyorsa `_yeniSecenek` sheet'ine madde ekle.
          : AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: [
          const AkisEkrani(), // TURU 75 — ana sayfa akisi
          const KesfetEkrani(), // TURU 76 — PROFIL ARAMA + kesfet izgarasi
          // ⚠️⚠️ REELS **YALNIZ SEKME ACIKKEN KURULUR** — bu bir SES GUVENLIGI
          //    karari, stil tercihi degil. `IndexedStack` TUM cocuklari agacta
          //    CANLI tutar; reels sekmesinden ciksaydik video oynaticisi
          //    yasamaya devam eder ve SES ARKA PLANDA CALMAYA DEVAM EDERDI.
          //    iOS'ta ses oturumu PROSES GENELINDE TEK nesnedir ve bu projede
          //    tam bu yuzden turu 64/65/73'te aramalar defalarca sagirlasti.
          //    Sekmeden cikinca widget DISPOSE olur -> oynatici KESIN olur.
          // ⚠️ YAPMA: burayi kosulsuz `ReelsSayfasi()` yapma.
          // ⚠️ Bedeli: sekmeye her donuste reels bastan yuklenir (Instagram da
          //    boyle davranir) — kabul edilen bir bedel.
          _index == _reels ? const ReelsSayfasi() : const SizedBox.shrink(),
          const _MesajSekmesi(), // sohbetler + CAGRI GECMISI segmenti
          const _CanliSekmesi(), // canli yayinlar + SESLI ODALAR segmenti
          const _ProfileTab(),
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
          destinations: [
            const NavigationDestination(
              icon: Icon(LucideIcons.house),
              label: 'Anasayfa',
            ),
            const NavigationDestination(
              icon: Icon(LucideIcons.search),
              label: 'Ara',
            ),
            const NavigationDestination(
              icon: Icon(LucideIcons.clapperboard),
              label: 'Reels',
            ),
            // ⚠️ OKUNMAMIS ROZETI: mesaj sekmesi artik alt menude ve kullanici
            //    surekli akista/reels'te olacagi icin rozet OLMADAN yeni mesaji
            //    HIC fark etmezdi (kullanicinin 1 numarali sikayeti "mesajlar
            //    ve bildirimler anlik gelmiyor" — gorunurluk bunun parcasi).
            NavigationDestination(
              icon: _RozetliIkon(
                ikon: LucideIcons.messageCircle,
                sayi:
                    ref
                        .watch(chatsProvider)
                        .valueOrNull
                        ?.where((c) => !c.archived)
                        .fold<int>(0, (a, c) => a + c.unread) ??
                    0,
              ),
              label: 'Mesaj',
            ),
            const NavigationDestination(
              icon: Icon(LucideIcons.radioTower),
              label: 'Canlı',
            ),
            const NavigationDestination(
              icon: Icon(LucideIcons.user),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

/// Alt menu ikonu + sag-ust kirmizi sayac.
/// ⚠️ 99+ tavani: uc haneli sayi hedefin genisligini tasirir.
class _RozetliIkon extends StatelessWidget {
  const _RozetliIkon({required this.ikon, required this.sayi});

  final IconData ikon;
  final int sayi;

  @override
  Widget build(BuildContext context) {
    if (sayi <= 0) return Icon(ikon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(ikon),
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 17),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              sayi > 99 ? '99+' : '$sayi',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ⚠️ TURU 76 — MESAJ SEKMESI: sohbetler + CAGRI GECMISI.
///
/// Cagri gecmisi alt menuden cikarildi ama SILINMEDI; buraya segment olarak
/// tasindi (WhatsApp'ta da aramalar mesajlarin yanindaki sekmededir).
/// ⚠️ YAPMA: `CallsTab`i kaldirma — arama gecmisi + "geri ara" akisi orada.
class _MesajSekmesi extends StatefulWidget {
  const _MesajSekmesi();

  @override
  State<_MesajSekmesi> createState() => _MesajSekmesiState();
}

class _MesajSekmesiState extends State<_MesajSekmesi> {
  int _alt = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Sohbetler')),
            ButtonSegment(value: 1, label: Text('Aramalar')),
          ],
          selected: {_alt},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _alt = s.first),
        ),
      ),
      // ⚠️ IndexedStack: sekme degistirince ChatsScreen'in WS dinleyicisi ve
      //    arama/filtre durumu KAYBOLMASIN.
      Expanded(
        child: IndexedStack(
          index: _alt,
          children: const [ChatsScreen(), CallsTab()],
        ),
      ),
    ],
  );
}

/// ⚠️ TURU 76 — CANLI SEKMESI: canli yayinlar + SESLI ODALAR.
/// ⚠️ YAPMA: `RoomsTab`i kaldirma — sesli oda (Spaces) akisi orada.
class _CanliSekmesi extends StatefulWidget {
  const _CanliSekmesi();

  @override
  State<_CanliSekmesi> createState() => _CanliSekmesiState();
}

class _CanliSekmesiState extends State<_CanliSekmesi> {
  int _alt = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Canlı yayınlar')),
            ButtonSegment(value: 1, label: Text('Sesli odalar')),
          ],
          selected: {_alt},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _alt = s.first),
        ),
      ),
      Expanded(
        child: IndexedStack(
          index: _alt,
          children: const [LiveTab(), RoomsTab()],
        ),
      ),
    ],
  );
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
              Text(
                p['name'] as String? ?? '',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '@${p['username'] ?? ''}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                p['phone'] as String? ?? '',
                style: TextStyle(color: scheme.outline, fontSize: 13),
              ),
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
            MaterialPageRoute(builder: (_) => const ProfilDuzenleEkrani()),
          ),
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
              MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: id)),
            );
          },
        ),
        // ⚠️⚠️ TURU 77 — ISLETME HESABI GIRISI (kullanici emri: "normal ve
        //    isletme profilleri olacak"). Bu projede "kod var ama hicbir
        //    dugmeye bagli degil" hatasi BES kez yasandi; giris noktasi
        //    ozelligin YAZILDIGI turda eklendi.
        ListTile(
          leading: const Icon(LucideIcons.store),
          title: Text(
            (profile.valueOrNull?['hesap_turu'] ?? '') == 'isletme'
                ? 'İşletme bilgilerim'
                : 'İşletme hesabı',
          ),
          subtitle: const Text('Kategori, adres, çalışma saatleri, menü'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const IsletmeDuzenleEkrani()),
            );
            ref.invalidate(myProfileProvider);
          },
        ),
        // ⚠️ ILANLARIM: ilan verme akisinin ikinci giris noktasi (birincisi
        //    hamburger menudeki "Ilanlar" karti).
        ListTile(
          leading: const Icon(LucideIcons.tag),
          title: const Text('İlanlarım'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const IlanListesiEkrani())),
        ),
        ListTile(
          leading: const Icon(LucideIcons.bell),
          title: const Text('Bildirimler'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const BildirimlerSayfasi())),
        ),
        ListTile(
          leading: const Icon(LucideIcons.userRoundCheck),
          title: const Text('Takip istekleri'),
          subtitle: const Text('Gizli hesapsan onay bekleyenler'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const TakipIstekleri())),
        ),
        ListTile(
          leading: const Icon(LucideIcons.ban),
          title: const Text('Engellenen kişiler'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EngellenenlerEkrani()),
          ),
        ),
        ListTile(
          leading: const Icon(LucideIcons.coins),
          title: const Text('Jeton bakiyem'),
          subtitle: Text(
            profile.valueOrNull != null
                ? '${profile.valueOrNull!['coin_balance'] ?? 0} jeton'
                : '...',
          ),
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
