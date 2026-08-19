import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
// ⚠️ TURU 83 — gonderi anketi modeli SOHBET tarafiyla AYNI (`chats/anket.dart`).
//    Ikinci bir model yazmak sunucunun TEK yanit bicimini iki yerde
//    cozumlemek demekti ve alanlar drift ederdi.
import '../chats/anket.dart' show Anket, AnketTaslak;

/// ⚠️ TURU 81 — olcusu BILINMEYEN medyanin varsayilan en-boyu (genislik/yukseklik).
///
/// 4:5 secildi: telefonla cekilen fotograflarin cogunlugu dikeydir ve bu deger
/// turu 80'e kadarki davranisin ta kendisidir — yani eski medya (olcusu
/// doldurulmamis satirlar) BIRDEN BOZULMUS gibi gorunmez, TANIDIK kalir.
const double _kVarsayilanEnBoy = 4 / 5;

/// ⚠️⚠️ TURU 75 — SOSYAL KATMAN ISTEMCISI (gonderi + akis + etkilesim + takip).
///
/// ⚠️ TEK KAYNAK: gonderi/profil/takip ile ilgili HER REST cagrisi buradan gecer.
///    Ekranlara `api.post('/posts/...')` DAGITMA — bu projede ayni mantigin
///    kopyalanmasi defalarca "drift" uretti (turu 56 mesgulluk kontrolu dersi).
class SosyalServisi {
  SosyalServisi(this._ref);
  final Ref _ref;

  Dio get _api => _ref.read(apiProvider);

  // ---------------- GONDERI ----------------

  /// Gonderi olustur. [tur]: foto | video | reels | yazi.
  /// ⚠️ Sunucu tutarliligi dogrular (medya tipiyse medya ZORUNLU, yazi ise
  ///    medya OLMAZ) — istemci de once kontrol eder ki kullanici bosuna beklemesin.
  Future<String> gonderiOlustur({
    required String tur,
    String metin = '',
    List<String> mediaIds = const [],
    bool yorumKapali = false,
    DateTime? yayinAt,
    AnketTaslak? anket,
    // TURU 90 - KONUM. Bos ad + 0 koordinat = KONUM YOK.
    String konum = '',
    double enlem = 0,
    double boylam = 0,
  }) async {
    final r = await _api.post(
      '/posts',
      data: {
        'tur': tur,
        'metin': metin,
        'media_ids': mediaIds,
        'yorum_kapali': yorumKapali,
        // ⚠️ TURU 83 — GONDERI ANKETI. Alan YALNIZ anket varsa gonderilir;
        //    `null` gondermek sunucuda `req.Anket != nil` kapisini gecerdi.
        //    Alan adlari SOHBET anketiyle BIREBIR ayni (`question/options/
        //    multi`) — sunucu ikisini de ayni `chat.GonderiAnketiYaz`a veriyor.
        if (anket != null)
          'anket': {
            'question': anket.soru,
            'options': anket.secenekler,
            'multi': anket.coklu,
          },
        // ⚠️ TURU 81 — ILERI TARIHLI PAYLASIM. Gonderilmezse ya da GECMIS bir
        //    zamansa sunucu gonderiyi HEMEN yayinlar.
        // ⚠️ `toUtc()`: sunucu RFC3339 bekliyor ve saat dilimi belirsizligi
        //    "1 saat once/sonra yayinlandi" hatalarinin klasik kaynagidir.
        if (yayinAt != null) 'yayin_at': yayinAt.toUtc().toIso8601String(),
        // TURU 90 - KONUM (kullanici emri). Sunucu sozlesmesi: 0,0 = yok.
        'konum': konum,
        'enlem': enlem,
        'boylam': boylam,
      },
    );
    return r.data['id'] as String;
  }

  Future<void> gonderiSil(String id) => _api.delete('/posts/$id');

  /// TURU 76 — gonderiyi DUZENLE (yalniz aciklama + yorum ayari).
  /// ⚠️ MEDYA DEGISMEZ: altinda yorum/begeni birikmis icerigi baska bir seye
  ///     cevirmeye izin verilmez (Instagram deseni). Medya degisecekse gonderi
  ///     silinip yenisi paylasilir.
  /// ⚠️ Alanlar OPSIYONEL: gonderilmeyen alan sunucuda DEGISMEZ.
  /// ⚠️⚠️ TURU 90c — [konumKaldir] ile KONUM SILINEBILIR (GIZLILIK).
  ///
  /// Turu 90b sunucuya konum kaldirma yolunu ekledi ve gerekcesini ACIKCA
  /// gizlilik olarak yazdi (*"yanlislikla konumla paylasan birinin TEK caresi
  /// GONDERIYI SILMEKTI... ev adresini paylastigini fark eden biri icin bu
  /// gercek bir gizlilik sorunudur"*) — ama ISTEMCI o ucu HIC CAGIRMIYORDU.
  /// Yani duzeltme sahada **OLU DOGMUSTU**; e2e'nin yesil olmasi yaniltiyordu
  /// cunku e2e SUNUCU ucunu cagiriyor, ISTEMCININ onu cagirdigini DEGIL
  /// (turu 87 dersi: *"bir ozelligin CALISTIGININ TEK KANITI ONA BAKMAKTIR"*).
  ///
  /// ⚠️ SOZLESME: `0,0 + bos ad` = KONUM YOK. Sunucu `enlem` gonderilmediyse
  ///    ucune de DOKUNMAZ, gonderildiyse UCUNU BIRLIKTE yazar.
  Future<void> gonderiDuzenle(
    String id, {
    String? metin,
    bool? yorumKapali,
    bool konumKaldir = false,
  }) => _api.patch(
    '/posts/$id',
    data: {
      if (metin != null) 'metin': metin,
      if (yorumKapali != null) 'yorum_kapali': yorumKapali,
      if (konumKaldir) ...{'konum': '', 'enlem': 0, 'boylam': 0},
    },
  );

  /// TURU 76 — YAZARA OZEL istatistik. Sunucu baskasina 404 doner.
  Future<Map<String, int>> istatistik(String id) async {
    final r = await _api.get('/posts/$id/istatistik');
    final m = (r.data as Map).cast<String, dynamic>();
    return m.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
  }

  /// Ana sayfa akisi. [before] imlec (son gonderinin `created_at` degeri).
  ///
  /// ⚠️ IMLEC (cursor) sayfalama — `offset` DEGIL. Offset olsaydi biz kaydirirken
  ///    yeni gonderi gelince tum satirlar KAYAR ve ayni gonderi iki kez gorunurdu.
  Future<({List<Gonderi> gonderiler, bool kesfet})> akis({
    String? before,
  }) async {
    final r = await _api.get(
      '/feed',
      queryParameters: {if (before != null) 'before': before},
    );
    final m = (r.data as Map).cast<String, dynamic>();
    return (
      gonderiler: ((m['posts'] as List?) ?? [])
          .map((e) => Gonderi.json((e as Map).cast<String, dynamic>()))
          .toList(),
      kesfet: m['kesfet'] == true,
    );
  }

  /// ⚠️⚠️ TURU 80 — "Keşfet" BOLMESI (hikaye seridinin altindaki secici).
  ///
  /// `/kesfet` ucu `/feed` ile **AYNI** `{posts: [...]}` bicimini donduruyor
  /// (`h.satirlariOku(rows)` — kaynaktan dogrulandi), bu yuzden SUNUCUDA
  /// HICBIR DEGISIKLIK GEREKMEDI ve ayni `Gonderi.json` ayristirmasi kullanilir.
  ///
  /// ⚠️ Bu uc `cardinality(media_ids) > 0` suzuyor, yani kesfet YALNIZ MEDYALI
  ///    gonderileri gosterir. BILINCLI: kesfet gorsel bir vitrindir (Instagram
  ///    Explore da boyle) ve yazi gonderileri takip akisinda zaten gorunur.
  /// ⚠️ `before` sayfalama ayni imlec desenini kullanir.
  Future<List<Gonderi>> kesfetAkisi({String? before}) async {
    final r = await _api.get(
      '/kesfet',
      queryParameters: {if (before != null) 'before': before},
    );
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['posts'] as List?) ?? [])
        .map((e) => Gonderi.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// ⚠️⚠️⚠️ TURU 114 — "MAHALLE" BOLMESI (kullanici emri: akistaki secici
  ///	**Arkadaş · Keşfet · Mahalle**).
  ///
  /// `GET /mahalle?lat&lng&km` — kullanicinin cevresindeki KONUMLU gonderiler.
  /// Yanit `{km, posts}`; `posts` bicimi `/feed` ile BIREBIR ayni oldugu icin
  /// ayni `Gonderi.json` ayristirmasi kullanilir.
  ///
  /// ⚠️ Sunucu KONUM ZORUNLU tutar (400 "konum gerekli"): koordinatsiz bir
  ///    "mahalle" tanimsizdir. Cagiran taraf konumu ONCE almali; izin yoksa
  ///    kullaniciya DURUSTCE sebebini yazmali (bkz. `akis_ekrani` serhi).
  /// ⚠️ Yeni tablo/migration ACILMADI: `posts.enlem/boylam` 044'ten beri var.
  Future<List<Gonderi>> mahalleAkisi({
    required double enlem,
    required double boylam,
    double? km,
    String? before,
  }) async {
    final r = await _api.get(
      '/mahalle',
      queryParameters: {
        'lat': enlem,
        'lng': boylam,
        if (km != null) 'km': km,
        if (before != null) 'before': before,
      },
    );
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['posts'] as List?) ?? [])
        .map((e) => Gonderi.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Tek gonderi (bildirimden / derin baglantidan acilir).
  Future<Gonderi> gonderiGetir(String id) async {
    final r = await _api.get('/posts/$id');
    return Gonderi.json((r.data as Map).cast<String, dynamic>());
  }

  /// Reels akisi — takipten BAGIMSIZ (TikTok/Instagram deseni).
  Future<List<Gonderi>> reels({String? before}) async {
    final r = await _api.get(
      '/reels',
      queryParameters: {if (before != null) 'before': before},
    );
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['posts'] as List?) ?? [])
        .map((e) => Gonderi.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<Gonderi>> kullaniciGonderileri(
    String userId, {
    String? before,
    String? tur,
  }) async {
    final r = await _api.get(
      '/users/$userId/posts',
      queryParameters: {
        if (before != null) 'before': before,
        if (tur != null) 'tur': tur,
      },
    );
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['posts'] as List?) ?? [])
        .map((e) => Gonderi.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ---------------- ETKILESIM ----------------

  Future<void> begen(String postId) => _api.post('/posts/$postId/like');
  Future<void> begeniGeriAl(String postId) =>
      _api.delete('/posts/$postId/like');
  Future<void> kaydet(String postId) => _api.post('/posts/$postId/save');
  Future<void> kaydetKaldir(String postId) =>
      _api.delete('/posts/$postId/save');

  /// Kaydettiklerim.
  /// ⚠️ Sunucu erisimi YENIDEN degerlendirir (yazar sonradan gizli hesaba
  ///    gecmis ya da engellemis olabilir) — liste kaydettigimden AZ olabilir.
  Future<List<Gonderi>> kaydedilenler({String? before}) async {
    final r = await _api.get(
      '/users/me/saved',
      queryParameters: {if (before != null) 'before': before},
    );
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['posts'] as List?) ?? [])
        .map((e) => Gonderi.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<Map<String, dynamic>>> begenenler(String postId) async {
    final r = await _api.get('/posts/$postId/likes');
    return ((r.data as List?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<List<Yorum>> yorumlar(String postId) async {
    final r = await _api.get('/posts/$postId/comments');
    return ((r.data as List?) ?? [])
        .map((e) => Yorum.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<int> yorumYaz(String postId, String metin, {int? parentId}) async {
    final r = await _api.post(
      '/posts/$postId/comments',
      data: {'metin': metin, if (parentId != null) 'parent_id': parentId},
    );
    return (r.data['id'] as num).toInt();
  }

  Future<void> yorumSil(int yorumId) => _api.delete('/comments/$yorumId');

  // ---------------- TAKIP / PROFIL ----------------

  /// Doner: `true` = onayli takip, `false` = istek BEKLEMEDE (gizli hesap).
  Future<bool> takipEt(String userId) async {
    final r = await _api.post('/users/$userId/follow');
    return (r.data is Map) && r.data['durum'] == 'onayli';
  }

  Future<void> takibiBirak(String userId) =>
      _api.delete('/users/$userId/follow');
  Future<void> istekOnayla(String userId) =>
      _api.post('/users/$userId/follow/approve');
  Future<void> istekReddet(String userId) =>
      _api.delete('/users/$userId/follow/approve');

  Future<Profil> profil(String userId) async {
    final r = await _api.get('/users/$userId/profile');
    return Profil.json((r.data as Map).cast<String, dynamic>());
  }

  /// [tur]: followers | following
  Future<List<Map<String, dynamic>>> takipListesi(
    String userId,
    String tur,
  ) async {
    final r = await _api.get('/users/$userId/$tur');
    return ((r.data as List?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<List<Map<String, dynamic>>> takipIstekleri() async {
    final r = await _api.get('/users/me/follow-requests');
    return ((r.data as List?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<void> gizlilikAyarla(bool gizli) =>
      _api.patch('/users/me/privacy', data: {'gizli_hesap': gizli});

  // ---------------- BILDIRIM ----------------

  Future<List<Map<String, dynamic>>> bildirimler() async {
    final r = await _api.get('/notifications');
    return ((r.data as List?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<void> bildirimleriOkudum() => _api.post('/notifications/read');
}

/// ⚠️ DEGISTIRILEBILIR (mutable) MODEL — bilincli karar.
///    Begeni/kaydetme "iyimser guncelleme" ile ANINDA cizilir; immutable olsaydi
///    her dokunusta tum liste yeniden kurulur ve kaydirma konumu ZIPLARDI.
class Gonderi {
  Gonderi({
    required this.id,
    required this.yazarId,
    required this.tur,
    required this.metin,
    required this.mediaIds,
    required this.mediaKinds,
    this.mediaBoyut = const [],
    required this.duzenlendi,
    this.konum = '',
    this.enlem = 0,
    this.boylam = 0,
    required this.begeniSayisi,
    required this.yorumSayisi,
    required this.goruntulenme,
    required this.yorumKapali,
    required this.createdAt,
    required this.yazarAd,
    required this.yazarUsername,
    required this.yazarAvatar,
    required this.yazarAvatarMediaId,
    required this.begendim,
    required this.kaydettim,
    this.anket,
    this.paylasimSayisi = 0,
    this.repostSayisi = 0,
    this.sponsorlu = false,
    this.sponsorAlan = '',
    this.sponsorCta = '',
    this.yayinAt,
  });

  /// ⚠️⚠️ TURU 98b — PAYLASIM ve REPOST SAYACI **SUNUCUDA YOK**.
  ///	Kullanici bu iki sayiyi tasarim demosunda gormek istedi. Alanlar
  ///	varsayilan **0**'dir ve `_eylem` sifiri HIC yazmaz; yani gercek
  ///	akista kullaniciya SAHTE sayi gosterilmez.
  /// ⚠️ Sunucu bu alanlari donmeye baslarsa `fromJson`a eklenmeli.
  final int paylasimSayisi;
  final int repostSayisi;

  /// ⚠️⚠️ TURU 98i — SPONSORLU GONDERI (kullanici emri: *"sponsorlu
  ///	paylasim da var, bizimkinde de gorunmeli"*).
  ///
  /// ⚠️ **SUNUCUDA REKLAM ALTYAPISI YOK** (turu 78 karari: reklamlar
  ///	tablosu ACILMADI, cunku icerigini girecek yol yok). Bu alanlar
  ///	JSONDAN OKUNMAZ — yalniz demo verisinde doludur, gercek akista
  ///	DAIMA false/bos gelir ve hicbir gonderi "Sponsorlu" gorunmez.
  /// ⚠️ YAPMA: bunlari fromJson'a baglamadan once sunucu tarafini yaz.
  final bool sponsorlu;
  final String sponsorAlan;
  final String sponsorCta;

  final String id;
  final String yazarId;
  final String tur;

  /// ⚠️ TURU 76: DEGISEBILIR — gonderi duzenlendiginde kart, listeyi bastan
  ///    cekmeden ANINDA guncellenir (begendim/kaydettim ile ayni desen).
  ///    Model paylasilan nesne oldugu icin akis, profil ve detay AYNI ANDA tazelenir.
  String metin;
  final List<String> mediaIds;

  /// ⚠️⚠️ TURU 76 — HER MEDYANIN TURU. `mediaKinds[i]` ile `mediaIds[i]` AYNI
  ///     medyayi gosterir (sunucu `WITH ORDINALITY` ile sirayi GARANTI EDIYOR).
  ///     Degerler: image | video | audio | document | yok (silinmis).
  /// ⚠️ Bu alan OLMADAN karma galeri (foto + video ayni gonderide) cizilemez:
  ///     kart gonderi seviyesindeki `tur`a bakip TUM medyayi ayni sanardi.
  /// ⚠️ ESKI SUNUCU YEDEGI: alan gelmezse gonderi turunden TUREYILIR (asagida).
  final List<String> mediaKinds;

  /// ⚠️⚠️ TURU 81 — HER MEDYANIN PIKSEL OLCUSU, "WxH" (or. "1080x1920").
  ///     `mediaBoyut[i]` ile `mediaIds[i]` AYNI medyayi gosterir (sunucu
  ///     `WITH ORDINALITY` ile sirayi GARANTI EDIYOR).
  /// ⚠️ Bu alan OLMADAN medya KIRPILMADAN cizilemez — kart orani bilmedigi
  ///     icin sabit bir kutuya `cover` ile sigdirmak ZORUNDA kalirdi
  ///     (turu 80'de dikey fotografin %41-51'i kirpiliyordu).
  /// ⚠️ ESKI SUNUCU / ESKI MEDYA YEDEGI: alan gelmezse ya da "0x0" ise
  ///     `enBoy()` varsayilana duser.
  final List<String> mediaBoyut;

  /// Sunucudaki `duzenlendi_at != NULL`. Kart "· düzenlendi" etiketi cizer.
  bool duzenlendi;

  /// ⚠️⚠️ TURU 115c — **ILERI TARIHLI PAYLASIM ZAMANI** (`posts.yayin_at`).
  ///
  /// ⚠️ Bu alan turu 81'de sunucuya eklendi ve HER gonderi satirinda
  ///    donduruluyor; `social/handler.go` serhi *"alan donmeden istemci rozeti
  ///    cizemez"* diyor. Ama istemci onu **HIC OKUMUYORDU** — yani ozellik
  ///    yarim bagliydi: yazar ileri tarihe zamanladigi gonderisini profilinde
  ///    normal gonderilerden AYIRT EDEMIYORDU.
  ///    ("sutun var, okuyan yol yok" sinifinin bu projedeki ONUNCU tekrari.)
  /// ⚠️ Gecmis bir tarih ROZET URETMEZ: yayinlanmis gonderide "Zamanlandı"
  ///    yazmak YALAN olurdu (`zamanlanmis` bunu kontrol eder).
  final DateTime? yayinAt;

  /// Gonderi HENUZ YAYINLANMADI mi? (yalniz YAZARA gorunur — sunucu zaten
  /// baskasina yayinlanmamis gonderi DONDURMUYOR.)
  bool get zamanlanmis =>
      yayinAt != null && yayinAt!.isAfter(DateTime.now().toUtc());

  /// TURU 90 - GONDERI KONUMU. Bos ad + 0 koordinat = KONUM YOK.
  ///
  /// ⚠️ TURU 90c — alanlar **DEGISEBILIR** (`final` DEGIL): duzenleme
  ///    ekranindan konum kaldirildiginda iyimser guncelleme yapilir ve hata
  ///    halinde GERI ALINIR. `metin`/`yorumKapali`/`duzenlendi` ile ayni desen.
  /// ⚠️ Nesne akis/izgara/detay arasinda PAYLASILIR — bu yuzden ALANLAR
  ///    guncellenir, YENI NESNE atanmaz (turu 76 dersi: yeni nesne atanirsa
  ///    detayda yapilan degisiklik izgarada gorunmez).
  String konum;
  double enlem;
  double boylam;

  bool get konumVar => enlem != 0 || boylam != 0;
  int begeniSayisi;
  int yorumSayisi;

  /// ⚠️ Yalniz REELS ve GONDERI DETAYINDA artar (akista artmaz — orada 20 kart
  ///    tek istekte gelir ama cogu HIC gorulmez, saymak sayiyi YALAN yapardi).
  final int goruntulenme;

  /// ⚠️ TURU 76: duzenleme ile degisebilir (bkz. `metin` serhi).
  bool yorumKapali;
  final String createdAt;
  final String yazarAd;
  final String yazarUsername;
  final String yazarAvatar;
  final String? yazarAvatarMediaId;
  bool begendim;
  bool kaydettim;

  /// GONDERI SEVIYESINDE video mu (reels/tek video). Karma galeride tek tek
  /// medyanin turu icin `mediaKinds` kullanilir — bu getter ONU EZMEZ.
  /// ⚠️⚠️ TURU 83 — GONDERI ANKETI (kullanici emri: "gonderide anket olmasi
  ///    elzem"). Sema: migration 042 (`polls.post_id`).
  ///
  /// ⚠️ **DEGISTIRILEBILIR ALAN** (`final` DEGIL): oy verilince sunucudan
  ///    gelen yeni anlik goruntu YERINDE yazilir. Yeni bir `Gonderi` nesnesi
  ///    uretilseydi model akis/izgara/detay arasinda PAYLASILDIGI icin
  ///    (turu 76 karari) diger yuzeyler eski anketi gostermeye devam ederdi.
  Anket? anket;

  bool get videoMu => tur == 'video' || tur == 'reels';

  /// Gonderinin SES ekli mi (ilk medya `audio` ise).
  ///
  /// ⚠️ Ses TEK medya olarak paylasilir: `media_kinds[0] == 'audio'`.
  ///    Galeriyle karistirilamaz cunku `Create` ses turunde tek medya kabul
  ///    ediyor ve kart ses dalinda galeri serodi CIZMIYOR.
  bool get sesliMi => mediaIds.isNotEmpty && kind(0) == 'audio';

  /// i. medyanin turu. Liste kisa/eksikse gonderi turunden turetir.
  String kind(int i) {
    if (i >= 0 && i < mediaKinds.length) return mediaKinds[i];
    return videoMu ? 'video' : 'image';
  }

  /// ⚠️⚠️⚠️ TURU 81 — i. medyanin EN-BOY ORANI (genislik / yukseklik).
  ///
  /// Kullanici UC KEZ *"gorseller cok uzun / boyutlar tutarsiz"* dedi. Threads
  /// modeli **YUKSEKLIK SABIT, GENISLIK ORANDAN** demektir: dikey fotograf DAR,
  /// yatay fotograf GENIS cizilir ve **KIRPMA OLMAZ**. Bunun on kosulu orani
  /// bilmektir; sunucu artik `media_boyut` ("WxH") donduruyor.
  ///
  /// ⚠️ OLCU YOKSA (eski medya "0x0", ya da alan hic gelmediyse) **4/5**
  ///    varsayilir — telefonla cekilen fotograflarin cogunlugu dikeydir ve bu,
  ///    turu 80'e kadarki davranisin ta kendisidir (yani yedek yol GORSEL
  ///    OLARAK TANIDIK kalir, birden bozulmus gibi gorunmez).
  /// ⚠️ SINIRLANIR (0.5 .. 1.91): asiri panoramik ya da asiri uzun bir medya
  ///    satiri patlatmasin. Ust sinir Instagram'in yatay tavani, alt sinir
  ///    9:16'dan biraz dar (story oraninin altina inmeye gerek yok).
  double enBoy(int i) {
    if (i < 0 || i >= mediaBoyut.length) return _kVarsayilanEnBoy;
    final p = mediaBoyut[i].split('x');
    if (p.length != 2) return _kVarsayilanEnBoy;
    final w = int.tryParse(p[0]) ?? 0;
    final h = int.tryParse(p[1]) ?? 0;
    if (w <= 0 || h <= 0) return _kVarsayilanEnBoy;
    return (w / h).clamp(0.5, 1.91);
  }

  /// Galeride EN AZ BIR video var mi (kapak/oto-oynatma karari icin).
  bool get videoIceriyor => videoMu || mediaKinds.any((k) => k == 'video');

  static Gonderi json(Map<String, dynamic> m) => Gonderi(
    id: (m['id'] ?? '').toString(),
    yazarId: (m['author_id'] ?? '').toString(),
    tur: (m['tur'] ?? 'yazi').toString(),
    metin: (m['metin'] ?? '').toString(),
    mediaIds: ((m['media_ids'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    mediaKinds: ((m['media_kinds'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    mediaBoyut: ((m['media_boyut'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    duzenlendi: m['duzenlendi'] == true,
    konum: (m['konum'] ?? '').toString(),
    enlem: (m['enlem'] as num?)?.toDouble() ?? 0,
    boylam: (m['boylam'] as num?)?.toDouble() ?? 0,
    begeniSayisi: (m['begeni_sayisi'] as num?)?.toInt() ?? 0,
    yorumSayisi: (m['yorum_sayisi'] as num?)?.toInt() ?? 0,
    goruntulenme: (m['goruntulenme'] as num?)?.toInt() ?? 0,
    yorumKapali: m['yorum_kapali'] == true,
    createdAt: (m['created_at'] ?? '').toString(),
    yazarAd: (m['yazar_ad'] ?? '').toString(),
    yazarUsername: (m['yazar_username'] ?? '').toString(),
    yazarAvatar: (m['yazar_avatar'] ?? '').toString(),
    yazarAvatarMediaId: m['yazar_avatar_media_id'] as String?,
    begendim: m['begendim'] == true,
    kaydettim: m['kaydettim'] == true,
    // ⚠️ TURU 115c — `yayin_at`: sunucu ISO 8601 UTC gonderiyor. Ayristirma
    //    BASARISIZ olursa `null` (rozet cizilmez) — bozuk bir damga yuzunden
    //    kart cizimi PATLAMAMALI.
    yayinAt: DateTime.tryParse((m['yayin_at'] ?? '').toString())?.toUtc(),
    // ⚠️ TURU 83 — GONDERI ANKETI. Sunucu `anket` alanini YALNIZ anketli
    //    gonderilerde gonderir (bkz. `social.satirlariOku`).
    anket: m['anket'] is Map
        ? Anket.fromJson((m['anket'] as Map).cast<String, dynamic>())
        : null,
  );
}

class Yorum {
  Yorum({
    required this.id,
    required this.parentId,
    required this.metin,
    required this.begeniSayisi,
    required this.createdAt,
    required this.yazarId,
    required this.yazarAd,
    required this.yazarUsername,
    required this.yazarAvatar,
    required this.yazarAvatarMediaId,
    required this.begendim,
  });

  final int id;
  final int? parentId;
  final String metin;
  int begeniSayisi;
  final String createdAt;
  final String yazarId;
  final String yazarAd;
  final String yazarUsername;
  final String yazarAvatar;
  final String? yazarAvatarMediaId;
  bool begendim;

  static Yorum json(Map<String, dynamic> m) => Yorum(
    id: (m['id'] as num?)?.toInt() ?? 0,
    parentId: (m['parent_id'] as num?)?.toInt(),
    metin: (m['metin'] ?? '').toString(),
    begeniSayisi: (m['begeni_sayisi'] as num?)?.toInt() ?? 0,
    createdAt: (m['created_at'] ?? '').toString(),
    yazarId: (m['yazar_id'] ?? '').toString(),
    yazarAd: (m['yazar_ad'] ?? '').toString(),
    yazarUsername: (m['yazar_username'] ?? '').toString(),
    yazarAvatar: (m['yazar_avatar'] ?? '').toString(),
    yazarAvatarMediaId: m['yazar_avatar_media_id'] as String?,
    begendim: m['begendim'] == true,
  );
}

class Profil {
  Profil({
    required this.id,
    required this.username,
    required this.ad,
    required this.hakkinda,
    required this.avatarUrl,
    required this.avatarMediaId,
    required this.gizli,
    required this.baglanti,
    required this.takipciSayisi,
    required this.takipSayisi,
    required this.gonderiSayisi,
    required this.takipEdiyorum,
    required this.istekBekliyor,
    required this.beniTakipEdiyor,
    required this.engelledim,
    this.kapakMediaId,
    this.onayli = false,
  });

  final String id;
  final String username;
  final String ad;
  final String hakkinda;
  final String avatarUrl;
  final String? avatarMediaId;

  /// TURU 78 — profil KAPAK (arka plan) gorseli. Yoksa kimlikten turetilen
  /// degrade cizilir (bkz. profil_basligi.dart).
  final String? kapakMediaId;

  /// TURU 78 — ONAYLI HESAP rozeti.
  /// ⚠️⚠️ Bu `users.verified` DEGILDIR: o "telefon dogrulandi" demek ve
  ///    kayit olan HERKESTE true. Rozet ayri bir kavram (`users.onayli`).
  final bool onayli;
  final bool gizli;
  final String baglanti;
  int takipciSayisi;
  final int takipSayisi;
  final int gonderiSayisi;
  bool takipEdiyorum;
  bool istekBekliyor;
  final bool beniTakipEdiyor;
  bool engelledim;

  /// Gizli hesabin gonderilerini goremiyoruz (kendisi ya da onayli takipci degilsek).
  bool get icerikKilitli => gizli && !takipEdiyorum;

  static Profil json(Map<String, dynamic> m) {
    final il = ((m['iliski'] as Map?) ?? {}).cast<String, dynamic>();
    return Profil(
      id: (m['id'] ?? '').toString(),
      username: (m['username'] ?? '').toString(),
      ad: (m['name'] ?? '').toString(),
      hakkinda: (m['about'] ?? '').toString(),
      avatarUrl: (m['avatar_url'] ?? '').toString(),
      avatarMediaId: m['avatar_media_id'] as String?,
      kapakMediaId: m['kapak_media_id'] as String?,
      onayli: m['onayli'] == true,
      gizli: m['gizli_hesap'] == true,
      baglanti: (m['baglanti'] ?? '').toString(),
      takipciSayisi: (m['takipci_sayisi'] as num?)?.toInt() ?? 0,
      takipSayisi: (m['takip_sayisi'] as num?)?.toInt() ?? 0,
      gonderiSayisi: (m['gonderi_sayisi'] as num?)?.toInt() ?? 0,
      // ⚠️ ALAN ADLARI backend `takipDurumResp` json etiketleriyle BIREBIR:
      //    takip_ediyor_mu · bekliyor_mu · beni_takip_ediyor_mu · engelli.
      //    (Yanlis ad SESSIZCE `false` uretir — dugme "Takip Et" gorunur ve
      //     kullanici zaten takip ettigi kisiyi tekrar takip etmeye calisir.)
      takipEdiyorum: il['takip_ediyor_mu'] == true,
      istekBekliyor: il['bekliyor_mu'] == true,
      beniTakipEdiyor: il['beni_takip_ediyor_mu'] == true,
      engelledim: il['engelli'] == true,
    );
  }
}

final sosyalServisiProvider = Provider<SosyalServisi>(
  (ref) => SosyalServisi(ref),
);
