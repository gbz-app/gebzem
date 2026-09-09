import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'belge_karti.dart';
import 'medya_gorsel.dart';
import 'tam_ekran_gorsel.dart';
import 'tam_ekran_video.dart';

/// Paylasilan medya kaydi: `id` = media UUID, `tur` = `image` | `video`.
typedef PaylasilanMedya = ({String id, String tur});

/// ⚠️⚠️⚠️ TURU 180ac — **PAYLASILAN MEDYA IZGARASI (TEK KAYNAK)**.
///
/// Kullanici: *"profil ve kanal vs bunlarin profiline tikladigimda galeri
/// vs gorunmuyor, hem kisiselde hem grup kanalda, bunu atliyorsun surekli;
/// profilleri tikladigimda profil detayinda gorunmeli"*.
///
/// ⚠️⚠️ **NEDEN ORTAK BILESEN**: izgara turu 180z'de YALNIZ kanal profiline
///	yazilmisti. Kisi ve grup ekranlarina KOPYALANSAYDI uc kopya
///	kacinilmaz olarak DRIFT ederdi — bu projede "ayni kuralin iki
///	kopyasi" sinifi ALTI kez sahaya cikti (turu 78 dersi). Kanal profili
///	de artik BU dosyayi kullanir; orada kopya KALMADI.
///
/// ⚠️ `shrinkWrap` + `NeverScrollable`: izgara DIS `ListView`in cocugu.
///	Kendi kaydirmasi olsaydi sayfada IKI dikey kaydirma alani olurdu
///	(turu 180j'de olculen "sayfa takiliyor" hatasinin ta kendisi).
class PaylasilanMedyaIzgarasi extends StatelessWidget {
  const PaylasilanMedyaIzgarasi({super.key, required this.medya});

  final List<PaylasilanMedya> medya;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 2),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
    ),
    itemCount: medya.length,
    itemBuilder: (gc, i) {
      final m = medya[i];
      final video = m.tur == 'video';
      return GestureDetector(
        onTap: () => Navigator.of(gc).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) =>
                video ? TamEkranVideo(mediaId: m.id) : TamEkranGorsel(mediaId: m.id),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ⚠️⚠️ VIDEO HUCRESINDE **`yalnizThumb` ZORUNLU**: poster yoksa
            //	`MedyaGorsel` HAM VIDEO adresine duser ve KIRIK GORSEL
            //	cizer (turu 83b). Postersiz videoda koyu kutu + oynat
            //	rozeti gorunur — bu BEKLENEN davranistir.
            if (video) ...[
              ColoredBox(color: Colors.white.withValues(alpha: 0.06)),
              MedyaGorsel(
                mediaId: m.id,
                kucuk: true,
                yalnizThumb: true,
                fit: BoxFit.cover,
              ),
              const Center(child: Icon(LucideIcons.play, size: 26)),
            ] else
              MedyaGorsel(mediaId: m.id, kucuk: true, fit: BoxFit.cover),
          ],
        ),
      );
    },
  );
}

/// Paylasilan medya bolumu: baslik + izgara + (varsa) belgeler.
///
/// ⚠️ Belgeler IZGARAYA KONULMAZ: bir PDF'in kapagi yoktur, ADI okunmalidir.
/// ⚠️⚠️ Bolum, icerik YOKKEN de bir sey soyler ("henüz paylasilmamis") —
///	sessizce hic cizilmemesi kullaniciya "galeri ozelligi yok" gibi
///	gorunurdu ve kullanicinin bu turdaki sikayeti TAM OLARAK buydu.
class PaylasilanMedyaBolumu extends StatelessWidget {
  const PaylasilanMedyaBolumu({
    super.key,
    required this.medya,
    this.belgeler = const [],
    this.bosMetin = 'Bu sohbette henüz fotoğraf veya video paylaşılmamış.',
    this.yukleniyor = false,
  });

  final List<PaylasilanMedya> medya;
  final List<String> belgeler;
  final String bosMetin;
  final bool yukleniyor;

  @override
  Widget build(BuildContext context) {
    final ks = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _baslik(context, 'Paylaşılan medya'),
        if (yukleniyor)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (medya.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: Text(
              bosMetin,
              style: TextStyle(
                fontSize: 13.5,
                color: ks.onSurface.withValues(alpha: 0.55),
              ),
            ),
          )
        else
          PaylasilanMedyaIzgarasi(medya: medya),
        if (belgeler.isNotEmpty) ...[
          const SizedBox(height: 18),
          _baslik(context, 'Belgeler'),
          for (final id in belgeler) BelgeKarti(mediaId: id, kompakt: true),
        ],
        const SizedBox(height: 10),
      ],
    );
  }

  /// ⚠️ Bolum basligi TEK KAYNAK: iki bolum de buradan cizilir ki ileride
  ///	biri degisince oteki geride kalmasin.
  Widget _baslik(BuildContext c, String metin) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
    child: Text(
      metin,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Theme.of(c).colorScheme.onSurface,
      ),
    ),
  );
}
