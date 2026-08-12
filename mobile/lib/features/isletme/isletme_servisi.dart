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
  }) async {
    final r = await _api.get(
      '/isletmeler',
      queryParameters: {
        if (kategori.isNotEmpty) 'kategori': kategori,
        if (q.isNotEmpty) 'q': q,
        if (il.isNotEmpty) 'il': il,
        if (ilce.isNotEmpty) 'ilce': ilce,
        if (yalnizOnayli) 'dogrulandi': '1',
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
    this.kapakMediaId,
    this.calisma = const [],
    this.minFiyatKurus,
    this.urunSayisi = 0,
    this.minTutarKurus,
    this.teslimatDkMin,
    this.teslimatDkMax,
    this.puan,
    this.puanSayisi = 0,
    this.kampanyalar = const [],
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

  /// ⚠️ TURU 85 — YALNIZ "Yakinimda" ucunda dolu gelir; diger listelerde 0.
  ///    Mesafe SUNUCUDA hesaplanir (istemcide tekrar hesaplamak "ayni
  ///    kuralin iki kopyasi" olurdu ve siralama ile gosterilen deger
  ///    AYRISABILIRDI).
  double enlem = 0;
  double boylam = 0;
  double km = 0;

  /// "1,2 km" / "350 m" — kart altinda gosterilir.
  String get mesafeMetni =>
      km <= 0 ? '' : (km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km');

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
    kapakMediaId: m['kapak_media_id'] as String?,
    calisma: (m['calisma'] as List?) ?? const [],
    minFiyatKurus: (m['min_fiyat_kurus'] as num?)?.toInt(),
    urunSayisi: (m['urun_sayisi'] as num?)?.toInt() ?? 0,
    minTutarKurus: (m['min_tutar_kurus'] as num?)?.toInt(),
    teslimatDkMin: (m['teslimat_dk_min'] as num?)?.toInt(),
    teslimatDkMax: (m['teslimat_dk_max'] as num?)?.toInt(),
    puan: (m['puan'] as num?)?.toDouble(),
    puanSayisi: (m['puan_sayisi'] as num?)?.toInt() ?? 0,
    kampanyalar:
        ((m['kampanyalar'] as List?) ?? const []).map((e) => e.toString()).toList(),
  )
    ..enlem = (m['enlem'] as num?)?.toDouble() ?? 0
    ..boylam = (m['boylam'] as num?)?.toDouble() ?? 0
    ..km = (m['km'] as num?)?.toDouble() ?? 0;
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

