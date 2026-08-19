import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ⚠️⚠️ TURU 77 — ILANLAR + HIZMETLER (kullanici emri: "ilanlar olacak
/// sahibinden gibi araba ev 2.el alim satim vs" + "hizmetler kategorisi").
///
/// ⚠️⚠️ KATEGORI AGACI **SUNUCUDAN** GELIR, ISTEMCIDE KOPYA YOK.
///    Turu 77 denetim bulgusu: bu projede "ayni listenin Go + Dart iki kopyasi"
///    itiraf edilmis bir drift bombasi (turu 72b/H). Ustelik agac `alanlar`
///    dizisi tasidigi icin ILAN VERME FORMU DA sunucudan uretiliyor — yeni bir
///    alan eklemek icin istemci guncellemesi GEREKMIYOR.
/// ⚠️ YAPMA: Dart'a kategori/tur sabiti yazma.
class IlanServisi {
  IlanServisi(this._ref);
  final Ref _ref;

  Dio get _api => _ref.read(apiProvider);

  /// ⚠️⚠️ TURU 93b — `kategori` VERILIRSE SUNUCU ALANLARI SUZER.
  ///
  ///	Kullanicinin emri iki daldi (*"düğün mü yapmak istiyorsun HIZMET mi
  ///	almak istiyorsun"*). Istemci dali ayiriyordu ama SORULAR ayni
  ///	kaliyor ve "Temizlik" talebi acana **Gelinlik / Gelin arabası /
  ///	Kır düğünü** soruluyordu.
  /// ⚠️ Suzme SUNUCUDA: hangi alanin hangi kategoride cizilecegini Dart'a
  ///    yazmak turu 77'nin "istemciye tur/kategori sabiti YAZMA" kuralini
  ///    ihlal ederdi ve yeni alan MAGAZA ONAYI gerektirirdi.
  /// ⚠️ Bos birakilirsa TAM agac doner (ilan verme formu DEGISMEDEN calisir).
  Future<List<IlanTuru>> agac({String kategori = ''}) async {
    final r = await _api.get('/ilan-kategoriler', queryParameters: {
      if (kategori.isNotEmpty) 'kategori': kategori,
    });
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['turler'] as List?) ?? [])
        .map((e) => IlanTuru.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<Ilan>> liste({
    String tur = '',
    String kategori = '',
    String il = '',
    String ilce = '',
    String q = '',
    int? minKurus,
    int? maksKurus,
    bool benim = false,
    bool favori = false,
  }) async {
    final r = await _api.get(
      '/ilanlar',
      queryParameters: {
        if (tur.isNotEmpty) 'tur': tur,
        if (kategori.isNotEmpty) 'kategori': kategori,
        if (il.isNotEmpty) 'il': il,
        if (ilce.isNotEmpty) 'ilce': ilce,
        if (q.isNotEmpty) 'q': q,
        if (minKurus != null) 'min': minKurus,
        if (maksKurus != null) 'maks': maksKurus,
        if (benim) 'benim': '1',
        if (favori) 'favori': '1',
      },
    );
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['ilanlar'] as List?) ?? [])
        .map((e) => Ilan.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Ilan> detay(String id) async {
    final r = await _api.get('/ilanlar/$id');
    return Ilan.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<String> olustur(Map<String, dynamic> govde) async {
    final r = await _api.post('/ilanlar', data: govde);
    return (r.data['id'] ?? '').toString();
  }

  Future<void> guncelle(String id, Map<String, dynamic> govde) =>
      _api.patch('/ilanlar/$id', data: govde);

  /// ⚠️ TURU 78 — ILAN HAKKINDA saticiya yaz. Sohbet ILANA baglidir; ayni
  ///    kisi ayni ilan icin tekrar yazarsa AYNI sohbet acilir, BASKA bir ilan
  ///    icin AYRI sohbet (sahibinden/Letgo davranisi).
  Future<String> sohbetAc(String id) async {
    final r = await _api.post('/ilanlar/$id/sohbet');
    return (r.data['chat_id'] ?? '').toString();
  }

  Future<void> favoriEkle(String id) => _api.post('/ilanlar/$id/favori');
  Future<void> favoriSil(String id) => _api.delete('/ilanlar/$id/favori');

  // ═══════════════ TURU 90 — IS ILANI BASVURUSU ═══════════════
  //
  // ⚠️⚠️⚠️ BU BES METOT TURU 90b DENETIMINDE EKLENDI. Sunucu tarafi
  // (5 uc + tablo + yetki kapilari + bildirim) turu 90'da yazilmisti ama
  // ISTEMCIDE TEK SATIR YOKTU: `grep -rn "basvur" mobile/lib/` SIFIR
  // donuyordu. Yani kullanicinin bu turdaki MANSET EMRI
  // (*"normal kullanicilar basvuru yapabilmeli"*) sahada **%100 OLU
  // DOGACAKTI** — uc bagimsiz denetim ajani da ayni sonuca vardi.
  // ⚠️ DERS (dokuzuncu tekrar): bir uc/sutun/servis ekledigin AN onu
  //    KULLANAN yolu da yaz; "sunucu hazir" YARIM istir.

  /// Basvur (ya da geri cekilmis basvuruyu YENIDEN AC).
  ///
  /// ⚠️ Sunucu tekrar basvuruyu HATA SAYMAZ (200) — istemci de saymaz.
  /// ⚠️ TURU 91 — [fiyatKurus] YALNIZ `tur='talep'` ilanlarda anlamlidir
  ///    (KARSI TEKLIF tutari). Is ilaninda sunucu onu YOK SAYAR.
  ///    ⚠️ Talebin BUTCESIYLE karistirilmamali: butce `ilanlar.fiyat_kurus`,
  ///       teklif `ilan_basvurular.fiyat_kurus`.
  Future<void> basvur(String ilanID, String not, {int fiyatKurus = 0}) =>
      _api.post('/ilanlar/$ilanID/basvuru',
          data: {'not': not, 'fiyat_kurus': fiyatKurus});

  Future<void> basvuruGeriCek(String ilanID) =>
      _api.delete('/ilanlar/$ilanID/basvuru');

  /// ILAN SAHIBI icin basvuranlar.
  ///
  /// ⚠️ Sahibi olmayan BOS liste alir (sunucu 404/bos doner — 403 DEGIL,
  ///    cunku 403 "bu ilanin basvurusu var" bilgisini SIZDIRIRDI).
  Future<List<Basvuru>> basvurular(String ilanID) async {
    final r = await _api.get('/ilanlar/$ilanID/basvurular');
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['basvurular'] as List?) ?? [])
        .map((e) => Basvuru.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> basvuruDurum(String ilanID, String basvuruID, String durum) =>
      _api.patch('/ilanlar/$ilanID/basvurular/$basvuruID',
          data: {'durum': durum});

  /// Kullanicinin KENDI basvurulari.
  /// ⚠️ TURU 91 — [tur] suzgeci: ayni uc hem "Başvurularım" (is ilanlari)
  ///    hem "Tekliflerim" (talepler) ekranini besler. Iki ayri uc acmak
  ///    ayni yetki yuklemini iki kez yazmak olurdu.
  Future<List<Basvuru>> basvurularim({String tur = ''}) async {
    final r = await _api.get('/users/me/basvurular',
        queryParameters: {if (tur.isNotEmpty) 'tur': tur});
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['basvurular'] as List?) ?? [])
        .map((e) => Basvuru.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}

/// Is ilani basvurusu.
///
/// ⚠️ TEK MODEL, IKI YON: sahibinin listesi basvuran bilgisini (ad/kadi/
///    avatar/not) tasir, kullanicinin kendi listesi ilan bilgisini
///    (ilan_id/baslik). Iki ayri model yazmak, ortak alanlarin (durum,
///    created_at) IKI KOPYASINI dogurur ve bu projede o kopyalar
///    KACINILMAZ olarak drift eder. Kullanilmayan alanlar bos kalir.
class Basvuru {
  Basvuru({
    required this.id,
    required this.userID,
    required this.ad,
    required this.kullaniciAdi,
    required this.avatarID,
    required this.not,
    required this.durum,
    required this.ilanID,
    required this.baslik,
    this.fiyatKurus = 0,
    this.guncellendiAt = '',
    this.createdAt = '',
  });

  final String id;
  final String userID;
  final String ad;
  final String kullaniciAdi;
  final String? avatarID;
  final String not;

  /// bekliyor | goruldu | olumlu | olumsuz | geri_cekildi
  final String durum;

  /// Yalniz "Basvurularim" listesinde dolu.
  final String ilanID;
  final String baslik;

  /// ⚠️ TURU 91 — TEKLIF TUTARI (talep ilanlarinda). Is ilaninda 0.
  final int fiyatKurus;

  /// ⚠️ Teklif REVIZE edilince degisir; `created_at` KORUNUR (revizede
  ///    listenin basina ziplamak spam kapisi olurdu). Arayuz "revize
  ///    edildi" etiketini bununla cizer — cizilmezse sutun OLU KALIR.
  final String guncellendiAt;

  /// ⚠️ TURU 93b — REVIZE KIYASI ICIN GEREKLI. Sunucu bu alani ZATEN
  ///    donduruyordu (`basvuru.go` yanit haritasi) ama istemci OKUMUYORDU;
  ///    o yuzden "revize edildi" etiketi `guncellendi_at`in yalnizca DOLU
  ///    olup olmadigina bakiyor ve HER teklifte ciziliyordu.
  final String createdAt;

  static Basvuru fromJson(Map<String, dynamic> m) => Basvuru(
    id: (m['id'] ?? '').toString(),
    userID: (m['user_id'] ?? '').toString(),
    ad: (m['name'] ?? '').toString(),
    kullaniciAdi: (m['username'] ?? '').toString(),
    avatarID: m['avatar_media_id'] as String?,
    not: (m['not'] ?? '').toString(),
    durum: (m['durum'] ?? 'bekliyor').toString(),
    ilanID: (m['ilan_id'] ?? '').toString(),
    baslik: (m['baslik'] ?? '').toString(),
    fiyatKurus: (m['fiyat_kurus'] as num?)?.toInt() ?? 0,
    guncellendiAt: (m['guncellendi_at'] ?? '').toString(),
    createdAt: (m['created_at'] ?? '').toString(),
  );

  /// ⚠️ ETIKET TEK KAYNAK: uc ekran (basvuranlar · basvurularim · rozet)
  ///    ayni metni cizer. Uc kopya yazilsaydi biri guncellenmeden kalirdi.
  String get durumEtiketi => switch (durum) {
    'bekliyor' => 'Bekliyor',
    'goruldu' => 'Görüldü',
    'olumlu' => 'Olumlu',
    'olumsuz' => 'Olumsuz',
    // ⚠️ TURU 91 — TEKLIF kararlari. Sunucudaki `basvuruDurumlari` beyaz
    //    listesiyle AYNI kume; biri guncellenip oteki unutulursa kullanici
    //    ham dize ("secildi") gorur.
    'secildi' => 'Seçildi',
    'elendi' => 'Elendi',
    'geri_cekildi' => 'Geri çekildi',
    _ => durum,
  };
}

class IlanTuru {
  IlanTuru({
    required this.anahtar,
    required this.ad,
    required this.kategoriler,
    required this.alanlar,
  });

  final String anahtar;
  final String ad;
  final List<({String anahtar, String ad})> kategoriler;
  final List<IlanAlani> alanlar;

  static IlanTuru fromJson(Map<String, dynamic> m) => IlanTuru(
    anahtar: (m['anahtar'] ?? '').toString(),
    ad: (m['ad'] ?? '').toString(),
    kategoriler: ((m['kategoriler'] as List?) ?? [])
        .map(
          (e) => (
            anahtar: ((e as Map)['anahtar'] ?? '').toString(),
            ad: (e['ad'] ?? '').toString(),
          ),
        )
        .toList(),
    alanlar: ((m['alanlar'] as List?) ?? [])
        .map((e) => IlanAlani.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

/// Tipe ozel alan tanimi — FORM BUNDAN URETILIR.
class IlanAlani {
  IlanAlani({
    required this.anahtar,
    required this.ad,
    required this.tip,
    required this.secenekler,
    required this.birim,
    this.adim = 0,
    this.zorunlu = false,
  });

  final String anahtar;
  final String ad;

  /// metin | sayi | secim | cok_secim | tarih
  final String tip;
  final List<String> secenekler;
  final String birim;

  /// ⚠️ TURU 91 — ADIM ADIM FORM. Sunucudan gelir; 0 = adimsiz (mevcut
  ///    tum turler). Istemci alanlari buna gore GRUPLAR — sirayi Dart'a
  ///    yazmak turu 77'nin "Dart'a sabit yazma" kuralini ihlal ederdi.
  final int adim;

  /// Istemcide "Devam" dugmesini kilitler. SUNUCU DOGRULAMAZ — bu bir
  /// arayuz kolayligidir, guvenlik kapisi DEGILDIR.
  final bool zorunlu;

  static IlanAlani fromJson(Map<String, dynamic> m) => IlanAlani(
    anahtar: (m['anahtar'] ?? '').toString(),
    ad: (m['ad'] ?? '').toString(),
    tip: (m['tip'] ?? 'metin').toString(),
    adim: (m['adim'] as num?)?.toInt() ?? 0,
    zorunlu: m['zorunlu'] == true,
    secenekler: ((m['secenekler'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    birim: (m['birim'] ?? '').toString(),
  );
}

class Ilan {
  Ilan({
    required this.id,
    required this.sahibiId,
    required this.sahibiAd,
    required this.sahibiAvatarMediaId,
    this.sahibiIsletme = false,
    this.sahibiOnayli = false,
    required this.tur,
    required this.kategori,
    required this.baslik,
    required this.aciklama,
    required this.fiyatKurus,
    required this.fiyatGizli,
    required this.il,
    required this.ilce,
    required this.mediaIds,
    required this.ozellikler,
    required this.durum,
    required this.goruntulenme,
    required this.createdAt,
    required this.favorim,
    required this.mediaKinds,
    this.duzenlendiAt,
  });

  final String id;
  final String sahibiId;
  final String sahibiAd;
  final String? sahibiAvatarMediaId;

  /// ⚠️ TURU 114 — ilan sahibinin ISLETME hesabi olup olmadigi. Kartta
  ///    "İşletme" rozeti bu alandan cizilir; TAHMIN EDILMEZ.
  /// ⚠️ Varsayilan `false`: eski sunucu bu alani dondurmezse rozet HIC
  ///    cizilmez (yanlis rozet, rozetsizlikten kotudur).
  final bool sahibiIsletme;
  final bool sahibiOnayli;
  final String tur;

  // ⚠️⚠️ TURU 78 — DUZENLEME sonrasi SESSIZ TAZELEME bu alanlari GUNCELLER.
  //    Nesne YENISIYLE DEGISTIRILMEZ (liste ayni ornegi tutuyor; yeni nesne
  //    atansaydi listedeki kart ESKI degeri gostermeye devam ederdi —
  //    turu 76 dersi). Bu yuzden duzenlenebilir alanlar `final` DEGIL.
  String kategori;
  String baslik;
  String aciklama;

  /// ⚠️ KURUS. Ekranda `fiyatMetni` ile bicimlenir.
  int fiyatKurus;
  bool fiyatGizli;
  String il;
  String ilce;
  final List<String> mediaIds; // icerigi degisir, referans degil
  final Map<String, dynamic> ozellikler;

  /// TURU 78 — `media_kinds[i]` <-> `mediaIds[i]` (image/video/yok).
  /// ⚠️ Sunucu SIRA KORUYARAK donduruyor; istemci indeksle eslestirir.
  final List<String> mediaKinds;

  /// TURU 78 — NULL ise hic duzenlenmedi. Alici guveni icin gosterilir.
  String? duzenlendiAt;
  String durum;
  /// ⚠️ DEGISEBILIR: detay ekrani acilista SESSIZCE tazeliyor (bkz.
  ///    `IlanDetayEkrani` serhi). `final` olsaydi sayac EKRANDA HEP 0 kalirdi.
  int goruntulenme;
  final String createdAt;

  /// ⚠️ DEGISEBILIR: iyimser guncelleme (kalp) icin.
  bool favorim;

  String get fiyatMetni {
    if (fiyatGizli || fiyatKurus <= 0) return 'Fiyat belirtilmemiş';
    // ⚠️ Binlik ayirici ELLE: `intl` NumberFormat icin yerel ayar yuklemesi
    //    gerekiyor ve uygulama acilisina yuk bindiriyor.
    final tl = (fiyatKurus ~/ 100).toString();
    final buf = StringBuffer();
    for (var i = 0; i < tl.length; i++) {
      if (i > 0 && (tl.length - i) % 3 == 0) buf.write('.');
      buf.write(tl[i]);
    }
    // ⚠️⚠️ **`TL`, `₺` DEGIL.** `isletme_kart.dart` serhi: bazi Android
    //    fontlarinda `₺` glifi EKSIK ve yerine TOFU (bos kare) cizilir;
    //    kullanici emriyle isletme kartinda `TL` yazilmisti. Ilan karti
    //    ayni gorsel slotu kullaniyor — iki ekran iki farkli para
    //    gosterimi kullanamaz.
    return '$buf TL';
  }

  /// ⚠️⚠️⚠️ TURU 106 — **FIYAT TURE GORE ANLAM DEGISTIRIR.**
  ///
  ///	Sunucu serhi (`internal/ilan/handler.go`): `fiyat_kurus`
  ///	  · `is`    -> **MAAS**
  ///	  · `talep` -> **BUTCE**
  ///	  · digerleri -> satis fiyati
  ///	Ilan verme formu bunu ZATEN biliyor ("Maaş belirtme" / "Maaş
  ///	(₺ / ay)") ama LISTE ve DETAY bilmiyordu: maasi girilmemis bir is
  ///	ilaninda ekranin en buyuk yazisi **"Fiyat belirtilmemiş"** oluyordu.
  ///	Ayni kuralin iki kopyasi, biri guncellenmis — bu projede kayitli
  ///	en sik hata sinifi.
  /// ⚠️ `fiyatMetni` TEK KAYNAK olarak KALIR; bu getter onu sarar.
  String get fiyatEtiketi {
    final bos = fiyatGizli || fiyatKurus <= 0;
    return switch (tur) {
      'is' => bos ? 'Maaş belirtilmemiş' : '$fiyatMetni / ay',
      'talep' => bos ? 'Bütçe belirtilmemiş' : 'Bütçe: $fiyatMetni',
      _ => fiyatMetni,
    };
  }

  bool get yayindaMi => durum == 'yayinda';

  static Ilan fromJson(Map<String, dynamic> m) => Ilan(
    id: (m['id'] ?? '').toString(),
    sahibiId: (m['sahibi_id'] ?? '').toString(),
    sahibiAd: (m['sahibi_ad'] ?? '').toString(),
    sahibiAvatarMediaId: m['sahibi_avatar_media_id'] as String?,
    sahibiIsletme: (m['sahibi_hesap_turu'] ?? '').toString() == 'isletme',
    sahibiOnayli: m['sahibi_onayli'] == true,
    tur: (m['tur'] ?? '').toString(),
    kategori: (m['kategori'] ?? '').toString(),
    baslik: (m['baslik'] ?? '').toString(),
    aciklama: (m['aciklama'] ?? '').toString(),
    fiyatKurus: (m['fiyat_kurus'] as num?)?.toInt() ?? 0,
    fiyatGizli: m['fiyat_gizli'] == true,
    il: (m['il'] ?? '').toString(),
    ilce: (m['ilce'] ?? '').toString(),
    mediaIds: ((m['media_ids'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    ozellikler: (m['ozellikler'] as Map?)?.cast<String, dynamic>() ?? {},
    // ⚠️ Sunucu SIRA KORUYARAK donduruyor (unnest ... WITH ORDINALITY);
    //    `mediaKinds[i]` <-> `mediaIds[i]`. Eski sunucudan bos gelirse
    //    galeri hepsini FOTOGRAF sayar (guvenli varsayilan).
    mediaKinds: ((m['media_kinds'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    duzenlendiAt: m['duzenlendi_at'] as String?,
    durum: (m['durum'] ?? 'yayinda').toString(),
    goruntulenme: (m['goruntulenme'] as num?)?.toInt() ?? 0,
    createdAt: (m['created_at'] ?? '').toString(),
    favorim: m['favorim'] == true,
  );
}

/// Tur/kategori agaci — SUREC OMURLU onbellek.
/// ⚠️ `FutureProvider`: agac nadiren degisir, her ekranda yeniden cekmek
///    gereksiz. Uygulama yeniden acilinca tazelenir.
final ilanAgaciProvider = FutureProvider<List<IlanTuru>>(
  (ref) => ref.read(ilanServisiProvider).agac(),
);

final ilanServisiProvider = Provider<IlanServisi>(IlanServisi.new);

/// ⚠️⚠️⚠️ TURU 106 — **HAM ANAHTAR EKRANA CIZILMEZ.**
///
///	Detay ekrani `ozellikler` haritasini oldugu gibi doluyordu ve
///	kullanici ekranda **`calisma_sekli`**, **`deneyim_yil`**, **`m2`**,
///	**`km`** goruyordu. Etiket (`Çalışma şekli`), BIRIM (`km`, `m²`) ve
///	SIRA sunucunun kategori agacinda ZATEN tanimli — istemci onlari
///	okumuyordu.
///
/// ⚠️ SIRA **AGACTAN** gelir, `ozellikler`den DEGIL: `ozellikler` bir
///    JSONB haritasidir ve anahtar sirasi GARANTI DEGILDIR (vasitada
///    `km · yil · marka` gibi rastgele cikiyordu).
/// ⚠️ Agac henuz gelmediyse **BOS liste** doner: ham anahtar basmaktansa
///    hic basmamak dogru (yanlis bilgi > eksik bilgi).
/// ⚠️ [enFazla] kart icin: yalnizca ilk N alan.
List<({String ad, String deger})> ilanOzellikleri(
  Ilan i,
  List<IlanTuru>? agac, {
  int? enFazla,
}) {
  final t = agac?.where((t) => t.anahtar == i.tur).firstOrNull;
  if (t == null) return const [];
  final out = <({String ad, String deger})>[];
  for (final a in t.alanlar) {
    final v = i.ozellikler[a.anahtar]?.toString().trim() ?? '';
    if (v.isEmpty) continue;
    out.add((ad: a.ad, deger: a.birim.isEmpty ? v : '$v ${a.birim}'));
    if (enFazla != null && out.length >= enFazla) break;
  }
  return out;
}