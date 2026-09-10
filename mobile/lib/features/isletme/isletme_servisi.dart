import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
// TURU 89 - Modul modeli (kategoriye ozel katalog).
import 'urun_servisi.dart' show Modul;

/// ⚠️⚠️ TURU 77 — ISLETME PROFILLERI (kullanici emri: "normal ve isletme
/// profilleri olacak").
class IsletmeServisi {
  IsletmeServisi(this._ref);
  final Ref _ref;

  Dio get _api => _ref.read(apiProvider);

  /// Isletmeye GEC / bilgileri guncelle (upsert).
  Future<void> kaydet(Isletme i) =>
      _api.put('/users/me/isletme', data: i.json());

  /// Kisisel hesaba don.
  /// ⚠️ Isletme bilgileri SILINMEZ (veri politikasi) — tekrar gecince hazir gelir.
  Future<void> kisiselYap() => _api.delete('/users/me/isletme');

  /// Bir kullanicinin isletme bilgileri. **Isletme DEGILSE `null`; baska her
  /// hatada FIRLATIR.**
  ///
  /// ⚠️⚠️⚠️ TURU 77b — BU AYRIM VERI KAYBINI ONLUYOR (denetim bulgusu).
  ///
  /// Eskiden `catch (_) { return null; }` vardi, yani "isletme degil (404)" ile
  /// "ag/sunucu hatasi" AYIRT EDILEMIYORDU. Zincir:
  ///   1. Isletme sahibi mobil agda "İşletme bilgilerim"e girer,
  ///   2. GET zaman asimina ugrar -> `null` -> ekran ILK KAYIT gibi BOS acilir
  ///      (hata mesaji YOK; normal ilk-kayit ekranindan ayirt edilemez),
  ///   3. Kullanici yalnizca telefonunu yazip Kaydet'e basar,
  ///   4. Sunucudaki `ON CONFLICT DO UPDATE SET adres=EXCLUDED.adres, il=...,
  ///      telefon=..., web=..., calisma=...` **adres + 7 gunluk calisma
  ///      saatlerini BOSA CEKER.**
  /// Yani sessiz veri kaybi — ustelik "VERI SILINMEZ" politikasina ragmen.
  /// ⚠️ YAPMA: burayi tekrar "her hatada null" haline dondurme.
  Future<Isletme?> detay(String userId) async {
    try {
      final r = await _api.get('/users/$userId/isletme');
      return Isletme.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null; // isletme degil
      rethrow; // ag/sunucu hatasi — CAGIRAN bilmek ZORUNDA
    }
  }

  /// Isletme rehberi (hamburger menudeki kategori kartlari BURAYA baglanir).
  /// ⚠️ TURU 85 — KONUMA GORE isletmeler (mesafeye gore SIRALI).
  ///
  /// ⚠️ Konumu OLMAYAN isletme listede CIKMAZ (sunucu suzuyor) — bu bir
  ///    eksiklik degil zorunluluk: (0,0) koordinati Gine Korfezi'ne denk
  ///    gelir ve tum konumsuz isletmeler ~6000 km uzakta gorunurdu.
  Future<List<IsletmeOzet>> yakinimda({
    required double enlem,
    required double boylam,
    double km = 10,
    String kategori = '',
  }) async {
    final r = await _api.get(
      '/isletmeler/yakinimda',
      queryParameters: {
        'lat': enlem,
        'lng': boylam,
        'km': km,
        if (kategori.isNotEmpty) 'kategori': kategori,
      },
    );
    final l = (r.data['isletmeler'] as List?) ?? [];
    return l
        .map((e) => IsletmeOzet.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<IsletmeOzet>> liste({
    String kategori = '',
    String q = '',
    String il = '',
    // ⚠️ TURU 78 — HIZLI KARTLARIN ON KOSULU. Bu iki parametre olmadan
    //    "Şehrimde" ve "Onaylı" kartlari OLU DOGARDI.
    String ilce = '',
    bool yalnizOnayli = false,
    // ⚠️⚠️ TURU 96h — FILTRE PANELI SUZGECLERI **SUNUCUYA** gecti.
    //    Onceden istemcide uygulaniyordu ve sunucu `LIMIT 60` donduruyordu:
    //    "60'in icinden suzulmus" sonuc "hepsinden suzulmus"ten FARKLIYDI.
    // ⚠️ Hepsi OPSIYONEL ve 0/false varsayilanli: gonderilmezse sunucu
    //    yuklemleri devre disi birakir.
    int minTutarKurus = 0,
    double puanTaban = 0,
    int teslimatTavanDk = 0,
    bool kampanyali = false,
    bool puansiz = false,
  }) async {
    final r = await _api.get(
      '/isletmeler',
      queryParameters: {
        if (kategori.isNotEmpty) 'kategori': kategori,
        if (q.isNotEmpty) 'q': q,
        if (il.isNotEmpty) 'il': il,
        if (ilce.isNotEmpty) 'ilce': ilce,
        if (yalnizOnayli) 'dogrulandi': '1',
        // ⚠️ Yalnizca DOLU olanlar gonderilir: bos parametre sunucuda
        //    "suzme yok" demek ama URL'i gereksiz sisirmenin anlami yok.
        if (minTutarKurus > 0) 'min_tutar': '$minTutarKurus',
        if (puanTaban > 0) 'puan': '$puanTaban',
        if (teslimatTavanDk > 0) 'teslimat': '$teslimatTavanDk',
        if (kampanyali) 'kampanyali': '1',
        if (puansiz) 'puansiz': '1',
      },
    );
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['isletmeler'] as List?) ?? [])
        .map((e) => IsletmeOzet.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// ⚠️⚠️ TURU 92 — KATEGORI KESIF VERISI (alt kategoriler + slayt metinleri).
  ///
  /// ⚠️ TEK UC, IKI VERI: ayri iki uc, ekran acilisinda IKI istek demekti
  ///    (turu 91'de olculen "acilistaki es zamanli istek" maliyeti).
  Future<KesifVerisi> kesif(String kategori) async {
    final r = await _api.get('/isletme-kesif',
        queryParameters: {if (kategori.isNotEmpty) 'kategori': kategori});
    final m = (r.data as Map).cast<String, dynamic>();
    return (
      altKategoriler: ((m['alt_kategoriler'] as List?) ?? [])
          .map((e) => (
                ad: ((e as Map)['ad'] ?? '').toString(),
                ara: (e['ara'] ?? '').toString(),
              ))
          .toList(),
      slaytlar: ((m['slaytlar'] as List?) ?? [])
          .map((e) => (
                baslik: ((e as Map)['baslik'] ?? '').toString(),
                alt: (e['alt'] ?? '').toString(),
              ))
          .toList(),
    );
  }
}

/// ⚠️⚠️ KATEGORILER — `backend/internal/isletme/handler.go` ILE AYNI OLMALI.
///    ⚠️ YAPMA: yalniz birini guncelleme. Istemci bilmedigi anahtari "Diğer"
///       gosterir ve kullanici kendi sectigi kategoriyi goremez.
const isletmeKategorileri = <String, String>{
  'yemek': 'Yemek',
  'kafe': 'Kafe',
  'market': 'Market',
  'giyim': 'Giyim',
  'kuafor': 'Kuaför',
  // TURU 90 - Go tarafiyla BIREBIR (handler.go Kategoriler).
  'guzellik': 'Güzellik Merkezi',
  'diyetisyen': 'Diyetisyen',
  'oto': 'Oto & Servis',
  'saglik': 'Sağlık',
  // ⚠️ TURU 85 — kullanici emri (eczane + otel). Sunucudaki `Kategoriler`
  //    haritasiyla BIREBIR ayni sirada ve ayni anahtarlarla.
  'eczane': 'Eczane',
  'otel': 'Otel & Konaklama',
  'egitim': 'Eğitim',
  'emlak': 'Emlak',
  'spor': 'Spor',
  'teknoloji': 'Teknoloji',
  'eglence': 'Eğlence',
  'hizmet': 'Hizmet',
  'diger': 'Diğer',
};

String isletmeKategoriAdi(String anahtar) =>
    isletmeKategorileri[anahtar] ?? 'Diğer';

/// Haftanin bir gunu icin calisma saati.
class CalismaGunu {
  CalismaGunu({
    required this.gun,
    this.acilis = '09:00',
    this.kapanis = '18:00',
    this.kapali = false,
  });

  /// 1 = Pazartesi ... 7 = Pazar
  final int gun;
  String acilis;
  String kapanis;
  bool kapali;

  Map<String, dynamic> json() => {
    'gun': gun,
    'acilis': acilis,
    'kapanis': kapanis,
    'kapali': kapali,
  };

  static CalismaGunu fromJson(Map<String, dynamic> m) => CalismaGunu(
    gun: (m['gun'] as num?)?.toInt() ?? 1,
    acilis: (m['acilis'] ?? '09:00').toString(),
    kapanis: (m['kapanis'] ?? '18:00').toString(),
    kapali: m['kapali'] == true,
  );
}

const gunAdlari = <int, String>{
  1: 'Pazartesi',
  2: 'Salı',
  3: 'Çarşamba',
  4: 'Perşembe',
  5: 'Cuma',
  6: 'Cumartesi',
  7: 'Pazar',
};

class Isletme {
  Isletme({
    this.kategori = 'diger',
    this.adres = '',
    this.il = '',
    this.ilce = '',
    this.telefon = '',
    this.web = '',
    this.ozellikler = const <String>[],
    this.odeme = const <String>[],
    this.kapakMedyalari,
    this.kapakTurleri = const <String>[],
    this.calisma = const [],
    this.enlem,
    this.boylam,
    this.dogrulandi = false,
    this.randevuAcik = false,
    this.randevuTuru = 'randevu',
    this.modul = Modul.varsayilan,
  });

  String kategori;
  String adres;
  String il;
  String ilce;
  String telefon;
  String web;

  /// ⚠️⚠️ TURU 180 — ISLETME OZELLIKLERI (sigara icilmez · cocuk alani …)
  //	ve ODEME SECENEKLERI. Kullanici emri.
  //
  // ⚠️ Bunlar **ANAHTAR**tir (`wifi`, `sigara_yok` …); gorunen ad ve ikon
  //	SUNUCUDAN gelir (`GET /isletme-katalog`). Istemcide ikinci bir
  //	kopya YOK — yeni bir ozellik magaza onayi GEREKTIRMEZ
  //	(turu 77 kurali).
  List<String> ozellikler;
  List<String> odeme;

  /// ⚠️⚠️⚠️ TURU 180k — **KAPAK SLIDERI** (kullanici emri: *"McDonald's
  ///	isletmesinin header'ina bu video koy, header slider tarzi; ILK bu
  ///	video gelsin, 15-20 saniye sonra degissin"*).
  ///
  /// Medya id listesi (foto VE video olabilir; tur `media_assets.kind`ten
  /// gelir ve `MedyaKucukResmi`/`MedyaVideo` ayrimi ISTEMCIDE yapilir).
  ///
  /// ⚠️⚠️ **BOSSA ESKI DAVRANIS**: `ProfilBasligi` tek `kapakMediaId`yi cizer.
  ///	Yani bu alan hicbir isletmede zorunlu degil ve doldurulmamis
  ///	kayitlarda gorunum DEGISMEZ.
  /// ⚠️ `users.kapak_media_id` DOKUNULMADI: liste/harita/Yakinimda kartlari
  ///	onu okuyor (tek 16:9 kapak orada DOGRU olan).
  /// ⚠️⚠️⚠️ **NULLABLE VE BU HAYATI** (turu 85b koordinat dersinin birebir
  ///	aynisi — o gun sahada YASANDI):
  ///
  ///	  `null`  -> alan istege KONMAZ; sunucu COALESCE ile MEVCUDU KORUR
  ///	  `[]`    -> alan bos gonderilir; sunucu slideri BOSALTIR
  ///	  dolu    -> normal kayit
  ///
  ///	`isletme_duzenle.dart` kaydederken YENI bir `Isletme(...)` kuruyor ve
  ///	slider alanini VERMIYOR (o ekranda boyle bir form YOK). Alan duz
  ///	`List<String>` olsaydi varsayilan bos dilim her kayitta sunucuya
  ///	`[]` olarak gider ve **calisma saatini duzenleyen bir isletme kapak
  ///	videosunu SESSIZCE SILERDI.**
  /// ⚠️ YAPMA: bunu non-nullable yapma; `json()`teki `!= null` kapisini
  ///	kaldirma.
  List<String>? kapakMedyalari;

  /// ⚠️ `kapakMedyalari` ile **BIREBIR HIZALI** tur listesi (`video`/`image`/
  ///	`yok`). SUNUCUDAN gelir (`unnest ... WITH ORDINALITY`), istemcide
  ///	TAHMIN EDILMEZ.
  ///
  /// ⚠️⚠️ `json()`E **EKLENMEZ**: bu bir TURETILMIS alan, kullanicinin
  ///	yazdigi veri DEGIL. Gonderilseydi sunucu onu yok sayardi ama
  ///	okuyan biri "demek ki yazilabilir" sanip bir yazma yolu acardi.
  /// ⚠️ Salt okunur (`final`): slider degistiginde tur listesi de SUNUCUDAN
  ///	yeniden gelir.
  final List<String> kapakTurleri;

  List<CalismaGunu> calisma;

  /// ⚠️⚠️ TURU 85b — **NULLABLE**: "gonderilmedi" ile "SIFIRLA" AYRI seylerdir.
  ///
  ///   `null`  -> alan istege KONMAZ; sunucu COALESCE ile mevcut konumu KORUR
  ///   `0`     -> alan 0 olarak GONDERILIR; sunucu konumu SIFIRLAR (kaldirma)
  ///   deger   -> normal kayit
  ///
  /// Onceden `double enlem = 0` idi ve `toJson` 0'i GONDERMIYORDU. Sonuc:
  /// isletme duzenlemedeki **"Konumu kaldır" (X) dugmesi OLU IDI** — ekranda
  /// temizleniyor ama sunucuya HIC ULASMIYOR, sayfa yenilenince konum GERI
  /// GELIYORDU. (Bu projenin 10 kez yasadigi "dugme var ama is yapmiyor" sinifi.)
  /// ⚠️ YAPMA: bunlari tekrar `double = 0` yapma.
  double? enlem;
  double? boylam;

  /// ⚠️ `users.verified` (TELEFON dogrulamasi) ILE KARISTIRILMAZ — bu ISLETME
  ///    dogrulamasidir ve ayri bir sutunda tutulur (bkz. migration 028).
  final bool dogrulandi;

  /// ⚠️⚠️ TURU 80 — isletme randevu/rezervasyon ALIYOR MU (SUNUCUDAN gelir).
  ///
  /// ⚠️ `json()`e **EKLENMEZ**: bu iki alan AYRI tablodan (`randevu_ayar`)
  ///    yonetiliyor. Isletme kaydiyla birlikte gonderilseydi `PUT
  ///    /users/me/isletme` upsert'i rezervasyon ayarini ilgisiz bir yerden
  ///    ezerdi — turu 78'in koordinat ezme hatasinin ayni sinifi.
  final bool randevuAcik;

  /// 'rezervasyon' | 'randevu' — ARAYUZ METINLERI buna gore degisir.
  /// ⚠️ Kategoriden ISTEMCIDE turetilmez (ikinci kopya = drift).
  final String randevuTuru;

  bool get rezervasyonMu => randevuTuru == 'rezervasyon';

  /// TURU 89 — KATEGORIYE OZEL KATALOG MODULU (otel->Odalar,
  /// doktor->Hizmetler, restoran->Menü). SUNUCUDAN gelir; kategoriden
  /// ISTEMCIDE turetilmez (randevuTuru ile ayni gerekce: ikinci kopya
  /// kacinilmaz olarak DRIFT EDER).
  final Modul modul;

  Map<String, dynamic> json() => {
    'kategori': kategori,
    'adres': adres,
    'il': il,
    'ilce': ilce,
    'telefon': telefon,
    'web': web,
    'calisma': calisma.map((c) => c.json()).toList(),
    'ozellikler': ozellikler,
    'odeme': odeme,
    if (kapakMedyalari != null) 'kapak_medyalari': kapakMedyalari,
    // ⚠️⚠️⚠️ TURU 78b — KOORDINATLAR **YALNIZ DOLUYSA** GONDERILIR (denetim).
    //
    //    Sunucuda `enlem`/`boylam` ISARETCI yapildi ve
    //    `COALESCE(EXCLUDED.enlem, isletmeler.enlem)` ile "gonderilmediyse
    //    MEVCUDU KORU" kurali yazildi. Ama istemci bu alanlari **HER ISTEKTE
    //    0 olarak** gonderiyordu: `0` NULL DEGILDIR, dolayisiyla COALESCE
    //    hicbir zaman devreye girmiyor ve koruma ATIL kaliyordu.
    //
    //    BUGUN gorunur bir zarari yok (koordinat girisi olan arayuz yok, tum
    //    kayitlar zaten 0). AMA koordinat girisi eklendigi GUN, kullanicinin
    //    haritadan sectigi konum, calisma saatlerini duzenlemek icin acilan
    //    HERHANGI bir kaydetme ile SIFIRLANIRDI — ve "duzeltildi" diye yazili
    //    oldugu icin kimse orada aramazdi.
    //
    // ⚠️⚠️ TURU 85b — OLCUT `!= 0` DEGIL **`!= null`**.
    //
    //    `!= 0` kurali dogru sorunu cozuyordu ama YENI bir tane yaratti:
    //    kullanici "Konumu kaldır"a bastiginda deger 0 olur ve alan
    //    GONDERILMEZ -> sunucudaki COALESCE eski konumu KORUR -> **kaldirma
    //    ISTEGI SUNUCUYA HIC ULASMAZ.** Dugme ekranda calisiyor gorunur,
    //    sayfa yenilenince konum GERI GELIR.
    //
    //    Artik alanlar `double?`: `null` "dokunma", `0` "SIFIRLA" demek.
    // ⚠️ YAPMA: olcutu tekrar `!= 0` yapma; alanlari non-nullable'a dondurme.
    if (enlem != null) 'enlem': enlem,
    if (boylam != null) 'boylam': boylam,
  };

  /// ⚠️ Ad : sinifin bir de ORNEK metodu  var (giden yon).
  ///    Ikisine de  denseydi Dart statik/ornek uye cakismasi verirdi.
  static Isletme fromJson(Map<String, dynamic> m) => Isletme(
    kategori: (m['kategori'] ?? 'diger').toString(),
    adres: (m['adres'] ?? '').toString(),
    il: (m['il'] ?? '').toString(),
    ilce: (m['ilce'] ?? '').toString(),
    telefon: (m['telefon'] ?? '').toString(),
    web: (m['web'] ?? '').toString(),
    ozellikler: ((m['ozellikler'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    odeme: ((m['odeme'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    kapakMedyalari: ((m['kapak_medyalari'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    kapakTurleri: ((m['kapak_turleri'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    calisma: ((m['calisma'] as List?) ?? [])
        .map((e) => CalismaGunu.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    enlem: (m['enlem'] as num?)?.toDouble() ?? 0,
    boylam: (m['boylam'] as num?)?.toDouble() ?? 0,
    dogrulandi: m['dogrulandi'] == true,
    // ⚠️⚠️ TURU 80 — RANDEVU BILGISI SUNUCUDAN gelir; istemci kategoriden
    //    TAHMIN ETMEZ (ayni kuralin ikinci kopyasi olurdu ve isletme
    //    ayari kapaliyken de dugme cizilirdi = 404 veren buton).
    randevuAcik: m['randevu_acik'] == true,
    randevuTuru: (m['randevu_turu'] ?? 'randevu').toString(),
    modul: m['modul'] is Map
        ? Modul.fromJson((m['modul'] as Map).cast<String, dynamic>())
        : Modul.varsayilan,
  );

  /// "Şu an açık" mi? ⚠️ Cihaz saatine gore hesaplanir; sunucuya sorulmaz
  ///    (isletme ile kullanici ayni saat diliminde varsayiliyor — Turkiye pazari).
  bool get simdiAcik {
    if (calisma.isEmpty) return false;
    final n = DateTime.now();
    final g = calisma.where((c) => c.gun == n.weekday).firstOrNull;
    if (g == null || g.kapali) return false;
    int dk(String s) {
      final p = s.split(':');
      if (p.length != 2) return -1;
      return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
    }

    final simdi = n.hour * 60 + n.minute;
    final a = dk(g.acilis), k = dk(g.kapanis);
    if (a < 0 || k < 0) return false;
    // ⚠️ Gece yarisini asan saatler (22:00 - 02:00) icin sarma mantigi.
    return k >= a ? (simdi >= a && simdi < k) : (simdi >= a || simdi < k);
  }
}

/// Rehber listesindeki tek satir.
/// ⚠️⚠️ TURU 181 — LISTE UCUNUN DONDURDUGU **URUN ONIZLEMESI**.
///
/// Tam `Urun` modeli DEGIL: liste yaniti yalnizca kartin menu seridini
/// cizmek icin gereken UC alani tasir (ad · fiyat · kapak gorseli). Tam
/// model (`urun_servisi.dart`) bolum, ozellikler, tum galeri gibi alanlari
/// da tasiyor ve liste yanitini gereksiz sisirirdi.
///
/// ⚠️ Fiyat KURUS cinsinden gelir; bicimleme `kurusMetni` TEK KAYNAGINDAN
///	yapilir (turu 77b: elle `kurus ~/ 100` yazilmis ve 12,50 TL "12 ₺"
///	olarak KIRPILMISTI).
class UrunOnizleme {
  const UrunOnizleme({
    required this.id,
    required this.ad,
    required this.fiyatKurus,
    required this.mediaId,
  });

  final String id;
  final String ad;
  final int fiyatKurus;

  /// Kapak gorseli (`media_ids[1]`). Urunun gorseli yoksa `null`.
  final String? mediaId;

  /// ⚠️ Sunucu `'[]'::json` varsayilaniyla DAIMA bir dizi doner; yine de
  ///	tip kontrolu yapilir — eski bir sunucu surumu alani HIC
  ///	gondermeyebilir ve o durumda kart menu seridini CIZMEZ (cokmez).
  static List<UrunOnizleme> liste(dynamic ham) {
    if (ham is! List) return const [];
    return ham
        .whereType<Map>()
        .map(
          (e) => UrunOnizleme(
            id: (e['id'] ?? '').toString(),
            ad: (e['ad'] ?? '').toString(),
            fiyatKurus: (e['fiyat_kurus'] as num?)?.toInt() ?? 0,
            // ⚠️ Bos dize `null`a cevrilir: `MedyaGorsel`e bos kimlik
            //	gitmesi gereksiz bir istek ve kirik gorsel demekti.
            mediaId: ((e['media_id'] ?? '').toString().isEmpty)
                ? null
                : e['media_id'].toString(),
          ),
        )
        .toList();
  }
}

class IsletmeOzet {
  IsletmeOzet({
    required this.id,
    required this.ad,
    required this.kullaniciAdi,
    required this.avatarUrl,
    required this.avatarMediaId,
    required this.kategori,
    required this.il,
    required this.ilce,
    required this.adres,
    required this.dogrulandi,
    this.aciklama = '',
    this.kapakMediaId,
    this.calisma = const [],
    this.minFiyatKurus,
    this.urunSayisi = 0,
    this.urunler = const [],
    this.minTutarKurus,
    this.teslimatDkMin,
    this.teslimatDkMax,
    this.puan,
    this.puanSayisi = 0,
    this.kampanyalar = const [],
    this.favorim = false,
  });

  final String id;
  final String ad;
  final String kullaniciAdi;
  final String avatarUrl;
  final String? avatarMediaId;
  final String kategori;
  final String il;
  final String ilce;
  final String adres;
  final bool dogrulandi;

  /// Kisa tanitim metni — kartta ADRESIN YERINE cizilir (kullanici emri:
  /// *"isletme aciklama olsun, acik adres yazma"*).
  ///
  /// ⚠️⚠️ **SUNUCUDA HENUZ KARSILIGI YOK** (`isletmeler` tablosunda
  ///	`aciklama` sutunu bulunmuyor — turu 93b'de olculdu). Alan burada
  ///	ACIK duruyor ki sunucu gondermeye basladigi GUN arayuz kendiliginde
  ///	cizsin; bugun BOS gelir ve kart o satiri HIC CIZMEZ.
  /// ⚠️ YAPMA: bos gelince adresi ya da uydurma bir cumleyi buraya yazma
  ///	(turu 135 "uydurma veri" yasagi).
  /// ⏳ BACKEND TURU: migration + `PUT /users/me/isletme` alani + duzenleme
  ///	formu + liste/detay SELECT'leri.
  final String aciklama;

  /// ⚠️ TURU 93 — KART KAPAGI. Yemeksepeti tarzi kartta BUYUK gorsel
  ///    gerekiyor; avatar 46px icin uygun ama 150px yuksekliginde kart
  ///    kapagi olarak BULANIK cikar.
  /// ⚠️ Bos olabilir: kapak yoksa avatara, o da yoksa gradyan yer tutucuya
  ///    dusulur — kirik gorsel CIZILMEZ.
  final String? kapakMediaId;

  /// ⚠️⚠️ KART BILGI SATIRI ICIN (kullanici emri: *"sana attigim gorseldeki
  ///    gibi bilgiler icersin"*).
  ///
  ///	Referans ekranda "25-35 dk · Min. 260 TL · ★ 3,9 (500+)" var. Bu
  ///	projede **puan, teslimat suresi ve minimum tutar YOK** — sahte deger
  ///	basmak kullaniciya YANLIS BILGI olurdu. Yerine BUGUN GERCEK OLAN iki
  ///	sey konuyor: **acik/kapali + kapanis saati** ve **en uygun fiyat**.
  /// ⚠️ Ikisi de sunucudan gelir; istemci HESAPLAMAZ, yalnizca cizer.
  final List<dynamic> calisma;
  final int? minFiyatKurus;
  final int urunSayisi;

  /// ⚠️⚠️⚠️ TURU 181 — **ILK 5 URUN ONIZLEMESI (SUNUCUDAN).**
  ///
  ///	Turu 180ag'de kartin altina menu seridi kondu; liste ucu urun ADI ve
  ///	GORSELI dondurmedigi icin istemci kart basina AYRI bir
  ///	`/users/{id}/urunler` istegi atmak ZORUNDAYDI — turu 17'de kapatilan
  ///	N+1 sinifi. Bedeli tembel yukleme + semafor(4) + onbellekle
  ///	sinirlanmisti ama SINIF DURUYORDU.
  ///
  ///	Turu 181'de sunucu bunu **TEK SORGUDA** donduruyor
  ///	(`isletmeSutunlari` icinde `json_agg` alt sorgusu) ve istemcideki
  ///	getirme katmani (`urun_onbellek.dart`) TAMAMEN kalkti.
  ///
  /// ⚠️ YALNIZ `durum='yayinda'` kalemler, `sira`ya gore, EN FAZLA 5.
  /// ⚠️ `urunSayisi` ile TUTARSIZ OLABILIR ve bu DOGRU: sayac "katalogda
  ///	kac kalem var" (tukendi DAHIL), onizleme "su an satista neler var"
  ///	sorusuna cevap verir.
  final List<UrunOnizleme> urunler;

  /// ⚠️⚠️ TURU 94 — VITRIN ALANLARI (migration 046).
  ///
  /// ⚠️ Hepsi NULL olabilir = **bilgi yok**. Kart o parcayi CIZMEZ; sifir
  ///    gostermek ("0 dk", "★ 0") YANLIS BILGI olurdu.
  /// ⚠️⚠️ `puan` bir DEGERLENDIRME SISTEMINDEN gelmiyor — isletmenin/
  ///    yoneticinin girdigi editoryal bir sayidir. Gercek puan icin oy
  ///    tablosu + siparis dogrulamasi gerekir (AYRI IS).
  final int? minTutarKurus;
  final int? teslimatDkMin;
  final int? teslimatDkMax;
  final double? puan;
  final int puanSayisi;
  final List<String> kampanyalar;

  /// ⚠️ DEGISTIRILEBILIR: kalp iyimser guncelleniyor ve kart nesnesi liste
  ///    ile PAYLASILIYOR — yeni nesne atansaydi favori degisikligi baska
  ///    ekranda gorunmezdi (turu 76 dersi).
  bool favorim;

  /// ⚠️ TURU 85 — YALNIZ "Yakinimda" ucunda dolu gelir; diger listelerde 0.
  ///    Mesafe SUNUCUDA hesaplanir (istemcide tekrar hesaplamak "ayni
  ///    kuralin iki kopyasi" olurdu ve siralama ile gosterilen deger
  ///    AYRISABILIRDI).
  double enlem = 0;
  double boylam = 0;
  double km = 0;

  /// "1,2 km" / "350 m" — kart altinda gosterilir.
  ///
  /// ⚠️⚠️ ONDALIK AYRACI **VIRGUL** (`mesafe_test.dart` bunu yakaladi):
  ///	`toStringAsFixed` DAIMA nokta uretir ve kartta "1.3 km" yaziyordu.
  ///	Ayni ekranda puan ZATEN virgulle ("4,5") ciziliyor; iki sayi yan yana
  ///	iki FARKLI ayracla duruyordu.
  /// ⚠️ 1 km ALTINDA metre: "0,3 km" demek, "300 m"den hem daha uzun hem
  ///    daha az okunakli.
  /// ⚠️ `km <= 0` = mesafe BILINMIYOR -> BOS doner ve kartta hicbir sey
  ///    cizilmez ("0 m" yazmak yanlis bilgi olurdu).
  String get mesafeMetni => km <= 0
      ? ''
      : (km < 1
          ? '${(km * 1000).round()} m'
          : '${km.toStringAsFixed(1).replaceAll('.', ',')} km');

  static IsletmeOzet json(Map<String, dynamic> m) => IsletmeOzet(
    id: (m['id'] ?? '').toString(),
    ad: (m['name'] ?? '').toString(),
    kullaniciAdi: (m['username'] ?? '').toString(),
    avatarUrl: (m['avatar_url'] ?? '').toString(),
    avatarMediaId: m['avatar_media_id'] as String?,
    kategori: (m['kategori'] ?? 'diger').toString(),
    il: (m['il'] ?? '').toString(),
    ilce: (m['ilce'] ?? '').toString(),
    adres: (m['adres'] ?? '').toString(),
    dogrulandi: m['dogrulandi'] == true,
    aciklama: (m['aciklama'] ?? '').toString(),
    kapakMediaId: m['kapak_media_id'] as String?,
    calisma: (m['calisma'] as List?) ?? const [],
    minFiyatKurus: (m['min_fiyat_kurus'] as num?)?.toInt(),
    urunSayisi: (m['urun_sayisi'] as num?)?.toInt() ?? 0,
    urunler: UrunOnizleme.liste(m['urunler']),
    minTutarKurus: (m['min_tutar_kurus'] as num?)?.toInt(),
    teslimatDkMin: (m['teslimat_dk_min'] as num?)?.toInt(),
    teslimatDkMax: (m['teslimat_dk_max'] as num?)?.toInt(),
    puan: (m['puan'] as num?)?.toDouble(),
    puanSayisi: (m['puan_sayisi'] as num?)?.toInt() ?? 0,
    kampanyalar:
        ((m['kampanyalar'] as List?) ?? const []).map((e) => e.toString()).toList(),
    favorim: m['favorim'] == true,
  )
    ..enlem = (m['enlem'] as num?)?.toDouble() ?? 0
    ..boylam = (m['boylam'] as num?)?.toDouble() ?? 0
    ..km = (m['km'] as num?)?.toDouble() ?? 0;
}

/// ⚠️⚠️⚠️ TURU 96 — NORMAL LISTEDE MESAFE (kullanici emri: *"isletme
///	kartlarinda yakinlik 1 km ya da 300 m gibi mesafeler gorunsun"*).
///
/// ⚠️ **SUNUCU DEGERI HER ZAMAN KAZANIR** (`km > 0` ise DOKUNULMAZ).
///	"Yakinimda" ucu mesafeyi SUNUCUDA hesaplar ve ona gore SIRALAR;
///	istemci ayni kaydin mesafesini yeniden hesaplarsa (farkli yuvarlama,
///	farkli konum ornegi) liste "3 km, 1 km, 5 km" gibi SIRASIZ gorunurdu —
///	yani gosterilen deger siralamayi YALANLARDI.
///	Bu fonksiyon YALNIZCA sunucunun mesafe hesaplamadigi listelerde
///	(kategori/rehber/favoriler) devreye girer. Orada siralama zaten
///	mesafeye gore DEGIL, dolayisiyla celiski YOK.
/// ⚠️ Koordinati OLMAYAN isletme atlanir: `0,0` Gine Korfezi'dir ve
///    "5.100 km" yazardi (turu 90b'de ayni sabit sahaya cikmisti).
/// ⚠️ Haversine — kaba kutu YOK: elimizde zaten en fazla 60 kayit var,
///    eleme degil GOSTERIM yapiyoruz.
void mesafeleriDoldur(List<IsletmeOzet> liste, double enlem, double boylam) {
  for (final o in liste) {
    if (o.km > 0) continue;
    if (o.enlem == 0 && o.boylam == 0) continue;
    o.km = _haversineKm(enlem, boylam, o.enlem, o.boylam);
  }
}

double _haversineKm(double la1, double lo1, double la2, double lo2) {
  const r = 6371.0; // Dunya yaricapi (km)
  final dLa = _rad(la2 - la1);
  final dLo = _rad(lo2 - lo1);
  final a = math.sin(dLa / 2) * math.sin(dLa / 2) +
      math.cos(_rad(la1)) * math.cos(_rad(la2)) *
          math.sin(dLo / 2) * math.sin(dLo / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double d) => d * math.pi / 180.0;

extension IsletmeFavori on IsletmeServisi {
  /// ⚠️ TURU 94 — favori ac/kapa. Sunucu IDEMPOTENT (cift dokunusta hata yok).
  Future<void> favoriCevir(String id, bool favori) async {
    if (favori) {
      await _api.post('/isletmeler/$id/favori');
    } else {
      await _api.delete('/isletmeler/$id/favori');
    }
  }

  Future<List<IsletmeOzet>> favorilerim() async {
    final r = await _api.get('/users/me/favori-isletmeler');
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['isletmeler'] as List?) ?? [])
        .map((e) => IsletmeOzet.json((e as Map).cast<String, dynamic>()))
        .toList();
  }
}

final isletmeServisiProvider = Provider<IsletmeServisi>(IsletmeServisi.new);

/// ⚠️⚠️ TURU 92 — KATEGORI KESIF VERISI (alt kategoriler + slayt metinleri).
///
/// ⚠️ HER IKISI DE SUNUCUDAN: istemciye sabit yazmak turu 77'nin "Dart'a
///    kategori sabiti YAZMA" kuralinin ihlali olurdu; yeni bir alt kategori
///    ya da slayt metni eklemek MAGAZA ONAYI gerektirirdi ve eski surumler
///    listeyi EKSIK gosterirdi.
typedef KesifVerisi = ({
  List<({String ad, String ara})> altKategoriler,
  List<({String baslik, String alt})> slaytlar,
});

/// ⚠️⚠️ TURU 180 — OZELLIK / ODEME TANIMI (sunucudan gelir).
///
/// ⚠️ `ikon` bir **Lucide adi**; istemci onu `kIsletmeIkon` ile cozer ve
///	bilinmeyen adda NOTR bir ikona duser. Boylece sunucuya yeni bir
///	ozellik eklemek eski istemcilerde ETIKETSIZ bir cip degil,
///	notr ikonlu ama DOGRU ETIKETLI bir cip uretir.
class KatalogOge {
  const KatalogOge({
    required this.anahtar,
    required this.ad,
    required this.ikon,
  });

  final String anahtar;
  final String ad;
  final String ikon;

  static KatalogOge fromJson(Map<String, dynamic> m) => KatalogOge(
        anahtar: (m['anahtar'] ?? '').toString(),
        ad: (m['ad'] ?? '').toString(),
        ikon: (m['ikon'] ?? '').toString(),
      );
}

class IsletmeKatalog {
  const IsletmeKatalog({this.ozellikler = const [], this.odeme = const []});

  final List<KatalogOge> ozellikler;
  final List<KatalogOge> odeme;

  /// Anahtar -> tanim (arayuz cizerken O(1) arama).
  Map<String, KatalogOge> get harita => {
        for (final o in [...ozellikler, ...odeme]) o.anahtar: o,
      };
}

/// ⚠️ `keepAlive`: katalog SABIT bir tanim listesi, her ekran acilisinda
///	yeniden cekmek gereksiz istek olurdu.
/// ⚠️ Hata durumunda BOS katalog doner — ozellik cizilmez ama ekran
///	COKMEZ (turu 113 `aiDurumProvider` dersi: hata surec boyunca
///	onbelleklenirse ozellik BIR DAHA gorunmez).
final isletmeKatalogProvider = FutureProvider<IsletmeKatalog>((ref) async {
  try {
    final r = await ref.read(apiProvider).get('/isletme-katalog');
    final m = (r.data as Map).cast<String, dynamic>();
    List<KatalogOge> coz(String k) =>
        ((m[k] as List?) ?? const [])
            .map((e) => KatalogOge.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
    return IsletmeKatalog(ozellikler: coz('ozellikler'), odeme: coz('odeme'));
  } catch (_) {
    ref.invalidateSelf();
    return const IsletmeKatalog();
  }
});

/// Lucide adi -> ikon. ⚠️ Bilinmeyen ad NOTR ikona duser (bkz. serh).
const Map<String, IconData> kIsletmeIkon = {
  'wifi': LucideIcons.wifi,
  'circleParking': LucideIcons.circleParking,
  'cigaretteOff': LucideIcons.cigaretteOff,
  'cigarette': LucideIcons.cigarette,
  'baby': LucideIcons.baby,
  'babyCarriage': LucideIcons.baby,
  'accessibility': LucideIcons.accessibility,
  'package': LucideIcons.package,
  'shoppingBag': LucideIcons.shoppingBag,
  'calendarCheck': LucideIcons.calendarCheck,
  'treePine': LucideIcons.treePine,
  'pawPrint': LucideIcons.pawPrint,
  'airVent': LucideIcons.airVent,
  'tv': LucideIcons.tv,
  'car': LucideIcons.car,
  'clock': LucideIcons.clock,
  'banknote': LucideIcons.banknote,
  'creditCard': LucideIcons.creditCard,
  'nfc': LucideIcons.nfc,
  'utensils': LucideIcons.utensils,
  'globe': LucideIcons.globe,
  'qrCode': LucideIcons.qrCode,
};

IconData isletmeIkonBul(String ad) =>
    kIsletmeIkon[ad] ?? LucideIcons.circleCheck;
