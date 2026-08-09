import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../sosyal/medya_video.dart';

/// ⚠️⚠️ TURU 80b — TAM EKRAN VIDEO (denetim bulgusu).
///
/// ═══════════════ NEDEN VAR ═══════════════
///
/// Turu 80 gonderi medyasina YUKSEKLIK TAVANI koydu (kullanici emri: *"video
/// resimler cok uzun yukseklikleri"*). Tavan dogru sonucu verdi — kutu artik
/// her cihazda ekranin ~%32'si — ama KACINILMAZ bir bedeli var: kutu artik
/// YATAY (en-boy ~1.36) ve icerik `BoxFit.cover` ile ciziliyor, yani
///
///   · 4:5 dikey fotograf  -> ~%41'i KIRPILIR
///   · 9:16 reels/video    -> ~%58'i KIRPILIR
///
/// FOTOGRAFTA bunun kurtarma yolu VARDI (karta dokun -> `TamEkranGorsel`,
/// `contain` ile kirpilmamis hali). **VIDEODA HICBIR KURTARMA YOLU YOKTU** —
/// yani akista yalniz videonun ORTA SERIDI gorunuyordu ve kullanicinin
/// tamamini gormesinin YOLU YOKTU. Kirpma bilincli bir tercihtir; ERISILEMEZLIK
/// degildir.
///
/// ⚠️⚠️ NEDEN TAM ALANLI `GestureDetector` DEGIL, KOSE DUGMESI:
///    Turu 77b'de olculdu — oynaticinin KENDI tam ekran `GestureDetector`i jest
///    arenasini kazanip ustteki dokunuslari YUTUYOR (video hikayede ileri/geri
///    dokunusu bu yuzden calismiyordu). Videonun USTUNE ikinci bir tam alanli
///    dinleyici koymak ayni cakismayi geri getirir ve ustelik oynat/duraklat
///    dokunusunu da calar. Bu yuzden giris NOKTASAL bir dugmedir.
/// ⚠️ YAPMA: burayi tam alanli dokunusa cevirme.
///
/// ⚠️ `sesli: true` — kullanici BILEREK tam ekrana gecti, sessiz acmak anlamsiz
///    olurdu. Akistaki `sesli: false` kurali DEGISMEZ (orada dokunmadan oynar;
///    burada dokunarak gelinir — turu 76b'nin ses guvenligi gerekcesi bu ekran
///    icin GECERLI DEGIL).
/// ⚠️ `kontrolGoster: true` — oynaticinin kendi kontrolleri BURADA istenir.
class TamEkranVideo extends StatelessWidget {
  const TamEkranVideo({super.key, required this.mediaId, this.kapakMediaId});

  final String mediaId;
  final String? kapakMediaId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: MedyaVideo(
          mediaId: mediaId,
          kapakMediaId: kapakMediaId,
          otoOynat: true,
          sesli: true,
          dolgu: BoxFit.contain,
        ),
      ),
    );
  }
}
