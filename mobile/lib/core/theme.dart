import 'package:flutter/material.dart';

const morLogo = Color(0xFF6C2BD9); // logodaki mor

// ⚠️⚠️⚠️ TURU 115 — **MARKA RENGI ARTIK LOGONUN MORU** (kullanici emri:
//	*"arayuz icin ozen, YESIL RENK YAPMA ARTIK, genel tasarima uy"*).
//
//	Eski tohum WhatsApp yesiline yakin bir tondu (`0xFF128C7E`) ve
//	`colorScheme.primary` her yerde ONDAN turedigi icin secili cipler,
//	dugmeler, baglantilar ve gostergeler YESIL cikiyordu — oysa logo,
//	alt menu halkasi ve hikaye halkasi MOR. Uygulama kendi markasiyla
//	celisiyordu.
//
// ⚠️ Tek satirlik degisiklik AMA genis etkili: renkler tek tek elle
//    yazilmadigi icin (`colorScheme` uzerinden) TUM ekranlar birlikte
//    donuyor. Elle boyanmis noktalar bu degisiklikten ETKILENMEZ —
//    onlar zaten ayri ayri gozden geciriliyor.
// ⚠️ YAPMA: tohumu tekrar yesile dondurme.
const _seed = morLogo; // logodaki mor — marka rengi
const morLogoAcik = Color(0xFF9D5CE9);
// Logo mor gradient'i (FAB + vurgu daireleri)
const morGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [morLogoAcik, morLogo],
);

// ⚠️⚠️ KOYU TEMA renkleri (test turu 5 redesign, turu 81'de KULLANICI TARAFINDAN
//    TEKRAR ONAYLANDI: "alt menu siyah, sayfa 1 tik acik rengi olacak").
//    Yani bu iki sabit YENI IS DEGIL, KORUNACAK mevcut davranistir.
// ⚠️⚠️ TURU 82 — kullanici IKINCI kez *"alt menu siyah, arka plan bir tik
//    acigi olacak dedim, o da oyle degil"* dedi. Kablolama DOGRUYDU (alt menu
//    siyah, sayfa `scaffoldBackgroundColor`) ama FARK OLCULEBILIR DEGILDI:
//    0x16 = %8.6 parlaklik, OLED siyahin yaninda goz bunu "ayni" okuyor.
//    0x1C (Apple systemGray6-dark) ayrimin standart degeri.
// ⚠️ YAPMA: bunu tekrar 0x16'ya dusurme.
// ⚠️ Alt menunun siyahi artik AYRI ve PUBLIC bir sabit: `kAltMenuZemin`
//    (asagida) — cunku iki temada da AYNI ve `alt_menu.dart` onu okuyor.
const _icerikZemin = Color(0xFF1C1C1E); // icerik alani (siyahin BIR TIK acigi)

// ⚠️⚠️ ACIK TEMA icerik zemini (turu 81): koyuda icerik siyahin 1 tik acigi,
//    acikta beyazin 1 tik kirlisi. Alt menu ARTIK BU SIMETRIYE DAHIL DEGIL
//    (bkz. asagidaki turu 96m blogu).
const _icerikZeminAcik = Color(0xFFF2F2F5); // icerik alani (beyazin kirlisi)

// ⚠️⚠️⚠️ TURU 96m — ALT MENU **IKI TEMADA DA SIYAH** (kullanici emri 15 Agu:
//	*"alt menu siyah olacak, ikonlar aktif beyaz pasif hafif gri"*).
//
//	Turu 81/82'de cubuk acik temada BEYAZ, koyu temada SIYAH idi ("aynadaki
//	karsiligi"). Kullanici o simetriyi ACIKCA kaldirdi: alt menu artik
//	temayla birlikte donen bir KATMAN degil, SABIT BIR SIYAH SERIT.
//
// ⚠️⚠️ IKON RENKLERI DE TEMADAN BAGIMSIZ SABITTIR — bu bir tercih degil
//    ZORUNLULUK: zemin sabit siyahken renk temaya baglansaydi (`onSurface`)
//    ACIK TEMADA SIYAH IKON SIYAH ZEMINE cizilir ve **menu tamamen
//    kaybolurdu**. Zemin sabitse onun uzerindeki her sey de sabit olmali.
// ⚠️ YAPMA: bu uc sabiti `Theme.of(context)`ten turetmeye calisma.
const kAltMenuZemin = Color(0xFF000000);
const kAltMenuAktifIkon = Color(0xFFFFFFFF);

/// Pasif ikon grisi. ⚠️ Deger KEYFI DEGIL: siyah zeminde kontrast **4.9:1**
/// (ikon/grafik icin gereken 3:1'in belirgin uzerinde) ama beyaza gore
/// ACIKCA soluk — yani hem OKUNUR hem "pasif" okunur.
/// ⚠️ Daha koyu bir gri (ornegin 0xFF4A4A4A) 3:1'in ALTINA duser ve pasif
///    sekmeler zayif gozde/gunes altinda GORUNMEZ olur.
const kAltMenuPasifIkon = Color(0xFF7A7A7E);

/// ⚠️⚠️⚠️ TURU 81 — TEK GOVDE, IKI PARLAKLIK.
///
/// Onceki surumde `lightTheme` ve `darkTheme` DEGISKENLERININ IKISI DE ayni
/// `_koyu()` fonksiyonunu cagiriyordu; yani `main.dart`taki
/// `themeMode: ThemeMode.system` **FIILEN NO-OP**tu ve acik tema HIC TANIMLI
/// DEGILDI. Kullanici acikca "dark ve beyaz 2 tema olsun, ayarlardan
/// secebilelim" dedi.
///
/// ⚠️ IKI TEMA **AYNI FONKSIYONDAN** uretilir, kopyalanmaz: iki ayri govde
///    kacinilmaz olarak DRIFT ederdi (bu projede "ayni kuralin iki kopyasi"
///    hatasi ALTI kez tekrarladi). Fark yalnizca renk sabitleri ve
///    `Brightness`.
/// ⚠️ DURUST SINIR: kod tabaninda ~500 sabit renk noktasi var
///    (`Color(0xFF..)` + `Colors.white/black`). Bu tema iskeleti dogru olsa da
///    o noktalar acik temada TEMANIN DISINDA kalir; kademeli olarak
///    `Theme.of(context)`e cevrilmeleri gerekir.
ThemeData _tema(Brightness parlaklik) {
  final koyu = parlaklik == Brightness.dark;
  final icerik = koyu ? _icerikZemin : _icerikZeminAcik;
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: parlaklik,
  ).copyWith(surface: icerik);
  return ThemeData(
    useMaterial3: true,
    brightness: parlaklik,
    colorScheme: scheme,
    scaffoldBackgroundColor: icerik,
    // TEST TURU 58 — UYGULAMA YAZI TIPI: GOOGLE SANS (kullanici istegi).
    // Dosyalar resmi Google Fonts API'sinden alindi (400/500/600/700), pubspec
    // `fonts:` blogunda tanimli.
    // ⚠️ Kod genelinde BASKA yerde `fontFamily` YAZILI DEGIL — aile degisikligi
    // yalnizca BURADAN ve pubspec'ten yapilir.
    fontFamily: 'Google Sans',
    // ALT MENU icon TAP dairesi (ripple/splash) KALDIR (test turu 7): NoSplash + saydam vurgu.
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: icerik,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    // ALT MENU: siyah zemin, gosterge (daire) YOK, yazi YOK, aktif beyaz/pasif gri.
    // ⚠️⚠️ TURU 96m — **CANLI ALT MENU BU BLOK DEGIL**: uygulamanin alt menusu
    //	`features/home/alt_menu.dart` icinde ELLE cizilir (`NavigationBar`
    //	kullanilmiyor — `grep 'NavigationBar('` SIFIR sonuc). Bu blok yalnizca
    //	ileride biri Material `NavigationBar` eklerse gorunumun AYRISMAMASI
    //	icin duruyor ve **ayni sabitleri** kullanir.
    // ⚠️ YAPMA: buradaki renkleri elle degistirme; `kAltMenu*` sabitlerini
    //    degistir — iki yuzey birlikte doner.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kAltMenuZemin,
      indicatorColor: Colors.transparent, // ikon arkasi daire KALDIRILDI (secili)
      overlayColor: WidgetStateProperty.all(Colors.transparent), // TAP dairesi de KALDIR
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide, // yazilar KALDIRILDI
      height: 62,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final aktif = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: aktif ? kAltMenuAktifIkon : kAltMenuPasifIkon,
        );
      }),
    ),
  );
}

final lightTheme = _tema(Brightness.light);
final darkTheme = _tema(Brightness.dark);

// ⚠️⚠️⚠️ TURU 81 — MESAJ BALONU RENKLERI **PARLAKLIGA GORE** (denetim
// bulgusu: SEVK ENGELIYDI).
//
// Onceki surumde bu uc renk SABITTI ve ikisi de KOYUYDU (`0xFF075E54`,
// `0xFF262D31`). Balonun ICINDEKI yazi ise temadan geliyor. Acik tema
// eklenince sonuc su oldu:
//
//	KOYU balon zemini  +  SIYAH yazi  =  **TUM SOHBET OKUNAMAZ**
//
// Yani turun getirdigi acik tema, uygulamanin EN COK KULLANILAN ekranini
// kullanilamaz hale getiriyordu. Kullanici "beyaz temayi da secelim" derken
// kastettigi kesinlikle bu degildi.
//
// ⚠️ Renkler `Brightness`e gore secilir. Acik temada:
//   · benim balonum  -> acik yesil (WhatsApp'in acik tema tonu)
//   · karsi balon    -> beyaz
//   Ikisinde de koyu yazi OKUNUR.
// ⚠️ YAPMA: bu uc renkten herhangi birini tekrar SABITE cevirme; acik tema
//    eklendikten sonra sabit renk = okunamaz ekran demektir.
// ⚠️ Mavi tik IKI TEMADA DA ayni kalir (marka isareti; iki zeminde de okunur).
extension ChatColors on ColorScheme {
  bool get _koyuMu => brightness == Brightness.dark;
  Color get bubbleMine =>
      _koyuMu ? const Color(0xFF075E54) : const Color(0xFFD9FDD3);
  Color get bubbleOther =>
      _koyuMu ? const Color(0xFF262D31) : const Color(0xFFFFFFFF);
  Color get tickRead => const Color(0xFF34B7F1); // mavi tik
}

/// Kimlikten (kullanici id'si) turetilen SABIT renk. **TEK KAYNAK.**
///
/// ⚠️⚠️ TURU 78 — Govde `chat_screen.dart` icindeki `_MessageBubble._adRengi`
///    metodundan TASINDI (kopyalanmadi; oradaki private metot silindi ve bu
///    fonksiyonu cagiriyor). Iki kopya birakilsaydi palet kacinilmaz olarak
///    DRIFT ederdi: ayni kisi grup sohbetinde mor, profil kapaginda yesil
///    gorunurdu — bu projede "ayni kuralin iki kopyasi" hatasi ALTI kez tekrarladi.
///
/// ⚠️ RASTGELE DEGIL: ayni id her zaman ayni rengi verir (id'nin kod
///    birimlerinden deterministik hash). Rastgele olsaydi her yeniden cizimde
///    renk degisir ve kullanici "bozuldu" sanardi.
/// ⚠️ YAPMA: bu paleti baska bir dosyaya kopyalama.
Color kimlikRengi(String id) {
  const palet = [
    Color(0xFF8B5CF6),
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
    Color(0xFFFFC107),
    Color(0xFF9C27B0),
  ];
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palet[h % palet.length];
}
