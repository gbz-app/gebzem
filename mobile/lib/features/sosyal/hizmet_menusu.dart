import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../etkinlik/etkinlik_ekranlari.dart';
import '../ilan/ilan_ekranlari.dart';
import '../isletme/isletme_listesi.dart';
import '../isletme/urun_ekranlari.dart' show AiDanismaEkrani;
import '../isletme/urun_servisi.dart' show aiDurumProvider;

/// ⚠️⚠️ TURU 76b/77 — ANASAYFA SOL UST MENU.
///
/// Kullanici emri (76b): *"anasayfada sol ustte menu ikonu olsun, 2 tane 2
/// satir cizgi hamburger tarzi; tikladigimda yemek, restoran, alisveris kartlar
/// olsun; ikon YOK, kart altinda yazi sadece"*.
/// Kullanici emri (77): *"etkinlikler ... soldaki menuye tikladiginda ekranda
/// olacak"* + ilanlar + hizmetler + isletmeler.
///
/// ⚠️⚠️ KARTLARDA IKON YOK — KULLANICI ACIKCA BOYLE ISTEDI. Kart bir renk
///    gecisli zemin + ALTINDA yazidir. ⚠️ YAPMA: kartlarin icine ikon koyma.
///
/// ⚠️⚠️ TURU 76b'DE KARTLAR HICBIR YERE GITMIYORDU ("yakında" diyordu) —
///    bu projede tekrar eden "olu dogmus ozellik" sinifiydi. TURU 77'de
///    HEPSI GERCEK EKRANLARA BAGLANDI:
///      Etkinlikler → EtkinlikListesiEkrani
///      İlanlar     → IlanListesiEkrani (tum turler)
///      Hizmetler   → IlanListesiEkrani(tur: 'hizmet')
///      İşletmeler  → IsletmeListesiEkrani (tum kategoriler)
///      Yemek/Restoran/Alışveriş → IsletmeListesiEkrani(kategori: ...)
///      Yapay zekâ  → AiDanismaEkrani (YALNIZ sunucuda AI aciksa)
///    ⚠️ YAPMA: bir karti "yakında" haline geri dondurme; ekran yoksa karti
///       EKLEME.
///
/// ⚠️ DUZEN: 8 bolum var, 3 SUTUNLU IZGARA. Tek satirlik Row 4. kartta
///    RenderFlex overflow verirdi (turu 60/62 dersi). Sheet KAYDIRILABILIR
///    (`isScrollControlled` + yukseklik tavani) — kucuk ekranda tasmasin.
class HizmetMenusu extends ConsumerWidget {
  const HizmetMenusu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiAcik = ref.watch(aiDurumProvider).valueOrNull?.acik ?? false;

    // ⚠️ Liste BURADA kuruluyor cunku AI karti KOSULLU (sunucuda kapaliysa
    //    HIC cizilmez — basip 503 almasin).
    final bolumler = <_Bolum>[
      _Bolum('Etkinlikler', [
        const Color(0xFF8B3FFF),
        const Color(0xFF5A1EBE),
      ], (c) => const EtkinlikListesiEkrani()),
      _Bolum('İlanlar', [
        const Color(0xFF2BB673),
        const Color(0xFF12805A),
      ], (c) => const IlanListesiEkrani()),
      _Bolum('Hizmetler', [
        const Color(0xFF3AA9FF),
        const Color(0xFF12547A),
      ], (c) => const IlanListesiEkrani(tur: 'hizmet', baslik: 'Hizmetler')),
      _Bolum('İşletmeler', [
        const Color(0xFFFFB03A),
        const Color(0xFFFF7A45),
      ], (c) => const IsletmeListesiEkrani()),
      _Bolum('Yemek', [
        const Color(0xFFFF7A45),
        const Color(0xFFFF3B5C),
      ], (c) => const IsletmeListesiEkrani(kategori: 'yemek', baslik: 'Yemek')),
      _Bolum('Restoran', [
        const Color(0xFFFF3B5C),
        const Color(0xFF8B1E3A),
      ], (c) => const IsletmeListesiEkrani(kategori: 'kafe', baslik: 'Kafe & Restoran')),
      _Bolum('Alışveriş', [
        const Color(0xFF7A5CFF),
        const Color(0xFF3A2A8A),
      ], (c) => const IsletmeListesiEkrani(kategori: 'market', baslik: 'Alışveriş')),
      if (aiAcik)
        _Bolum('Yapay zekâ', [
          const Color(0xFF00C2A8),
          const Color(0xFF00695C),
        ], (c) => const AiDanismaEkrani()),
    ];

    return SafeArea(
      child: ConstrainedBox(
        // ⚠️ Yukseklik TAVANI: 8+ kart kucuk telefonda sheet'i ekran disina
        //    taşırırdı. Icerik daha uzunsa `GridView` kaydirilir.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Gebzem',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              const Text(
                'Şehrindeki her şey',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 12,
                        // ⚠️ Kart = kare zemin + altinda yazi -> 1'den kucuk
                        //    en-boy. 0.82 ile yazi kirpilmadan sigar.
                        childAspectRatio: 0.82,
                      ),
                  itemCount: bolumler.length,
                  itemBuilder: (_, i) => _kart(context, bolumler[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kart(BuildContext context, _Bolum b) => GestureDetector(
    onTap: () {
      // ⚠️⚠️ NAVIGATOR POP'TAN **ONCE** YAKALANIR. `Navigator.of(context)`
      //    pop'tan sonra okunursa sheet'in context'i olu olur ve ekran HIC
      //    ACILMAZ (turu 59b/75b'nin "yanlis route" sinifi).
      final nav = Navigator.of(context);
      nav.pop();
      nav.push(MaterialPageRoute(builder: b.ac));
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ⚠️ IKONSUZ kart: yalnizca renk gecisli zemin (kullanici emri).
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: b.renkler,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        // ⚠️ Yazi KARTIN ALTINDA (icinde DEGIL) — kullanici emri.
        Text(
          b.ad,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _Bolum {
  _Bolum(this.ad, this.renkler, this.ac);
  final String ad;
  final List<Color> renkler;

  /// ⚠️ HER BOLUM GERCEK BIR EKRANA GIDER. `null` (yakında) DESTEGI YOK —
  ///    ekran yoksa kart EKLENMEZ.
  final Widget Function(BuildContext) ac;
}

/// Anasayfa AppBar'inin sol ustundeki hamburger dugmesi.
///
/// ⚠️ IKI CIZGI (kullanici emri: "2 tane 2 satir cizgi hamburger tarzi").
///    Lucide'in `menu` ikonu UC cizgidir; bu yuzden ikon KULLANILMADI, iki
///    cizgi ELLE cizildi.
/// ⚠️ YAPMA: `LucideIcons.menu` koyma (uc cizgi olur).
class HamburgerDugmesi extends StatelessWidget {
  const HamburgerDugmesi({super.key});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).iconTheme.color;
    return IconButton(
      tooltip: 'Menü',
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        // ⚠️ ZORUNLU: 8 kartlik izgara varsayilan yukseklige SIGMAZ.
        isScrollControlled: true,
        showDragHandle: false,
        builder: (_) => const HizmetMenusu(),
      ),
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cizgi(renk, 20),
          const SizedBox(height: 5),
          _cizgi(renk, 14),
        ],
      ),
    );
  }

  Widget _cizgi(Color? renk, double genislik) => Container(
    width: genislik,
    height: 2,
    decoration: BoxDecoration(
      color: renk,
      borderRadius: BorderRadius.circular(1),
    ),
  );
}
