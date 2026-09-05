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
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
  });

  final DateTime tarih;

  /// WMO hava kodu (bkz. [havaMetni]).
  final int kod;
  final double enAz;
  final double enCok;
}

/// Hava durumu yaniti.
class Hava {
  const Hava({
    required this.simdi,
    required this.simdikiKod,
    required this.gunler,
  });

  final double simdi;
  final int simdikiKod;
  final List<HavaGunu> gunler;
}

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

  // ⚠️ Gebze koordinati SABIT: bu uygulama Gebze'ye ozel ve hava kartinda
  //    "Gebze" yazisi da sabit. Kullanicinin GPS'ine baglamak, sehir disinda
  //    "Gebze 24°" yazip YANLIS bilgi vermek olurdu.
  static const double _enlem = 40.8028;
  static const double _boylam = 29.4307;

  Hava? _hava;
  DateTime? _havaAn;
  static const Duration _havaOmru = Duration(minutes: 30);

  final Map<String, List<KurGunu>> _kur = {};
  DateTime? _kurAn;
  // ⚠️ TCMB gunde BIR KEZ (15:30) yayinlar; daha sik cekmek bosuna trafik.
  static const Duration _kurOmru = Duration(hours: 6);

  Future<Hava?>? _havaIsi;
  Future<void>? _kurIsi;

  /// Hava verisi (onbellekli).
  ///
  /// ⚠️ **Ucusta olan istek PAYLASILIR**: iki widget ayni anda cagirirsa
  ///    tek ag istegi gider (turu 91 `medya` semafor dersi).
  Future<Hava?> havaGetir() {
    final t = _havaAn;
    if (_hava != null && t != null && DateTime.now().difference(t) < _havaOmru) {
      return Future.value(_hava);
    }
    return _havaIsi ??= _havaCek().whenComplete(() => _havaIsi = null);
  }

  Future<Hava?> _havaCek() async {
    try {
      final u = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$_enlem&longitude=$_boylam'
        '&current=temperature_2m,weather_code'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min'
        '&timezone=Europe%2FIstanbul&forecast_days=7',
      );
      final y = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        responseType: ResponseType.plain,
      )).getUri<String>(u);
      if (y.statusCode != 200 || y.data == null) return _hava;
      final j = jsonDecode(y.data!) as Map<String, dynamic>;
      final c = j['current'] as Map<String, dynamic>;
      final d = j['daily'] as Map<String, dynamic>;
      final t = (d['time'] as List).cast<String>();
      final kod = (d['weather_code'] as List).cast<num>();
      final maks = (d['temperature_2m_max'] as List).cast<num>();
      final min = (d['temperature_2m_min'] as List).cast<num>();
      final gunler = <HavaGunu>[];
      for (var k = 0; k < t.length; k++) {
        gunler.add(HavaGunu(
          tarih: DateTime.parse(t[k]),
          kod: kod[k].toInt(),
          enAz: min[k].toDouble(),
          enCok: maks[k].toDouble(),
        ));
      }
      _hava = Hava(
        simdi: (c['temperature_2m'] as num).toDouble(),
        simdikiKod: (c['weather_code'] as num).toInt(),
        gunler: gunler,
      );
      _havaAn = DateTime.now();
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
  Future<List<KurGunu>> kurGetir(String kod, {int gun = 14}) async {
    final t = _kurAn;
    if (_kur.isNotEmpty && t != null && DateTime.now().difference(t) < _kurOmru) {
      return _kur[kod] ?? const [];
    }
    await (_kurIsi ??= _kurCek(gun).whenComplete(() => _kurIsi = null));
    return _kur[kod] ?? const [];
  }

  /// Onbellekteki son deger (ag beklemeden okumak icin).
  double? sonKur(String kod) {
    final l = _kur[kod];
    return (l == null || l.isEmpty) ? null : l.last.deger;
  }

  Future<void> _kurCek(int gun) async {
    final bugun = DateTime.now();
    final toplanan = <String, List<KurGunu>>{for (final k in kDovizler) k: []};
    var bulunan = 0;
    // ⚠️ Geriye dogru en fazla `gun * 2` takvim gunu taranir: hafta sonlari
    //    ve tatiller bos gecer, yoksa 14 is gunu icin 14 gun yetmezdi.
    for (var i = 0; i < gun * 2 && bulunan < gun; i++) {
      final g = bugun.subtract(Duration(days: i));
      // ⚠️ Hafta sonu ATLANIR: istek atmadan eleyerek gereksiz 404'u onler.
      if (g.weekday == DateTime.saturday || g.weekday == DateTime.sunday) {
        continue;
      }
      final xml = await _tcmbGun(g);
      if (xml == null) continue;
      bulunan++;
      for (final k in kDovizler) {
        final d = _kurAyikla(xml, k);
        if (d != null) toplanan[k]!.add(KurGunu(tarih: g, deger: d));
      }
    }
    if (bulunan == 0) return; // ⚠️ Onbellek EZILMEZ: bayat veri > bos veri.
    for (final k in kDovizler) {
      // ⚠️ Eskiden yeniye: grafik soldan saga akar.
      _kur[k] = toplanan[k]!.reversed.toList();
    }
    _kurAn = DateTime.now();
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
      final y = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 10),
        responseType: ResponseType.bytes,
        // UYARI 404 ISTISNA FIRLATMASIN: hafta sonu/tatil dosyasi YOKTUR
        //    ve bu NORMAL bir durumdur, hata degil.
        validateStatus: (_) => true,
      )).getUri<List<int>>(u);
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
class HavaDovizCipleri extends StatefulWidget {
  const HavaDovizCipleri({super.key, this.kompakt = false, this.onTap});

  /// Dar yerlesim (anasayfa basligi) — punto ve dolgu kuculur.
  final bool kompakt;
  final VoidCallback? onTap;

  @override
  State<HavaDovizCipleri> createState() => _HavaDovizCipleriDurumu();
}

class _HavaDovizCipleriDurumu extends State<HavaDovizCipleri> {
  Hava? _hava;
  int _sira = 0;
  Timer? _tik;

  @override
  void initState() {
    super.initState();
    _yukle();
    // UYARI 2 sn'de bir SIRADAKI doviz (kullanici emri). `setState`
    //	yalniz veri VARSA cagrilir.
    _tik = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || HavaDoviz.i.sonKur(kDovizler[0]) == null) return;
      setState(() => _sira = (_sira + 1) % kDovizler.length);
    });
  }

  @override
  void dispose() {
    // UYARI Iptal edilmezse OLU State'e setState cagrilir.
    _tik?.cancel();
    super.dispose();
  }

  Future<void> _yukle() async {
    final h = await HavaDoviz.i.havaGetir();
    if (mounted && h != null) setState(() => _hava = h);
    await HavaDoviz.i.kurGetir(kDovizler[0]);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final h = _hava;
    final kod = kDovizler[_sira % kDovizler.length];
    final v = HavaDoviz.i.sonKur(kod);
    if (h == null && v == null) return const SizedBox.shrink();
    final p = widget.kompakt ? 7.0 : 10.0;
    final yazi = widget.kompakt ? 12.0 : 13.0;
    final ikonBoy = widget.kompakt ? 15.0 : 16.0;
    Widget cip(Widget bas, String metin) => Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Material(
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: p, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    bas,
                    const SizedBox(width: 4),
                    Text(
                      metin,
                      style: TextStyle(
                        fontSize: yazi,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (h != null)
          cip(
            Icon(havaIkonu(h.simdikiKod),
                size: ikonBoy, color: const Color(0xFFFFB020)),
            '${h.simdi.round()}°',
          ),
        if (v != null)
          cip(
            // UYARI Simge METIN: Lucide'da TL/€/£ glifi YOK.
            Text(
              kDovizSimge[kod] ?? '',
              style: TextStyle(
                fontSize: yazi + 1,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF2BB673),
              ),
            ),
            v.toStringAsFixed(2).replaceAll('.', ','),
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
