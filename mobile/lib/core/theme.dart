import 'package:flutter/material.dart';

// Gebzem marka rengi (yesil aksan) + logo moru (mor gradient FAB / vurgular)
const _seed = Color(0xFF128C7E); // WhatsApp yesiline yakin, kendi tonumuz
const morLogo = Color(0xFF6C2BD9); // logodaki mor
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
//    `_altMenuZemin`, sayfa `scaffoldBackgroundColor`) ama FARK OLCULEBILIR
//    DEGILDI: 0x16 = %8.6 parlaklik, OLED siyahin yaninda goz bunu "ayni"
//    okuyor. 0x1C (Apple systemGray6-dark) ayrimin standart degeri.
// ⚠️ YAPMA: bunu tekrar 0x16'ya dusurme; alt menuyu siyahtan cikarma.
const _icerikZemin = Color(0xFF1C1C1E); // icerik alani (siyahin BIR TIK acigi)
const _altMenuZemin = Color(0xFF000000); // alt menu SIYAH

// ⚠️⚠️ ACIK TEMA renkleri (turu 81). KOYUNUN AYNADAKI KARSILIGI:
//    koyuda alt menu EN KOYU (siyah) ve icerik 1 tik ACIK;
//    acikta alt menu EN ACIK (beyaz) ve icerik 1 tik KOYU.
//    Boylece iki temada da alt menu icerikten AYRISIR ve kullanicinin
//    tarif ettigi katman hissi KORUNUR.
const _icerikZeminAcik = Color(0xFFF2F2F5); // icerik alani (beyazin kirlisi)
const _altMenuZeminAcik = Color(0xFFFFFFFF); // alt menu BEYAZ

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
  final altMenu = koyu ? _altMenuZemin : _altMenuZeminAcik;
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
    // ALT MENU: siyah zemin, gosterge (daire) YOK, yazi YOK, ikon buyuk, aktif beyaz/pasif gri.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: altMenu,
      indicatorColor: Colors.transparent, // ikon arkasi daire KALDIRILDI (secili)
      overlayColor: WidgetStateProperty.all(Colors.transparent), // TAP dairesi de KALDIR
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide, // yazilar KALDIRILDI
      height: 62,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final aktif = states.contains(WidgetState.selected);
        // ⚠️ Aktif ikon zemine gore TERS: koyuda beyaz, acikta siyah.
        //    Sabit beyaz birakilsaydi acik temada gorunmezdi.
        return IconThemeData(
          size: 28, // 1 tik daha buyuk
          color: aktif
              ? (koyu ? Colors.white : Colors.black)
              : const Color(0xFF7A7A7E), // pasif gri: iki temada da okunur
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
