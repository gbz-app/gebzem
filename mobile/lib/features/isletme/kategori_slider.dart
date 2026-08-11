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
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Sunucudan gelen slayt.
typedef Slayt = ({String baslik, String alt});

class KategoriSlider extends StatefulWidget {
  const KategoriSlider({
    super.key,
    required this.slaytlar,
    required this.haritaya,
  });

  final List<Slayt> slaytlar;

  /// Sag ustteki harita ikonuna dokununca.
  final VoidCallback haritaya;

  /// ⚠️ Kullanicinin verdigi olcu. Sabit tutulur: `MediaQuery` ile oranlamak
  ///    kucuk telefonda metni sikistirir, buyukte gereksiz bosluk birakir.
  static const yukseklik = 350.0;

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
    // ⚠️ "COK HAFIF GRI" (kullanici emri). Koyu temada ayni tonu kullanmak
    //    metni okunamaz yapardi; koyu temada hafif ACIK bir yuzey secilir.
    final zemin = koyu ? const Color(0xFF232326) : const Color(0xFFF1F1F3);

    return SizedBox(
      height: KategoriSlider.yukseklik,
      width: double.infinity,
      child: Stack(
        children: [
          // ── ZEMIN + ALTA BAKAN RADIUS ──
          // ⚠️ YALNIZ ALT KOSELER yuvarlak (kullanici emri: "sol sag radius
          //    ALTA BAKAN"). Ust koseler DUZ kalir cunku slider ekranin en
          //    ustune, durum cubugunun ALTINA dayaniyor.
          // ⚠️ `ClipRRect` ZORUNLU: yalniz `BoxDecoration` verilseydi icindeki
          //    `PageView` kose disina TASARDI.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
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

          // ── GERI (sol ust) ──
          // ⚠️ "yeni gonderideki gibi OPAK BEYAZ": beyaz dolgu + hafif golge.
          //    Saydam bir ikon acik gri zeminde KAYBOLURDU.
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            child: _yuvarlakIkon(
              LucideIcons.chevronLeft,
              () => Navigator.of(context).maybePop(),
              'Geri',
            ),
          ),

          // ── HARITA (sag ust) ──
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 12,
            child: _yuvarlakIkon(LucideIcons.map, widget.haritaya, 'Haritada gör'),
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
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 34),
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
                fontSize: 14.5,
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

  /// Opak beyaz yuvarlak ikon dugmesi.
  ///
  /// ⚠️ 40x40: Material'in 48dp hedefinin altinda ama `InkWell` splash'i
  ///    kutunun disina tasarak dokunma alanini buyutur; ayrica iki ikon da
  ///    ekran kenarinda ve cevresinde rakip hedef YOK.
  Widget _yuvarlakIkon(IconData ikon, VoidCallback bas, String ipucu) =>
      Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: bas,
          child: Tooltip(
            message: ipucu,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(ikon, size: 20, color: Colors.black87),
            ),
          ),
        ),
      );
}
