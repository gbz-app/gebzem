/// ⚠️⚠️⚠️ TURU 151 — **ADRES ARAMA + TERS GEOCODING** (kullanici emri:
/// *"rota olustururken arama yok yani SOKAK ADI CADDE"* + *"ben sectigim
/// yerin ADRESI DE gorunmeli neredende ve nereyede"*).
///
/// ⚠️⚠️ **API ANAHTARI YOK, PARA YOK.** Cozum cihazin KENDI geocoder'i:
///	Android `Geocoder`, iOS `CLGeocoder` (`geocoding` 5.0.0 paketi, turu
///	87'de isletme adreslerini pinlemek icin ZATEN eklenmisti). Google
///	Places/Geocoding **web servisi KULLANILMIYOR**: bu repo PUBLIC ve o
///	uclarin anahtari uygulama kimligiyle KISITLANAMIYOR (yalniz IP ile),
///	yani ikiliye gomulen bir anahtar cikarilip baskasi tarafindan
///	harcanabilirdi.
///
/// ⚠️⚠️ **DURUST SINIR — BU BIR "AUTOCOMPLETE" DEGIL.** Cihaz geocoder'i
///	yazarken oneri vermez; TAM(A YAKIN) bir adres ister. "Atatürk Cad"
///	yazan kullaniciya Google Places gibi anlik liste DUSMEZ. Bunun
///	karsiliginda: bedava, anahtarsiz ve sunucu gerektirmiyor.
///	Places'e gecilecekse bu dosyanin IMZASI degismeden arka ucu
///	degistirilebilir (cagri yerleri ETKILENMEZ).
///
/// ⚠️⚠️ **IKI AYRI UC GEREKIYOR** (kaynaktan dogrulandi, `geocoding` 5.0.0):
///	· `locationFromAddress` -> `Location` (enlem/boylam) ama **AD YOK**
///	· `placemarkFromAddress` -> `Placemark` (ad) ama **KOORDINAT YOK**
///	· `placemarkFromCoordinates` -> `Placemark` (ters yon)
///	Yani "arama sonucunu etiketiyle gostermek" icin ONCE koordinat, SONRA
///	o koordinatin ters cozumu gerekiyor. Bu yuzden sonuc sayisi
///	[kEnFazlaAdres] ile SINIRLI: her sonuc ek bir tur demek.
library;

import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:geocoding/geocoding.dart';

import 'ulasim_veri.dart';

/// Arama sonucu — durak ya da adres.
class AdresSonucu {
  const AdresSonucu({
    required this.ad,
    required this.altAd,
    required this.enlem,
    required this.boylam,
    required this.durak,
  });

  /// Birincil satir ("Atatürk Caddesi" ya da "İBRAHİMAĞA CADDESİ").
  final String ad;

  /// Ikincil satir ("Hacı Halil Mah. · Gebze"); bos olabilir.
  final String altAd;

  final double enlem;
  final double boylam;

  /// `true` ise bu bir OTOBUS DURAGI (listede otobus ikonu cizilir).
  final bool durak;
}

/// Adres aramasindan en fazla kac sonuc gosterilecek.
///
/// ⚠️ Her sonuc BIR ek ters-geocoding turu demek (bkz. dosya serhi). 3'un
///    ustune cikmak aramayi gozle gorulur yavaslatir.
const int kEnFazlaAdres = 3;

/// Cihaz geocoder'inin zaman asimi.
///
/// ⚠️⚠️ **ZORUNLU:** Android `Geocoder` AG GEREKTIRIR ve sebekesiz/bogulmus
///	durumda `IOException` firlatmadan UZUN SURE ASILI KALABILIR. Zaman
///	asimi olmasaydi arama kutusu kullaniciya sonsuza kadar "aranıyor"
///	gosterirdi.
const Duration kGeocoderZamanAsimi = Duration(seconds: 6);

class AdresServisi {
  AdresServisi._();
  static final AdresServisi i = AdresServisi._();

  /// ⚠️⚠️⚠️ **KURUCUYA `locale` VERILMEZ — PAKET ONU SESSIZCE DUSURUYOR.**
  ///	Kaynaktan birebir dogrulandi (`geocoding-5.0.0/lib/geocoding.dart`):
  ///
  ///	    Geocoding({Locale? locale})
  ///	        : this._fromPlatformCreationParams(
  ///	              pi.GeocodingCreationParams());
  ///
  ///	Ozel kurucunun `locale` adli parametresi VAR ama genel kurucu
  ///	onu **ILETMIYOR**; sonucta `_locale = null` kaliyor. Yani
  ///	`Geocoding(locale: ...)` yazmak HICBIR SEY YAPMAZ ve adresler
  ///	cihazin yerelinde donerdi.
  /// ⚠️ Bu yuzden yerel **HER CAGRIYA AYRI AYRI** gecilir (asagida).
  static const Locale _yerel = Locale('tr', 'TR');

  final Geocoding _geo = Geocoding();

  final Map<String, List<AdresSonucu>> _aramaOnbellek = {};
  final Map<String, String> _cozOnbellek = {};

  /// Metinle arama — **DURAKLAR + ADRESLER birlikte**.
  ///
  /// ⚠️⚠️ Kullanici emri: *"durak adi arayi NEREYE GIDIYORSUN'dan kaldir"*.
  ///	Duraklar SILINMEDI, ayni kutunun ICINE alindi: kullanici artik tek
  ///	kutuya hem "İBRAHİMAĞA" hem "Atatürk Caddesi" yazabiliyor. Ayri iki
  ///	kutu olsaydi kullanici hangisine ne yazacagini bilemezdi.
  ///
  /// ⚠️ Duraklar ONCE gelir: bu bir TOPLU TASIMA ekrani ve elimizdeki EN
  ///    KESIN veri durak tablosu (2032 kayit, koordinatlari dogrulanmis).
  ///
  /// ⚠️⚠️ **YEREL ONYARGI (Gebze) BILINCLI:** Turkiye'de "Atatürk Caddesi"
  ///	her ilcede var; ciplak sorgu Ankara'yi dondurebilir. Bu yuzden once
  ///	`"<sorgu>, Gebze, Kocaeli"` denenir, BOS donerse CIPLAK sorgu
  ///	denenir (kullanici gercekten baska sehir yaziyorsa o dal calisir).
  ///	⚠️ YAPMA: yalniz ciplak sorguya donme — yerel kullanici yanlis
  ///	   sehirdeki bir caddeye yonlendirilir.
  ///
  /// ⚠️ Hata SESSIZ: geocoder patlarsa DURAK sonuclari yine doner. Adres
  ///    aramasinin cokmesi, calisan durak aramasini goturmemeli.
  Future<List<AdresSonucu>> ara(
    String sorgu, {
    double? yakinEnlem,
    double? yakinBoylam,
  }) async {
    final q = sorgu.trim();
    if (q.length < 2) return const [];

    final anahtar = '$q|${yakinEnlem?.toStringAsFixed(2)}';
    final onbellek = _aramaOnbellek[anahtar];
    if (onbellek != null) return onbellek;

    final sonuc = <AdresSonucu>[];

    // ── 1) DURAKLAR (yerel, anlik) ──
    try {
      final hepsi = await UlasimVeri.i.duraklar();
      final a = sadelestir(q);
      final eslesen = hepsi.where((d) => sadelestir(d.ad).contains(a)).toList();
      if (yakinEnlem != null && yakinBoylam != null) {
        eslesen.sort((x, y) => UlasimVeri.kabaMetre(
                yakinEnlem, yakinBoylam, x.enlem, x.boylam)
            .compareTo(UlasimVeri.kabaMetre(
                yakinEnlem, yakinBoylam, y.enlem, y.boylam)));
      }
      for (final d in eslesen.take(12)) {
        sonuc.add(AdresSonucu(
          ad: d.ad,
          altAd: 'Otobüs durağı',
          enlem: d.enlem,
          boylam: d.boylam,
          durak: true,
        ));
      }
    } catch (_) {
      // Durak tablosu okunamadi — adres dali yine denenir.
    }

    // ── 2) ADRESLER (cihaz geocoder'i) ──
    try {
      var yerler = await _konumlar('$q, Gebze, Kocaeli');
      if (yerler.isEmpty) yerler = await _konumlar(q);
      for (final y in yerler.take(kEnFazlaAdres)) {
        final p = await _placemark(y.latitude, y.longitude);
        final ad = p == null ? q : (_ad(p) ?? q);
        sonuc.add(AdresSonucu(
          ad: ad,
          altAd: p == null ? 'Adres' : _altAd(p),
          enlem: y.latitude,
          boylam: y.longitude,
          durak: false,
        ));
      }
    } catch (_) {
      // Geocoder yok / sebeke yok / bogulmus — adres sonucu OLMAZ, hata
      // GOSTERILMEZ; durak sonuclari zaten listede.
    }

    _aramaOnbellek[anahtar] = sonuc;
    return sonuc;
  }

  /// Ters geocoding: koordinat -> okunabilir adres.
  ///
  /// ⚠️ Kullanici emri: *"ben sectigim yerin ADRESI DE gorunmeli"*. Haritadan
  ///    isaretlenen nokta artik "Seçilen varış" degil gercek adresiyle yazar.
  /// ⚠️ Cozulemezse **null** doner ve cagiran ESKI etiketi korur — ekranda
  ///    bos bir satir birakmak, kaba bir etiketten kotudur.
  Future<String?> coz(double enlem, double boylam) async {
    // ⚠️ Onbellek anahtari ~11 m'ye yuvarlanir (5 ondalik): GPS gurultusu
    //    her karede yeni bir istek uretmesin.
    final anahtar =
        '${enlem.toStringAsFixed(5)},${boylam.toStringAsFixed(5)}';
    final onbellek = _cozOnbellek[anahtar];
    if (onbellek != null) return onbellek;
    try {
      final p = await _placemark(enlem, boylam);
      if (p == null) return null;
      final ad = _ad(p);
      if (ad == null || ad.isEmpty) return null;
      final alt = _altAd(p);
      final metin = alt.isEmpty ? ad : '$ad, $alt';
      _cozOnbellek[anahtar] = metin;
      return metin;
    } catch (_) {
      return null;
    }
  }

  /// Yalniz ONBELLEKTEN okur - **AG ISTEGI ATMAZ, BEKLETMEZ**.
  ///
  /// ⚠️ Sheet acilirken kullanilir: ters geocoding icin bir sayfayi
  ///    BEKLETMEK saniyelerce bos ekran demektir. Onbellekte yoksa null
  ///    doner ve o satir HIC cizilmez.
  String? onbellektenCoz(double enlem, double boylam) =>
      _cozOnbellek[
          '${enlem.toStringAsFixed(5)},${boylam.toStringAsFixed(5)}'];

  Future<List<Location>> _konumlar(String adres) async {
    try {
      return await _geo
          .locationFromAddress(adres, locale: _yerel)
          .timeout(kGeocoderZamanAsimi);
    } catch (_) {
      return const [];
    }
  }

  Future<Placemark?> _placemark(double enlem, double boylam) async {
    try {
      final liste = await _geo
          .placemarkFromCoordinates(enlem, boylam, locale: _yerel)
          .timeout(kGeocoderZamanAsimi);
      return liste.isEmpty ? null : liste.first;
    } catch (_) {
      return null;
    }
  }

  /// Birincil satir: **cadde/sokak + kapi no**.
  ///
  /// ⚠️ Sira ONEMLI: Android'de `thoroughfare` cadde adini, `name` cogu
  ///    zaman TAM ADRES SATIRINI dondurur; iOS'ta `name` bir POI adi
  ///    olabilir. Once cadde denenir ki iki platformda da AYNI seyi yazsin.
  static String? _ad(Placemark p) {
    final cadde = (p.thoroughfare ?? '').trim();
    if (cadde.isNotEmpty) {
      final no = (p.subThoroughfare ?? '').trim();
      return no.isEmpty ? cadde : '$cadde No:$no';
    }
    // ⚠️⚠️ **`street` PLATFORMA GORE BASKA SEY**: Android'de
    //	`getAddressLine(0)`, yani **TAM ADRES SATIRI**; iOS'ta gercek
    //	sokak adi. Bu yuzden yalnizca `thoroughfare` YOKSA yedek
    //	olarak kullanilir ve `name` ondan da SONRA gelir.
    for (final s in [p.street, p.name]) {
      final t = (s ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  /// Ikincil satir: **mahalle · ilce**.
  static String _altAd(Placemark p) {
    final parca = <String>[];
    for (final s in [p.subLocality, p.locality]) {
      final t = (s ?? '').trim();
      // ⚠️ Tekrar ELENIR: bazi cihazlar mahalle ve ilce icin AYNI dizeyi
      //    dondurur ve "Gebze · Gebze" cikar.
      if (t.isNotEmpty && !parca.contains(t)) parca.add(t);
    }
    return parca.join(' · ');
  }

  /// Turkce duyarsiz sadelestirme — **TEK KAYNAK**.
  ///
  /// ⚠️⚠️ `toLowerCase()` TEK BASINA YETMEZ: Dart 'İ' harfini BIRLESIK
  ///	noktali 'i̇'ye cevirir ve "İSTASYON" -> "istasyon" aramasi
  ///	ESLESMEZ (turu 140'ta olculdu).
  static String sadelestir(String s) => s
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}
