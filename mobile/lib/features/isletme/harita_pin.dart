/// ⚠️⚠️⚠️ TURU 96g — HARITADAN PIN SECME (kullanici emri: *"konum secte
/// haritadan pin secebilelim, Yemeksepeti gibi"*).
///
/// Yemeksepeti/Getir deseni: harita SERBESTCE kaydirilir, pin **EKRANIN
/// ORTASINDA SABIT** durur; yani kullanici pini surumez, HARITAYI surer.
/// Bu, tek parmakla tek elle kullanilabilen tek desendir — surukelenebilir
/// bir marker parmagin ALTINDA kalir ve kullanici nereyi sectigini goremez.
/// ⚠️ YAPMA: pini `Marker` yapip surukletme.
///
/// ⚠️⚠️ HARITA ANAHTARI YOKSA (`--dart-define=HARITA` gecilmemis derleme)
///	bu ekran **ACILMAZ**; cagiran taraf dugmeyi hic cizmez. Anahtarsiz
///	`GoogleMap` Android'de filigranli GRI kutu, iOS'ta BOS ekran cizerdi
///	(turu 85 dersi).
///
/// ⚠️ Secilen noktanin ADRESI COZULMEZ: `geocoding` paketi projede var ama
///    ters cozumleme (koordinat -> adres) ayri bir is ve bu ekranin isi
///    DEGIL — kullanici konuma KENDI adini veriyor. Sahte bir adres metni
///    uretmek yanlis bilgi olurdu.
library;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'isletme_kart.dart' show kYanBosluk, kYaricap, kVurgu;
import 'yakinimda_ekrani.dart' show haritaAnahtariVar;

/// Haritadan bir nokta sectirir. `null` = vazgecildi.
Future<(double, double)?> haritadanPinSec(
  BuildContext context, {
  required double baslangicEnlem,
  required double baslangicBoylam,
}) =>
    Navigator.of(context).push<(double, double)>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _HaritaPinEkrani(
          enlem: baslangicEnlem,
          boylam: baslangicBoylam,
        ),
      ),
    );

class _HaritaPinEkrani extends StatefulWidget {
  const _HaritaPinEkrani({required this.enlem, required this.boylam});

  final double enlem;
  final double boylam;

  @override
  State<_HaritaPinEkrani> createState() => _HaritaPinEkraniState();
}

class _HaritaPinEkraniState extends State<_HaritaPinEkrani> {
  late double _enlem = widget.enlem;
  late double _boylam = widget.boylam;

  /// ⚠️ Kamera HAREKET EDERKEN her karede `setState` cagirmak, harita
  ///    suruklenirken saniyede ~60 yeniden cizim demektir. Koordinat
  ///    yalnizca hareket BITINCE (`onCameraIdle`) okunur; hareket sirasinda
  ///    pin zaten sabit duruyor ve ekranda degisen bir sey yok.
  CameraPosition? _son;

  @override
  Widget build(BuildContext context) {
    final koyu = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haritadan seç'),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          tooltip: 'Vazgeç',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.enlem, widget.boylam),
                zoom: 16,
              ),
              // ⚠️ Jestler ACIK: bu ekranin TEK isi haritayi surmek.
              //    Kapali olsaydi pin hic hareket etmezdi.
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              // ⚠️ `Marker` YOK: pin ekranin ortasinda SABIT bir katman
              //    (asagida). Marker olsaydi haritayla birlikte kayardi.
              markers: const {},
              onCameraMove: (p) => _son = p,
              onCameraIdle: () {
                final p = _son;
                if (p == null) return;
                setState(() {
                  _enlem = p.target.latitude;
                  _boylam = p.target.longitude;
                });
              },
            ),
          ),
          // ── SABIT PIN ──
          // ⚠️ `IgnorePointer` ZORUNLU: pin dokunuslari YUTARSA haritanin
          //    tam ortasindan surukleme BASLATILAMAZ ve kullanici "harita
          //    kilitli" sanir.
          // ⚠️ Ucu tam merkezde olsun diye ikon YUKARI kaydirilir: ikonun
          //    gorsel agirlik merkezi ile SIVRI UCU ayni yerde degildir.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 34),
                child: Icon(
                  LucideIcons.mapPin,
                  size: 44,
                  color: kVurgu(context),
                  shadows: const [
                    Shadow(color: Color(0x55000000), blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
          // ── ALT BILGI + ONAY ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      kYanBosluk, 12, kYanBosluk, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Haritayı kaydır, pin istediğin yere gelsin.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      // ⚠️ Koordinat GORUNUR: kullanici pinin gercekten
                      //    hareket ettigini boyle dogrular (adres cozumu yok).
                      Text(
                        '${_enlem.toStringAsFixed(5)}, '
                        '${_boylam.toStringAsFixed(5)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: (koyu ? Colors.white : Colors.black)
                              .withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            // ⚠️ Renk TEMADAN ALINMAZ: varsayilan `primary`
                            //    YESIL ve kullanici bu akista yesili reddetti.
                            backgroundColor: kVurgu(context),
                            foregroundColor:
                                koyu ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(kYaricap(52)),
                            ),
                          ),
                          onPressed: () =>
                              Navigator.of(context).pop((_enlem, _boylam)),
                          child: const Text(
                            'Bu konumu seç',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Harita secimi bu derlemede mumkun mu?
/// ⚠️ Cagiran taraf dugmeyi buna gore cizer: anahtarsiz derlemede dugme
///    GORUNMEZ (basildiginda bos ekran acilan bir dugme "bozuk" gorunurdu).
bool get haritadanSecilebilir => haritaAnahtariVar;
