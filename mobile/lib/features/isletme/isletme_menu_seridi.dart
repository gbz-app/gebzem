import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../medya/medya_gorsel.dart';
import 'isletme_kart.dart' show kKartIcDolgu, kYaricap, kYuzeyGri;
import 'urun_detay.dart';
import 'urun_onbellek.dart';
import 'urun_servisi.dart';

/// ⚠️⚠️⚠️ TURU 180ag — ISLETME KARTININ **ALTINDAKI MENU SERIDI**
///	(kullanici emri: *"altina menuler gelsin menu ekle · sol sag scroll
///	seklinde olsun menuler · menu icinde resim menu ismi ve fiyat"*).
///
/// ═══════════ NEDEN AYRI DOSYA ═══════════
/// `isletme_kart.dart` 1000+ satir ve bu projede o dosyalarda uye silmek
/// BES kez komsu uyeyi goturdu. Serit KENDI dosyasinda yasar; karta tek
/// satirla girer, tek satirla cikar.
///
/// ═══════════ N+1 (turu 17) — BILEREK, SINIRLANDIRILMIS ═══════════
/// Liste ucu (`/isletmeler`, `/isletmeler/yakinimda`) urun ADI ve GORSELI
/// **DONDURMUYOR** (olculdu: yalniz `urun_sayisi` + `min_fiyat_kurus`).
/// Menuyu cizmenin TEK yolu isletme basina `/users/{id}/urunler`.
/// Bedeli DORT katmanla sinirlandi:
///   1. **KAPI**: `urunSayisi == 0` ise istek **HIC ATILMAZ** (urunu olmayan
///      isletme cogunlukta — bu tek kapi istek sayisini yariya indiriyor).
///   2. **TEMBEL**: yalniz EKRANA CIZILEN kart ister (`SliverList.builder`
///      gorunmeyen karti kurmaz) -> 60 kayitlik listede ~3-5 istek.
///   3. **SEMAFOR (4) + TEK UCUS + ONBELLEK**: `UrunDeposu` (bkz.
///      `urun_onbellek.dart`).
///   4. **HATA ONBELLEGE YAZILMAZ**: gecici ag hatasi kaliciya donusmez.
///
/// ⏳ **BACKEND TURU:** liste yanitina isletme basina ILK 5 URUN (ad ·
///	fiyat_kurus · ilk media_id) eklenirse BU DOSYA KOMPLE SILINIR.
///
/// ═══════════ YERLESIM TUZAKLARI (uc kez emulatorde olculdu) ═══════════
/// ⚠️⚠️ Oge `Center` ile SARILIR: yatay `ListView` cocuguna DIKEYDE **TIGHT**
///	kisit verir; sarmalsiz oge seridin tam boyuna GERILIR ve `kYaricap`
///	sabit kaldigi icin kose "hap" degil KIRPIK gorunur (turu 96/121d/144).
/// ⚠️ IKINCI bir `Center` KOYMA — loose-bounded kisitta EN BUYUGU alir,
///	gerilme geri gelir (turu 144 olcumu).
/// ⚠️⚠️ Oge kutusuna `Container(alignment:)` VERME: `alignment` cocugu bir
///	`Align`e sarar, `Align` gevsek kisitta EN BUYUGU alir ve yatay
///	`ListView`de genislik kisiti SINIRSIZ oldugu icin bu **SONSUZ GENISLIK**
///	demektir (turu 138/180t — ayni sinif sohbet listesini EKRANDAN SILMISTI).
/// ⚠️ `PageScrollPhysics`/`snap`/`PageView` **YASAK** (turu 76b): o fizik
///	sayfa genisligini viewport'un TAMAMI sanar; esit olmayan ogelerde
///	yaslanma her ogede biraz daha kayar.
/// ⚠️⚠️ Yatay dolgu KARTIN `Column`unda DEGIL **SERIDIN KENDI `padding`inde**
///	(turu 144 dersi): kolonda kalsaydi serit kartin IC kenarinda biter ve
///	ogeler "duvara carpmis gibi" dururdu. Kart bu yuzden dolgusunu ic
///	bloklara devretti.
/// ⚠️ Yukseklik SABIT dp DEGIL, **yazi olceginden turetilir** (turu
///	121/135b/157/173: uygulamanin fontu Roboto DEGIL, satir kutusu daha
///	yuksek) + 1 dp yuvarlama payi.
const double kMenuOgeEn = 108;

/// 4:3 gorsel — `kMenuOgeEn`den TURETILIR, elle yazilmaz.
const double kMenuGorselBoy = kMenuOgeEn * 3 / 4;

const double _kAdPunto = 12;
const double _kAdSatir = 1.2;

/// Serit yuksekligi **TEK KAYNAK**.
///
/// ⚠️ Gorsel yazi olceginden BAGIMSIZ (sabit 4:3); buyuyen tek sey metin.
double menuSeritBoy(BuildContext c) {
  final o = MediaQuery.textScalerOf(c);
  final ad = o.scale(_kAdPunto) * _kAdSatir * 2; // ad DAIMA iki satirlik yer
  final fiyat = o.scale(_kAdPunto) * _kAdSatir;
  return (kMenuGorselBoy + 6 + ad + 2 + fiyat).ceilToDouble() + 1;
}

class IsletmeMenuSeridi extends ConsumerStatefulWidget {
  const IsletmeMenuSeridi({
    super.key,
    required this.isletmeId,
    required this.isletmeAd,
    required this.urunSayisi,
  });

  final String isletmeId;
  final String isletmeAd;

  /// ⚠️⚠️ **KAPI**: sunucunun liste yanitindaki `urun_sayisi`. 0 ise widget
  ///	KURULMAZ (cagri yerinde kontrol edilir) — burada da savunma kapisi
  ///	var ki cagri yeri degisirse istek yine atilmasin.
  final int urunSayisi;

  @override
  ConsumerState<IsletmeMenuSeridi> createState() => _IsletmeMenuSeridiState();
}

class _IsletmeMenuSeridiState extends ConsumerState<IsletmeMenuSeridi> {
  /// `null` = HENUZ YUKLENMEDI (yer tutucu cizilir, kart ZIPLAMAZ).
  /// `[]`   = urun YOK / hata (serit TAMAMEN kalkar).
  List<Urun>? _urunler;

  @override
  void initState() {
    super.initState();
    // ⚠️ Onbellekte HAZIRSA istek ATILMAZ ve ilk karede DOGRU cizilir
    //    (kaydirmada kart yeniden kuruldugunda yer tutucu "yanip sonmesin").
    final hazir = ref.read(urunDeposuProvider).bak(widget.isletmeId);
    if (hazir != null) {
      _urunler = hazir;
    } else if (widget.urunSayisi > 0) {
      _yukle();
    } else {
      _urunler = const [];
    }
  }

  Future<void> _yukle() async {
    // ⚠️ Servis TUM await'lerden ONCE yakalanir: kullanici kaydirirsa State
    //    dispose olur ve `ref.read` `StateError` firlatir (turu 77b).
    final depo = ref.read(urunDeposuProvider);
    final l = await depo.coz(widget.isletmeId);
    if (!mounted) return;
    setState(() => _urunler = l);
  }

  @override
  Widget build(BuildContext context) {
    final l = _urunler;
    // ⚠️ Urun YOKSA serit HIC cizilmez — bos bir serit "menu var ama
    //    yuklenemedi" gibi gorunur ve kartin altinda anlamsiz bosluk birakir.
    if (l != null && l.isEmpty) return const SizedBox.shrink();
    // ⚠️ Yer tutucu adedi `urunSayisi`den turer (tavan 4): gercek sayidan
    //    fazla kutu cizmek "5 menusu var" gibi bir IDDIA olurdu.
    final adet = l?.length ?? widget.urunSayisi.clamp(1, 4);
    return Padding(
      padding: const EdgeInsets.only(bottom: kKartIcDolgu),
      child: SizedBox(
        height: menuSeritBoy(context),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: kKartIcDolgu),
          itemCount: adet,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (c, i) =>
              Center(child: l == null ? _yerTutucu(c) : _oge(c, l[i])),
        ),
      ),
    );
  }

  /// Yukleme sirasindaki kutu — **METIN YOK**, yalniz gorsel alani.
  ///
  /// ⚠️ Sahte ad/fiyat yazilmaz (turu 135 uydurma-veri yasagi); yukseklik
  ///	yine TEK KAYNAKTAN gelir, boylece veri gelince kart ZIPLAMAZ.
  Widget _yerTutucu(BuildContext c) => SizedBox(
    width: kMenuOgeEn,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(kYaricap(kMenuGorselBoy)),
          child: SizedBox(
            width: kMenuOgeEn,
            height: kMenuGorselBoy,
            child: ColoredBox(color: kYuzeyGri(c)),
          ),
        ),
      ],
    ),
  );

  Widget _oge(BuildContext c, Urun u) {
    final soluk = Theme.of(
      c,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72);
    final olcek = MediaQuery.textScalerOf(c);
    return GestureDetector(
      // ⚠️ **DALGA YOK** — kartin geri kaliyla ayni dil (kullanici emri:
      //    "tikladiginda titreme olmasin").
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(c).push(
        MaterialPageRoute(
          // ⚠️⚠️ `modul` GECILMEZ -> `Modul.varsayilan`. Kategoriden modul
          //	TAHMIN EDILMEZ (turu 89 karari): modul SUNUCUDAN gelir ve
          //	liste ucu onu dondurmez. Varsayilanin `alanlar`i BOS oldugu
          //	icin uydurma bir ozellik satiri da cizilmez.
          builder: (_) =>
              UrunDetayEkrani(urun: u, isletmeAd: widget.isletmeAd),
        ),
      ),
      child: SizedBox(
        width: kMenuOgeEn,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(kYaricap(kMenuGorselBoy)),
              child: SizedBox(
                width: kMenuOgeEn,
                height: kMenuGorselBoy,
                // ⚠️⚠️ Gorsel alani **DAIMA** cizilir (medya olmasa da):
                //	kosullu olsaydi kimi oge 81 kimi 0 dp olur ve serit
                //	ZIPLARDI (turu 178 dersi).
                // ⚠️ `width` + `kucuk: true` ZORUNLU: yoksa ham 1600x1600
                //	gorsel TAM COZUNURLUKTE cozulur (~10 MB gecici RAM/oge,
                //	turu 91).
                // ⚠️ `mediaIds.first` = KAPAK; urun medyasi `kind:'image'`
                //	SABIT oldugu icin video id'si gelme riski YOK.
                child: u.mediaIds.isEmpty
                    ? ColoredBox(color: kYuzeyGri(c))
                    : MedyaGorsel(
                        mediaId: u.mediaIds.first,
                        fit: BoxFit.cover,
                        width: kMenuOgeEn,
                        kucuk: true,
                      ),
              ),
            ),
            const SizedBox(height: 6),
            // ⚠️ Ad kutusu SABIT IKI SATIRLIK: tek satirlik adlarda fiyat
            //    yukari kayar ve serit "merdiven" gibi gorunurdu.
            SizedBox(
              height: olcek.scale(_kAdPunto) * _kAdSatir * 2,
              child: Text(
                u.ad,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: _kAdPunto,
                  height: _kAdSatir,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // ⚠️⚠️ FIYAT BICIMI **TEK KAYNAK** (`Urun.fiyatMetni` ->
            //	`kurusMetni`): turu 77b'de elle `kurus ~/ 100` yazilmis ve
            //	12,50 TL "12 ₺" olarak KIRPILMISTI.
            // ⚠️ Fiyat 0 ise satir BOS birakilir (kaldirilmaz): "0 TL"
            //	yanlis bilgidir, satirin kalkmasi ise seridi ziplatirdi.
            Text(
              u.fiyatKurus > 0 ? u.fiyatMetni : '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _kAdPunto,
                height: _kAdSatir,
                fontWeight: FontWeight.w700,
                color: soluk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
