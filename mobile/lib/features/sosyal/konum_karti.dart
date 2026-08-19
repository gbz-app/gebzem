library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../isletme/isletme_kart.dart' show kYanBosluk;
import '../medya/konum_servisi.dart';

/// ⚠️⚠️⚠️ TURU 104 — **KONUM PAYLASIM KARTI** (kullanici emri: *"birde konum
///	paylasma ornegi olsun"*).
///
/// ═══════════ NEDEN KART, NEDEN KUCUK BIR CIP DEGIL ═══════════
///
/// Turu 90'dan beri konum, gonderi basliginin altinda **12 punto tek satirlik
/// bir cip** olarak ciziliyordu. O cip bir META VERIDIR ("bu fotograf surada
/// cekildi"). Kullanicinin istedigi ise bir **ICERIK**: gonderinin KENDISI bir
/// konum paylasimi. Ikisi ayni yuzeyle anlatilamaz — WhatsApp/Instagram da
/// ayirir.
///
/// **KURAL (bkz. `gonderi_karti`):** gonderide medya · ses · anket YOKSA ve
/// konum VARSA -> bu KART cizilir. Medya varsa konum yine META'dir ve eski cip
/// kalir.
///
/// ═══════════ ⚠️⚠️ NEDEN GERCEK HARITA CIZILMIYOR (DURUST SINIR) ═══════════
///
/// 1. **Akista N adet harita** demek N adet platform view demektir. Android'de
///    `liteModeEnabled` bir static goruntu verir ama **iOS'ta lite mode YOKTUR**;
///    orada her kart tam bir harita motoru acar. Turu 91'in performans dersi
///    ("bir tik kasiyor") tam bu siniftan.
/// 2. **Google Static Maps** bir goruntu dondurur ama AYRI bir uctur, AYRI
///    faturalandirilir ve anahtar istemciye acilir. Bugun boyle bir anahtar da
///    butce de YOK.
/// 3. Elle "harita gibi" sokaklar cizmek **YANILTICI** olurdu: kullanici o
///    cizgileri O ADRESIN haritasi sanar. Bu projede sahte veri cizmek yasak.
///
/// Bu yuzden zemin bir HARITA DEGIL, bir **konum isaretidir**: pinden yayilan
/// halkalar. Gercek harita, karta dokununca **cihazin kendi harita
/// uygulamasinda** acilir (`KonumServisi.haritadaAc`) — yani harita YOK degil,
/// DOGRU YERDE.
///
/// ⚠️ YAPMA: buraya `GoogleMap` widget'i koyma (akista N tane olur).
/// ⚠️ YAPMA: zemine sahte sokak/bina cizme.
class KonumKarti extends StatelessWidget {
  const KonumKarti({
    super.key,
    required this.baslik,
    required this.enlem,
    required this.boylam,
  });

  /// Yer adi (ters geocoding sonucu). Bos olabilir.
  final String baslik;
  final double enlem;
  final double boylam;

  /// Kart yuksekligi — 16:9'dan basik, cunku icerigi bir goruntu DEGIL.
  static const double kBoy = 148;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final scheme = tema.colorScheme;
    final ad = baslik.isEmpty ? 'Konum' : baslik;
    // ⚠️ 4 ondalik ~11 m hassasiyet: kullanicinin ev adresini gereginden fazla
    //    hassas gostermemek icin BILEREK kirpiliyor (gonderi zaten herkese acik).
    final koordinat =
        '${enlem.toStringAsFixed(4)}, ${boylam.toStringAsFixed(4)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, kYanBosluk, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => KonumServisi.haritadaAc(enlem, boylam),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---- ISARET ALANI
                SizedBox(
                  height: kBoy,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _Halkalar(
                              renk: scheme.primary.withValues(alpha: 0.16),
                            ),
                          ),
                        ),
                        // ⚠️ Pin bir DAIRE icinde: zemin desenli oldugu icin
                        //    ciplak ikon okunmuyordu.
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.primary,
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.28),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            LucideIcons.mapPin,
                            size: 24,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ---- BILGI SATIRI
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ad,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              koordinat,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // ⚠️ Metin + ikon BIRLIKTE: renk tek basina bilgi tasimaz
                      //    ve "yol tarifi" gibi bir vaat verilmiyor — kart
                      //    yalnizca noktayi ACAR.
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Haritada aç',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: scheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pinden yayilan halkalar — **harita degil, konum isareti**.
///
/// ⚠️ Yaricaplar kutunun KISA kenarindan turetilir; sabit sayi yok, dolayisiyla
///    her genislikte ayni gorunur.
class _Halkalar extends CustomPainter {
  const _Halkalar({required this.renk});
  final Color renk;

  @override
  void paint(Canvas canvas, Size size) {
    final merkez = Offset(size.width / 2, size.height / 2);
    final taban = math.min(size.width, size.height) / 2;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true;
    for (var i = 1; i <= 4; i++) {
      final t = i / 4;
      // ⚠️ Disa dogru SOLAR: kenarda sert bir cember birakmaz.
      p.color = renk.withValues(alpha: renk.a * (1.0 - t * 0.7));
      canvas.drawCircle(merkez, taban * (0.42 + t * 0.85), p);
    }
  }

  @override
  bool shouldRepaint(_Halkalar eski) => eski.renk != renk;
}
