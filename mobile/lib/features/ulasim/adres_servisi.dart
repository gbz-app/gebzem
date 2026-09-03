/// ⚠️⚠️⚠️ TURU 151 — **ADRES ARAMA + TERS GEOCODING** (kullanici emri:
/// *"rota olustururken arama yok yani SOKAK ADI CADDE"* + *"ben sectigim
/// yerin ADRESI DE gorunmeli neredende ve nereyede"*).
///
/// ⚠️⚠️⚠️ **TURU 152 — ARKA UC GOOGLE PLACES OLDU (kullanici emri).**
///
///	Kullanici: *"ben 1711 sokak dedigimde GOOGLE ile arama yapip TAM
///	SOKAK CADDEYI bulacak mi"*. Turu 151'de cihazin kendi geocoder'i
///	kullaniliyordu ve **EMULATORDE OLCULDU: bulamiyordu** —
///	"1711 sokak" -> *"Şehit Erdem Demir Caddesi No:49"* (YANLIS).
///	Artik Google Places (New) kullaniliyor ve ayni sorgu
///	*"1711. Sokak · Gaziler, 1711. Sk., 41400 Gebze/Kocaeli"* donuyor
///	(canli sunucuda dogrulandi).
///
/// ⚠️⚠️ **ANAHTAR UYGULAMADA DEGIL — KENDI SUNUCUMUZ VEKIL.**
///	Places bir WEB SERVISI ve Google bu grup icin yalniz **IP**
///	kisitlamasi destekliyor (Maps SDK'daki paket/bundle kisiti YOK).
///	Repo PUBLIC oldugu icin ikiliye gomulen anahtar cikarilip bizim
///	faturamiza harcanirdi. Istemci `GET /yolbul/adres` cagirir;
///	Google'i HIC gormez.
///
/// ⚠️ Bu dosyanin **IMZASI DEGISMEDI**: turu 151'deki serhte
///    *"arka ucu degistirilebilir, cagri yerleri ETKILENMEZ"* yaziyordu
///    ve aynen oyle oldu — `rota_sayfalari.dart` hic degismedi.
///
/// ⚠️⚠️ **CIHAZ GEOCODER'I SILINMEDI, YEDEK OLARAK DURUYOR**:
///	sunucu/ag erisilemezse ya da `GOOGLE_SERVIS_KEY` yoksa (uc 503
///	doner) arama yine calisir — yalnizca daha kaba sonucla. Ozelligin
///	tamamen olmesindense kaba sonuc iyidir.
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
import 'dart:math' as math;

import 'package:dio/dio.dart';
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
    this.yerId,
    this.mesafeM,
  });

  /// ⚠️⚠️⚠️ Google **place id**. DOLU ise **KOORDINAT HENUZ YOK**
  ///	([enlem]/[boylam] **0**'dir) ve secim aninda [yerCoz] ile
  ///	cozulmek ZORUNDADIR.
  ///
  ///	Sebep: Autocomplete koordinat DONDURMEZ. Koordinati her
  ///	oneri icin cekmek, her harfte 5 Place Details cagrisi
  ///	demekti; yalniz SECIM icin cekiliyor.
  /// ⚠️ **YAPMA: `yerId` doluyken `enlem`/`boylam` ile cizim/rota yapma**
  ///    — (0,0) Gine Korfezi'dir (bu projede turu 90b'de yasandi).
  final String? yerId;

  /// Kullanicinin konumuna uzaklik (metre). Yalnizca sunucuya konum
  /// gonderildiyse dolar (Google `origin` olmadan `distanceMeters`
  /// dondurmuyor).
  final int? mesafeM;

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

  /// ⚠️⚠️ **API ISTEMCISI DISARIDAN BAGLANIR** (`main.dart` acilista
  ///	bir kez). Servis bir singleton (`i`) ve `ConsumerState` degil;
  ///	`apiProvider`a baska turlu ulasamiyor.
  /// ⚠️ **Ref DEGIL FONKSIYON alinir**: `ConsumerState` icindeki `ref`
  ///    bir `WidgetRef`tir, `Ref` DEGIL. Fonksiyon almak ikisini de
  ///    kabul eder ve bu dosyayi Riverpod tiplerine baglamaz.
  /// ⚠️ Bagli DEGILSE sunucu dali ATLANIR ve cihaz geocoder'ina
  ///    dusulur — ozellik COKMEZ.
  Dio Function()? _apiAl;
  void baglaApi(Dio Function() al) => _apiAl = al;

  Dio? get _api {
    final f = _apiAl;
    if (f == null) return null;
    try {
      return f();
    } catch (_) {
      return null;
    }
  }

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
    String? oturum,
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

    // ── 2) ADRESLER — ONCE SUNUCU (Google Places) ──
    // ⚠️ Sunucu tek istekte hem AD hem ADRES hem KOORDINAT donuyor;
    //    cihaz geocoder'inda bunun icin IKI tur gerekiyordu.
    final sunucudan = await _sunucudanAra(q, yakinEnlem, yakinBoylam, oturum);
    if (sunucudan != null) {
      sonuc.addAll(sunucudan);
      _aramaOnbellek[anahtar] = sonuc;
      return sonuc;
    }

    // ── 3) YEDEK: CIHAZ GEOCODER'I ──
    // ⚠️⚠️ Sunucuya ulasilamadiginda ozellik TAMAMEN olmesin diye
    //	duruyor. Sonuc daha kaba (olculdu: "1711 sokak" yanlis cadde
    //	donduruyor) ama hicbir sey gostermemekten iyidir.
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
  /// ⚠️⚠️ **TERS YON SUNUCUYA TASINMADI — BILINCLI:** cihaz geocoder'i
  ///	koordinattan adres uretmede IYI (olculdu: "İbrahim Ağa Caddesi
  ///	No:35, Mustafa..."), UCRETSIZ ve CEVRIMDISI onbellekli.
  ///	Zayif oldugu yon METINDEN koordinat bulmaktı; o taraf Google'a
  ///	gecti. Ters yonu de Google'a vermek her harita dokunusunu
  ///	FATURAYA cevirirdi.
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

  /// ⚠️⚠️⚠️ Secilen onerinin **KOORDINATINI** cozer (Place Details).
  ///
  /// `null` = cozulemedi. Cagiran taraf o secimi **KABUL ETMEMELI**:
  /// koordinatsiz bir varis noktasi (0,0) demektir.
  ///
  /// ⚠️ [oturum] AYNI jeton olmali: Google, autocomplete isteklerini
  ///    kapatan Details cagrisini o jetonla eslestirip TEK oturum
  ///    sayiyor. Farkli/eksik jeton = her istek AYRI faturalanir.
  Future<({double enlem, double boylam})?> yerCoz(
    String yerId, {
    String? oturum,
  }) async {
    final api = _api;
    if (api == null || yerId.isEmpty) return null;
    try {
      final y = await api.get<Map<String, dynamic>>(
        '/yolbul/yer',
        queryParameters: {
          'id': yerId,
          if (oturum != null) 'oturum': oturum,
        },
      );
      final en = (y.data?['enlem'] as num?)?.toDouble();
      final boy = (y.data?['boylam'] as num?)?.toDouble();
      if (en == null || boy == null) return null;
      // ⚠️ (0,0) GECERSIZ sayilir — Gine Korfezi.
      if (en == 0 && boy == 0) return null;
      return (enlem: en, boylam: boy);
    } catch (_) {
      return null;
    }
  }

  /// Yeni autocomplete **oturum jetonu** (UUID v4 bicimi).
  ///
  /// ⚠️⚠️ Kullanici yazmaya baslayinca URETILIR ve **SECIMDEN SONRA
  ///	ATILIR**. Ayni jeton tekrar kullanilirsa Google oturumu
  ///	GECERSIZ sayar ve *"the requests are charged as if no
  ///	session token was provided"* — yani tum istekler oturumsuz
  ///	fiyattan faturalanir.
  /// ⚠️ Paket EKLENMEDI: tek bir UUID icin bagimlilik almak yerine
  ///    `Random.secure` ile uretiliyor (bicim yeterli, kriptografik
  ///    bir iddia tasimiyor).
  static String yeniOturum() {
    final r = math.Random.secure();
    String h(int n) => List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${h(8)}-${h(4)}-4${h(3)}-${'89ab'[r.nextInt(4)]}${h(3)}-${h(12)}';
  }

  /// Yalniz ONBELLEKTEN okur - **AG ISTEGI ATMAZ, BEKLETMEZ**.
  ///
  /// ⚠️ Sheet acilirken kullanilir: ters geocoding icin bir sayfayi
  ///    BEKLETMEK saniyelerce bos ekran demektir. Onbellekte yoksa null
  ///    doner ve o satir HIC cizilmez.
  String? onbellektenCoz(double enlem, double boylam) =>
      _cozOnbellek[
          '${enlem.toStringAsFixed(5)},${boylam.toStringAsFixed(5)}'];

  /// Sunucudaki Places vekilinden arar.
  ///
  /// ⚠️ **`null` = "sunucu kullanilamadi"**, bos liste = "sunucu
  ///    calisti ama sonuc yok". Ikisi ayri: birincide cihaz geocoder'ina
  ///    DUSULUR, ikincide DUSULMEZ (Google bakti ve bulamadi; cihaz
  ///    geocoder'i daha kotu bir tahmin uretirdi).
  Future<List<AdresSonucu>?> _sunucudanAra(
    String q,
    double? enlem,
    double? boylam,
    String? oturum,
  ) async {
    final api = _api;
    if (api == null) return null;
    try {
      final y = await api.get<Map<String, dynamic>>(
        '/yolbul/adres',
        queryParameters: {
          'q': q,
          if (enlem != null) 'enlem': enlem,
          if (boylam != null) 'boylam': boylam,
          if (oturum != null) 'oturum': oturum,
        },
      );
      final ham = (y.data?['sonuclar'] as List?) ?? const [];
      return [
        for (final e in ham.whereType<Map>())
          // ⚠️⚠️ `yer_id` BOS olan satir ATLANIR: koordinati YOK ve
          //	cozulemez — listede secilince hicbir sey yapmayan
          //	OLU BIR SATIR olurdu.
          if ((e['yer_id'] ?? '').toString().isNotEmpty)
            AdresSonucu(
              ad: (e['ad'] ?? '').toString(),
              altAd: (e['adres'] ?? '').toString(),
              // ⚠️ Koordinat BILEREK 0: Autocomplete dondurmuyor,
              //    secimde `yerCoz` ile aliniyor.
              enlem: 0,
              boylam: 0,
              durak: false,
              yerId: (e['yer_id']).toString(),
              mesafeM: (e['mesafe_m'] as num?)?.toInt(),
            ),
      ];
    } catch (_) {
      // ⚠️ 503 (anahtar yok) ya da ag hatasi -> cihaz geocoder'ina dus.
      return null;
    }
  }

  /// ⚠️⚠️⚠️ **TURU 152 — SOKAKTAN GIDEN YAYA ROTASI** (kullanici emri:
  ///	*"shape guzel ciziyor ama bizim yurume EVLERIN UZERINDEN
  ///	gidiyor, sokak cadde guzel cizmiyor"*).
  ///
  /// Sunucudaki Routes vekilini cagirir; **[null] = rota alinamadi** ve
  /// cagiran taraf KUS UCUSU duz cizgiye duser (ozellik COKMEZ).
  ///
  /// ⚠️ **DURUST SINIR (Google'in kendi uyarisi):** WALK modu BETA ve
  ///    *"might sometimes be missing clear sidewalks, pedestrian paths"*.
  ///    Ustelik Gebze'de OSM yaya verisi fiilen yok (canli olculdu:
  ///    9.647 yolda 99 kaldirim, 40 isaretli gecit). Yani rota SOKAK
  ///    AGINDAN gider; "karsidan karsiya gecidi" garanti EDILMEZ.
  ///    Sunucu bu uyari metnini yanitta donduruyor.
  ///
  /// ⚠️ Onbellek: ayni bacak her cizimde yeniden faturalanmasin.
  /// ⚠️⚠️⚠️ TURU 158 - **MESAFE VE SURE DE DONER.**
  ///
  ///	Kullanici sahada gordu: rota OZETI *"...duragina yuru **5 dk**"*
  ///	derken adim ekrani AYNI BACAK icin *"**9 dk · 677 m** kaldi"*
  ///	diyordu. Kullanici: *"hesaplamalar duzgun yapilmali, mesafe
  ///	rota hesaplamalari"*.
  ///
  /// ⚠️⚠️ **KOK NEDEN:** bu fonksiyon sunucunun donen `mesafe_m` ve
  ///	`sure_sn` alanlarini **ATIYORDU** (yalniz `noktalar` okunuyordu).
  ///	Bacagin `dakika`/`metre`si KUS UCUSU tahmininde kaliyor, ama
  ///	takip ekrani kalan mesafeyi GERCEK polyline'dan olcuyordu -
  ///	yani ayni bacak icin ekranda IKI FARKLI sayi.
  ///	Ekrandan olculdu: gercek/kus-ucusu orani **~1,74**.
  /// ⚠️ Sunucu bu alanlari ZATEN donduruyor (`yolbul/handler.go`),
  ///    yani duzeltme TAMAMEN ISTEMCIDE - backend'e dokunulmadi.
  /// ⚠️ Alanlar gelmezse `null` kalir ve cagiran KUS UCUSU tahminini
  ///    korur; ozellik eski davranisina duser, COKMEZ.
  Future<
      ({
        List<({double enlem, double boylam})> noktalar,
        int? mesafeM,
        int? sureSn,
      })?> yayaRotasi(
    double basEnlem,
    double basBoylam,
    double varEnlem,
    double varBoylam,
  ) async {
    final api = _api;
    if (api == null) return null;
    final ck = '${basEnlem.toStringAsFixed(5)},${basBoylam.toStringAsFixed(5)}>${varEnlem.toStringAsFixed(5)},${varBoylam.toStringAsFixed(5)}';
    final onbellek = _yayaOnbellek[ck];
    if (onbellek != null) return onbellek;
    try {
      final y = await api.post<Map<String, dynamic>>(
        '/yolbul/yaya',
        data: {
          'bas_enlem': basEnlem,
          'bas_boylam': basBoylam,
          'var_enlem': varEnlem,
          'var_boylam': varBoylam,
        },
      );
      final ham = (y.data?['noktalar'] as List?) ?? const [];
      // ⚠️ IKI NOKTADAN AZ ise rota YOK sayilir: tek noktali bir
      //    polyline cizilemez ve duz cizgi daha durust olur.
      if (ham.length < 2) return null;
      final nk = <({double enlem, double boylam})>[
        for (final e in ham)
          if (e is List && e.length >= 2)
            (
              enlem: (e[0] as num).toDouble(),
              boylam: (e[1] as num).toDouble(),
            ),
      ];
      if (nk.length < 2) return null;
      final sonuc = (
        noktalar: nk,
        mesafeM: (y.data?['mesafe_m'] as num?)?.round(),
        sureSn: (y.data?['sure_sn'] as num?)?.round(),
      );
      _yayaOnbellek[ck] = sonuc;
      return sonuc;
    } catch (_) {
      return null;
    }
  }

  final Map<
      String,
      ({
        List<({double enlem, double boylam})> noktalar,
        int? mesafeM,
        int? sureSn,
      })> _yayaOnbellek = {};

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
  /// ⚠️⚠️⚠️ TURU 160 — **GUZERGAH SEKLINI YOLA OTURTUR** (snap to roads).
  ///
  ///	Kullanici: *"otobus rota shape KALDIRIMIN USTUNDE geciyor,
  ///	koselerde kaldirim ustunden geciyor... Yandex'te U donusu
  ///	MUKEMMEL, yolun ortasindan tasmadan gidiyor"*.
  ///
  /// ⚠️⚠️ **KOK NEDEN SEKLIN KABALIGI** (olculdu): belediyenin GTFS
  ///	sekli iki durak arasini ortalama **6 NOKTA** ile ciziyor ve
  ///	guzergahin **%34'u 200 m'den uzun DUZ parcalar** (en uzun tek
  ///	segment 4.070 m). Yol kivrilinca cizgi koseyi KESIYOR: 15 m
  ///	yaricapli virajda 53 m'lik kiris **23,4 m** sapma demek —
  ///	z17'de cizginin yari genisligi 3,6 m, yani GOZLE GORULUR.
  ///
  /// ⚠️⚠️ **SONUC PAKETE GOMULMEZ, SUNUCUDAN GELIR.** Google sartlari
  ///	donen yol koordinatlarini en fazla **30 gun** saklamaya izin
  ///	veriyor ve "yollari dijitallestirmeyi" ACIKCA yasakliyor. Sunucu
  ///	onbellegi 25 gun (bkz. `backend/internal/yolbul/sekil.go`).
  ///	⚠️ YAPMA: bu ciktiyi `assets/ulasim/sekiller.json`a yazma.
  ///
  /// ⚠️⚠️ **FAIL-OPEN**: ag yoksa, sunucu kapaliysa ya da Google hata
  ///	dondururse **ORIJINAL sekil** kullanilir. Ozellik COKMEZ,
  ///	yalnizca kabalasir (`yayaRotasi` ile ayni ilke).
  /// ⚠️ Maliyet: sunucu ICERIK OZETINE gore onbellekler, yani ayni hat
  ///    kac kullanici isterse istesin Google'a BIR KEZ gider. Olculdu:
  ///    202 sekil -> 845 istek; Roads ayda 5.000 cagri ucretsiz.
  Future<String?> sekliOturt(String kod) async {
    final api = _api;
    if (api == null || kod.isEmpty) return null;
    try {
      final r = await api.post<Map<String, dynamic>>(
        '/yolbul/sekil',
        data: {'kod': kod},
      );
      final yeni = (r.data?['kod'] as String?) ?? '';
      if (r.data?['oturtuldu'] == true && yeni.isNotEmpty) return yeni;
    } catch (_) {
      // ⚠️ Sessiz: cagiran ORIJINALI kullanmaya devam eder.
    }
    return null;
  }

  /// Turkce duyarsiz sadelestirme — **TEK KAYNAK**.
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
