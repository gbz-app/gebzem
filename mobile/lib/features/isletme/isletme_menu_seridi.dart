import 'package:flutter/material.dart';

import '../medya/medya_gorsel.dart';
import 'isletme_kart.dart' show kKartIcDolgu, kYaricap, kYuzeyGri;
import 'isletme_servisi.dart' show UrunOnizleme;
import 'urun_ekranlari.dart';
import 'urun_servisi.dart' show kurusMetni;

/// ⚠️⚠️⚠️ TURU 180ag — ISLETME KARTININ **ALTINDAKI MENU SERIDI**
///	(kullanici emri: *"altina menuler gelsin menu ekle · sol sag scroll
///	seklinde olsun menuler · menu icinde resim menu ismi ve fiyat"*).
///
/// ═══════════ TURU 181: N+1 **KOKTEN KALKTI** ═══════════
///
/// Ilk yazimda liste ucu urun ADI/GORSELI dondurmuyordu, bu yuzden serit
/// isletme basina AYRI bir `/users/{id}/urunler` istegi atiyordu (turu
/// 17'de kapatilan N+1 sinifi). Bedeli DORT katmanla sinirlanmisti:
/// kapi (`urunSayisi>0`) · tembel yukleme · semafor(4) + tek ucus +
/// onbellek (`urun_onbellek.dart`) · hatada onbellege yazmama.
///
/// Turu 181'de **sunucu ilk 5 urunu liste yanitinda donduruyor**
/// (`isletmeSutunlari` icindeki `json_agg` alt sorgusu). Sonuc:
///   · istek katmani TAMAMEN kalkti (`UrunDeposu` SILINDI),
///   · serit ILK KAREDE dolu ciziliyor — yer tutucu / zıplama YOK,
///   · `logout`ta temizlenecek bir onbellek KALMADI.
///
/// ⚠️ YAPMA: buraya tekrar bir ag istegi ekleme. Ek alan gerekiyorsa
///	sunucudaki `json_build_object` listesine ekle.
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
///	ogeler "duvara carpmis gibi" dururdu.
/// ⚠️ Yukseklik SABIT dp DEGIL, **yazi olceginden turetilir** (turu
///	121/135b/157/173) + 1 dp yuvarlama payi.
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

/// ⚠️ Artik `StatelessWidget`: veri kartla BIRLIKTE geliyor, yuklenecek
///	bir sey YOK. Eski hali `ConsumerStatefulWidget`ti cunku istek
///	atiyordu.
class IsletmeMenuSeridi extends StatelessWidget {
  const IsletmeMenuSeridi({
    super.key,
    required this.isletmeId,
    required this.isletmeAd,
    required this.urunler,
  });

  final String isletmeId;
  final String isletmeAd;
  final List<UrunOnizleme> urunler;

  @override
  Widget build(BuildContext context) {
    // ⚠️ Urun YOKSA serit HIC cizilmez — cagri yeri de ayni kontrolu yapar
    //	ama burada da savunma kapisi var (cagri yeri degisirse bos bir
    //	serit kartin altinda anlamsiz bosluk birakmasin).
    if (urunler.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: kKartIcDolgu),
      child: SizedBox(
        height: menuSeritBoy(context),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: kKartIcDolgu),
          itemCount: urunler.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (c, i) => Center(child: _oge(c, urunler[i])),
        ),
      ),
    );
  }

  Widget _oge(BuildContext c, UrunOnizleme u) {
    final soluk = Theme.of(
      c,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72);
    final olcek = MediaQuery.textScalerOf(c);
    return GestureDetector(
      // ⚠️ **DALGA YOK** — kartin geri kaliyla ayni dil (kullanici emri:
      //    "tikladiginda titreme olmasin").
      behavior: HitTestBehavior.opaque,
      onTap: () => _detayAc(c, u),
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
                // ⚠️ `media_id` = `media_ids[1]` (KAPAK, sunucudan); urun
                //	medyasi `kind:'image'` SABIT oldugu icin video id'si
                //	gelme riski YOK.
                child: (u.mediaId == null)
                    ? ColoredBox(color: kYuzeyGri(c))
                    : MedyaGorsel(
                        mediaId: u.mediaId!,
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
            // ⚠️⚠️ FIYAT BICIMI **TEK KAYNAK** (`kurusMetni`): turu 77b'de
            //	elle `kurus ~/ 100` yazilmis ve 12,50 TL "12 ₺" olarak
            //	KIRPILMISTI.
            // ⚠️ Fiyat 0 ise satir BOS birakilir (kaldirilmaz): "0 TL"
            //	yanlis bilgidir, satirin kalkmasi ise seridi ziplatirdi.
            Text(
              u.fiyatKurus > 0 ? kurusMetni(u.fiyatKurus) : '',
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

  /// ⚠️⚠️⚠️ TURU 181 — DOKUNUS **KATALOGU ACAR**, urun detayini DEGIL.
  ///
  ///	Liste yaniti yalnizca ONIZLEME tasiyor (ad · fiyat · kapak
  ///	gorseli); `UrunDetayEkrani` ise aciklama, bolum, TUM galeri ve
  ///	modul alanlarini bekliyor. Onizleme alanlarindan sahte bir `Urun`
  ///	kurup detaya gecmek, kullaniciya **BOS bir aciklama ve tek
  ///	gorsellik bir galeri** gosterirdi — turu 135'te reddedilen
  ///	uydurma-veri sinifinin ta kendisi.
  ///
  ///	Katalog ekrani ayni verinin TAMAMINI kendi ucundan cekiyor
  ///	(`/users/{id}/urunler`), yani kullanici menunun tamamini GERCEK
  ///	verisiyle goruyor ve oradan istedigi urunun detayina giriyor.
  ///
  /// ⚠️ YAPMA: onizleme alanlarindan `Urun` kurup `UrunDetayEkrani`na verme.
  /// ⚠️ `modul` GECILMEZ -> `Modul.varsayilan`. Modul SUNUCUDAN gelir
  ///	(`Isletme.detay()`) ve liste ucu onu dondurmez; kategoriden
  ///	ISTEMCIDE TAHMIN EDILMEZ (turu 89 karari). Katalog ekrani zaten
  ///	kendi verisini cekerken dogru basligi ogrenir.
  void _detayAc(BuildContext c, UrunOnizleme u) {
    Navigator.of(c).push(
      MaterialPageRoute(
        builder: (_) => UrunKatalogEkrani(
          isletmeId: isletmeId,
          isletmeAd: isletmeAd,
          benimMi: false,
        ),
      ),
    );
  }
}
