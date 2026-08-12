/// ⚠️⚠️⚠️ TURU 92 — KATEGORI USTU SLIDER + GERI/HARITA IKONLARI.
///
/// Kullanici emri: *"ustunde bir slider, slider %100 genislikte 350px
/// yukseklikte ve slider sol sag radius ALTA BAKAN radius — sanki bir div
/// var sol sag radius verilmis alta dogru bakar gibi olacak. 'Yemek' yazisi
/// gerek yok, sadece GERI IKONU, yeni gonderideki gibi OPAK BEYAZ. Arkadaki
/// slider cok hafif gri. Sliderda kisa baslik, altinda kisa PROFESYONEL
/// baslik, 3-4 tane, 3 SANIYEDE BIR gecen, BUTON YOK"* +
/// *"slider sag uste HARITA ekle, ona tikladiginda haritadan gorunsun"*.
library;

import 'dart:async';

import 'package:flutter/material.dart';

/// Sunucudan gelen slayt.
typedef Slayt = ({String baslik, String alt});

class KategoriSlider extends StatefulWidget {
  const KategoriSlider({super.key, required this.slaytlar});

  final List<Slayt> slaytlar;

  /// ⚠️ Kullanicinin verdigi olcu. Sabit tutulur: `MediaQuery` ile oranlamak
  ///    kucuk telefonda metni sikistirir, buyukte gereksiz bosluk birakir.
  static const yukseklik = 350.0;

  /// ⚠️⚠️ TURU 93 — GERI/HARITA IKONLARI **BURADAN CIKARILDI**.
  ///
  /// Kullanici: *"header'da geri ikonu arrow-left olsun, sagdaki harita
  /// kalsin, bunlarin ARKASINDAKI DAIRE KALDIR — bunlar BIR HEADER olacak,
  /// ALTINDA 10px bosluktan sonra slider olacak"*.
  ///
  /// Yani ikonlar artik slider'in USTUNDE YUZMUYOR; ayri bir header
  /// satirinda duruyorlar ve slider onlarin ALTINDAN basliyor.
  /// ⚠️ Bu sayede slider'in ust koseleri de yuvarlanabildi (eskiden durum
  ///    cubuguna dayandigi icin duz birakilmisti).

  @override
  State<KategoriSlider> createState() => _KategoriSliderState();
}

class _KategoriSliderState extends State<KategoriSlider> {
  final _sayfa = PageController();
  Timer? _zamanlayici;
  int _aktif = 0;

  @override
  void initState() {
    super.initState();
    _zamanlayiciKur();
  }

  @override
  void didUpdateWidget(covariant KategoriSlider eski) {
    super.didUpdateWidget(eski);
    // ⚠️ Slayt sayisi degisirse (kategori degisti) zamanlayici YENIDEN
    //    kurulur; yoksa 4 slayttan 2'ye dusuldugunde `animateToPage`
    //    OLMAYAN bir sayfaya gitmeye calisirdi.
    if (eski.slaytlar.length != widget.slaytlar.length) {
      _aktif = 0;
      // ⚠️ TURU 93b — CONTROLLER DA BASA ALINIR (denetim). Yalniz `_aktif`
      //    sifirlaniyordu; `PageController` hala ESKI sayfadaydi ve ilk
      //    timer atisi `animateToPage(1)` ile **GERIYE** kayiyordu.
      if (_sayfa.hasClients) _sayfa.jumpToPage(0);
      _zamanlayiciKur();
    }
  }

  void _zamanlayiciKur() {
    _zamanlayici?.cancel();
    // ⚠️ TEK SLAYTTA ZAMANLAYICI KURULMAZ: her 3 saniyede kendi kendine
    //    animasyon yapan bir sayfa gereksiz kare uretirdi (turu 91
    //    performans dersi).
    if (widget.slaytlar.length < 2) return;
    _zamanlayici = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_sayfa.hasClients) return;
      final sonraki = (_aktif + 1) % widget.slaytlar.length;
      _sayfa.animateToPage(
        sonraki,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    // ⚠️ ZAMANLAYICI ONCE iptal edilir: `dispose` edilmis bir
    //    `PageController`a `animateToPage` cagirmak PATLAR.
    _zamanlayici?.cancel();
    _sayfa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final koyu = Theme.of(context).brightness == Brightness.dark;
    // ⚠️ TURU 93 — GRI TONU **BIR KAT KOYULASTIRILDI** (kullanici emri:
    //    *"slider gri tonu 1 kat daha artik"*). Onceki `0xFFF1F1F3` beyaz
    //    zeminde neredeyse fark edilmiyordu.
    final zemin = koyu ? const Color(0xFF2A2A2E) : const Color(0xFFE7E7EA);

    return SizedBox(
      height: KategoriSlider.yukseklik,
      child: Stack(
        children: [
          // ── ZEMIN + RADIUS ──
          // ⚠️ TURU 93 — SLIDER ARTIK **%100 GENISLIKTE DEGIL** (kullanici
          //    emri). Yan bosluk cagiran ekranin `Padding`inden gelir; bu
          //    widget kendi genisligini DAYATMAZ (`width: double.infinity`
          //    KALDIRILDI) — boylece ayni container icindeki arama kutusu ve
          //    kartlarla AYNI hizada durur.
          // ⚠️ Ikonlar header'a tasindigi icin ARTIK DORT KOSE de yuvarlak.
          // ⚠️ `ClipRRect` ZORUNLU: yalniz `BoxDecoration` verilseydi icindeki
          //    `PageView` kose disina TASARDI.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: ColoredBox(
                color: zemin,
                child: PageView.builder(
                  controller: _sayfa,
                  onPageChanged: (i) => setState(() => _aktif = i),
                  itemCount: widget.slaytlar.length,
                  itemBuilder: (_, i) => _slayt(widget.slaytlar[i]),
                ),
              ),
            ),
          ),

          // ── SAYFA NOKTALARI ──
          // ⚠️ KULLANICI "BUTON YOK" DEDI: ok/ileri-geri dugmesi ve
          //    tiklanabilir gosterge YOKTUR. Bu noktalar SALT BILGI
          //    (`IgnorePointer`) — kacinci slaytta oldugunu gosterir ve
          //    kaydirmanin mumkun oldugunu ima eder.
          if (widget.slaytlar.length > 1)
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.slaytlar.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _aktif ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: (koyu ? Colors.white : Colors.black)
                              .withValues(alpha: i == _aktif ? 0.55 : 0.18),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slayt(Slayt s) => Padding(
        // ⚠️ Alt dolgu nokta gostergesine yer birakir.
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 34),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.baslik,
              // ⚠️ `maxLines` + ellipsis: metin SUNUCUDAN geliyor ve uzun bir
              //    cumle yazilirsa 350px'lik kutuyu TASIRMAMALI.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.alt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                // ⚠️ TURU 93 — 14.5 -> 16 (kullanici emri: "baslik altindaki
                //    aciklama 1 tik daha buyuk").
                fontSize: 16,
                height: 1.3,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
      );

  // ⚠️ TURU 93 — `_yuvarlakIkon` SILINDI: ikonlar header'a tasindi ve
  //    kullanici "arkasindaki DAIRE KALDIR" dedi. Olu birakmak, ileride
  //    birinin onu geri baglayip IKI AYRI geri dugmesi olusturmasina yol
  //    acardi (turu 90b `OlusturFab` dersi).
}
