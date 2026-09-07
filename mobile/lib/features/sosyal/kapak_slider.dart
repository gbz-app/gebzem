import 'dart:async';

import 'package:flutter/material.dart';

import '../medya/medya_gorsel.dart';
import 'medya_video.dart';

/// ⚠️⚠️⚠️ TURU 180k — **ISLETME KAPAK SLIDERI** (kullanici emri: *"McDonald's
/// isletmesinin header'ina bu video koy, header slider tarzi; ILK bu video
/// gelsin, 15-20 saniye sonra degissin"*).
///
/// Kapak alaninda birden fazla medya (foto VE video) sirayla gosterilir.
///
/// ⚠️⚠️ **TEK SLAYTTA ZAMANLAYICI KURULMAZ.** Kurulsaydi tek gorselli her
///	isletmede saniyede bir gereksiz `setState` kosardi ve kapak
///	`AnimatedSwitcher` yuzunden surekli kendine gecis yapardi.
///	(Turu 92'de `KategoriSlider`da ayni karar alinmisti.)
///
/// ⚠️⚠️ **`PageView`/KAYDIRMA JESTI YOK — BILINCLI.** Turu 180j'de profil
///	sayfasindaki ic ice kaydirma catismasi (kullanici: *"sayfa yukari
///	asagi TAKILIYOR"*) yeni temizlendi. Kapak, sayfanin EN USTUNDE ve
///	uzerinde geri/hamburger dugmeleri var; oraya yatay bir kaydirma
///	yuzeyi koymak o sinifi geri davet ederdi. Gecis OTOMATIK.
/// ⚠️ YAPMA: buraya `PageView` ya da `onHorizontalDrag*` ekleme.
class KapakSlider extends StatefulWidget {
  const KapakSlider({
    super.key,
    required this.medyaIds,
    required this.turler,
    this.altPay = 10,
  });

  /// Nokta gostergesinin ALTTAN payi.
  ///
  /// ⚠️⚠️ TURU 180k — **SABIT 10 YETMEZ, EMULATORDE OLCULDU.** Kapagin alt
  ///	~52 dp'si avatarin tasmasi ve KOYU SAYFANIN ust kenari tarafindan
  ///	ORTULUYOR (`ProfilBasligi._tasma`); `bottom: 10` ile noktalar tam
  ///	o gorunmez seride dusuyor ve ekranda **HIC gorunmuyorlardi**.
  /// ⚠️ Deger cagri yerinden gelir (`_tasma + 10`): burada sabit yazilsaydi
  ///	`_tasma` degistiginde sessizce yine kaybolurlardi.
  final double altPay;

  /// Sunucudan gelen medya id listesi (`isletmeler.kapak_medyalari`).
  final List<String> medyaIds;

  /// ⚠️⚠️ `medyaIds` ile **BIREBIR HIZALI** tur listesi (`'video'`/`'image'`/
  ///	`'yok'`). Sunucu `unnest(...) WITH ORDINALITY` ile sirayi koruyarak
  ///	uretir (bkz. `isletme/handler.go` Detay serhi).
  ///
  /// ⚠️ Tur bilgisi OLMADAN bir video id'si `MedyaGorsel`e giderdi ve ekranda
  ///	**KIRIK GORSEL** cizilirdi — turu 83b denetiminin profil izgarasinda
  ///	bulup kapattigi hatanin ta kendisi.
  final List<String> turler;

  /// ⚠️ VIDEO slayti neden **18 sn**: kullanici *"15-20 saniye sonra degissin"*
  ///	dedi ve elimizdeki kapak videosu **8,9 sn** (olculdu, ffprobe).
  ///	18 sn = videonun iki tam donusu; 15 ya da 20 saniyede slayt
  ///	videonun ORTASINDA kesilirdi.
  static const videoSuresi = Duration(seconds: 18);

  /// ⚠️ FOTOGRAF slayti **6 sn**: video suresiyle ayni yapilsaydi iki
  ///	fotografli bir kapak 36 saniyede bir donerdi, yani kullanici
  ///	ikinci gorseli pratikte HIC gormezdi.
  static const fotoSuresi = Duration(seconds: 6);

  @override
  State<KapakSlider> createState() => _KapakSliderState();
}

class _KapakSliderState extends State<KapakSlider> {
  int _i = 0;
  Timer? _zamanlayici;

  @override
  void initState() {
    super.initState();
    _kur();
  }

  /// ⚠️⚠️ TURU 92 dersi — `didUpdateWidget` ZORUNLU: isletme detayi AG
  ///	ISTEGIYLE sonradan gelir, yani bu widget once BOS/TEK slaytla
  ///	kurulup sonra dolar. Olmasaydi slider ilk haliyle DONAR
  ///	(zamanlayici hic kurulmaz) ve kapak sabit kalirdi.
  @override
  void didUpdateWidget(covariant KapakSlider eski) {
    super.didUpdateWidget(eski);
    if (eski.medyaIds.length == widget.medyaIds.length &&
        eski.medyaIds.join() == widget.medyaIds.join()) {
      return;
    }
    // ⚠️ Liste degisti: indeks TASARSA kirp (yeni liste daha kisa olabilir).
    if (_i >= widget.medyaIds.length) _i = 0;
    _kur();
  }

  @override
  void dispose() {
    // ⚠️ ZORUNLU: iptal edilmezse OLU bir `State`e `setState` gider ve ekran
    //    kirmizi olur (turu 96i'de sahada yasandi).
    _zamanlayici?.cancel();
    super.dispose();
  }

  void _kur() {
    _zamanlayici?.cancel();
    // ⚠️ TEK (ya da sifir) slaytta zamanlayici KURULMAZ (bkz. sinif serhi).
    if (widget.medyaIds.length < 2) return;
    _zamanlayici = Timer(_sure(_i), _sonraki);
  }

  Duration _sure(int i) =>
      _videoMu(i) ? KapakSlider.videoSuresi : KapakSlider.fotoSuresi;

  bool _videoMu(int i) =>
      i < widget.turler.length && widget.turler[i] == 'video';

  void _sonraki() {
    if (!mounted) return;
    setState(() => _i = (_i + 1) % widget.medyaIds.length);
    _kur();
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.medyaIds;
    if (ids.isEmpty) return const SizedBox.shrink();
    final i = _i.clamp(0, ids.length - 1);
    return Stack(
      fit: StackFit.expand,
      children: [
        // ⚠️⚠️ `AnimatedSwitcher` cocugunu ANAHTARLA ayirir; anahtar
        //    verilmezse ayni tipteki iki widget AYNI SAYILIR ve gecis HIC
        //    oynamaz (yalnizca icerik degisir). Anahtar medya id'sinden.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          child: KeyedSubtree(
            key: ValueKey<String>('kapak-${ids[i]}'),
            child: _slayt(i),
          ),
        ),
        // ⚠️⚠️ TURU 180k — **SAGA HIZALI, ORTADA DEGIL** (emulatorde IKI KEZ
        //	olculdu). Ortalandiginda noktalar AVATARIN TAM ARKASINDA
        //	kaliyordu: avatar da yatayda ortali ve dikeyde tam kapagin alt
        //	kenarina oturuyor, yani "alttan pay ver" duzeltmesi onlari
        //	avatarin merkezine tasidi. Sagda hicbir sey yok — geri oku
        //	SOLDA, yardim/hamburger YUKARIDA.
        if (ids.length > 1)
          Positioned(
            right: 16,
            bottom: widget.altPay,
            // ⚠️ `IgnorePointer`: noktalar SUS, dokunulabilir degil. Aksi
            //    halde kapaga dokunmak isteyen kullanicinin dokunusunu
            //    yutarlardi.
            child: IgnorePointer(child: _noktalar(i, ids.length)),
          ),
      ],
    );
  }

  Widget _slayt(int i) {
    final id = widget.medyaIds[i];
    // ⚠️ Silinmis medya (`'yok'`): ne gorsel ne video cizilir — saydam
    //    birakilir ve ALTTAKI degrade gorunur. Kirik bir kutu cizmekten iyi.
    if (i < widget.turler.length && widget.turler[i] == 'yok') {
      return const SizedBox.shrink();
    }
    if (_videoMu(i)) {
      // ⚠️⚠️ **SESSIZ VE KONTROLSUZ.** Kapak bir dekordur:
      //    · `sesli: false` — profile girer girmez ses patlamasi kabul
      //      edilemez ve iOS'ta ses oturumunu ele gecirip AKTIF ARAMAYI
      //      sagirlastirabilir (turu 77b'de olculen sinif).
      //    · `kontrolGoster: false` — kapagin uzerinde oynat/duraklat
      //      dugmesi geri okuyla ve hamburger menuyle carpisirdi.
      //    · `ilerlemeGoster: false` — kapakta ilerleme cubugu gurultu.
      //    · `dongu: true` — 18 saniyelik slaytta 8,9 sn'lik video iki kez
      //      doner; kapali olsaydi son 9 saniye DONMUS KARE kalirdi.
      return MedyaVideo(
        mediaId: id,
        otoOynat: true,
        dongu: true,
        sesli: false,
        dolgu: BoxFit.cover,
        kontrolGoster: false,
        ilerlemeGoster: false,
      );
    }
    // ⚠️ `kucuk: false` — kapak TAM GENISLIK cizilir; kucuk resim bulanik
    //    cikar (`ProfilBasligi._kapak` ile ayni gerekce).
    return MedyaGorsel(mediaId: id, fit: BoxFit.cover);
  }

  Widget _noktalar(int aktif, int adet) => Row(
        // ⚠️ `min` ZORUNLU: `Positioned(right:)` ile konumlandiginda `Row`
        //    genislik kisiti almaz; `max` olsaydi sinirsiz kisitta PATLARDI.
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var k = 0; k < adet; k++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: k == aktif ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                // ⚠️ Renk TEMADAN DEGIL SABIT: kapak bir FOTOGRAFIN uzerinde
                //    ve fotograf her renkte olabilir. Beyaz + siyah golge,
                //    hem acik hem koyu gorselde okunur (turu 138 pin dersi).
                color: k == aktif
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.45),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 3),
                ],
              ),
            ),
        ],
      );
}
