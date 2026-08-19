/// ⚠️⚠️⚠️ TURU 90 — SAG ALT "+" -> ALTTAN ACILAN OLUSTURMA MENUSU.
///
/// Kullanici emri: *"sag alttaki + bastigimda POPUP acilsin, EN ALTTAN
/// yukari, YUKSEKLIK FAZLA OLMASIN; gonderi, story, reels, canli yayin,
/// ODA KUR, GRUP KUR gibi butonlar burada olsun"*.
///
/// ═══════════ NEDEN TEK MENU ═══════════
///
/// Bu alti eylem bugun BES AYRI YERDEN aciliyordu (akis ekrani · reels
/// sayfasi · story seridi · canli sekmesi · sohbet FAB'i). Kullanici bir
/// seyi olusturmak istediginde ONCE DOGRU SEKMEYI BULMAK zorundaydi.
/// ⚠️ Eski girisler KALDIRILMADI: sohbet FAB'i (turu 76b'de "TEK GIRIS FAB"
///    diye ozellikle kurulmustu) ve story seridindeki "Hikâyen" halkasi
///    (ozelligin VARLIGINI ogrenmenin tek yolu — turu 76b serhi) YERINDE
///    duruyor. Bu menu onlara EK bir kestirmedir, YERINE gecmez.
///
/// ⚠️⚠️ TURU 115b — MENU MODERNLESTIRILDI (kullanici: "cikan pencereyi
///	modernlestir"). UST SIRADA UC BUYUK KART (Gönderi · Reels · Canlı),
///	altta uc satir. Kartlara SABIT YUKSEKLIK VERILMEDI: Row+Expanded+
///	mainAxisSize.min ile en uzun kart belirler; sabit yukseklik yazi
///	olcegi 1.5/2.0da TASARDI (turu 98c dersi). Ikon kutusu marka renginin
///	acigi — alti farkli renk "renk cumbusu" olurdu.
///
/// ⚠️ YUKSEKLIK: alti madde x ~52dp + baslik = ~360dp. `mainAxisSize.min`
///    ile sheet icerigi kadar yer kaplar — kullanicinin "yukseklik fazla
///    olmasin" istegi BOYLE karsilanir.
///    ⚠️ TURU 90c — BU SERH DUZELTILDI: eskiden *"`isScrollControlled`
///       VERILMEZ"* diyordu ama govde turu 90b'de `true` vermeye baslamisti
///       (kucuk telefonlarda son madde KIRPILIYORDU). Bayrak yalnizca
///       TAVANI kaldirir, yuksekligi ZORLAMAZ — ikisi CELISMEZ.
///       Bu, projenin en sik hata sinifinin (serh govdeyi YANLIS anlatiyor)
///       bu dosyadaki ornegiydi.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../router.dart' show rootNavigatorKey;
import '../chats/grup_olustur.dart';
import '../live/live_start_screen.dart';
import 'gonderi_olustur.dart';

/// Alttan acilan olusturma menusunu gosterir.
///
/// ⚠️ `Navigator` POP'TAN ONCE yakalanir: pop'tan sonra sheet'in context'i
///    OLU olur ve ekran HIC ACILMAZ (turu 59b/75b "yanlis route" sinifi).
/// [sonrasinda] — acilan ekran KAPANDIGINDA sonucuyla cagrilir.
///
/// ⚠️⚠️ TURU 90b — BU GERI CAGIRIM ZORUNLU. `GonderiOlustur` `pop(postId)`
///    ile id dondurur ve akis onu kullanarak kendini tazeler. Ilk yazimda
///    menu ekrani `nav.push(...)` ile acip DONEN ID'yi ATIYORDU; kullanici
///    paylasip geri donuyor ve **gonderisini akista GORMUYORDU**.
/// ⚠️ Sheet'in KENDI future'i KULLANILAMAZ: ekran, sheet POP EDILDIKTEN
///    SONRA push edilir (sheet context'i o an olu olur) — bu yuzden geri
///    cagirim sart.
Future<void> olusturMenusuAc(
  BuildContext context, {
  void Function(String? id)? sonrasinda,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    // ⚠️⚠️ TURU 90b — `isScrollControlled` **ZORUNLU** (olculdu).
    //    Verilmediginde Flutter tavani `ekranYuksekligi * 9/16`; ustune
    //    `showDragHandle` 48dp yiyor. 360x640'ta son madde ("Grup")
    //    **VARSAYILAN yazi olceginde bile** KIRPILIYORDU.
    //    ⚠️ Test cihazi 414x896 oldugu icin hata ORADA GORUNMUYORDU
    //       (turu 70b'nin birebir tekrari).
    // ⚠️ Bayrak yalnizca TAVANI kaldirir, yuksekligi ZORLAMAZ:
    //    `mainAxisSize.min` duruyor, sheet yine icerik boyunda acilir.
    isScrollControlled: true,
    showDragHandle: true,
    // ⚠️ Kose yaricapi ACIKCA veriliyor: uygulama genelinde 20 dp kullaniliyor,
    //    Material 3 varsayilani (28) burada daha "sisman" duruyordu.
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Text(
                'Oluştur',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // ⚠️⚠️ TURU 115b — `IntrinsicHeight` ZORUNLU (emulatorde
              //	OLCULDU, EKRAN BOMBOS ACILIYORDU).
              //	Ilk yazimda yalnizca `crossAxisAlignment.stretch` vardi:
              //	`Row` bir `SingleChildScrollView` icinde oldugu icin dikey
              //	kisiti SINIRSIZ, `stretch` de cocuklara o sinirsiz
              //	yuksekligi dayatiyor ->
              //	  *BoxConstraints forces an infinite height* ->
              //	  *RenderBox was not laid out* -> **SHEET HIC CIZILMIYOR**
              //	(perde kararıyor, icerik gorunmuyor).
              //	`IntrinsicHeight` yuksekligi EN UZUN KARTTAN turetir; sabit
              //	yukseklik verilmedigi icin yazi olcegi 1.5/2.0'da da tasmaz.
              // ⚠️ YAPMA: `IntrinsicHeight`i kaldirma; kartlara sabit
              //    `height` verme (turu 98c tasma dersi).
              // ⚠️ Bu, turu 98i'deki `DemoYorumSatiri` hatasinin BIREBIR
              //    aynisi (`Expanded` + sinirsiz yukseklik).
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _kart(
                        c,
                        LucideIcons.imagePlus,
                        'Gönderi',
                        () => const GonderiOlustur(),
                        sonrasinda: sonrasinda,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _kart(
                        c,
                        LucideIcons.clapperboard,
                        'Reels',
                        () => const GonderiOlustur(reels: true),
                        sonrasinda: sonrasinda,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _kart(
                        c,
                        LucideIcons.radio,
                        'Canlı',
                        () => const LiveStartScreen(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ⚠️ HIKAYE: editor bir DOSYA bekliyor ve secici mantigi
            //    `story_seridi.dart`ta (izin + boyut tavani + yukleme
            //    ilerlemesi). O mantigi BURAYA KOPYALAMAK ikinci bir kopya
            //    olurdu; kullanici "Hikâyen" halkasina yonlendirilir.
            //    ⚠️ YAPMA: secici/yukleme kodunu buraya kopyalama.
            _satir(
              c,
              LucideIcons.circlePlus,
              'Hikâye',
              'Anasayfadaki "Hikâyen" halkasından',
              null,
              ipucu: 'Anasayfadaki "Hikâyen" halkasına dokun',
            ),
            // ⚠️ SESLI ODA: olusturma akisi `rooms_tab.dart` icinde private
            //    (`_odaAc`) ve oda kurulumu ses birimi/mesgulluk kapilariyla
            //    ic ice. Disari cikarmak o kapilari ikinci kez yazmak demekti.
            _satir(
              c,
              LucideIcons.audioLines,
              'Sesli oda',
              'Canlı sekmesi > Odalar > "+"',
              null,
              ipucu: 'Canlı sekmesi > Odalar > "+"',
            ),
            // ⚠️⚠️ TURU 90c — GRUP KURULUNCA SOHBETE GIDILIR.
            //    `GrupOlusturEkrani` `pop(chatId)` donduruyor; menu onu
            //    ATIYORDU: kullanici grubu kuruyor ve **hicbir yere
            //    gitmiyordu**. Turu 90b'nin GONDERI icin duzelttigi "donen id
            //    atiliyor" hatasinin GRUP kopyasiydi.
            _satir(
              c,
              LucideIcons.users,
              'Grup',
              'Yeni grup sohbeti',
              () => const GrupOlusturEkrani(),
              sonrasinda: (chatId) {
                if (chatId == null || chatId.isEmpty) return;
                // ⚠️ `call_screen.dart:286-290` ile BIREBIR AYNI desen:
                //    kok context alinir, `mounted` kontrol edilir, `GoRouter`
                //    ile push edilir. Ciplak `Navigator` KULLANILMAZ — sohbet
                //    rotasi GoRouter'da tanimli.
                final ctx = rootNavigatorKey.currentContext;
                if (ctx != null && ctx.mounted) {
                  GoRouter.of(ctx).push('/chat/$chatId');
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    ),
  );
}

/// Ust siradaki buyuk kart.
Widget _kart(
  BuildContext c,
  IconData ikon,
  String baslik,
  Widget Function() ekran, {
  void Function(String? id)? sonrasinda,
}) {
  final scheme = Theme.of(c).colorScheme;
  return Material(
    color: scheme.primary.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _ac(c, ekran, sonrasinda: sonrasinda),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 25, color: scheme.primary),
            const SizedBox(height: 9),
            Text(
              baslik,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Alt bolumdeki satir.
///
/// ⚠️ [ekran] NULL ise satir bir EKRAN ACMAZ, yalnizca NEREDE oldugunu
///    soyler. Bu, "dugme var ama hicbir sey yapmiyor" sinifindan (bu projede
///    alti kez yasandi) KACINMANIN durust yoludur: kullanici yine de yolu
///    ogrenir. O satirlarda ok (chevron) CIZILMEZ — ok "seni bir yere
///    goturecegim" demektir ve goturmuyoruz.
Widget _satir(
  BuildContext c,
  IconData ikon,
  String baslik,
  String altBaslik,
  Widget Function()? ekran, {
  String? ipucu,
  void Function(String? id)? sonrasinda,
}) {
  final scheme = Theme.of(c).colorScheme;
  final soluk = scheme.onSurface.withValues(alpha: 0.6);
  return InkWell(
    onTap: () async {
      final nav = Navigator.of(c);
      final mesajci = ScaffoldMessenger.of(c);
      nav.pop();
      if (ekran == null) {
        mesajci.showSnackBar(SnackBar(content: Text(ipucu ?? baslik)));
        return;
      }
      final id = await nav.push<String>(
        MaterialPageRoute(builder: (_) => ekran()),
      );
      sonrasinda?.call(id);
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(ikon, size: 19, color: scheme.onSurface),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  baslik,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(altBaslik, style: TextStyle(fontSize: 12, color: soluk)),
              ],
            ),
          ),
          if (ekran != null)
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: scheme.onSurface.withValues(alpha: 0.35),
            ),
        ],
      ),
    ),
  );
}

/// Kartlarin ortak acma yolu (satirla AYNI sozlesme).
Future<void> _ac(
  BuildContext c,
  Widget Function() ekran, {
  void Function(String? id)? sonrasinda,
}) async {
  final nav = Navigator.of(c);
  nav.pop();
  // ⚠️ SONUC BEKLENIR ve GERI VERILIR: `GonderiOlustur` paylasilan gonderinin
  //    id'sini `pop(...)` ile dondurur; akis onu kullanip kendini tazeler.
  //    `await` atlanirsa kullanici paylasip donuyor ve gonderisini AKISTA
  //    GOREMIYOR (turu 90b bulgusu).
  final id = await nav.push<String>(MaterialPageRoute(builder: (_) => ekran()));
  sonrasinda?.call(id);
}

// ⚠️⚠️⚠️ TURU 90c — `OlusturFab` SINIFI **SILINDI**.
//
// Turu 90'da `home_screen`e konmus, turu 90b'de ORADAN KALDIRILMISTI
// (akisin KENDI FAB'iyle piksel piksel ust uste biniyordu ve akisinkini
// ULASILAMAZ kiliyordu). Geriye SINIF kaldi: hicbir yerden cagrilmayan,
// ama **DOLU BIR SILAH** — birisi "hazir bir FAB var" diye onu bir
// Scaffold'a koydugu anda turu 90b'nin IKI duzeltmesini birden geri
// getirirdi (cift FAB + paylasim sonrasi akisin tazelenmemesi, cunku bu
// sinif `sonrasinda` geri cagirimini GECMIYORDU).
//
// ⚠️ YAPMA: "kolaylik olsun" diye bunu geri ekleme. Olusturma menusunun
//    TEK GIRISI `akis_ekrani.dart`taki FAB'dir ve o, sonucu
//    `_paylasimSonrasi`ya baglar.
