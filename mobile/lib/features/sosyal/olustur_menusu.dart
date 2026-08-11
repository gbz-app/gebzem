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
    //    `showDragHandle` 48dp yiyor. Icerik 371dp, 360x640'ta butce 312dp
    //    -> **VARSAYILAN yazi olceginde bile** son madde ("Grup") KIRPILIYOR
    //    ve release'te sessizce ekran disina boyaniyordu.
    //    ⚠️ Test cihazi 414x896 oldugu icin hata ORADA GORUNMUYORDU
    //       (turu 70b'nin birebir tekrari).
    // ⚠️ Kullanicinin "yukseklik fazla olmasin" istegi BOZULMAZ:
    //    `mainAxisSize.min` duruyor, sheet yine icerik boyunda acilir;
    //    `isScrollControlled` yalnizca TAVANI kaldirir, yuksekligi ZORLAMAZ.
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Oluştur',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          _madde(c, LucideIcons.imagePlus, 'Gönderi', 'Fotoğraf, video, anket',
              () => const GonderiOlustur(), sonrasinda: sonrasinda),
          _madde(c, LucideIcons.clapperboard, 'Reels', 'Dikey kısa video',
              () => const GonderiOlustur(reels: true), sonrasinda: sonrasinda),
          // ⚠️ HIKAYE: editor bir DOSYA bekliyor ve secici mantigi
          //    `story_seridi.dart`ta (izin + boyut tavani + yukleme ilerlemesi).
          //    O mantigi BURAYA KOPYALAMAK ikinci bir kopya olurdu; bunun
          //    yerine kullanici anasayfadaki "Hikâyen" halkasina yonlendirilir.
          //    ⚠️ YAPMA: secici/yukleme kodunu buraya kopyalama.
          _madde(c, LucideIcons.circlePlus, 'Hikâye',
              'Anasayfada "Hikâyen" halkasından', null,
              ipucu: 'Anasayfadaki "Hikâyen" halkasına dokun'),
          _madde(c, LucideIcons.radio, 'Canlı yayın', 'Hemen yayına başla',
              () => const LiveStartScreen()),
          // ⚠️ SESLI ODA: olusturma akisi `rooms_tab.dart` icinde private
          //    (`_odaAc`) ve oda kurulumu ses birimi/mesgulluk kapilariyla
          //    ic ice. Disari cikarmak o kapilari ikinci kez yazmak demekti.
          _madde(c, LucideIcons.audioLines, 'Sesli oda',
              'Canlı sekmesinden aç', null,
              ipucu: 'Canlı sekmesi > Odalar > "+"'),
          // ⚠️⚠️ TURU 90c — GRUP KURULUNCA SOHBETE GIDILIR.
          //    `GrupOlusturEkrani` `pop(chatId)` ile kurulan grubun kimligini
          //    donduruyor; menu onu ATIYORDU. Sonuc: kullanici grubu kuruyor,
          //    ekran kapaniyor ve **hicbir yere gitmiyordu** — grubu bulmak
          //    icin Mesaj sekmesine gidip listede aramasi gerekiyordu.
          //    Bu, turu 90b'nin GONDERI icin duzelttigi "donen id atiliyor"
          //    hatasinin GRUP kopyasiydi.
          _madde(c, LucideIcons.users, 'Grup', 'Yeni grup sohbeti',
              () => const GrupOlusturEkrani(), sonrasinda: (chatId) {
            if (chatId == null || chatId.isEmpty) return;
            // ⚠️ `call_screen.dart:286-290` ile BIREBIR AYNI desen (kanitli):
            //    kok context alinir, `mounted` kontrol edilir, `GoRouter.of`
            //    ile push edilir. Ciplak `Navigator` KULLANILMAZ — sohbet
            //    rotasi GoRouter'da tanimli.
            final ctx = rootNavigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              GoRouter.of(ctx).push('/chat/$chatId');
            }
          }),
          const SizedBox(height: 8),
        ],
        ),
      ),
    ),
  );
}

/// Menu maddesi.
///
/// ⚠️ `ekran` NULL ise madde bir EKRAN ACMAZ, yalnizca NEREDE oldugunu
///    soyler. Bu, "dugme var ama hicbir sey yapmiyor" sinifindan (bu projede
///    alti kez yasandi) KACINMANIN durust yoludur: kullanici yine de yolu
///    ogrenir.
Widget _madde(
  BuildContext c,
  IconData ikon,
  String baslik,
  String altBaslik,
  Widget Function()? ekran, {
  String? ipucu,
  void Function(String? id)? sonrasinda,
}) =>
    ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(ikon, size: 21),
      title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(altBaslik, style: const TextStyle(fontSize: 12)),
      onTap: () async {
        final nav = Navigator.of(c);
        final mesajci = ScaffoldMessenger.of(c);
        nav.pop();
        if (ekran == null) {
          mesajci.showSnackBar(SnackBar(content: Text(ipucu ?? baslik)));
          return;
        }
        // ⚠️ SONUC BEKLENIR ve GERI VERILIR: `GonderiOlustur` paylasilan
        //    gonderinin id'sini `pop(...)` ile dondurur; akis onu kullanip
        //    kendini tazeler. `await` atlanirsa kullanici paylasip donuyor
        //    ve gonderisini AKISTA GOREMIYOR (turu 90b bulgusu).
        final id = await nav.push<String>(
          MaterialPageRoute(builder: (_) => ekran()),
        );
        sonrasinda?.call(id);
      },
    );

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
