import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../auth/auth_provider.dart';
import '../medya/medya_gorsel.dart';
import 'engellenenler.dart';
import 'profil_duzenle.dart';
import '../calls/calls_tab.dart';
// ⚠️ `chats_provider` importu TURU 96m'de KALDIRILDI: okunmamis rozeti sayaci
//    96l'de `alt_menu.dart`a tasindi, import geride kalmisti (olu bagimlilik).
import '../chats/chats_screen.dart';
import '../ilan/ilan_ekranlari.dart';
import '../randevu/randevu_listeleri.dart';
import '../isletme/isletme_duzenle.dart';
import '../live/live_tab.dart';
import '../rooms/rooms_tab.dart';
import '../sosyal/akis_ekrani.dart';
import '../sosyal/bildirimler_sayfasi.dart';
import '../sosyal/kesfet_ekrani.dart';
import '../sosyal/profil_sayfasi.dart';
import '../sosyal/reels_sayfasi.dart';
import '../sosyal/takip_listesi.dart';
import 'alt_menu.dart';
import 'ayarlar_ekrani.dart';
import '../diyet/diyet_ekranlari.dart';
import '../diyet/danisan_ekranlari.dart';
import '../ilan/basvuru_ekranlari.dart';

/// Ana kabuk: 5 sekmeli alt menu (ozellik-listesi.md'deki yapi)
/// Sohbetler aktif; Aramalar/Odalar/Canli sonraki fazlarda doluyor
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// ⚠️⚠️⚠️ TURU 77b — AKTIF SEKME **KURESEL** OLARAK YAYINLANIR.
///
/// **NEDEN (denetim bulgusu — SEVK ENGELIYDI):** akistaki videolar
/// `IndexedStack` icinde yasar ve `IndexedStack` secili OLMAYAN cocuklari da
/// **agacta canli + LAYOUT EDILMIS** tutar (`Visibility.maintain`). Sonuc:
///   · Mesaj/Canli/Profil sekmesine gecince akistaki video OYNAMAYA DEVAM
///     ediyordu — arka planda MOBIL VERI harciyor ve ses donanimini tutuyordu,
///   · `gorunurluk.dart` gozcusu YALNIZ kaydirma olayinda olctugu icin
///     `_gorunurOran` BAYAT kaliyordu; ustelik `IndexedStack` tum cocuklari
///     AYNI konuma yerlestirdigi icin olcum eklemek TEK BASINA da COZMEZDI.
/// CLAUDE.md'deki "IndexedStack TUM cocuklari canli tutar — reels sekmesi bu
/// yuzden KOSULLU kuruldu" dersi akis videolarina uygulanmamisti.
///
/// ⚠️ `ValueNotifier` secildi (provider degil): `GonderiKarti` her karede
///    okuyor; Riverpod dinleyicisi eklemek her kart icin ayri abonelik demekti.
/// ⚠️ YAPMA: bunu kaldirip autoplay kapisini yalniz gorunurluge baglama.
final aktifSekme = ValueNotifier<int>(0);

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  /// ⚠️⚠️⚠️ TURU 96l — SEKME DURUMU **`aktifSekme`DEN DE** OKUNUR.
  ///
  ///	Kategori ekrani (`IsletmeListesiEkrani`) bu ekranin USTUNE push
  ///	edilmis bir route'tur ve artik alt menuyu o da ciziyor. Oradan bir
  ///	sekmeye dokunuldugunda `aktifSekme` yazilip route kapatiliyor;
  ///	`HomeScreen` bunu dinlemeseydi kullanici KAPANAN ekrandan ESKI
  ///	sekmeye donerdi ve dokundugu yer hicbir sey yapmamis gorunurdu.
  /// ⚠️ Ayri bir "sekme sec" kanali ACILMADI: `aktifSekme` zaten sekme
  ///    durumunu tasiyor (akis videolarinin ses guvenligi kapisi ona
  ///    bakiyor). Ikinci bir kaynak kacinilmaz olarak ayrisirdi.
  /// ⚠️ Esitlik kapisi ZORUNLU: menuden secimde `_index` ve `aktifSekme`
  ///    BIRLIKTE yaziliyor; kapi olmasaydi her dokunusta ikinci bir
  ///    gereksiz `setState` kosardi.
  void _sekmeSenkron() {
    if (mounted && _index != aktifSekme.value) {
      setState(() => _index = aktifSekme.value);
    }
  }

  @override
  void initState() {
    super.initState();
    aktifSekme.addListener(_sekmeSenkron);
  }

  @override
  void dispose() {
    aktifSekme.removeListener(_sekmeSenkron);
    super.dispose();
  }

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

  /// TURU 89 — IZIN EKRANI KALDIRILDI, IZINLER ONBOARDINGTE ALINIYOR.
  ///
  ///	Kullanici emri: *"sana onboardingde izin al demistim, o izin ekrani
  ///	icin AYRI SAYFAYI KALDIR, onboardingte sirayla gecerken izin
  ///	alinsin"*.
  ///
  /// Bu ekranin ONUNDEKI tam sayfa izin kapisi ARTIK YOK. Onboarding
  /// (uygulamanin ILK acilisi, oturumdan ONCE) her sayfasinda ilgili izni
  /// istiyor; PermissionsScreen SILINDI.
  ///
  /// ⚠️ KURTARMA YOLU **Ayarlar > IZINLER**e tasindi: onboarding bayragi
  ///    KALICI oldugu icin, izinleri reddeden kullanicinin baska donus yolu
  ///    kalmazdi (uygulamayi silip yeniden kurmak disinda).
  /// ⚠️ YAPMA: buraya tam sayfa izin kapisi geri koyma — kullanici ACIKCA
  ///    ayri izin sayfasi ISTEMEDIGINI soyledi.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ⚠️⚠️⚠️ TURU 98n — ALT MENU KOSELERINDEKI **BEYAZ CENTIK** (kullanici
      //	sahada IKINCI KEZ bildirdi).
      //
      //	Cubugun ust koseleri 20 dp yuvarlak; radius disindaki ucgenler
      //	SAYDAMDIR ve ARKALARINDAKI **SCAFFOLD ZEMINI** gorunur. Reels
      //	sekmesi KENDI Scaffoldunda siyah boyaniyor ama ALT MENU BU DIS
      //	Scaffoldda yasiyor; dis zemin acik gri oldugu icin siyah sayfanin
      //	uzerinde iki BEYAZ CENTIK cikiyordu.
      // ⚠️ Govde zaten siyah boyandigi icin dis zemini de siyaha almak
      //    EKRANDA BASKA HICBIR SEYI DEGISTIRMEZ; yalniz kose ucgenlerini
      //    dogru renge oturtur.
      // ⚠️ YAPMA: cozumu `AltMenu` icine sabit renk koyarak arama (98h oyle
      //    yapildi ve acik ekranlarda da siyah/beyaz yanlisi uretti).
      backgroundColor: _index == _reels ? Colors.black : null,
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
      // TURU 90 - SAG ALT OLUSTUR DUGMESI (kullanici emri).
      // YALNIZ ANASAYFADA: Mesaj sekmesinin KENDI FAB'i var (turu 76b
      // "TEK GIRIS FAB") ve iki FAB ust uste binerdi.
      // ⚠️⚠️⚠️ TURU 90b — BURAYA FAB **KOYULMAZ**.
      //    Turu 90 buraya `OlusturFab` koymustu; ama `AkisEkrani` KENDI
      //    Scaffold'unda ZATEN bir "+" FAB'i tasiyor. Ikisi de `endFloat`
      //    ve ic Scaffold'un dibi dis govdenin dibiyle AYNI cizgide oldugu
      //    icin PIKSEL PIKSEL ust uste biniyorlardi; dokunusu bu (dis) FAB
      //    aliyor, akisin kendi FAB'i ULASILAMAZ kaliyordu. Sonuc: turu
      //    76b'de bilerek kapatilan "iki tane + var ve FARKLI IS
      //    YAPIYORLAR" hatasinin GERI DONMESI.
      //    Olusturma menusu artik AKISIN KENDI FAB'inden acilir.
      // ⚠️ YAPMA: buraya FAB geri ekleme. Yeni bir olusturma eylemi
      //    gerekiyorsa `olustur_menusu.dart` icine madde ekle.
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
      // ⚠️⚠️⚠️ TURU 96g — ALT MENU **YENIDEN KURULDU** (kullanici emri:
      //	*"alt menuyu getir menun ortasina, alt menudeki ikonlari ortasina
      //	3 sol 3 sag, ortada sana verdigim logoyu daire yap, ikonlarin 2
      //	kati olsun, alt menu ikonlari bir tik yukarisinda kalsin"*).
      //
      // ⚠️⚠️ `NavigationBar` **KULLANILAMAZ**: Material'in bu bileseni esit
      //	genislikte N hedef cizer; ORTAYA farkli olculu bir oge (logo)
      //	koymanin yolu yoktur. O yuzden elde cizildi.
      // ⚠️ Sekme INDEKSLERI DEGISMEDI (0..5): `_index`, `aktifSekme` ve
      //    `_reels` sabiti bu sayilara bagli. Sira degistirilseydi reels'in
      //    ses guvenligi kapisi (bkz. `IndexedStack` serhi) YANLIS sekmeye
      //    bakardi.
      bottomNavigationBar: _altMenu(),
    );
  }

  /// ⚠️⚠️ TURU 96l — GOVDE **`alt_menu.dart`a TASINDI** (tek kaynak):
  ///    kategori ekrani da AYNI menuyu ciziyor. Burada yalnizca DURUM baglanir.
  /// ⚠️ `aktifSekme` ile `_index` BIRLIKTE yazilir: akistaki videolarin ses
  ///    guvenligi kapisi `aktifSekme`ye bakiyor (bkz. `IndexedStack` serhi).
  /// ⚠️ YAPMA: menu govdesini buraya geri kopyalama.
  Widget _altMenu() => AltMenu(
    secili: _index,
    onSec: (sira) => setState(() {
      _index = sira;
      aktifSekme.value = sira;
    }),
  );
}

/// Alt menu ikonu + sag-ust kirmizi sayac.
/// ⚠️ 99+ tavani: uc haneli sayi hedefin genisligini tasirir.

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
///
/// ⚠️⚠️ TURU 80b — OTURUMA BAGLI (denetim: YUKSEK).
///
///	Bu saglayici `keepAlive` (autoDispose DEGIL) oldugu icin cikis yapilsa
///	bile onbellegi SURECTE YASIYORDU. Turu 80'de alt menudeki profil ikonu
///	GERCEK PROFIL RESMINE cevrilince bunun bedeli gorunur oldu: cikis yapip
///	BASKA bir hesapla girildiginde alt menude ve Profil sekmesinde ONCEKI
///	kullanicinin adi + avatari cizilmeye devam ediyordu (ekran elle
///	yenilenene kadar). Tek cihazda tek hesapla test edilse GORULMEZDI.
///
/// ⚠️ `ref.watch(authProvider)` — `myUserIdProvider` ile BIREBIR ayni desen:
///    oturum jetonu degisince saglayici KENDILIGINDEN yeniden kosar.
/// ⚠️ YAPMA: bunu `logout()` icine elle `invalidate` koyarak cozme — bir
///    sonraki oturuma bagli saglayicida yine unutulur (yapisal cozum budur).
final myProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider);
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
        // ⚠️⚠️ TURU 80 — RANDEVULARIM (MUSTERI tarafi). Bu giris OLMASAYDI
        //    kullanici aldigi randevuyu bir daha GOREMEZ ve IPTAL EDEMEZDI —
        //    projede ALTI kez yasanan "yazan yol var, okuyan yol yok" sinifi.
        ListTile(
          leading: const Icon(LucideIcons.calendarCheck),
          title: const Text('Randevularım'),
          subtitle: const Text('Rezervasyon ve randevu taleplerin'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RandevuListesiEkrani()),
          ),
        ),
        // ⚠️ ISLETME tarafi: gelen kutusu + ayarlar. YALNIZ isletme hesabinda
        //    cizilir — kisisel hesapta ulasilamaz bir ekran olurdu.
        if ((profile.valueOrNull?['hesap_turu'] ?? '') == 'isletme')
          ListTile(
            leading: const Icon(LucideIcons.calendarClock),
            title: const Text('Randevu ayarları'),
            subtitle: const Text('Gelen talepler, saat aralığı, kapasite'),
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RandevuAyarEkrani()),
            ),
          ),
        // ⚠️ ILANLARIM: ilan verme akisinin ikinci giris noktasi (birincisi
        //    hamburger menudeki "Ilanlar" karti).
        ListTile(
          leading: const Icon(LucideIcons.tag),
          title: const Text('İlanlarım'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const IlanListesiEkrani(benim: true, baslik: 'İlanlarım'),
            ),
          ),
        ),
        // ⚠️⚠️ TURU 91 — PROFILDE TAKIP GIRISLERI (kullanici emri:
        //    *"profilde DIYETIM ve DUGUNUM olsun, HIZMETLERIM olsun,
        //    oradan takip edebilsin"*).
        //
        // ⚠️ "Düğünüm/Hizmetlerim" TEK GIRISTE birlesti: ikisi de
        //    `tur='talep'` ilanlaridir ve AYRI iki ekran ayni listenin iki
        //    kopyasi olurdu. Baslik "Taleplerim" — kullanicinin dugun VE
        //    hizmet taleplerinin ikisini de kapsar.
        ListTile(
          leading: const Icon(LucideIcons.clipboardList),
          title: const Text('Taleplerim'),
          subtitle: const Text('Düğün · hizmet teklif istekleri'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const IlanListesiEkrani(
                tur: 'talep',
                benim: true,
                baslik: 'Taleplerim',
              ),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(LucideIcons.salad),
          title: const Text('Diyetim'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const DiyetimEkrani())),
        ),
        // ⚠️ Basvurularim: turu 90'da YALNIZ ilan listesinin AppBar'indan
        //    ulasilabiliyordu; profil ikinci ve daha kesfedilebilir giris.
        ListTile(
          leading: const Icon(LucideIcons.briefcase),
          title: const Text('Başvurularım'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const BasvurularimEkrani(tur: 'is'),
            ),
          ),
        ),
        // ⚠️ ISLETME'ye ozel girisler.
        if ((profile.valueOrNull?['hesap_turu'] ?? '') == 'isletme') ...[
          ListTile(
            leading: const Icon(LucideIcons.megaphone),
            title: const Text('Gelen talepler'),
            subtitle: const Text('Teklif verebileceğin istekler'),
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const IlanListesiEkrani(
                  tur: 'talep',
                  baslik: 'Gelen Talepler',
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(LucideIcons.handCoins),
            title: const Text('Tekliflerim'),
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BasvurularimEkrani(tur: 'talep'),
              ),
            ),
          ),
          // ⚠️ YALNIZ DIYETISYEN: baska bir isletme icin "Danışanlarım"
          //    BOS bir ekran olurdu (sunucu yalniz diyetisyene veri doner).
          if ((profile.valueOrNull?['isletme_kategori'] ?? '') == 'diyetisyen')
            ListTile(
              leading: const Icon(LucideIcons.users),
              title: const Text('Danışanlarım'),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DanisanlarimEkrani()),
              ),
            ),
        ],
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
        // ⚠️⚠️ TURU 81 — AYARLAR (kullanici emri: "ayarlardan beyaz temayi da
        //    secelim"). Uygulamada BUGUNE KADAR HIC ayarlar ekrani yoktu.
        ListTile(
          leading: const Icon(LucideIcons.settings),
          title: const Text('Ayarlar'),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AyarlarEkrani())),
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

/// ⚠️⚠️⚠️ TURU 80 — ALT MENUDEKI PROFIL SEKMESI: IKON DEGIL **PROFIL RESMI**.
///
/// Kullanici emri: *"sağdaki profil ikonu yerine profil resmi olacak"*.
///
/// ⚠️ `ConsumerWidget`: avatar DEGISINCE (profil duzenleme) alt menu de
///    KENDILIGINDEN guncellenir. `ref.watch` olmasaydi kullanici fotografini
///    degistirir ve alt menude ESKISINI gormeye devam ederdi.
/// ⚠️ AG ISTEGI KAYGISI YOK: `MedyaGorsel` imzali adresi SUREC OMURLU olarak
///    onbellekliyor; ayrica `icon`/`selectedIcon` AYNI SINIF oldugu icin
///    element yeniden kullanilir ve widget her sekme degisiminde SIFIRDAN
///    kurulmaz.
/// ⚠️ Profil resmi YOKSA `Avatar` zaten HARF YEDEGINE duser — bos kutu cizilmez.
