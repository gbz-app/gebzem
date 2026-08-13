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

// ⚠️ Kose yaricapi TEK KAYNAK: slider, kart kapagi ve 60x60 kutu ayni
//    sabiti kullanmak ZORUNDA (bkz. `isletme_kart.dart` yaricap serhi).
import 'isletme_kart.dart' show kYaricap;

/// Sunucudan gelen slayt.
typedef Slayt = ({String baslik, String alt});

class KategoriSlider extends StatefulWidget {
  const KategoriSlider({super.key, required this.slaytlar});

  final List<Slayt> slaytlar;

  /// ⚠️ Kullanicinin verdigi olcu. Sabit tutulur: `MediaQuery` ile oranlamak
  ///    kucuk telefonda metni sikistirir, buyukte gereksiz bosluk birakir.
  /// ⚠️ 350 -> 250 -> **200** (kullanici emri, iki adimda). Slayt metinleri
  ///    kaldirildiktan sonra 250 de fazlaydi; liste artik 150px daha erken
  ///    basliyor.
  static const yukseklik = 200.0;

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
    // ⚠️ TEK KAYNAK: kapak yer tutucusu ve 60x60 kartlarla AYNI gri.
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
              borderRadius: BorderRadius.circular(kYaricap),
              child: ColoredBox(
                color: zemin,
                child: PageView.builder(
                  controller: _sayfa,
                  // ⚠️ TURU 96 — `setState` KALDIRILDI. Gecis cizgileri
                  //    silindikten sonra `_aktif`e BAGLI CIZILEN HICBIR SEY
                  //    kalmadi; `setState` her 3 saniyede bir bos bir
                  //    yeniden cizim tetikliyordu. Alan hala gerekli:
                  //    zamanlayici bir sonraki sayfayi ondan hesapliyor.
                  onPageChanged: (i) => _aktif = i,
                  itemCount: widget.slaytlar.length,
                  itemBuilder: (_, i) => _slayt(widget.slaytlar[i]),
                ),
              ),
            ),
          ),

          // ⚠️⚠️⚠️ TURU 96 — **GECIS CIZGILERI KALDIRILDI** (kullanici
          //	emri: *"sliderdeki alt cizgileri kaldir"*).
          //
          //	Onceden 2px kalinliginda, aktif olani 26px / digerleri 14px
          //	uzunlugunda siyah cizgiler ciziliyordu. Slaytlarin ICI BOS
          //	oldugu icin (metinler turu 95te kaldirildi) bu cizgiler
          //	gri bir dikdortgenin uzerinde TEK gorsel unsurdu ve
          //	"sayfalayici" degil "cizik" gibi duruyordu.
          // ⚠️ Slayt VERISI ve otomatik gecis DURUYOR: sunucudan gelen slayt
          //    sayisi hala `PageView`i besliyor ve 3 saniyede bir donuyor.
          //    Bu alana gorsel konuldugunda gecis ZATEN gorunur olacak.
          // ⚠️ YAPMA: buraya nokta/cizgi/ok gostergesi geri koyma (kullanici
          //    iki ayri turda "BUTON YOK" ve "cizgileri kaldir" dedi).
        ],
      ),
    );
  }

  /// ⚠️⚠️ SLAYT **BOS** — metinler kaldirildi (kullanici emri, IKINCI KEZ).
  ///
  ///	Slayt VERISI (`baslik`/`alt`) sunucudan GELMEYE DEVAM EDIYOR ve burada
  ///	BILEREK cizilmiyor:
  ///	  · slayt SAYISI hala sayfalayiciyi ve gecis cizgilerini besliyor;
  ///	  · bu alana yarin gorsel/kampanya konuldugunda sunucu sozlesmesi
  ///	    DEGISMEYECEK (turu 77 kurali: liste sunucudan gelir).
  /// ⚠️ YAPMA: veriyi `Kesif` ucundan silme — sildigin an slayt sayisi 0 olur,
  ///    `PageView` tek sayfaya duser ve gecis cizgileri KAYBOLUR.
  Widget _slayt(Slayt s) => const SizedBox.expand();
}
