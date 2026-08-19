import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ⚠️⚠️ TURU 77 — ISLETME URUNLERI / MENU + AI.
///
/// ⚠️ AYRI DOSYA (isletme_servisi.dart'a EKLENMEDI): o dosya 200+ satir ve
///    profil sorumlulugu tasiyor; urun + AI ikinci bir sorumluluk olurdu.
class UrunServisi {
  UrunServisi(this._ref);
  final Ref _ref;

  Dio get _api => _ref.read(apiProvider);

  Future<List<Urun>> liste(String isletmeId) async {
    final r = await _api.get('/users/$isletmeId/urunler');
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['urunler'] as List?) ?? [])
        .map((e) => Urun.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<String> ekle(Map<String, dynamic> govde) async {
    final r = await _api.post('/isletme/urunler', data: govde);
    return (r.data['id'] ?? '').toString();
  }

  Future<void> guncelle(String id, Map<String, dynamic> govde) =>
      _api.patch('/isletme/urunler/$id', data: govde);

  Future<void> sil(String id) => _api.delete('/isletme/urunler/$id');
}

class Urun {
  Urun({
    required this.id,
    required this.isletmeId,
    required this.ad,
    required this.aciklama,
    required this.bolum,
    required this.fiyatKurus,
    required this.mediaIds,
    required this.sira,
    required this.durum,
    required this.tur,
    required this.ozellikler,
  });

  final String id;
  final String isletmeId;
  String ad;
  String aciklama;
  String bolum;
  int fiyatKurus;
  final List<String> mediaIds;
  final int sira;
  String durum;

  /// TURU 89 — kategoriye ozel modul turu: 'urun' | 'oda' | 'hizmet'.
  String tur;

  /// Modulun kendi alanlari (kapasite, yatak, sure_dakika...).
  Map<String, String> ozellikler;

  String get fiyatMetni => kurusMetni(fiyatKurus);

  static Urun fromJson(Map<String, dynamic> m) => Urun(
    id: (m['id'] ?? '').toString(),
    isletmeId: (m['isletme_id'] ?? '').toString(),
    ad: (m['ad'] ?? '').toString(),
    aciklama: (m['aciklama'] ?? '').toString(),
    bolum: (m['bolum'] ?? '').toString(),
    fiyatKurus: (m['fiyat_kurus'] as num?)?.toInt() ?? 0,
    mediaIds: ((m['media_ids'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    sira: (m['sira'] as num?)?.toInt() ?? 0,
    durum: (m['durum'] ?? 'yayinda').toString(),
    tur: (m['tur'] ?? 'urun').toString(),
    ozellikler: ((m['ozellikler'] as Map?) ?? {})
        .map((k, v) => MapEntry(k.toString(), (v ?? '').toString())),
  );
}

/// ⚠️⚠️ AI SERVISI — ozellik SUNUCUDA ACIK DEGILSE ARAYUZDE HIC CIZILMEZ.
///
/// `aiDurumProvider` once `GET /ai/durum` sorar; `acik == false` ise AI
/// dugmeleri GOSTERILMEZ. Bu kapi OLMASAYDI kullanici dugmeye basar ve 503
/// alirdi — bu projede tekrar eden "ozellik var gorunup fiilen yok" hatasi.
class AiServisi {
  AiServisi(this._ref);
  final Ref _ref;

  Dio get _api => _ref.read(apiProvider);

  Future<AiDurum> durum() async {
    try {
      final r = await _api.get('/ai/durum');
      final m = (r.data as Map).cast<String, dynamic>();
      return AiDurum(
        acik: m['acik'] == true,
        kalan: (m['kalan'] as num?)?.toInt() ?? 0,
        kota: (m['gunluk_kota'] as num?)?.toInt() ?? 0,
        // ⚠️ Eski sunucuda bu alanlar YOK -> `false`/0 (dugme cizilmez).
        gorsel: m['gorsel'] == true,
        gorselKalan: (m['gorsel_kalan'] as num?)?.toInt() ?? 0,
        gorselKota: (m['gorsel_gunluk_kota'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      // ⚠️ Hata durumunda KAPALI varsayilir — yanlislikla dugme cizmektense
      //    cizmemek daha durust.
      // ⚠️⚠️ TURU 78b — AMA BU KARAR **ONBELLEKLENMEMELI** (denetim bulgusu):
      //    `aiDurumProvider` `autoDispose` DEGILDIR ve tek bir gecici ag hatasi
      //    (asansor, metro, sunucu restart'i) `acik:false`u SUREC OMRU BOYUNCA
      //    onbelleklerdi -> AI ozelligi uygulama YENIDEN BASLATILANA kadar
      //    KAYBOLURDU ve kullanici sebebini anlayamazdi.
      //    Cozum saglayicida: hata durumu onbelleklenmez (bkz. `aiDurumProvider`).
      rethrow;
    }
  }

  /// ⚠️⚠️ TURU 78b — AI CAGRILARI ICIN **UZUN ZAMAN ASIMI** (denetim: SEVK ENGELI).
  ///
  /// Sunucu tarafi OpenAI cagrisina **60 saniye** veriyor. Istemcinin genel
  /// Dio ayari ise `receiveTimeout: 20 sn` (core/api.dart) idi: yani model
  /// 20 saniyeden uzun surdugunde
  ///   · istemci VAZGECER ve kullaniciya jenerik "Bir şeyler ters gitti" der,
  ///   · sunucu cagriyi TAMAMLAR ve **KOTAYI DUSURUR** (rezervasyon cagridan
  ///     ONCE yapiliyor),
  ///   · sonuc URETILMIS oldugu halde KAYBOLUR.
  /// Yani kullanici gunluk 20 hakkindan birini HICBIR SEY ALMADAN yakardi ve
  /// tekrar denedikce ayni sey tekrarlardi.
  ///
  /// ⚠️⚠️⚠️ TURU 79b — SURE **SUNUCU TAVANININ USTUNDE** OLMAK ZORUNDA
  /// (denetim: SEVK ENGELI).
  ///
  ///	Metin uclari icin sunucu tavani 60 sn; **GORSEL uretimi icin 120 sn**
  ///	(`gorselZamanAsimi`) ve ustune R2'ye yazma suresi biniyor. Istemci 90
  ///	sn'de vazgectiginde:
  ///	  · sunucu uretimi TAMAMLAR ve OpenAI faturayi KESER,
  ///	  · gorsel R2'ye yazilir ama istemci `media_id`yi HIC ALMAZ,
  ///	  · kota rezervasyonu 'tamam' olarak kapanir -> gunluk hak YANAR,
  ///	  · uretilen gorsel HICBIR YERE baglanmadan YETIM kalir,
  ///	  · kullanici jenerik bir hata gorur ve tekrar dener (ikinci hak da gider).
  ///	Yani YAVAS uretim GARANTILI kayipti.
  ///
  /// ⚠️ 150 sn = sunucu 120 + R2 yazma payi + ag. Sunucudaki
  ///	`gorselZamanAsimi` degisirse BURASI DA degismeli (iki AYRI yer).
  /// ⚠️ YAPMA: genel Dio zaman asimini buyutme (tum uclari yavaslatir).
  static final _aiSecenek = Options(
    receiveTimeout: const Duration(seconds: 150),
    sendTimeout: const Duration(seconds: 150),
  );

  /// Menu fotografindan ya da aciklamadan yapilandirilmis menu ONERISI.
  /// ⚠️ Sonuc DOGRUDAN KAYDEDILMEZ; kullanici gozden gecirip onaylar.
  Future<String> menu({String mediaId = '', String metin = ''}) async {
    final r = await _api.post(
      '/ai/menu',
      data: {'media_id': mediaId, 'metin': metin},
      options: _aiSecenek,
    );
    return (r.data['sonuc'] ?? '').toString();
  }

  /// Urun fotografindan/adindan satis metni.
  Future<String> urunMetni({String mediaId = '', String metin = ''}) async {
    final r = await _api.post(
      '/ai/urun-metni',
      data: {'media_id': mediaId, 'metin': metin},
      options: _aiSecenek,
    );
    return (r.data['sonuc'] ?? '').toString();
  }

  /// ⚠️⚠️ TURU 79 — METINDEN URUN GORSELI URETIR. **`media_id` DONER.**
  ///
  ///	URL degil id donmesi bilincli: imzali adres kisa omurludur ve kullanici
  ///	gorseli kaydetmeden once olurdu. `media_id` mevcut TUM medya boru
  ///	hattina (erisim dallari, kota, silme kuyrugu) oturur ve istemci onu
  ///	ZATEN bildigi `MedyaGorsel` ile cizer.
  /// ⚠️ Uretilen gorsel HICBIR YERE otomatik baglanmaz; kullanici onaylar.
  Future<String> gorsel({required String metin}) async {
    final r = await _api.post(
      '/ai/gorsel',
      data: {'metin': metin},
      options: _aiSecenek,
    );
    return (r.data['media_id'] ?? '').toString();
  }

  /// ⚠️ TURU 79b — BEGENILMEYEN uretimi siler; DEPOLAMA kotasi geri verilir.
  ///    AI hakki IADE EDILMEZ (uretim gercekten para harcadi).
  /// ⚠️ Hata YUTULUR: bu bir TEMIZLIK yolu, kullanicinin akisini kesmemeli.
  Future<void> gorselVazgec(String mediaId) async {
    try {
      await _api.delete('/ai/gorsel/$mediaId');
    } catch (_) {}
  }

  /// Fotograftan sorun tespiti.
  /// ⚠️⚠️ TURU 111 — SOHBET: fotograf ARTIK ZORUNLU DEGIL ve [gecmis]
  ///	ile BAGLAM tasinir. Sunucu gecmisi SAKLAMAZ; her istekte ekrandaki
  ///	konusma gonderilir (tablo yok -> "sohbetlerim" gibi olmayan bir
  ///	ozellik vaat edilmiyor).
  /// ⚠️ Sunucu son 12 mesaji alir ve her birini kirpar (token maliyeti).
  Future<String> danisma({
    String mediaId = '',
    String metin = '',
    List<({String rol, String metin})> gecmis = const [],
  }) async {
    final r = await _api.post(
      '/ai/danisma',
      data: {
        'media_id': mediaId,
        'metin': metin,
        'gecmis': [
          for (final m in gecmis) {'rol': m.rol, 'metin': m.metin},
        ],
      },
      options: _aiSecenek,
    );
    return (r.data['sonuc'] ?? '').toString();
  }
}

class AiDurum {
  const AiDurum({
    required this.acik,
    required this.kalan,
    required this.kota,
    this.gorsel = false,
    this.gorselKalan = 0,
    this.gorselKota = 0,
  });
  final bool acik;
  final int kalan;
  final int kota;

  /// ⚠️⚠️ TURU 79 — GORSEL URETIMI **AYRI BAYRAK**.
  ///    `acik` ile aynilastirilamaz: anahtar VAR ama medya (R2) KAPALI ise
  ///    uretilen bayti koyacak yer YOKTUR ve sunucu 503 doner. Dugmeyi bu
  ///    bayraga bakmadan cizmek, projede alti kez tekrarlayan "ozellik var
  ///    gorunup fiilen yok" hatasinin yenisi olurdu.
  final bool gorsel;

  /// ⚠️ Gorsel kotasi METINDEN AYRI sayilir (bir gorsel ~40 metin cagrisina
  ///    bedel). Metin hakki dolu olsa bile gorsel hakki DURUYOR olabilir.
  final int gorselKalan;
  final int gorselKota;
}

final urunServisiProvider = Provider<UrunServisi>(UrunServisi.new);
final aiServisiProvider = Provider<AiServisi>(AiServisi.new);

/// ⚠️ SUREC OMURLU: AI acik mi sorusu her ekranda tekrar sorulmaz.
///
/// ⚠️⚠️ TURU 78b — HATA **ONBELLEKLENMEZ** (denetim bulgusu).
///
///	Bu saglayici `autoDispose` DEGIL; eskiden `durum()` hatayi yutup
///	`acik:false` DONDURDUGU icin tek bir gecici ag hatasi (asansor, metro,
///	sunucu restart'i, 10 sn'lik connectTimeout) **AI ozelligini uygulama
///	yeniden baslatilana kadar YOK EDIYORDU**: butun AI dugmeleri cizilmiyor,
///	kullanici sebebini anlayamiyor, kurtarma yolu da yok (invalidate eden
///	tek yer basarili bir AI cagrisiydi — ki dugme cizilmedigi icin
///	ULASILAMAZ).
///
///	Artik `durum()` FIRLATIYOR, hata AsyncError olarak dusuyor ve
///	`ref.invalidateSelf()` ile onbellek ATILIYOR: bir sonraki ekran acilisi
///	YENIDEN SORUYOR. Bu arada `valueOrNull` null oldugu icin dugmeler yine
///	cizilmez — yani "yanlislikla dugme cizme" korumasi KORUNUYOR, yalnizca
///	kalicilik gidiyor.
/// ⚠️ YAPMA: `durum()` icindeki `rethrow`u tekrar `return AiDurum(acik:false)`
///	yapma; bu saglayiciyi `keepAlive`a cevirme.
final aiDurumProvider = FutureProvider<AiDurum>((ref) async {
  try {
    return await ref.read(aiServisiProvider).durum();
  } catch (_) {
    ref.invalidateSelf();
    rethrow;
  }
});

/// Kurus -> "12,50 ₺" bicimi. **TEK KAYNAK.**
///
/// ⚠️ TURU 77b — AI menu onizlemesi bu bicimlendiriciyi KULLANMIYOR, kendi
///    `kurus ~/ 100` hesabini yapiyordu ve **KURUSU KIRPIYORDU** (12,50 TL
///    "12 ₺" gorunuyordu) — ayni ekranin katalog satiri ise dogru gosteriyordu.
///    Ayni kuralin iki kopyasi yine drift etmisti (CLAUDE.md turu 72b/H).
/// ⚠️ YAPMA: fiyat bicimini baska bir yerde elle hesaplama.
String kurusMetni(int kurus) {
  if (kurus <= 0) return '';
  final tl = kurus ~/ 100;
  final kr = kurus % 100;
  return kr == 0 ? '$tl ₺' : '$tl,${kr.toString().padLeft(2, '0')} ₺';
}

/// ⚠️⚠️⚠️ TURU 89 — KATEGORIYE OZEL KATALOG MODULU.
///
/// Kullanici emri: *"otel ekledin ama ODALAR var mi? isletme oda eklemeli,
/// doktorlar vs HIZMET ALANI eklemeli, belirli baslikli MODULLER olacakti"*.
///
/// ⚠️ TANIM **SUNUCUDAN** gelir (`GET /isletme-modulleri`), istemciye
///    GOMULMEZ. Gomulseydi Go + Dart arasinda UCUNCU bir kopya acilirdi;
///    `isletmeKategorileri` zaten itiraf edilmis bir kopya ve onun ucuncusu
///    (vitrin) turu 85b'de SESSIZCE KIRILMISTI.
/// ⚠️ Boylece yeni bir alan eklemek ISTEMCI GUNCELLEMESI GEREKTIRMEZ.
class Modul {
  const Modul({
    required this.ad,
    required this.tekil,
    required this.tur,
    required this.bolumEtiketi,
    required this.alanlar,
  });

  /// Katalog basligi ("Odalar", "Hizmetler", "Menü").
  final String ad;

  /// Tekil ad ("Oda ekle", "Hizmet ekle").
  final String tekil;

  /// `isletme_urunleri.tur` degeri.
  final String tur;

  /// "Bölüm" alaninin kategoriye ozel etiketi.
  final String bolumEtiketi;

  /// Kategoriye ozel ek alanlar.
  final List<ModulAlan> alanlar;

  static const varsayilan = Modul(
    ad: 'Ürünler',
    tekil: 'Ürün',
    tur: 'urun',
    bolumEtiketi: 'Bölüm',
    alanlar: [],
  );

  static Modul fromJson(Map<String, dynamic> m) => Modul(
    ad: (m['ad'] ?? 'Ürünler').toString(),
    tekil: (m['tekil'] ?? 'Ürün').toString(),
    tur: (m['tur'] ?? 'urun').toString(),
    bolumEtiketi: (m['bolum_etiketi'] ?? 'Bölüm').toString(),
    alanlar: ((m['alanlar'] as List?) ?? [])
        .map((e) => ModulAlan.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

/// Modulun tek bir alani. `ilan.Alan` ile AYNI sozlesme (sunucuda da ayni tip).
class ModulAlan {
  const ModulAlan({
    required this.anahtar,
    required this.ad,
    required this.tip,
    required this.secenekler,
    required this.birim,
  });

  final String anahtar;
  final String ad;

  /// metin | sayi | secim
  final String tip;
  final List<String> secenekler;
  final String birim;

  static ModulAlan fromJson(Map<String, dynamic> m) => ModulAlan(
    anahtar: (m['anahtar'] ?? '').toString(),
    ad: (m['ad'] ?? '').toString(),
    tip: (m['tip'] ?? 'metin').toString(),
    secenekler: ((m['secenekler'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    birim: (m['birim'] ?? '').toString(),
  );
}
