// TURU 171 — HAVA DURUMU + DOVIZ (GERCEK VERI).
//
// Kullanici emri: *"aramanin soluna gunes ve derece, sagina dolar olsun;
// dolar euro sterlin ve altin olarak degissin 2 saniyede bir; tikladigimda
// alttan popup acilsin, hava durumu 1 haftalik goster, dolari google piyasa
// gibi sol sag yapinca tarih o gunun dolar degeri, telefon titremesi olsun"*.
//
// ═══════════ ⚠️⚠️⚠️ ONCEKI HAL: SAYILAR UYDURMAYDI ═══════════
//
// Menudeki `24° · Gebze · Örnek` ve `43,20 Dolar · Örnek` kartlari **koda
// gomulu sabitlerdi**; "Örnek" etiketi tam da bu yuzden vardi. Turu 135'te
// kur seridi (`kur_serit.dart`, 1457 satir) **AYNI SEBEPLE SILINMISTI**:
// *"her sayisi uydurmaydi; projede kur/emtia verisi ne tabloda ne bir ucta
// ne de bir dis servis anahtarinda var"*.
//
// Bu dosya o bosluğu **GERCEK VERIYLE** kapatir.
//
// ═══════════ KAYNAKLAR (ikisi de ANAHTARSIZ ve UCRETSIZ) ═══════════
//
//	· **Open-Meteo** — hava. Anahtar YOK, kota YOK, ticari kullanim serbest.
//	  Tek cagride hem ANLIK sicaklik hem **7 GUNLUK** tahmin doner.
//	· **TCMB gunluk kur XML** — doviz. **RESMI** kaynak, anahtar YOK.
//	  Gecmis tarihler ayri adreste durur -> kaydirmali grafik icin BIREBIR
//	  uygun (uydurma seri URETMEK GEREKMEZ).
//
// ⚠️⚠️ **SUNUCUYA DOKUNULMADI** (kural 9): iki kaynak da istemciden
//	dogrudan cagrilabiliyor; backend uc/anahtar/onbellek GEREKMEDI.
//	Google Places/Routes'tan farki bu — orada anahtar IP kisitli oldugu
//	icin sunucu zorunluydu.
//
// ⚠️ **ALTIN YOK — DURUST SINIR.** Kullanici altin da istedi ama TCMB
//	gunluk kur dosyasi altin ICERMEZ ve denenen anahtarsiz kaynaklarin
//	(frankfurter · exchangerate.host · open.er-api) hicbiri XAU vermiyor
//	(olculdu). Uydurma bir gram-altin fiyati yazmak, silinen `kur_serit`in
//	hatasini geri getirmek olurdu. Kaynak bulununca `kDovizler`e eklenir.

import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../features/medya/konum_servisi.dart' show KonumServisi;
import 'theme.dart' show kAiZemin;

// UYARI `http` paketi projede YOK; `dio` ZATEN bagimlilik listesinde.
//	Tek dosya icin yeni paket eklemek pubspec'i sisirirdi.

/// Gosterilecek doviz kodlari — **sirayla doner**.
///
/// ⚠️ `XAU` (altin) BILEREK YOK (bkz. dosya serhi).
const List<String> kDovizler = ['USD', 'EUR', 'GBP'];

/// Doviz kodunun ekranda yazilan adi.
const Map<String, String> kDovizAdi = {
  'USD': 'Dolar',
  'EUR': 'Euro',
  'GBP': 'Sterlin',
};

/// Doviz sembolu.
const Map<String, String> kDovizSimge = {
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
};

/// Bir gunun hava ozeti.
class HavaGunu {
  const HavaGunu({
    required this.tarih,
    required this.kod,
    required this.enAz,
    required this.enCok,
    this.yagisOlasilik = 0,
  });

  final DateTime tarih;

  /// WMO hava kodu (bkz. [havaMetni]).
  final int kod;
  final double enAz;
  final double enCok;

  /// TURU 171f - gunun en yuksek yagis olasiligi (%).
  final int yagisOlasilik;
}

/// Bir saatlik tahmin.
class HavaSaati {
  const HavaSaati({
    required this.saat,
    required this.sicaklik,
    required this.yagisOlasilik,
  });

  final DateTime saat;
  final double sicaklik;
  final int yagisOlasilik;
}

/// Hava durumu yaniti.
class Hava {
  const Hava({
    required this.simdi,
    required this.simdikiKod,
    required this.gunler,
    this.hissedilen,
    this.nem,
    this.ruzgar,
    this.saatler = const [],
  });

  final double simdi;
  final int simdikiKod;
  final List<HavaGunu> gunler;

  /// TURU 171f - **TAM HAVA DURUMU** (kullanici: *"google gibi tam hava
  ///	durumu verecek mi"*). Open-Meteo bunlarin HEPSINI ayni
  ///	cagrida donduruyor; onceden yalnizca sicaklik okunuyordu.
  final double? hissedilen;
  final int? nem;
  final double? ruzgar;

  /// Saat basi tahmin (bugunden itibaren).
  final List<HavaSaati> saatler;
}

/// TURU 172 — **ALTIN TURLERI** (kullanici emri: *"dovizde altin da
/// olmali, gram altina tikladiginda ceyrek vb degerler gorunmeli"*).
///
/// UYARI **TCMB'DE ALTIN YOKTUR** - gunluk kur dosyasi yalniz doviz
///	icerir (olculdu). Ceyrek/yarim/tam altin zaten SERBEST PIYASA
///	fiyatidir: gram altindan HESAPLANAMAZ (isçilik + arz/talep
///	payi vardir). Bu yuzden ayri bir kaynak sart.
/// UYARI Kaynak `finans.truncgil.com/v4` - anahtarsiz, ucretsiz.
///	**GECMIS VERI VERMEZ** (tarihli adres 404 doner), bu yuzden
///	altin GRAFIK degil LISTE olarak gosterilir; uydurma bir seri
///	cizmek yerine gunluk DEGISIM YUZDESI yazilir.
/// UYARI Resmi bir kaynak DEGIL. Alinamazsa altin bolumu HIC cizilmez
///	(doviz tarafi TCMB'den bagimsiz calismaya devam eder).
class AltinTuru {
  const AltinTuru({
    required this.anahtar,
    required this.ad,
    required this.satis,
    required this.degisim,
  });

  final String anahtar;
  final String ad;
  final double satis;

  /// Gunluk degisim yuzdesi (negatif olabilir).
  final double degisim;
}

/// Gosterilecek altin turleri — **SIRA EKRANDAKI SIRADIR**.
///
/// UYARI `ONS` · `BRENT` · `DBITCOIN` BILEREK YOK: kaynak onlari **0**
///	donduruyor (olculdu) ve sifir bir fiyat degil, EKSIK VERIDIR.
const Map<String, String> kAltinTurleri = {
  'GRA': 'Gram altın',
  'CEYREKALTIN': 'Çeyrek altın',
  'YARIMALTIN': 'Yarım altın',
  'TAMALTIN': 'Tam altın',
  'CUMHURIYETALTINI': 'Cumhuriyet altını',
  'ATAALTIN': 'Ata altın',
  'RESATALTIN': 'Reşat altın',
  'HAS': 'Has altın',
  'IKIBUCUKALTIN': 'İkibuçuk altın',
  'BESLIALTIN': 'Beşli altın',
  '18AYARALTIN': '18 ayar altın',
  '14AYARALTIN': '14 ayar altın',
  'GUMUS': 'Gümüş',
};

/// TURU 173 — **GRAFIK ARALIGI** (kullanici emri: *"para vs sag
/// tarafta gunluk haftalik aylik ve yillik gostersin"*).
///
/// Bunlar bir SURE degil, grafikteki **NOKTALARIN PERIYODU**:
///	gunluk  -> son 14 is gunu, her gun bir nokta
///	haftalik-> son 13 hafta, her haftanin CUMA'si
///	aylik   -> son 14 ay, her ayin SON is gunu
///	yillik  -> son 7 yil, her yilin SON is gunu
///
/// ⚠️⚠️ **KAYNAK TEK: TCMB.** ECB tabanli ucretsiz servisler (frankfurter
///	vb.) bir yillik seriyi TEK istekte veriyor ve cok cazip
///	gorunuyordu; KULLANILMADI. Ekranin en buyuk sayisi TCMB
///	**doviz satis** kuru ve altina "TCMB" yaziyor. Grafik baska
///	bir kurumdan gelseydi ayni kartta IKI FARKLI BUYUKLUK yan yana
///	dururdu — turu 165/168'de tam bu yuzden *"saatler uymuyor"*
///	sikayeti alinmisti.
/// ⚠️ ISTEK SAYISI OLCULDU: 20 nokta = **23 istek** (ortalama 1,15;
///	tatile denk gelen nokta icin geriye 1-2 gun deneniyor). Yani
///	yillik grafik bile ~8 istek eder. Gunluk dosyalari 365 kez
///	cekmek YAPILMADI - nokta periyodu tam da bunu onluyor.
enum KurAralik { gunluk, haftalik, aylik, yillik }

/// Aralik dugmelerinin etiketi — **TEK KAYNAK**.
const Map<KurAralik, String> kAralikAdi = {
  KurAralik.gunluk: 'Gün',
  KurAralik.haftalik: 'Hafta',
  KurAralik.aylik: 'Ay',
  KurAralik.yillik: 'Yıl',
};

/// Bir gunun kur degeri.
class KurGunu {
  const KurGunu({required this.tarih, required this.deger});
  final DateTime tarih;

  /// TL karsiligi (TCMB **doviz satis**).
  final double deger;
}

/// WMO hava kodunu Turkce metne cevirir.
///
/// ⚠️ Kod listesi Open-Meteo dokumanindan; bilinmeyen kod icin notr metin
///    doner ("—" degil), yoksa ekranda bosluk gorunurdu.
String havaMetni(int kod) => switch (kod) {
      0 => 'Açık',
      1 => 'Az bulutlu',
      2 => 'Parçalı bulutlu',
      3 => 'Bulutlu',
      45 || 48 => 'Sisli',
      51 || 53 || 55 => 'Çisenti',
      56 || 57 => 'Dondurucu çisenti',
      61 || 63 || 65 => 'Yağmurlu',
      66 || 67 => 'Dondurucu yağmur',
      71 || 73 || 75 => 'Karlı',
      77 => 'Kar taneleri',
      80 || 81 || 82 => 'Sağanak',
      85 || 86 => 'Kar sağanağı',
      95 => 'Gök gürültülü',
      96 || 99 => 'Dolulu fırtına',
      _ => 'Bilinmiyor',
    };

/// Hava ve doviz verisini ceker ve **onbellekler**.
///
/// ⚠️ Singleton: iki tuketici (arama satiri + alttan panel) ayni veriyi
///    kullanir; ikisi ayri istek atsaydi ayni saniyede IKI cagri giderdi.
class HavaDoviz {
  HavaDoviz._();
  static final HavaDoviz i = HavaDoviz._();

  // Konum bilinmiyorsa DUSULECEK nokta (Gebze merkez).
  static const double _varsayilanEnlem = 40.8028;
  static const double _varsayilanBoylam = 29.4307;

  /// TURU 171e — **IZGARA ADIMI (derece)**, ~5,5 km.
  ///
  /// UYARI Ham GPS koordinatiyla onbelleklemek MUMKUN DEGIL: cihaz her
  ///	birkac metrede yeni bir koordinat verir, her biri AYRI anahtar
  ///	olur ve onbellek HIC tutmaz (turu 169'da rota onbelleginde
  ///	birebir ayni hata olculmustu: `%.5f` = 1 m -> isabet ~0).
  /// UYARI 0.05 OLCULEREK secildi: Gebze merkez 22,7° · Cayirova 23,0° ·
  ///	Darica 23,2° · Dilovasi 23,9° — ilceler AYRI hucrelere duser
  ///	ama ayni mahalledeki iki kullanici AYNI hucreyi paylasir.
  /// UYARI Buyutme (0.2 gibi): ilceler tek hucreye duser, fark kaybolur.
  ///	Kucultme (0.01): hucre sayisi patlar, onbellek anlamsizlasir.
  static const double _izgara = 0.05;

  /// Koordinati izgaraya yuvarlar — **onbellek anahtari**.
  static String _hucre(double e, double b) =>
      '${(e / _izgara).round()}:${(b / _izgara).round()}';

  final Map<String, Hava> _havaHucre = {};
  final Map<String, DateTime> _havaHucreAn = {};
  Hava? _hava;
  DateTime? _havaAn;
  static const Duration _havaOmru = Duration(minutes: 30);

  // ⚠️⚠️⚠️ TURU 173 — **TEK VE PAYLASILAN `Dio`** (baglanti havuzu).
  //
  //	Onceden her istek `Dio(BaseOptions(...))` ile YENI bir istemci
  //	yaratiyordu; her yeni istemci kendi `HttpClient`ini kurar, yani
  //	**HER ISTEKTE yeniden DNS + TLS el sikismasi**. Tek dosya
  //	cekilirken gorunmuyordu, ama yillik grafik 7-11 istek attigi an
  //	sahada **30 saniyeden uzun** bir bekleme uretti (emulatorde
  //	goruldu).
  //
  //	OLCULDU (ayni 6 TCMB dosyasi, masaustu):
  //	  sirali + her seferinde yeni baglanti : **6.758 ms**
  //	  paralel + keep-alive                 : **1.090 ms**  (6,2 kat)
  //
  // ⚠️ YAPMA: cagri yerlerinde tekrar `Dio(...)` yaratma. Istek basina
  //	farkli ayar gerekiyorsa `Options` ile ver - o havuzu bozmaz.
  static final Dio _ag = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
  ));

  // TURU 173 - **ARALIK BASINA AYRI ONBELLEK** (kullanici emri: *"para
  //	vs sag tarafta gunluk haftalik aylik ve yillik gostersin"*).
  //	Tek seri tutulsaydi kullanici her sekme degistirdiginde onceki
  //	aralik SILINIR ve geri donuste YENIDEN cekilirdi.
  final Map<KurAralik, Map<String, List<KurGunu>>> _kur = {};
  final Map<KurAralik, DateTime> _kurAn = {};
  final Map<KurAralik, Future<void>> _kurIsi = {};
  // ⚠️ TCMB gunde BIR KEZ (15:30) yayinlar; daha sik cekmek bosuna trafik.
  static const Duration _kurOmru = Duration(hours: 6);

  Future<Hava?>? _havaIsi;

  /// Hava verisi (onbellekli).
  ///
  /// ⚠️ **Ucusta olan istek PAYLASILIR**: iki widget ayni anda cagirirsa
  ///    tek ag istegi gider (turu 91 `medya` semafor dersi).
  /// TURU 171e - **KONUMA DUYARLI** (kullanici sordu: *"konuma gore
  ///	verecek degil mi, yoksa Gebze genel mi"*).
  ///	Onceden SABIT Gebze merkeziydi; Darica'daki kullanici da
  ///	merkezin havasini goruyordu (olculen fark 1,2 °C).
  /// UYARI Koordinat IZGARAYA yuvarlanarak onbelleklenir (bkz. `_izgara`).
  /// UYARI Konum verilmezse Gebze merkeze duser - "konum yok" diye hava
  ///	gostermemek, kullanicinin gordugu tek bilgiyi silmek olurdu.
  Future<Hava?> havaGetir({double? enlem, double? boylam}) {
    final e = enlem ?? _varsayilanEnlem;
    final b = boylam ?? _varsayilanBoylam;
    final h = _hucre(e, b);
    final t = _havaHucreAn[h];
    final onbellek = _havaHucre[h];
    if (onbellek != null &&
        t != null &&
        DateTime.now().difference(t) < _havaOmru) {
      _hava = onbellek;
      return Future.value(onbellek);
    }
    // UYARI Ucusta olan istek PAYLASILIR (ayni hucre icin ikinci cagri
    //    ayni Future'i alir); anahtar hucre bazli.
    return _havaIsi ??=
        _havaCek(e, b, h).whenComplete(() => _havaIsi = null);
  }

  Future<Hava?> _havaCek(double enlem, double boylam, String hucre) async {
    try {
      final u = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$enlem&longitude=$boylam'
        '&current=temperature_2m,apparent_temperature,'
        'relative_humidity_2m,wind_speed_10m,weather_code'
        '&hourly=temperature_2m,precipitation_probability'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,'
        'precipitation_probability_max'
        '&timezone=Europe%2FIstanbul&forecast_days=7',
      );
      final y = await _ag.getUri<String>(
        u,
        options: Options(responseType: ResponseType.plain),
      );
      if (y.statusCode != 200 || y.data == null) return _hava;
      final j = jsonDecode(y.data!) as Map<String, dynamic>;
      final c = j['current'] as Map<String, dynamic>;
      final d = j['daily'] as Map<String, dynamic>;
      final t = (d['time'] as List).cast<String>();
      final kod = (d['weather_code'] as List).cast<num>();
      final maks = (d['temperature_2m_max'] as List).cast<num>();
      final min = (d['temperature_2m_min'] as List).cast<num>();
      // UYARI Alan EKSIK olabilir (model bazi bolgelerde vermez) ->
      //    `?` ile okunur ve yoksa 0 yazilir, cagri COKMEZ.
      final yag = (d['precipitation_probability_max'] as List?)?.cast<num?>();
      final gunler = <HavaGunu>[];
      for (var k = 0; k < t.length; k++) {
        gunler.add(HavaGunu(
          tarih: DateTime.parse(t[k]),
          kod: kod[k].toInt(),
          enAz: min[k].toDouble(),
          enCok: maks[k].toDouble(),
          yagisOlasilik: (yag != null && k < yag.length)
              ? (yag[k]?.toInt() ?? 0)
              : 0,
        ));
      }
      // Saatlik: SIMDIDEN SONRAKI 24 saat.
      // TURU 171f - **GECMIS SAAT TAMAMEN ATLANIR.** Ilk yazimda 1
      //	saatlik tolerans vardi ve emulatorde SU CELISKI gorundu:
      //	ustte anlik **22°**, seritte "Şimdi **26°**" - cunku saat
      //	19:41 iken 19:00 kaydi "simdi" sayiliyordu. Iki farkli
      //	buyukluk ayni etiketle yan yana duruyordu (turu 168'in
      //	"09:20 ama 7 dakika var" hatasiyla AYNI SINIF).
      final saatler = <HavaSaati>[];
      final hh = j['hourly'] as Map<String, dynamic>?;
      if (hh != null) {
        final ht = (hh['time'] as List).cast<String>();
        final hs = (hh['temperature_2m'] as List).cast<num?>();
        final hy = (hh['precipitation_probability'] as List?)?.cast<num?>();
        final simdi = DateTime.now();
        for (var k = 0; k < ht.length && saatler.length < 24; k++) {
          final an = DateTime.parse(ht[k]);
          if (!an.isAfter(simdi)) continue;
          saatler.add(HavaSaati(
            saat: an,
            sicaklik: (hs[k] ?? 0).toDouble(),
            yagisOlasilik:
                (hy != null && k < hy.length) ? (hy[k]?.toInt() ?? 0) : 0,
          ));
        }
      }
      _hava = Hava(
        simdi: (c['temperature_2m'] as num).toDouble(),
        simdikiKod: (c['weather_code'] as num).toInt(),
        gunler: gunler,
        hissedilen: (c['apparent_temperature'] as num?)?.toDouble(),
        nem: (c['relative_humidity_2m'] as num?)?.toInt(),
        ruzgar: (c['wind_speed_10m'] as num?)?.toDouble(),
        saatler: saatler,
      );
      _havaAn = DateTime.now();
      // Hucre onbellegi: baska bir ilceye gecince ESKI deger kullanilmaz.
      _havaHucre[hucre] = _hava!;
      _havaHucreAn[hucre] = _havaAn!;
      return _hava;
    } catch (_) {
      // ⚠️ SESSIZ: hava bir yan bilgi; ag yoksa satir CIZILMEZ, kullaniciya
      //    hata gosterilmez. Bayat deger varsa O kullanilir.
      return _hava;
    }
  }

  /// Son [gun] is gununun kur serisi (bugunden geriye).
  ///
  /// ⚠️ TCMB **hafta sonu ve tatilde YAYIN YAPMAZ**; o gunlerin dosyasi 404
  ///    doner ve seride yer ALMAZ. Bu dogru davranistir: olmayan bir gun icin
  ///    deger uydurmak grafigi yalanci yapardi.
  Future<List<KurGunu>> kurGetir(
    String kod, {
    KurAralik aralik = KurAralik.gunluk,
  }) async {
    final t = _kurAn[aralik];
    final onbellek = _kur[aralik];
    if (onbellek != null &&
        onbellek.isNotEmpty &&
        t != null &&
        DateTime.now().difference(t) < _kurOmru) {
      return onbellek[kod] ?? const [];
    }
    // ⚠️ Ucusta olan istek PAYLASILIR ve **ARALIK BASINADIR**: kullanici
    //    hizli sekme degistirirse ayni aralik iki kez CEKILMEZ, farkli
    //    araliklar ise birbirini BEKLEMEZ.
    await (_kurIsi[aralik] ??=
        _kurCek(aralik).whenComplete(() => _kurIsi.remove(aralik)));
    return _kur[aralik]?[kod] ?? const [];
  }

  final List<AltinTuru> _altin = [];
  DateTime? _altinAn;
  Future<void>? _altinIsi;
  // UYARI Altin gun ici DEGISIR (doviz gibi gunde bir degil) - 15 dk.
  static const Duration _altinOmru = Duration(minutes: 15);

  /// Altin turleri (onbellekli). Bos liste = veri yok.
  Future<List<AltinTuru>> altinGetir() async {
    final t = _altinAn;
    if (_altin.isNotEmpty &&
        t != null &&
        DateTime.now().difference(t) < _altinOmru) {
      return _altin;
    }
    await (_altinIsi ??= _altinCek().whenComplete(() => _altinIsi = null));
    return _altin;
  }

  /// Onbellekteki gram altin (cip icin, ag beklemeden).
  AltinTuru? get gramAltin {
    for (final a in _altin) {
      if (a.anahtar == 'GRA') return a;
    }
    return null;
  }

  Future<void> _altinCek() async {
    try {
      final y = await _ag.get<String>(
        'https://finans.truncgil.com/v4/today.json',
        options: Options(responseType: ResponseType.plain),
      );
      if (y.statusCode != 200 || y.data == null) return;
      final j = jsonDecode(y.data!) as Map<String, dynamic>;
      final yeni = <AltinTuru>[];
      kAltinTurleri.forEach((k, ad) {
        final v = j[k];
        if (v is! Map) return;
        final satis = (v['Selling'] as num?)?.toDouble();
        // UYARI 0 ve null ATLANIR: kaynak bazi kalemleri (ONS, BRENT)
        //    sifir donduruyor ve sifir bir fiyat DEGIL, eksik veridir.
        if (satis == null || satis <= 0) return;
        yeni.add(AltinTuru(
          anahtar: k,
          ad: ad,
          satis: satis,
          degisim: (v['Change'] as num?)?.toDouble() ?? 0,
        ));
      });
      if (yeni.isEmpty) return; // onbellek EZILMEZ
      _altin
        ..clear()
        ..addAll(yeni);
      _altinAn = DateTime.now();
    } catch (_) {
      // SESSIZ: altin bir yan bilgi; alinamazsa bolum cizilmez.
    }
  }

  /// Onbellekteki GUNLUK seri (cipteki yon oku icin).
  ///
  /// ⚠️ Aralik parametresi YOK: cip her zaman GUNCEL degeri ve BIR
  ///	GUNLUK yonu gosterir. Aylik seride "yon" bir ayin degisimi
  ///	olurdu ve cipteki ok baska bir sey anlatirdi.
  List<KurGunu> seri(String kod) => _kur[KurAralik.gunluk]?[kod] ?? const [];

  /// Onbellekteki son deger (ag beklemeden okumak icin).
  double? sonKur(String kod) {
    final l = seri(kod);
    return l.isEmpty ? null : l.last.deger;
  }

  /// Bir araligin hedef TARIHLERI (yeniden eskiye).
  ///
  /// ⚠️ Gelecege dusen hedef BUGUNE cekilir: ayin son gunu henuz
  ///	gelmediyse o ay icin en taze veri BUGUNKUDUR.
  static List<DateTime> _hedefler(KurAralik a) {
    final n = DateTime.now();
    final bugun = DateTime(n.year, n.month, n.day);
    DateTime kirp(DateTime d) => d.isAfter(bugun) ? bugun : d;
    switch (a) {
      case KurAralik.gunluk:
        final l = <DateTime>[];
        var d = bugun;
        // ⚠️ Hafta sonu ISTEK ATILMADAN elenir (TCMB o gun yayin yapmaz).
        while (l.length < 14) {
          if (d.weekday != DateTime.saturday &&
              d.weekday != DateTime.sunday) {
            l.add(d);
          }
          d = d.subtract(const Duration(days: 1));
        }
        return l;
      case KurAralik.haftalik:
        return [
          for (var i = 0; i < 13; i++)
            () {
              final g = bugun.subtract(Duration(days: 7 * i));
              return kirp(g.add(Duration(days: DateTime.friday - g.weekday)));
            }(),
        ];
      case KurAralik.aylik:
        // ⚠️ `DateTime(y, m + 1, 0)` = o ayin SON gunu (Dart tasmayi
        //    kendisi cozer; 0. gun bir onceki ayin sonudur).
        return [
          for (var i = 0; i < 14; i++)
            kirp(DateTime(bugun.year, bugun.month - i + 1, 0)),
        ];
      case KurAralik.yillik:
        return [
          for (var i = 0; i < 7; i++) kirp(DateTime(bugun.year - i, 12, 31)),
        ];
    }
  }

  /// Bir hedef tarih icin TCMB kaydi; tatilse [geri] gun daha dener.
  ///
  /// ⚠️ Hafta sonu DENEME SAYILMAZ (istek de atilmaz): 31 Mayis Pazar
  ///	ise 29 Mayis Cuma'ya ulasmak icin iki 'bedava' adim gerekir.
  Future<({DateTime gun, Map<String, double> kur})?> _nokta(
    DateTime hedef,
    int geri,
  ) async {
    var d = hedef;
    var deneme = 0;
    // ⚠️ `adim` tavani SONSUZ DONGU kapisi: hafta sonu dali `deneme`yi
    //    artirmadigi icin tek basina yeterli bir durma olcutu DEGIL.
    for (var adim = 0; deneme <= geri && adim < 24; adim++) {
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
        d = d.subtract(const Duration(days: 1));
        continue;
      }
      final xml = await _tcmbGun(d);
      if (xml != null) {
        final m = <String, double>{};
        for (final k in kDovizler) {
          final v = _kurAyikla(xml, k);
          if (v != null) m[k] = v;
        }
        if (m.isNotEmpty) return (gun: d, kur: m);
      }
      deneme++;
      d = d.subtract(const Duration(days: 1));
    }
    return null;
  }

  Future<void> _kurCek(KurAralik aralik) async {
    final hedefler = _hedefler(aralik);
    // ⚠️ GUNLUKTE geri deneme YOK (`geri = 0`): hedefler zaten ardisik is
    //    gunleri; tatil gununde bir onceki gune kaysaydik AYNI nokta
    //    iki kez cizilir ve grafik yatay bir basamak uretirdi.
    // ⚠️ 5 gun OLCULEREK secildi: 20 hedefin 20'si en fazla **2 gun**
    //    geride bulundu (yilbasi/bayram dahil). Daha buyuk bir sayi
    //    yalniz gercekten VERI OLMAYAN nokta icin bekleme uretirdi.
    final geri = aralik == KurAralik.gunluk ? 0 : 5;
    final sonuc = <DateTime, Map<String, double>>{};
    // ⚠️ PARALEL ama **6'SAR**: 14-23 istek sirali atilinca ~7 sn suruyordu
    //    (olculdu). Sinirsiz paralel de TCMB'yi gereksiz doverdi. 7 secildi
    for (var i = 0; i < hedefler.length; i += 7) {
      final grup = hedefler.skip(i).take(7);
      final r = await Future.wait(grup.map((h) => _nokta(h, geri)));
      for (final x in r) {
        if (x != null) sonuc[x.gun] = x.kur;
      }
    }
    if (sonuc.isEmpty) return; // ⚠️ Onbellek EZILMEZ: bayat veri > bos veri.
    // ⚠️ Eskiden yeniye: grafik soldan saga akar.
    final gunler = sonuc.keys.toList()..sort();
    final toplanan = <String, List<KurGunu>>{for (final k in kDovizler) k: []};
    for (final g in gunler) {
      for (final k in kDovizler) {
        final d = sonuc[g]![k];
        if (d != null) toplanan[k]!.add(KurGunu(tarih: g, deger: d));
      }
    }
    _kur[aralik] = toplanan;
    _kurAn[aralik] = DateTime.now();
  }

  Future<String?> _tcmbGun(DateTime g) async {
    final yil = g.year.toString();
    final ay = g.month.toString().padLeft(2, '0');
    final gg = g.day.toString().padLeft(2, '0');
    // ⚠️ BUGUN icin `today.xml`: gun ici yayin saatinden (15:30) once tarihli
    //    dosya HENUZ YOKTUR ama `today.xml` bir onceki gunu dondurur.
    final bugunMu = DateTime.now().difference(g).inDays == 0;
    final u = bugunMu
        ? Uri.parse('https://www.tcmb.gov.tr/kurlar/today.xml')
        : Uri.parse('https://www.tcmb.gov.tr/kurlar/$yil$ay/$gg$ay$yil.xml');
    try {
      final y = await _ag.getUri<List<int>>(
        u,
        options: Options(
          responseType: ResponseType.bytes,
          // UYARI 404 ISTISNA FIRLATMASIN: hafta sonu/tatil dosyasi
          //    YOKTUR ve bu NORMAL bir durumdur, hata degil.
          validateStatus: (_) => true,
          // ⚠️ Grafik icin 10-20 istek atiliyor; tek bir yavas dosya
          //    tum grafigi bekletmesin diye burada tavan DAHA DAR.
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      if (y.statusCode != 200 || y.data == null) return null;
      // ⚠️⚠️ **`bodyBytes` + latin1 ZORUNLU**: TCMB dosyasi UTF-8 bildirse de
      //    Turkce adlar (`ISVIÇRE FRANGI`) latin1 baytlariyla gelir; `y.body`
      //    okumak ayristirmayi bozmaz ama isimleri bozar.
      return latin1.decode(y.data!, allowInvalid: true);
    } catch (_) {
      return null;
    }
  }

  /// XML'den bir dovizin **satis** kurunu cikarir.
  ///
  /// ⚠️ Tam XML ayristiricisi KULLANILMADI: dosya sabit bicimli ve tek alan
  ///    okunuyor; `xml` paketi eklemek 1 alan icin gereksiz bagimlilik olurdu.
  /// ⚠️ `ForexSelling` (doviz satis) secildi — bankalarin ve haber
  ///    sitelerinin gosterdigi deger budur.
  double? _kurAyikla(String xml, String kod) {
    final i = xml.indexOf('CurrencyCode="$kod"');
    if (i < 0) return null;
    final kesit = xml.substring(i, (i + 700).clamp(0, xml.length));
    final m = RegExp(r'<ForexSelling>([\d.]+)</ForexSelling>').firstMatch(kesit);
    if (m == null) return null;
    return double.tryParse(m.group(1)!);
  }
}

/// TURU 171b — **ANASAYFADAKI HAVA + DOVIZ CIPLERI** (kullanici emri:
/// *"ANASAYFADA aramanin yanina 2 tane ikon koy: biri hava durumu ikonu
/// ve hava durumu sayisi, yaninda dolar olsun, sterlin euro diye
/// degissin"*).
///
/// UYARI **TEK KAYNAK**: hem anasayfa hem harita ekrani bu widget'i
///	kullanir; ayri ayri yazilsalardi biri degisince oteki geride
///	kalirdi (bu projede ayni sinif ONCE kez yasandi).
/// UYARI Veri YOKSA hicbir sey cizmez (`SizedBox.shrink`): bos kutu
///	"bozuk mu" izlenimi verirdi.
/// TURU 172 — **CIP YUKSEKLIGI TEK KAYNAK.**
///
/// Kullanici emri: *"arama dairesi soldaki altin/hava durumu yuksekligi
/// ile AYNI olsun, ikonu da ona gore ayarla"*. Arama bir `IconButton`
/// idi ve Material varsayilani **48 dp** dayatir; cipler ~32 dp oldugu
/// icin daire gorunur bicimde BUYUKTU.
///
/// UYARI Sabit dp YAZILMADI: yazi olcegi buyudukce cipin ICI buyur ve
///	sabit bir daire ORANTISIZ kalirdi (turu 141/150 dersi). Olcu
///	metin olceginden TURETILIR; ikon da bu boydan turetilir.
double havaCipBoy(BuildContext c, {bool kompakt = false}) {
  final yazi = kompakt ? 13.2 : 14.3;
  final ikon = kompakt ? 16.5 : 17.6;
  final metin = MediaQuery.textScalerOf(c).scale(yazi) * 1.3;
  return (math.max(ikon, metin) + 14).ceilToDouble();
}

class HavaDovizCipleri extends StatefulWidget {
  const HavaDovizCipleri({
    super.key,
    this.kompakt = false,
    this.onTap,
    this.enlem,
    this.boylam,
  });

  /// Dar yerlesim (anasayfa basligi) — punto ve dolgu kuculur.
  final bool kompakt;
  final VoidCallback? onTap;

  /// TURU 171e - kullanicinin konumu (yoksa Gebze merkez).
  final double? enlem;
  final double? boylam;

  @override
  State<HavaDovizCipleri> createState() => _HavaDovizCipleriDurumu();
}

class _HavaDovizCipleriDurumu extends State<HavaDovizCipleri> {
  Hava? _hava;
  int _sira = 0;
  Timer? _tik;

  /// TURU 172 - donguye **ALTIN** da girer (kullanici emri: *"dolar,
  ///	euro, sterlin ve ALTIN olarak degissin"*).
  /// UYARI Altin verisi YOKSA adim ATLANIR (`+1` uygulanmaz): olmayan
  ///	bir kalem icin 2 saniye BOS cip gostermek yerine dongu
  ///	yalniz dovizler uzerinde doner.
  bool get _altinVar => HavaDoviz.i.gramAltin != null;
  int get _adim => kDovizler.length + (_altinVar ? 1 : 0);
  bool get _altinSirasi => _altinVar && _sira == kDovizler.length;

  @override
  void initState() {
    super.initState();
    _yukle();
    // UYARI 2 sn'de bir SIRADAKI doviz (kullanici emri). `setState`
    //	yalniz veri VARSA cagrilir.
    _tik = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || HavaDoviz.i.sonKur(kDovizler[0]) == null) return;
      setState(() => _sira = (_sira + 1) % _adim);
    });
  }

  @override
  void dispose() {
    // UYARI Iptal edilmezse OLU State'e setState cagrilir.
    _tik?.cancel();
    super.dispose();
  }

  ({double enlem, double boylam})? _konum;

  Future<void> _yukle() async {
    // TURU 171e - **KONUM SESSIZCE OKUNUR** (izin DIYALOGU ACILMAZ).
    //	Izin zaten verilmisse kullanicinin bulundugu ilcenin havasi,
    //	verilmemisse Gebze merkez gosterilir. Hava icin izin ISTEMEK
    //	sert bir surtunme olurdu (menudeki `yakinMesafeProvider`
    //	ayni ilkeyi uyguluyor).
    _konum = widget.enlem != null && widget.boylam != null
        ? (enlem: widget.enlem!, boylam: widget.boylam!)
        : await KonumServisi.konumAl(sessiz: true);
    if (!mounted) return;
    final h = await HavaDoviz.i
        .havaGetir(enlem: _konum?.enlem, boylam: _konum?.boylam);
    if (mounted && h != null) setState(() => _hava = h);
    await HavaDoviz.i.kurGetir(kDovizler[0]);
    if (mounted) setState(() {});
    // TURU 172 - altin AYRI kaynaktan; kur beklenmeden istenir ki
    //	dovizler cizilirken altin arka planda hazirlansin.
    await HavaDoviz.i.altinGetir();
    if (mounted) setState(() {});
  }

  /// Bir onceki gune gore yon: +1 yukseldi, -1 dustu, 0 ayni/bilinmiyor.
  ///
  /// UYARI Seri TCMB is gunlerinden; iki kayit yoksa yon IDDIA EDILMEZ
  ///	(0 doner ve ok CIZILMEZ) - uydurma bir yon gostermek yanlis
  ///	bilgi olurdu.
  int _yon(String kod) {
    final l = HavaDoviz.i.seri(kod);
    if (l.length < 2) return 0;
    final f = l.last.deger - l[l.length - 2].deger;
    if (f.abs() < 0.0001) return 0;
    return f > 0 ? 1 : -1;
  }

  @override
  Widget build(BuildContext context) {
    final h = _hava;
    final altin = _altinSirasi ? HavaDoviz.i.gramAltin : null;
    final kod = kDovizler[_sira % kDovizler.length];
    final v = altin != null ? null : HavaDoviz.i.sonKur(kod);
    if (h == null && v == null && altin == null) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    // TURU 171c - **%10 BUYUTULDU** (kullanici: *"%10 daha buyut, kucuk
    //	kalmislar"*).
    final yazi = widget.kompakt ? 13.2 : 14.3;
    final ikonBoy = widget.kompakt ? 16.5 : 17.6;
    final p = widget.kompakt ? 8.0 : 11.0;

    // TURU 172 - her cip KENDI panelini acar (kullanici: *"hava durumu
    //	ile dolar vs AYRI olacak"*).
    Widget kutu({required Widget ic, double? en, VoidCallback? bas}) =>
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Material(
            color: scheme.onSurface.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              // TURU 171c - **DOKUNUS ARTIK PANELI ACAR.** Onceki surumde
              //	`onTap` anasayfada VERILMEMISTI ve cipler OLU
              //	gorunuyordu (kullanici: *"tikladigimda pencere
              //	acilmiyor"*). Varsayilan artik ortak panel.
              onTap: widget.onTap ?? bas,
              child: SizedBox(
                width: en,
                // TURU 172 - yukseklik `havaCipBoy` ILE AYNI KAYNAKTAN;
                //	arama dairesi de onu okuyor (kullanici emri).
                height: havaCipBoy(context, kompakt: widget.kompakt),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: p),
                  child: Center(child: ic),
                ),
              ),
            ),
          ),
        );

    final yon = altin != null
        ? (altin.degisim > 0 ? 1 : (altin.degisim < 0 ? -1 : 0))
        : (v == null ? 0 : _yon(kod));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (h != null)
          kutu(
            bas: () => havaPanelAc(context,
                enlem: _konum?.enlem, boylam: _konum?.boylam),
            ic: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(havaIkonu(h.simdikiKod),
                    size: ikonBoy, color: const Color(0xFFFFB020)),
                const SizedBox(width: 5),
                Text('${h.simdi.round()}°',
                    style: TextStyle(
                        fontSize: yazi,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface)),
              ],
            ),
          ),
        if (v != null || altin != null)
          kutu(
            bas: () => dovizPanelAc(context),
            // TURU 171c - **SABIT GENISLIK** (kullanici: *"dolar euro vs
            //	degisirken sol sag buton kuculme oluyor, o olmasin"*).
            //	Simge ve rakam genisligi paraya gore degisiyordu
            //	("48,32" vs "56,16" vs "65,04") ve kutu her 2
            //	saniyede ZIPLIYORDU. Genislik en genis olasiliga
            //	gore SABITLENDI.
            // TURU 171c - kompakt genislik 104 -> 96: emulatorde 360 dp
            //    ekranda selamlama ("Iyi Gunler") KIRPILIYORDU. 96 dp
            //    en genis olasiligi ("65,04" + ok) hala tasirmadan alir.
            // TURU 171d - 96 -> 88 ve icerik ORTALANDI (kullanici:
            //	*"dolar vs de saginda cok bosluk olmus, azalt"*).
            //	Sabit genislik KALIR (zıplamayi o onluyor) ama artik
            //	icerige daha yakin ve ortali duruyor.
            en: widget.kompakt ? 88 : 110,
            ic: Row(
              mainAxisSize: MainAxisSize.min,
              // UYARI Sabit genislikte icerik SOLA yaslaniyordu ve sagda
              //    bos bir seri kaliyordu (kullanici bunu gordu).
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // TURU 172 - altin sirasinda SIMGE yerine SIKKE IKONU:
                //	altinin TL simgesi yok ve "₺" yazmak onu bir
                //	dovizmis gibi gosterirdi.
                if (altin != null)
                  // TURU 173 - **TEK SIKKE** (kullanici: *"ikon normal
                  //    coin olsun, TEK"*); `coins` IKI sikke cizer.
                  Icon(LucideIcons.circleDollarSign,
                      size: ikonBoy - 1, color: const Color(0xFFFFB020))
                else
                  Text(
                    kDovizSimge[kod] ?? '',
                    style: TextStyle(
                        fontSize: yazi + 1,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2BB673)),
                  ),
                const SizedBox(width: 4),
                Text(
                  // UYARI Altin **KURUSSUZ** yazilir: gram altin dort
                  //    haneli (6.898,85) ve kurusla birlikte SABIT 88 dp
                  //    kutuya SIGMIYOR (olculdu). Kutu genisligini
                  //    buyutmek de olmaz - sabit genislik tam da 2
                  //    saniyelik ZIPLAMAYI onlemek icin var (turu 171c).
                  altin != null
                      ? _KurBolumuDurumu.binlik(altin.satis.round())
                      : v!.toStringAsFixed(2).replaceAll('.', ','),
                  style: TextStyle(
                      fontSize: yazi,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface),
                ),
                // TURU 171c - **YON OKU** (kullanici: *"saginda asagi
                //	yukari ikon olsun, yukseldi azaldi diye"*).
                // UYARI Yon bilinmiyorsa (tek kayit) ok CIZILMEZ.
                if (yon != 0) ...[
                  const SizedBox(width: 3),
                  Icon(
                    yon > 0 ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                    size: ikonBoy - 3,
                    color: yon > 0
                        ? const Color(0xFF2BB673)
                        : const Color(0xFFE0523F),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// WMO koduna gore ikon — **TEK KAYNAK** (cipler ve panel ayni tabloyu okur).
IconData havaIkonu(int kod) => switch (kod) {
      0 || 1 => LucideIcons.sun,
      2 => LucideIcons.cloudSun,
      3 => LucideIcons.cloud,
      45 || 48 => LucideIcons.cloudFog,
      51 || 53 || 55 || 56 || 57 => LucideIcons.cloudDrizzle,
      61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => LucideIcons.cloudRain,
      71 || 73 || 75 || 77 || 85 || 86 => LucideIcons.snowflake,
      95 || 96 || 99 => LucideIcons.cloudLightning,
      _ => LucideIcons.cloud,
    };

/// TURU 172 — **HAVA PANELI** (kullanici emri: *"hava durumu ile dolar
/// vs AYRI olacak"*). Onceden ikisi TEK sayfadaydi; hava icin acan
/// kullanici kur grafigini, kur icin acan hava kartlarini gormek
/// zorunda kaliyordu.
Future<void> havaPanelAc(
  BuildContext context, {
  double? enlem,
  double? boylam,
}) async {
  final h = await HavaDoviz.i.havaGetir(enlem: enlem, boylam: boylam);
  if (h == null || !context.mounted) return;
  await _sayfa(context, (tc) => _HavaBolumu(hava: h));
}

/// TURU 172 — **DOVIZ + ALTIN PANELI** (hava panelinden AYRI).
Future<void> dovizPanelAc(BuildContext context) async {
  await HavaDoviz.i.kurGetir(kDovizler[0]);
  if (!context.mounted) return;
  await _sayfa(context, (tc) => const _KurBolumu());
}

/// Iki panelin ORTAK kabugu — **TEK KAYNAK**.
///
/// UYARI `isScrollControlled` TEK BASINA YETMEZ: tavani kaldirir ama
///	icerigi KAYDIRILABILIR YAPMAZ (turu 114/115c'de iki kez sahaya
///	cikti). Govde `SingleChildScrollView` icinde.
/// UYARI Zorla KOYU tema: panel `kAiZemin` (sabit siyah) uzerinde; acik
///	temada metinler 1.x:1 kontrastla KAYBOLURDU (turu 135c/140).
Future<void> _sayfa(
  BuildContext context,
  Widget Function(BuildContext) govde,
) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kAiZemin,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (bc) => Theme(
        data: ThemeData.dark().copyWith(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: Builder(
          builder: (tc) => SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: govde(tc),
            ),
          ),
        ),
      ),
    );

/// ESKI ortak panel — artik yalnizca geri uyumluluk icin.
///
/// UYARI Onceki surumde panel `yakinimda_ekrani.dart` icinde OZEL bir
///	metottu; anasayfadaki cipler ona ULASAMIYORDU ve dokunus HICBIR
///	SEY YAPMIYORDU (kullanici: *"tikladigimda pencere acilmiyor"*).
///	Artik ortak - tek kaynak, her yerden acilir.
/// UYARI Veri YOKSA acilmaz: bos sayfa "bozuk" izlenimi verirdi.
// ignore: unused_element
Future<void> havaDovizPanelAc(
  BuildContext context, {
  double? enlem,
  double? boylam,
}) async {
  final h = await HavaDoviz.i.havaGetir(enlem: enlem, boylam: boylam);
  if (h == null && HavaDoviz.i.sonKur(kDovizler[0]) == null) return;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: kAiZemin,
    // UYARI `isScrollControlled` TEK BASINA YETMEZ: tavani kaldirir ama
    //	icerigi KAYDIRILABILIR YAPMAZ (turu 114/115c'de iki kez sahaya
    //	cikti). Govde `SingleChildScrollView` icinde.
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (bc) => Theme(
      // UYARI Zorla KOYU tema: panel `kAiZemin` (sabit siyah) uzerinde;
      //    acik temada metinler 1.x:1 kontrastla KAYBOLURDU (turu 135c/140).
      data: ThemeData.dark().copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: Builder(
        builder: (tc) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (h != null) ...[
                  _HavaBolumu(hava: h),
                  const SizedBox(height: 22),
                ],
                const _KurBolumu(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// 7 GUNLUK hava (kullanici emri: *"hava durumu 1 haftalik goster"*).
class _HavaBolumu extends StatelessWidget {
  // ignore: unused_element_parameter
  const _HavaBolumu({required this.hava, this.yer});

  final Hava hava;

  /// Gosterilecek yer adi (null ise yazilmaz).
  final String? yer;

  static const _gun = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  /// Tek bir olcu (ikon + etiket + deger).
  Widget _olcu(BuildContext c, IconData ikon, String etiket, String deger) {
    final scheme = Theme.of(c).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 15, color: scheme.onSurface.withValues(alpha: 0.55)),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(etiket,
                  style: TextStyle(
                      fontSize: 10.5,
                      color: scheme.onSurface.withValues(alpha: 0.55))),
              Text(deger,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(havaIkonu(hava.simdikiKod),
                size: 34, color: const Color(0xFFFFB020)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${hava.simdi.round()}°',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        // UYARI Renk ACIKCA: koyu temanin varsayilan govde
                        //    rengi TAM BEYAZ DEGIL (turu 129/135c).
                        color: scheme.onSurface)),
                Text(
                  // TURU 171e - yer adi SABIT "Gebze" DEGIL: konuma
                  //    duyarli olunca Darica'daki kullaniciya "Gebze"
                  //    yazmak YANLIS bilgi olurdu. Ad verilmezse yalniz
                  //    hava durumu yazilir (bos bir iddia URETILMEZ).
                  (yer ?? '').isEmpty
                      ? havaMetni(hava.simdikiKod)
                      : '${havaMetni(hava.simdikiKod)} · $yer',
                  style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ],
        ),
        // TURU 171f - **OLCU SATIRI** (hissedilen · nem · ruzgar).
        // UYARI Her deger AYRI kontrol edilir: model bazi alanlari
        //    vermeyebilir ve o zaman o parca satira GIRMEZ (bos bir
        //    iddia URETILMEZ).
        if (hava.hissedilen != null || hava.nem != null || hava.ruzgar != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                if (hava.hissedilen != null)
                  _olcu(context, LucideIcons.thermometer, 'Hissedilen',
                      '${hava.hissedilen!.round()}°'),
                if (hava.nem != null)
                  _olcu(context, LucideIcons.droplets, 'Nem',
                      '%${hava.nem}'),
                if (hava.ruzgar != null)
                  _olcu(context, LucideIcons.wind, 'Rüzgâr',
                      '${hava.ruzgar!.round()} km/s'),
              ],
            ),
          ),
        if (hava.saatler.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            // UYARI Yagis satiri kosullu oldugu icin yukseklik ONA GORE:
            //    68 dp iki satiri (saat + derece) rahat alir, ucuncusu
            //    varsa `spaceEvenly` sikistirir - tasma OLMAZ.
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              // UYARI +1: ILK kutu **ANLIK** degerdir (saatlik tahmin
              //    DEGIL). Ikisini karistirmak ustteki buyuk sayiyla
              //    celisen bir "Şimdi" uretiyordu.
              itemCount: hava.saatler.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final simdiMi = i == 0;
                final h = simdiMi ? null : hava.saatler[i - 1];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      simdiMi
                          ? 'Şimdi'
                          : '${h!.saat.hour.toString().padLeft(2, '0')}:00',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface
                              .withValues(alpha: simdiMi ? 1 : 0.65)),
                    ),
                    Text(
                        simdiMi
                            ? '${hava.simdi.round()}°'
                            : '${h!.sicaklik.round()}°',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface)),
                    if (!simdiMi && h!.yagisOlasilik > 0)
                      Text('%${h.yagisOlasilik}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3AA9FF))),
                  ],
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        // UYARI Yatay kaydirma: 7 gun dar ekranda yan yana SIGMAZ.
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: hava.gunler.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final g = hava.gunler[i];
              return Container(
                width: 66,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      i == 0 ? 'Bugün' : _gun[g.tarih.weekday - 1],
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface
                              .withValues(alpha: i == 0 ? 1 : 0.7)),
                    ),
                    Icon(havaIkonu(g.kod),
                        size: 20, color: const Color(0xFFFFB020)),
                    Text('${g.enCok.round()}°',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface)),
                    Text('${g.enAz.round()}°',
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                scheme.onSurface.withValues(alpha: 0.5))),
                    // UYARI Yagis ihtimali 0 ise satir CIZILMEZ: "%0"
                    //    yazmak kutuyu gereksiz kalabaliklastirirdi.
                    if (g.yagisOlasilik > 0)
                      Text('%${g.yagisOlasilik}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3AA9FF))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// KUR GRAFIGI — sol/sag kaydirinca tarih ve o gunun degeri (kullanici emri).
class _KurBolumu extends StatefulWidget {
  const _KurBolumu();

  @override
  State<_KurBolumu> createState() => _KurBolumuDurumu();
}

class _KurBolumuDurumu extends State<_KurBolumu> {
  /// Secili sekme: 0..n-1 doviz, `_altinSekmesi` ise ALTIN.
  int _kod = 0;
  List<KurGunu> _seri = const [];
  int? _secili;
  List<AltinTuru> _altin = const [];

  /// TURU 172 - altin sekmesinin indisi (dovizlerden SONRA).
  int get _altinSekmesi => kDovizler.length;
  bool get _altinMi => _kod == _altinSekmesi;

  /// TURU 173 - secili grafik araligi (kullanici emri).
  KurAralik _aralik = KurAralik.gunluk;

  @override
  void initState() {
    super.initState();
    _getir();
  }

  /// Bayat yanit kapisi icin istek nesli.
  int _istek = 0;

  Future<void> _getir() async {
    final istek = ++_istek;
    if (_altinMi) {
      final a = await HavaDoviz.i.altinGetir();
      if (!mounted || istek != _istek) return;
      setState(() => _altin = a);
      return;
    }
    final l =
        await HavaDoviz.i.kurGetir(kDovizler[_kod], aralik: _aralik);
    // ⚠️ BAYAT YANIT KAPISI: kullanici yanit gelmeden BASKA bir aralik
    //    ya da doviz sectiyse gelen liste ARTIK GECERLI DEGIL. Bu kapi
    //    olmasaydi 'Yil' secilirken gec gelen 'Gun' yaniti grafigi
    //    yanlis veriyle cizerdi (turu 141/144 sinifi).
    if (!mounted || istek != _istek) return;
    setState(() => _seri = l);
  }

  /// Gram altin (serit disinda, USTTE buyuk gosterilir).
  AltinTuru? get _gram {
    for (final a in _altin) {
      if (a.anahtar == 'GRA') return a;
    }
    return null;
  }

  /// Yatay seritteki kalemler — gram HARIC (o zaten ustte).
  List<AltinTuru> get _digerAltin =>
      [for (final a in _altin) if (a.anahtar != 'GRA') a];

  /// Seritteki KISA ad ('Cumhuriyet altını' -> 'Cumhuriyet').
  ///
  /// ⚠️ 132 dp kartta tam adlar kirpiliyordu (emulatorde goruldu:
  ///	*'Cumhuriyet a…'*). Karti genisletmek yerine ad kisaltildi:
  ///	bolumun basligi ZATEN 'Altın' ve her kartta 'altın' yazmak
  ///	bilgi TASIMIYOR.
  /// ⚠️ SIRA ONEMLI: once ' altını', sonra ' altın'. Ters olsaydi
  ///	'Cumhuriyet altını' -> 'Cumhuriyet ı' olurdu.
  /// ⚠️ 'Gümüş' DOKUNULMAZ (altin degil) - degistirilecek ek YOK.
  static String _seritAdi(String ad) =>
      ad.replaceAll(' altını', '').replaceAll(' altın', '');

  /// Serit kartinin yuksekligi.
  ///
  /// ⚠️ SABIT dp YAZILMADI: uc metin satiri var ve yazi olcegi 2.0'da
  ///	sabit bir kutu TASARDI (turu 137/141/150'de olculen sinif).
  /// ⚠️⚠️ SATIR CARPANI **1.45**, 1.3 DEGIL. Ilk yazimda 1.3 kullanildi ve
  ///	emulatorde **"BOTTOM OVERFLOWED BY 4.0 PIXELS"** cikti:
  ///	uygulamanin fontu Roboto DEGIL Google Sans ve satir kutusu
  ///	punto x ~1.44 geliyor (turu 121/135b/157'de olculen ayni
  ///	sinif). Ustune 2 dp pay: `TextPainter` satir yuksekligini
  ///	YUKARI yuvarlar ve carpim tam degeri vermez.
  static double _altinKartBoy(BuildContext c) {
    final o = MediaQuery.textScalerOf(c);
    // ad 11.5 + fiyat 14.5 + degisim 11.5 · dikey dolgu 2x10.
    return ((o.scale(11.5) + o.scale(14.5) + o.scale(11.5)) * 1.45 + 20 + 2)
        .ceilToDouble();
  }

  /// Gunluk degisim rozeti — **TEK KAYNAK** (ust deger ve serit kartlari).
  ///
  /// ⚠️ Degisim 0 ise HICBIR SEY cizilmez: yon bilinmiyorken ok gostermek
  ///	yon IDDIA ETMEK olurdu (cipteki `_yon` ayni ilkeyi uyguluyor).
  static Widget _degisim(double d, {bool buyuk = false}) {
    if (d == 0) return const SizedBox.shrink();
    final arti = d > 0;
    final renk = arti ? const Color(0xFF2BB673) : const Color(0xFFE0523F);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(arti ? LucideIcons.arrowUp : LucideIcons.arrowDown,
            size: buyuk ? 15 : 12, color: renk),
        Text(
          '%${d.abs().toStringAsFixed(2).replaceAll('.', ',')}',
          style: TextStyle(
              fontSize: buyuk ? 14 : 11.5,
              fontWeight: FontWeight.w700,
              color: renk),
        ),
      ],
    );
  }

  /// Binlik ayracli TL metni (6898.85 -> "6.898,85 ₺").
  ///
  /// UYARI `intl` KULLANILMADI: tek bicim icin paket baglamak yerine
  ///	ayrac ELLE konuyor; sonuc Turkce bicimle BIREBIR ayni.
  static String _paraMetni(double v) {
    final tam = v.floor();
    final kur = ((v - tam) * 100).round().toString().padLeft(2, '0');
    return '${binlik(tam)},$kur ₺';
  }

  /// Binlik ayracli tam sayi (6899 -> "6.899"). Cip de bunu okur.
  static String binlik(int t) {
    final b = t.toString();
    final sb = StringBuffer();
    for (var i = 0; i < b.length; i++) {
      if (i > 0 && (b.length - i) % 3 == 0) sb.write('.');
      sb.write(b[i]);
    }
    return sb.toString();
  }

  /// UYARI Titresim YALNIZ nokta DEGISINCE: her piksel hareketinde
  ///	tetiklenseydi surekli titreyen bir telefon olurdu.
  void _sec(double x, double en) {
    if (_seri.isEmpty) return;
    final i =
        ((x / en) * (_seri.length - 1)).round().clamp(0, _seri.length - 1);
    if (i == _secili) return;
    HapticFeedback.selectionClick();
    setState(() => _secili = i);
  }

  /// Grafik araligi hap grubu.
  ///
  /// ⚠️ `mainAxisSize.min` ZORUNLU: bu widget bir `Row`un ESNEK OLMAYAN
  ///	cocugu; sinirsiz genislik kisiti alir ve `max` ile ciziliyorsa
  ///	RenderFlex tasmasi uretir.
  Widget _aralikSecici(ColorScheme scheme) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in KurAralik.values) ...[
            GestureDetector(
              onTap: () {
                if (a == _aralik) return;
                HapticFeedback.selectionClick();
                setState(() {
                  _aralik = a;
                  _secili = null;
                  // ⚠️ Seri BOSALTILIR: eski aralikin noktalari yeni
                  //    etiketle bir an cizilseydi kullanici 'Yıl' yazan
                  //    bir kartta gunluk grafigi gorurdu.
                  _seri = const [];
                });
                _getir();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: a == _aralik
                      ? const Color(0xFF2BB673)
                      : scheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  kAralikAdi[a]!,
                  style: TextStyle(
                    fontSize: 11.5,
                    // ⚠️ Kalinlik SABIT: secili/pasif arasinda degisseydi
                    //    metin genisler ve grup her dokunusta KAYARDI
                    //    (turu 140'ta cip seridinde olculdu).
                    fontWeight: FontWeight.w700,
                    color: a == _aralik ? Colors.white : scheme.onSurface,
                  ),
                ),
              ),
            ),
            if (a != KurAralik.values.last) const SizedBox(width: 5),
          ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final i = _secili ?? (_seri.isEmpty ? 0 : _seri.length - 1);
    final g = _seri.isEmpty ? null : _seri[i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // TURU 172 - dovizler + **ALTIN** sekmesi (kullanici emri).
            for (var k = 0; k <= kDovizler.length; k++) ...[
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _kod = k;
                    _secili = null;
                    _seri = const [];
                  });
                  _getir();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: k == _kod
                        ? const Color(0xFF2BB673)
                        : scheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    k == kDovizler.length
                        ? 'Altın'
                        : (kDovizAdi[kDovizler[k]] ?? kDovizler[k]),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: k == _kod ? Colors.white : scheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),
        // TURU 172 - **ALTIN GRAFIK DEGIL LISTE.** Kaynak gecmis veri
        //	VERMIYOR (tarihli adres 404); uydurma bir seri cizmek
        //	yerine gunluk DEGISIM YUZDESI yazilir.
        // TURU 173 - **DIKEY LISTE -> YATAY SERIT** (kullanici emri:
        //	*"tam sayfa degil, altta gram vs sol sag scroll
        //	olsun"*). 13 kalem alt alta panelin TAMAMINI
        //	kapliyordu; artik gram altin USTTE buyuk, digerleri
        //	yatay kaydirilan kartlarda ve panel doviz sekmesiyle
        //	AYNI yukseklikte kaliyor.
        if (_altinMi) ...[
          if (_altin.isEmpty)
            const SizedBox(
              height: 150,
              child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else ...[
            // Gram altin USTTE, dovizdeki buyuk deger hiyerarsisiyle AYNI.
            if (_gram != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _paraMetni(_gram!.satis),
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface),
                          ),
                        ),
                        Text(
                          'Gram altın · serbest piyasa',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurface
                                  .withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                  _degisim(_gram!.degisim, buyuk: true),
                ],
              ),
              const SizedBox(height: 14),
            ],
            // ⚠️ Yatay serit: gram HARIC digerleri (gram zaten USTTE;
            //    iki kez yazmak ayni sayiyi tekrar ederdi).
            SizedBox(
              height: _altinKartBoy(context),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: _digerAltin.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final a = _digerAltin[i];
                  return Container(
                    width: 132,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // TURU 173 - **TEK SIKKE** (kullanici: *"ikon
                            //    normal coin olsun, TEK"*). Onceki
                            //    `LucideIcons.coins` IKI sikke cizer.
                            const Icon(LucideIcons.circleDollarSign,
                                size: 15, color: Color(0xFFFFB020)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _seritAdi(a.ad),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // ⚠️ `FittedBox`: 'Besli altin' 225.362,08 ₺ eder
                        //    ve 132 dp karta SIGMAZ; kirpmak yerine
                        //    kuculur (ekranin ASIL bilgisi bu sayidir).
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _paraMetni(a.satis),
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface),
                          ),
                        ),
                        _degisim(a.degisim),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ] else ...[
          // TURU 173 - **ARALIK SECICI BUYUK DEGERIN SAGINDA** (kullanici:
          //	*"para vs SAG TARAFTA gunluk haftalik aylik ve yillik
          //	gostersin"*).
          // ⚠️⚠️ Secici **YUKLEME SIRASINDA DA CIZILIR**: yalniz veri
          //	gelince cizilseydi 'Yıl'a basan kullanicinin altinda
          //	secici KAYBOLUR ve (23 istek boyunca) vazgecip geri
          //	donmenin HICBIR YOLU kalmazdi.
          // ⚠️ Tarih satiri ASAGIDA ve TAM GENISLIKTE: ayni satira
          //    konsaydi 360 dp ekranda '04.09.2026 · TCMB döviz satış'
          //    (~175 dp) ile secici (~150 dp) yan yana SIGMAZDI.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: g == null
                    // ⚠️ Bos `SizedBox` yerine METIN: yillik seri 7-11
                    //    istek suruyor ve o sure boyunca kartin sol
                    //    yarisi BOMBOS duruyordu (emulatorde goruldu).
                    ? SizedBox(
                        height: 36,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Yükleniyor…',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${g.deger.toStringAsFixed(4).replaceAll('.', ',')} ₺',
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              _aralikSecici(scheme),
            ],
          ),
          Text(
            g == null
                ? 'TCMB döviz satış'
                : '${tarihMetni(g.tarih)} · TCMB döviz satış',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 14),
          if (g == null)
            const SizedBox(
              height: 130,
              child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
          // UYARI Hem DOKUNUS hem SURUKLEME kabul edilir (Google piyasa deseni).
          LayoutBuilder(
            builder: (_, kisit) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _sec(d.localPosition.dx, kisit.maxWidth),
              onHorizontalDragUpdate: (d) =>
                  _sec(d.localPosition.dx, kisit.maxWidth),
              child: SizedBox(
                height: 130,
                width: double.infinity,
                child: CustomPaint(
                  // UYARI `Size.infinite` ZORUNLU: cocuksuz `CustomPaint`
                  //    varsayilan `Size.zero` alir ve grafik HIC CIZILMEZ
                  //    (turu 156'da olculen tuzak).
                  size: Size.infinite,
                  painter: _KurCizer(
                    seri: _seri,
                    secili: i,
                    cizgi: const Color(0xFF2BB673),
                    izgara: scheme.onSurface.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Tarihi 'GG.AA.YYYY' olarak yazar.
String tarihMetni(DateTime t) =>
    '${t.day.toString().padLeft(2, '0')}.'
    '${t.month.toString().padLeft(2, '0')}.${t.year}';

class _KurCizer extends CustomPainter {
  const _KurCizer({
    required this.seri,
    required this.secili,
    required this.cizgi,
    required this.izgara,
  });

  final List<KurGunu> seri;
  final int secili;
  final Color cizgi;
  final Color izgara;

  @override
  void paint(Canvas canvas, Size size) {
    if (seri.length < 2) return;
    var enAz = seri.first.deger, enCok = seri.first.deger;
    for (final g in seri) {
      if (g.deger < enAz) enAz = g.deger;
      if (g.deger > enCok) enCok = g.deger;
    }
    // UYARI Duz seride (enAz == enCok) sifira bolme olurdu.
    final fark = (enCok - enAz).abs() < 1e-9 ? 1.0 : enCok - enAz;
    final pay = size.height * 0.08;
    Offset nokta(int i) => Offset(
          size.width * (i / (seri.length - 1)),
          size.height -
              pay -
              ((seri[i].deger - enAz) / fark) * (size.height - 2 * pay),
        );
    final yol = Path()..moveTo(nokta(0).dx, nokta(0).dy);
    for (var i = 1; i < seri.length; i++) {
      yol.lineTo(nokta(i).dx, nokta(i).dy);
    }
    final dolgu = Path.from(yol)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      dolgu,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cizgi.withValues(alpha: 0.28), cizgi.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      yol,
      Paint()
        ..color = cizgi
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
    final p = nokta(secili.clamp(0, seri.length - 1));
    canvas.drawLine(Offset(p.dx, 0), Offset(p.dx, size.height),
        Paint()..color = izgara..strokeWidth = 1);
    canvas.drawCircle(p, 6, Paint()..color = Colors.white);
    canvas.drawCircle(p, 4, Paint()..color = cizgi);
  }

  @override
  bool shouldRepaint(_KurCizer o) =>
      o.secili != secili || !listEquals(o.seri, seri);
}
