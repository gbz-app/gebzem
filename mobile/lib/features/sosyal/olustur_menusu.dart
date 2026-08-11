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
///    ile sheet icerigi kadar yer kaplar; `isScrollControlled` VERILMEZ
///    (verilirse tam ekrana kadar buyuyebilir — kullanici "yukseklik fazla
///    olmasin" dedi).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chats/grup_olustur.dart';
import '../live/live_start_screen.dart';
import 'gonderi_olustur.dart';

/// Alttan acilan olusturma menusunu gosterir.
///
/// ⚠️ `Navigator` POP'TAN ONCE yakalanir: pop'tan sonra sheet'in context'i
///    OLU olur ve ekran HIC ACILMAZ (turu 59b/75b "yanlis route" sinifi).
Future<void> olusturMenusuAc(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
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
              () => const GonderiOlustur()),
          _madde(c, LucideIcons.clapperboard, 'Reels', 'Dikey kısa video',
              () => const GonderiOlustur(reels: true)),
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
          _madde(c, LucideIcons.users, 'Grup', 'Yeni grup sohbeti',
              () => const GrupOlusturEkrani()),
          const SizedBox(height: 8),
        ],
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
}) =>
    ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(ikon, size: 21),
      title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(altBaslik, style: const TextStyle(fontSize: 12)),
      onTap: () {
        final nav = Navigator.of(c);
        final mesajci = ScaffoldMessenger.of(c);
        nav.pop();
        if (ekran == null) {
          mesajci.showSnackBar(SnackBar(content: Text(ipucu ?? baslik)));
          return;
        }
        nav.push(MaterialPageRoute(builder: (_) => ekran()));
      },
    );

/// Anasayfadaki sag alt "+" dugmesi.
///
/// ⚠️ YALNIZ ANASAYFADA cizilir: Mesaj sekmesinin KENDI FAB'i var
///    (turu 76b "TEK GIRIS FAB") ve iki FAB ayni ekranda ust uste binerdi.
class OlusturFab extends ConsumerWidget {
  const OlusturFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FloatingActionButton(
    heroTag: 'olustur-fab',
    onPressed: () => olusturMenusuAc(context),
    child: const Icon(LucideIcons.plus),
  );
}
