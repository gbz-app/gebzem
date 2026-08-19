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
import 'ayar_bilesenleri.dart';
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

  /// ⚠️ TURU 108 — profil sekmesi artik KENDI ust duzenini ciziyor
  ///    (seffaf header), bu yuzden dis AppBar muafiyetine girdi.
  static const _profil = 5;

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
      appBar:
          (_index == _akis ||
              _index == _ara ||
              _index == _reels ||
              _index == _profil)
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
          // ⚠️⚠️⚠️ TURU 108 — **DOGRUDAN PROFIL** (kullanici emri: *"profile
          //	tikladigimda direk profil gelmeli"*). Eskiden bu sekme AYARLAR
          //	listesiydi; kendi profiline ulasmak IKI dokunustu.
          const _ProfilSekmesi(),
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

/// ⚠️⚠️⚠️ TURU 105 — **PROFIL / AYARLAR SEKMESI** (kullanici emri + referans
///	ekran goruntusu: *"profil ayarlarini boyle yap; profile tikladiginda
///	profile gitsin"*).
///
/// ═══════════ ESKI HAL VE NEDEN DEGISTI ═══════════
///
/// Sekme, ortada dev bir avatar ve altinda **yirmiden fazla `ListTile`**dan
/// olusan DUZ bir listeydi: "Profili düzenle" ile "Çıkış yap" arasinda hicbir
/// gruplama yoktu, hepsi ayni agirlikta ve ayni gorunumdeydi. Kullanici
/// aradigi ayari tarayarak buluyordu.
///
/// Yeni duzen (referans): ustte **dokunulabilir profil karti**, altinda
/// **gruplanmis kartlar** (Hesap · Icerigim · Etkilesim · Tercihler · Hesabim).
///
/// ⚠️⚠️ **PROFIL KARTI PROFILE GIDER** (kullanici emri). Eski halde ustteki
///	avatar SALT DEKORATIFTI; kendi profiline gitmek icin listede ayri bir
///	satir aramak gerekiyordu. O satir ("Gönderilerim ve profilim") artik
///	KALDIRILDI — ayni hedefe iki giris, ikisinin de kesfedilmesini
///	zorlastiriyordu.
/// ⚠️ YAPMA: profil kartinin `onTap`ini kaldirma.
///
/// ⚠️⚠️ **HICBIR SATIR ULASILAMAZ BIR EKRANA GITMEZ.** Bu projede "arayuz var,
///	veri/ekran yok" hatasi ALTI kez sahaya cikti; bu yuzden buraya
///	referanstaki "Password & Security" / "Language" / "Help Center" gibi
///	satirlar **EKLENMEDI** — karsiliklari YOK. Sifre degistirme yalnizca
///	"Şifremi unuttum" akisiyla, dil TR sabit, destek ekrani ise hic yok.
/// Alt menunun profil sekmesi — KENDI profilimi acar.
///
/// ⚠️⚠️ `id.isEmpty` KAPISI ZORUNLU: `myProfileProvider` ASENKRON, ama
///	`IndexedStack` cocuklarini SENKRON kurar. Bos dize gecilseydi sunucu
///	404 doner ve sekme "Kullanıcı bulunamadı" ile acilirdi.
class _ProfilSekmesi extends ConsumerWidget {
  const _ProfilSekmesi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = (ref.watch(myProfileProvider).valueOrNull?['id'] ?? '')
        .toString();
    if (id.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ProfilSayfasi(userId: id, sekmeModu: true);
  }
}

/// ⚠️⚠️⚠️ TURU 108 — **HESABIM** (eski profil sekmesi listesi).
///
///	Profil sekmesi artik gercek profili aciyor; bu liste ULASILAMAZ
///	KALMADI: profilin AppBar'indaki dis carktan acilir. Icindeki 15
///	satirin (isletme hesabi · randevular · basvurular · diyet · bildirim
///	· takip istekleri · engellenenler · ayarlar · cikis) BASKA girisi
///	YOK.
/// ⚠️ YAPMA: dis carki kaldirma.
class HesabimEkrani extends ConsumerWidget {
  const HesabimEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Hesabım')),
    body: const _ProfileTab(),
  );
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final p = profile.valueOrNull;
    final isletme = (p?['hesap_turu'] ?? '') == 'isletme';
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ═══════════ PROFIL KARTI ═══════════
        ProfilKarti(
          onTap: () {
            final id = (p?['id'] ?? '').toString();
            if (id.isEmpty) return;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: id)),
            );
          },
          cocuk: Row(
            children: [
              // ⚠️ TURU 74 — gercek profil fotografi (varsa R2'den imzali
              //    adresle); yoksa `Avatar` harf yedegine duser.
              Avatar(
                ad: (p?['name'] as String?) ?? '',
                mediaId: p?['avatar_media_id'] as String?,
                avatarUrl: (p?['avatar_url'] as String?) ?? '',
                cap: 56,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: profile.when(
                  loading: () => const Text('...'),
                  error: (_, _) => const Text('Profil yüklenemedi'),
                  data: (v) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        v['name'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${v['username'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: scheme.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),

        // ═══════════ HESAP ═══════════
        AyarBolumu(
          baslik: 'Hesap',
          satirlar: [
            AyarSatiri(
              ikon: LucideIcons.circleUser,
              baslik: 'Profili düzenle',
              altBaslik: 'Ad, fotoğraf, hakkımda',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfilDuzenleEkrani()),
              ),
            ),
            // ⚠️⚠️ TURU 77 — ISLETME HESABI GIRISI. Bu projede "kod var ama
            //    hicbir dugmeye bagli degil" hatasi BES kez yasandi.
            AyarSatiri(
              ikon: LucideIcons.store,
              baslik: isletme ? 'İşletme bilgilerim' : 'İşletme hesabı',
              altBaslik: 'Kategori, adres, çalışma saatleri, menü',
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const IsletmeDuzenleEkrani(),
                  ),
                );
                ref.invalidate(myProfileProvider);
              },
            ),
            // ⚠️⚠️ TURU 80 — RANDEVULARIM (MUSTERI tarafi). Bu giris
            //    OLMASAYDI kullanici aldigi randevuyu bir daha GOREMEZ ve
            //    IPTAL EDEMEZDI.
            AyarSatiri(
              ikon: LucideIcons.calendarCheck,
              baslik: 'Randevularım',
              altBaslik: 'Rezervasyon ve randevu taleplerin',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RandevuListesiEkrani(),
                ),
              ),
            ),
            // ⚠️ YALNIZ isletme hesabinda: kisisel hesapta ulasilamaz bir
            //    ekran olurdu.
            if (isletme)
              AyarSatiri(
                ikon: LucideIcons.calendarClock,
                baslik: 'Randevu ayarları',
                altBaslik: 'Gelen talepler, saat aralığı, kapasite',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RandevuAyarEkrani()),
                ),
              ),
          ],
        ),

        // ═══════════ ICERIGIM ═══════════
        AyarBolumu(
          baslik: 'İçeriğim',
          satirlar: [
            // ⚠️ TURU 108 — 'İlanlarım' ve 'Taleplerim' PROFIL SEKMELERINE
            //    tasindi. Iki giris birakmak KACINILMAZ olarak drift eder
            //    (turu 76b dersi).
            // ⚠️⚠️ TURU 91 — "Düğünüm/Hizmetlerim" TEK GIRISTE birlesti: ikisi
            //    de `tur='talep'` ilanlaridir ve ayri iki ekran ayni listenin
            //    iki kopyasi olurdu.

            AyarSatiri(
              ikon: LucideIcons.briefcase,
              baslik: 'Başvurularım',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BasvurularimEkrani(tur: 'is'),
                ),
              ),
            ),
            AyarSatiri(
              ikon: LucideIcons.salad,
              baslik: 'Diyetim',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DiyetimEkrani()),
              ),
            ),
            if (isletme) ...[
              AyarSatiri(
                ikon: LucideIcons.megaphone,
                baslik: 'Gelen talepler',
                altBaslik: 'Teklif verebileceğin istekler',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const IlanListesiEkrani(
                      tur: 'talep',
                      baslik: 'Gelen Talepler',
                    ),
                  ),
                ),
              ),
              AyarSatiri(
                ikon: LucideIcons.handCoins,
                baslik: 'Tekliflerim',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BasvurularimEkrani(tur: 'talep'),
                  ),
                ),
              ),
              // ⚠️ YALNIZ DIYETISYEN: baska bir isletme icin "Danışanlarım"
              //    BOS bir ekran olurdu (sunucu yalniz diyetisyene veri doner).
              if ((p?['isletme_kategori'] ?? '') == 'diyetisyen')
                AyarSatiri(
                  ikon: LucideIcons.users,
                  baslik: 'Danışanlarım',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DanisanlarimEkrani(),
                    ),
                  ),
                ),
            ],
          ],
        ),

        // ═══════════ ETKILESIM ═══════════
        AyarBolumu(
          baslik: 'Etkileşim',
          satirlar: [
            AyarSatiri(
              ikon: LucideIcons.bell,
              baslik: 'Bildirimler',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BildirimlerSayfasi()),
              ),
            ),
            AyarSatiri(
              ikon: LucideIcons.userRoundCheck,
              baslik: 'Takip istekleri',
              altBaslik: 'Gizli hesapsan onay bekleyenler',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TakipIstekleri()),
              ),
            ),
            // ⚠️ TURU 74 — ENGELLENENLER. App Store 1.2 (UGC) engellemeyi sart
            //    kosuyor; engellemek kadar engeli GOREBILMEK ve KALDIRABILMEK
            //    de gerekli. ⚠️ YAPMA: bu girisi kaldirma.
            AyarSatiri(
              ikon: LucideIcons.ban,
              baslik: 'Engellenen kişiler',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EngellenenlerEkrani()),
              ),
            ),
          ],
        ),

        // ═══════════ TERCIHLER ═══════════
        AyarBolumu(
          baslik: 'Tercihler',
          satirlar: [
            AyarSatiri(
              ikon: LucideIcons.settings,
              baslik: 'Ayarlar',
              altBaslik: 'Tema, harita rengi, izinler',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AyarlarEkrani()),
              ),
            ),
            // ⚠️ Jeton satiri TIKLANMAZ (`onTap` yok): satin alma/harcama
            //    ekrani YOK. Dokunulup hicbir sey yapmayan bir satir, olmayan
            //    bir ozelligi VAR gibi gosterirdi.
            AyarSatiri(
              ikon: LucideIcons.coins,
              baslik: 'Jeton bakiyem',
              deger: p == null ? '...' : '${p['coin_balance'] ?? 0}',
            ),
          ],
        ),

        // ═══════════ HESABIM ═══════════
        AyarBolumu(
          baslik: 'Hesabım',
          satirlar: [
            AyarSatiri(
              ikon: LucideIcons.logOut,
              baslik: 'Çıkış yap',
              tehlikeli: true,
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
          ],
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
