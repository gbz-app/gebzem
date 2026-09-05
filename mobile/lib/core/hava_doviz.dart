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
  Future<List<KurGunu>> kurGetir(String kod, {int gun = 14}) async {
    final t = _kurAn;
    if (_kur.isNotEmpty && t != null && DateTime.now().difference(t) < _kurOmru) {
      return _kur[kod] ?? const [];
    }
    await (_kurIsi ??= _kurCek(gun).whenComplete(() => _kurIsi = null));
    return _kur[kod] ?? const [];
  }

  /// Onbellekteki TUM seri (yon oku ve grafik icin).
  List<KurGunu> seri(String kod) => _kur[kod] ?? const [];

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
    final kod = kDovizler[_sira % kDovizler.length];
    final v = HavaDoviz.i.sonKur(kod);
    if (h == null && v == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    // TURU 171c - **%10 BUYUTULDU** (kullanici: *"%10 daha buyut, kucuk
    //	kalmislar"*).
    final yazi = widget.kompakt ? 13.2 : 14.3;
    final ikonBoy = widget.kompakt ? 16.5 : 17.6;
    final p = widget.kompakt ? 8.0 : 11.0;

    Widget kutu({required Widget ic, double? en}) => Padding(
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
              onTap: widget.onTap ??
                  () => havaDovizPanelAc(context,
                      enlem: _konum?.enlem, boylam: _konum?.boylam),
              child: SizedBox(
                width: en,
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: p, vertical: 7),
                  child: ic,
                ),
              ),
            ),
          ),
        );

    final yon = v == null ? 0 : _yon(kod);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (h != null)
          kutu(
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
        if (v != null)
          kutu(
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
                Text(
                  kDovizSimge[kod] ?? '',
                  style: TextStyle(
                      fontSize: yazi + 1,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2BB673)),
                ),
                const SizedBox(width: 4),
                Text(
                  v.toStringAsFixed(2).replaceAll('.', ','),
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

/// TURU 171c — **ORTAK HAVA + KUR PANELI** (her ekrandan cagrilabilir).
///
/// UYARI Onceki surumde panel `yakinimda_ekrani.dart` icinde OZEL bir
///	metottu; anasayfadaki cipler ona ULASAMIYORDU ve dokunus HICBIR
///	SEY YAPMIYORDU (kullanici: *"tikladigimda pencere acilmiyor"*).
///	Artik ortak - tek kaynak, her yerden acilir.
/// UYARI Veri YOKSA acilmaz: bos sayfa "bozuk" izlenimi verirdi.
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
  const _HavaBolumu({required this.hava, this.yer});

  final Hava hava;

  /// Gosterilecek yer adi (null ise yazilmaz).
  final String? yer;

  static const _gun = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

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
        const SizedBox(height: 16),
        // UYARI Yatay kaydirma: 7 gun dar ekranda yan yana SIGMAZ.
        SizedBox(
          height: 104,
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
  int _kod = 0;
  List<KurGunu> _seri = const [];
  int? _secili;

  @override
  void initState() {
    super.initState();
    _getir();
  }

  Future<void> _getir() async {
    final l = await HavaDoviz.i.kurGetir(kDovizler[_kod]);
    if (mounted) setState(() => _seri = l);
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
            for (var k = 0; k < kDovizler.length; k++) ...[
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
                    kDovizAdi[kDovizler[k]] ?? kDovizler[k],
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
        if (g == null)
          const SizedBox(
            height: 150,
            child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else ...[
          Text(
            '${g.deger.toStringAsFixed(4).replaceAll('.', ',')} ₺',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface),
          ),
          Text(
            tarihMetni(g.tarih) + ' · TCMB döviz satış',
            style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 14),
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
