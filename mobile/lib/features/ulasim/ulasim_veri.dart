/// ⚠️⚠️⚠️ TURU 149 — **TOPLU TASIMA VERISI (GERCEK).**
///
/// Kaynak: KentKart Kocaeli **GTFS** akisi (kullanici verdi). `tools/
/// ulasim_uret.js` betigi ham GTFS'i (2,4 milyon satirlik `stop_times`)
/// Gebze bolgesine indirip `assets/ulasim/` altina kompakt varliklar
/// olarak yaziyor:
///
///   duraklar.json  ~95 KB   2032 durak
///   hatlar.json    ~23 KB   105 hat (kisa/uzun ad · renk · yon basligi)
///   sekiller.json  ~234 KB  202 guzergah (encoded polyline)
///   seferler.json  ~1,7 MB  799.816 kalkis
///   taksi.json     ~5 KB    53 taksi duragi
///
/// ⚠️⚠️ **NEDEN VARLIK, SUNUCU DEGIL:** bu veri gunluk DEGISMEZ (GTFS
///	takvimi 2100'e kadar gecerli) ve toplam ~2 MB. Varlik olarak:
///	  · fatura YOK, sunucu yuku YOK,
///	  · **CEVRIMDISI** calisir,
///	  · durak/hat/saat ANINDA gelir (ag beklemesi yok).
///	⚠️ Saatler guncellenirse betik yeniden kosulur ve YENI SURUM cikilir.
///
/// ⚠️⚠️ **HICBIR SAYI UYDURULMADI.** Bu dosyadaki her durak, her hat, her
///	kalkis saati kullanicinin verdigi resmi GTFS akisindan geliyor.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Bir otobus duragi.
class Durak {
  const Durak({
    required this.id,
    required this.ad,
    required this.enlem,
    required this.boylam,
  });

  final String id;
  final String ad;
  final double enlem;
  final double boylam;
}

/// Bir otobus hatti.
class Hat {
  const Hat({
    required this.id,
    required this.kisaAd,
    required this.uzunAd,
    required this.renk,
    required this.yonBaslik,
    required this.yonSekil,
  });

  final String id;

  /// Hattin numarasi ("563", "G1"...). Kartlarda BUYUK gosterilir.
  final String kisaAd;
  final String uzunAd;

  /// GTFS'ten gelen kurumsal renk ("006633"); bos olabilir.
  final String renk;

  /// yon (0/1) -> "MERKEZ - SANAYI" gibi hedef basligi.
  final Map<int, String> yonBaslik;

  /// yon (0/1) -> guzergah kimligi (`sekiller.json` anahtari).
  final Map<int, String> yonSekil;
}

/// Bir duraktan gecen hattin BIR YONU + o yonun kalkis saatleri.
class DurakHatti {
  const DurakHatti({
    required this.hat,
    required this.yon,
    required this.kalkislar,
  });

  final Hat hat;
  final int yon;

  /// Gece yarisindan itibaren DAKIKA cinsinden, ARTAN sirali.
  /// ⚠️ GTFS'te 24'u asan degerler olabilir (gece yarisini gecen sefer);
  ///    `sonrakiler` bunu ertesi gun olarak dogru yorumlar.
  final List<int> kalkislar;

  /// Verilen dakikadan SONRAKI ilk [adet] kalkis (dakika cinsinden).
  ///
  /// ⚠️⚠️⚠️ TURU 158b - **GECE HATLARI 00:00-04:00 ARASI GORUNMEZDI**
  ///	(yayin oncesi denetim; YUKSEK).
  ///
  ///	GTFS gece yarisini asan seferi **24:xx+** olarak saklar; bu
  ///	varlikta **16.167 kalkis >= 1440** ve bunlarin **16.158**'i
  ///	24:00-05:00 arasi (OLCULDU). Duvar saati ise 0..1439.
  ///	Eski govde `k >= suAnDakika` ile SIRALI listede ILERI dogru
  ///	tariyordu: saat 00:05'te (`suAn = 5`) listenin BASINDAKI
  ///	SABAH kalkislari (330 = 05:30) hemen esliyor ve `adet`
  ///	dolduruluyordu; 24:30 (=1470) gece otobusu listenin SONUNDA
  ///	oldugu icin **HIC GORULMUYORDU**. Ustelik gorulseydi bile
  ///	`varis - suAn` farki 1440 dakika sisip `kToplamSureTavani`
  ///	(150) kapisinda elenecekti.
  ///	Sonuc: 00:00-01:30 arasi rota aramasi **TEK ADAY BILE**
  ///	uretmiyor, 02:30'da uretilenlerin hicbiri gece otobusu degil.
  ///
  /// ⚠️⚠️ **COZUM: SIRALAMA "SIMDIDEN KAC DAKIKA SONRA" ILE YAPILIR.**
  ///	Her kalkis `((k - suAn) mod 1440)` ile bekleme suresine
  ///	cevrilir, EN KISA bekleyenler secilir ve geri donerken
  ///	`suAn + bekleme` yazilir — yani donen deger yine MUTLAK
  ///	dakikadir ve cagiranlarin aritmetigi DEGISMEZ.
  /// ⚠️ Eski "gun sonunda basa don, +1440 ekle" davranisi KORUNUR:
  ///    23:50'de (1430) ilk sefer 05:30 -> bekleme 340 -> 1770 doner.
  /// ⚠️ `mod` iki kez sarilir: Dart'ta `%` negatif sol operandda
  ///    negatif donebilir.
  List<int> sonrakiler(int suAnDakika, {int adet = 3}) {
    if (kalkislar.isEmpty) return const [];
    final bekleme = <int>[];
    for (final k in kalkislar) {
      bekleme.add(((k - suAnDakika) % 1440 + 1440) % 1440);
    }
    bekleme.sort();
    final c = <int>[];
    for (final b in bekleme) {
      c.add(suAnDakika + b);
      if (c.length >= adet) break;
    }
    return c;
  }
}

/// Bir taksi duragi.
class TaksiDuragi {
  const TaksiDuragi({
    required this.ad,
    required this.ilce,
    required this.adres,
    required this.enlem,
    required this.boylam,
  });

  final String ad;
  final String ilce;
  final String adres;
  final double enlem;
  final double boylam;
}

// ─────────────────────────────────────────────────────────────────────
// Cozuculer
// ─────────────────────────────────────────────────────────────────────

/// Google "encoded polyline" cozucusu.
///
/// ⚠️ Uretici betikteki `polyKodla` ile BIREBIR ayni algoritma; biri
///    degisirse oteki de degismek ZORUNDA.
List<({double enlem, double boylam})> polyCoz(String s) {
  final c = <({double enlem, double boylam})>[];
  var i = 0;
  var lat = 0;
  var lon = 0;
  while (i < s.length) {
    var shift = 0;
    var sonuc = 0;
    int b;
    do {
      b = s.codeUnitAt(i++) - 63;
      sonuc |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (sonuc & 1) != 0 ? ~(sonuc >> 1) : (sonuc >> 1);

    shift = 0;
    sonuc = 0;
    do {
      b = s.codeUnitAt(i++) - 63;
      sonuc |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lon += (sonuc & 1) != 0 ? ~(sonuc >> 1) : (sonuc >> 1);

    c.add((enlem: lat / 1e5, boylam: lon / 1e5));
  }
  return c;
}

/// Tek boyutlu (fark kodlu) tam sayi dizisi cozucusu — kalkis dakikalari.
List<int> dizeCoz(String s) {
  final c = <int>[];
  var i = 0;
  var onceki = 0;
  while (i < s.length) {
    var shift = 0;
    var sonuc = 0;
    int b;
    do {
      b = s.codeUnitAt(i++) - 63;
      sonuc |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    onceki += (sonuc & 1) != 0 ? ~(sonuc >> 1) : (sonuc >> 1);
    c.add(onceki);
  }
  return c;
}

// ─────────────────────────────────────────────────────────────────────
// Yukleyici
// ─────────────────────────────────────────────────────────────────────

/// ⚠️ Isolate'te kosar (`compute`): 1,7 MB'lik `seferler.json` ana is
///    parcaciginda cozulseydi acilis ~200-400 ms DONARDI (turu 120'de
///    olculen ANR sinifi).
Map<String, dynamic> _jsonCoz(String s) => jsonDecode(s) as Map<String, dynamic>;

/// Toplu tasima verisinin TEK KAYNAGI.
///
/// ⚠️ Her bolum AYRI ve TEMBEL yuklenir: harita acilirken yalniz duraklar
///    (95 KB) okunur; kalkislar (1,7 MB) ancak bir duraga DOKUNULDUGUNDA,
///    guzergahlar ancak bir hat SECILDIGINDE cozulur.
class UlasimVeri {
  UlasimVeri._();
  static final UlasimVeri i = UlasimVeri._();

  List<Durak>? _duraklar;
  Map<String, Hat>? _hatlar;
  Map<String, String>? _sekilHam;
  Map<String, dynamic>? _seferHam;
  List<TaksiDuragi>? _taksiler;

  Future<void>? _durakIsi;
  Future<void>? _hatIsi;
  Future<void>? _sekilIsi;
  Future<void>? _seferIsi;
  Future<void>? _taksiIsi;

  Future<List<Durak>> duraklar() async {
    if (_duraklar != null) return _duraklar!;
    _durakIsi ??= () async {
      final ham = await rootBundle.loadString('assets/ulasim/duraklar.json');
      final j = await compute(_jsonCoz, ham);
      final l = <Durak>[];
      for (final e in (j['d'] as List)) {
        final a = e as List;
        l.add(Durak(
          id: a[0] as String,
          enlem: (a[1] as num) / 1e5,
          boylam: (a[2] as num) / 1e5,
          ad: a[3] as String,
        ));
      }
      _duraklar = l;
    }();
    await _durakIsi;
    return _duraklar!;
  }

  Future<Map<String, Hat>> hatlar() async {
    if (_hatlar != null) return _hatlar!;
    _hatIsi ??= () async {
      final ham = await rootBundle.loadString('assets/ulasim/hatlar.json');
      final j = await compute(_jsonCoz, ham);
      final m = <String, Hat>{};
      (j['h'] as Map<String, dynamic>).forEach((id, v) {
        final o = v as Map<String, dynamic>;
        final yb = <int, String>{};
        (o['y'] as Map<String, dynamic>).forEach((k, b) {
          yb[int.parse(k)] = b as String;
        });
        final ys = <int, String>{};
        (o['s'] as Map<String, dynamic>).forEach((k, b) {
          ys[int.parse(k)] = b as String;
        });
        m[id] = Hat(
          id: id,
          kisaAd: (o['k'] ?? '') as String,
          uzunAd: (o['u'] ?? '') as String,
          renk: (o['r'] ?? '') as String,
          yonBaslik: yb,
          yonSekil: ys,
        );
      });
      _hatlar = m;
    }();
    await _hatIsi;
    return _hatlar!;
  }

  Future<Map<String, String>> _sekiller() async {
    if (_sekilHam != null) return _sekilHam!;
    _sekilIsi ??= () async {
      final ham = await rootBundle.loadString('assets/ulasim/sekiller.json');
      final j = await compute(_jsonCoz, ham);
      _sekilHam = (j['s'] as Map<String, dynamic>).cast<String, String>();
    }();
    await _sekilIsi;
    return _sekilHam!;
  }

  Future<Map<String, dynamic>> _seferler() async {
    if (_seferHam != null) return _seferHam!;
    _seferIsi ??= () async {
      final ham = await rootBundle.loadString('assets/ulasim/seferler.json');
      final j = await compute(_jsonCoz, ham);
      _seferHam = j['k'] as Map<String, dynamic>;
    }();
    await _seferIsi;
    return _seferHam!;
  }

  Future<List<TaksiDuragi>> taksiler() async {
    if (_taksiler != null) return _taksiler!;
    _taksiIsi ??= () async {
      final ham = await rootBundle.loadString('assets/ulasim/taksi.json');
      final j = await compute(_jsonCoz, ham);
      final l = <TaksiDuragi>[];
      for (final e in (j['t'] as List)) {
        final a = e as List;
        l.add(TaksiDuragi(
          enlem: (a[0] as num) / 1e5,
          boylam: (a[1] as num) / 1e5,
          ad: a[2] as String,
          ilce: a[3] as String,
          adres: a[4] as String,
        ));
      }
      _taksiler = l;
    }();
    await _taksiIsi;
    return _taksiler!;
  }

  // ───────────────────────────────────────────────────────────────────
  // Sorgular
  // ───────────────────────────────────────────────────────────────────

  /// Kaba mesafe (metre). ⚠️ Haversine DEGIL, duz izdusum: 2 km'lik bir
  ///    yaricapta hata ihmal edilebilir ve 2000 durak icin cok daha ucuz.
  ///    Boylam **`cos(enlem)`** ile daraltilir (turu 85b'de olculen ders:
  ///    duz bolen kutuyu Gebze enleminde %24 dar/genis yapar).
  static double kabaMetre(
    double aEn,
    double aBoy,
    double bEn,
    double bBoy,
  ) {
    final dEn = (aEn - bEn) * 111320.0;
    final dBoy = (aBoy - bBoy) * 111320.0 * math.cos(aEn * math.pi / 180);
    return math.sqrt(dEn * dEn + dBoy * dBoy);
  }

  /// Verilen noktaya en yakin [adet] durak (en yakin ONCE).
  ///
  /// ⚠️ [yaricapM] disindakiler ELENIR: 2032 duragin hepsini haritaya
  ///    koymak hem pin uretimini hem cizimi bogar (turu 91 dersi).
  Future<List<Durak>> yakinDuraklar(
    double enlem,
    double boylam, {
    int adet = 40,
    double yaricapM = 1500,
  }) async {
    final d = await duraklar();
    final c = <({Durak d, double m})>[];
    for (final x in d) {
      final m = kabaMetre(enlem, boylam, x.enlem, x.boylam);
      if (m <= yaricapM) c.add((d: x, m: m));
    }
    c.sort((a, b) => a.m.compareTo(b.m));
    return [for (final x in c.take(adet)) x.d];
  }

  /// Verilen noktaya en yakin taksi duraklari (en yakin ONCE).
  Future<List<({TaksiDuragi t, double m})>> yakinTaksiler(
    double enlem,
    double boylam, {
    int adet = 12,
  }) async {
    final t = await taksiler();
    final c = <({TaksiDuragi t, double m})>[
      for (final x in t)
        (t: x, m: kabaMetre(enlem, boylam, x.enlem, x.boylam)),
    ];
    c.sort((a, b) => a.m.compareTo(b.m));
    return c.take(adet).toList();
  }

  /// Bir duraktan gecen hatlar + o duraktaki kalkis saatleri.
  ///
  /// [servis] GTFS servis kimligi: 1 = hafta ici · 2 = cumartesi · 3 = pazar.
  /// ⚠️ Servis GUNDEN turetilir (bkz. `bugunServis`), uydurulmaz.
  Future<List<DurakHatti>> duraginHatlari(String durakId, int servis) async {
    final sf = await _seferler();
    final ht = await hatlar();
    final o = sf[durakId] as Map<String, dynamic>?;
    if (o == null) return const [];
    final c = <DurakHatti>[];
    o.forEach((hatId, v) {
      final hat = ht[hatId];
      if (hat == null) return;
      (v as Map<String, dynamic>).forEach((anahtar, kod) {
        final p = anahtar.split('|');
        if (p.length != 2) return;
        if (p[0] != '$servis') return;
        final yon = int.tryParse(p[1]) ?? 0;
        final dk = dizeCoz(kod as String);
        if (dk.isEmpty) return;
        c.add(DurakHatti(hat: hat, yon: yon, kalkislar: dk));
      });
    });
    return c;
  }

  /// ⚠️⚠️⚠️ TURU 157 - **HAT -> DURAKLAR TERS INDEKSI** (aktarma icin).
  ///
  ///	`seferler.json` **DURAK -> hat** yonunde saklanir. Aktarma
  ///	aramasi ise TERS soruyu sorar: *"bu hat-yon hangi duraklardan
  ///	geciyor ve her birine kacta variyor?"* Bu indeks olmadan o
  ///	soru ancak 2032 duragi bastan tarayarak cevaplanabilirdi.
  ///
  /// ⚠️⚠️ **TEK SEFER, TEMBEL.** Acilista KURULMAZ: `seferler.json`
  ///	1,7 MB ve ana is parcaciginda ~200-400 ms donma demektir
  ///	(turu 120 ANR dersi). Indeks yalnizca ILK AKTARMA ARAMASINDA
  ///	ve YALNIZ bir kez kurulur (olculdu: ~10 ms).
  /// ⚠️ Anahtar `hatId|yon`; deger, o hat-yonun duraklari ve o
  ///    duraktaki KALKIS SUTUNU.
  /// ⚠️⚠️ Servis basina AYRI onbellek: hafta ici ile pazar seferleri
  ///	farkli sutunlar tasir, karistirilamaz.
  final Map<int, Map<String, List<({String durakId, List<int> kalkislar})>>>
      _hatDurakOnbellek = {};

  Future<Map<String, List<({String durakId, List<int> kalkislar})>>>
      hatDuraklari(int servis) async {
    final v = _hatDurakOnbellek[servis];
    if (v != null) return v;
    final sf = await _seferler();
    final m = <String, List<({String durakId, List<int> kalkislar})>>{};
    sf.forEach((durakId, o) {
      (o as Map<String, dynamic>).forEach((hatId, v2) {
        (v2 as Map<String, dynamic>).forEach((anahtar, kod) {
          final p = anahtar.split(String.fromCharCode(124));
          if (p.length != 2) return;
          if (p[0] != '$servis') return;
          final dk = dizeCoz(kod as String);
          if (dk.isEmpty) return;
          (m['$hatId|${p[1]}'] ??= [])
              .add((durakId: durakId, kalkislar: dk));
        });
      });
    });
    _hatDurakOnbellek[servis] = m;
    return m;
  }

  /// ⚠️⚠️⚠️ TURU 157 - **DURAK -> HATLAR, SERVIS BASINA ONBELLEKLI.**
  ///
  ///	`duraginHatlari` her cagrida dizeleri YENIDEN cozup yeni
  ///	`DurakHatti` nesneleri uretiyor. Aktarma aramasinda bu
  ///	fonksiyon BINLERCE kez cagrilirdi; onbellek olmadan tek
  ///	arama on binlerce gereksiz ayristirma yapardi.
  /// ⚠️ `duraginHatlari` DEGISTIRILMEDI: ekranin baska yerlerinde
  ///    tek tek cagriliyor ve orada onbellek gereksiz.
  final Map<int, Map<String, List<DurakHatti>>> _durakHatOnbellek = {};

  Future<Map<String, List<DurakHatti>>> durakHatIndeksi(int servis) async {
    final v = _durakHatOnbellek[servis];
    if (v != null) return v;
    final sf = await _seferler();
    final ht = await hatlar();
    final m = <String, List<DurakHatti>>{};
    sf.forEach((durakId, o) {
      final c = <DurakHatti>[];
      (o as Map<String, dynamic>).forEach((hatId, v2) {
        final hat = ht[hatId];
        if (hat == null) return;
        (v2 as Map<String, dynamic>).forEach((anahtar, kod) {
          final p = anahtar.split(String.fromCharCode(124));
          if (p.length != 2) return;
          if (p[0] != '$servis') return;
          final yon = int.tryParse(p[1]) ?? 0;
          final dk = dizeCoz(kod as String);
          if (dk.isEmpty) return;
          c.add(DurakHatti(hat: hat, yon: yon, kalkislar: dk));
        });
      });
      if (c.isNotEmpty) m[durakId] = c;
    });
    _durakHatOnbellek[servis] = m;
    return m;
  }

  /// ⚠️⚠️⚠️ TURU 157 - **AKTARMA KOMSULARI (IZGARA ILE).**
  ///
  ///	Aktarma noktasi ararken her durak icin 2032 duragi taramak
  ///	gerekirdi; tek aramada bu **milyonlarca** mesafe hesabi
  ///	demektir ve 200 ms butcesini KATLAYARAK asar.
  ///	Izgara hucresi = aktarma yaricapi, yani bir duragin komsulari
  ///	yalnizca 3x3 hucrede aranir.
  /// ⚠️⚠️ **YARICAP 150 m OLCULEREK SECILDI**: 250/400 m kapsamaya
  ///	**hicbir sey eklemiyor** ama komsu cifti sayisini 3.880'den
  ///	22.657'ye cikariyor.
  /// ⚠️ Duragin KENDISI listeye girmez; cagiran taraf onu ayrica
  ///    (yurume 0 ile) degerlendirir - aktarmalarin %36'si ayni durakta.
  /// ⚠️ Boylamda `cos(enlem)`: duz derece kullanilsaydi Gebze
  ///    enleminde hucre boylamda %24 dar olurdu (turu 85b dersi).
  Map<String, List<({Durak d, double m})>>? _komsuOnbellek;

  Future<Map<String, List<({Durak d, double m})>>> komsuDuraklar(
    double yaricapM,
  ) async {
    final v = _komsuOnbellek;
    if (v != null) return v;
    final d = await duraklar();
    const kEn = 111320.0;
    final kBoy = 111320.0 * math.cos(40.8 * math.pi / 180);
    final izgara = <String, List<Durak>>{};
    for (final x in d) {
      final gx = (x.enlem * kEn / yaricapM).floor();
      final gy = (x.boylam * kBoy / yaricapM).floor();
      (izgara['$gx|$gy'] ??= []).add(x);
    }
    final m = <String, List<({Durak d, double m})>>{};
    for (final x in d) {
      final gx = (x.enlem * kEn / yaricapM).floor();
      final gy = (x.boylam * kBoy / yaricapM).floor();
      final c = <({Durak d, double m})>[];
      for (var a = -1; a <= 1; a++) {
        for (var b = -1; b <= 1; b++) {
          for (final y in izgara['${gx + a}|${gy + b}'] ?? const <Durak>[]) {
            if (y.id == x.id) continue;
            final mm = kabaMetre(x.enlem, x.boylam, y.enlem, y.boylam);
            if (mm <= yaricapM) c.add((d: y, m: mm));
          }
        }
      }
      if (c.isNotEmpty) m[x.id] = c;
    }
    return _komsuOnbellek = m;
  }

  /// ⚠️⚠️ TURU 157 - **DURAK KIMLIGINDEN DURAK** (aktarma icin O(1)).
  ///	Ters indeks yalnizca durak KIMLIGI donduruyor; koordinat
  ///	ve ad icin liste taramak aramayi O(n) yapardi.
  Map<String, Durak>? _durakHaritasi;

  Future<Map<String, Durak>> durakHaritasi() async {
    if (_durakHaritasi != null) return _durakHaritasi!;
    final d = await duraklar();
    return _durakHaritasi = {for (final x in d) x.id: x};
  }

  /// Bir hattin bir yonunun guzergah cizgisi (bos olabilir).
  Future<List<({double enlem, double boylam})>> guzergah(
    String hatId,
    int yon,
  ) async {
    final ht = await hatlar();
    final h = ht[hatId];
    if (h == null) return const [];
    final sid = h.yonSekil[yon] ?? h.yonSekil[1 - yon];
    if (sid == null) return const [];
    final sk = await _sekiller();
    final kod = sk[sid];
    if (kod == null || kod.isEmpty) return const [];
    return polyCoz(kod);
  }

  /// Bugunun GTFS servis kimligi (1 hafta ici · 2 cumartesi · 3 pazar).
  ///
  /// ⚠️ `calendar.txt` bu akista TAM OLARAK bu ucunu tanimliyor; baska bir
  ///    servis kimligi YOK (dogrulandi). Yeni bir akista degisirse burasi
  ///    da degismek zorunda.
  static int bugunServis([DateTime? an]) {
    final g = (an ?? DateTime.now()).weekday;
    if (g == DateTime.saturday) return 2;
    if (g == DateTime.sunday) return 3;
    return 1;
  }

  /// Gece yarisindan itibaren gecen dakika.
  static int suAnDakika([DateTime? an]) {
    final t = an ?? DateTime.now();
    return t.hour * 60 + t.minute;
  }

  /// Dakikayi "HH:MM" olarak yazar (24'u asan degerleri sarar).
  static String saatMetni(int dakika) {
    final d = dakika % 1440;
    final s = (d ~/ 60).toString().padLeft(2, '0');
    final dd = (d % 60).toString().padLeft(2, '0');
    return '$s:$dd';
  }
}
