import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' show Geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../router.dart' show rootMessengerKey;

/// Konum izni verilmediginde `konumAkisi` bunu firlatir.
///
/// ⚠️ Ayri bir tip: cagiran taraf "izin yok" ile "GPS sinyali kesildi"
///    durumlarini AYIRT EDIP farkli mesaj gosterebilsin.
class KonumIzniYok implements Exception {
  const KonumIzniYok();
  @override
  String toString() => 'Konum izni verilmedi';
}

/// ⚠️⚠️⚠️ TURU 81 — KONUM PAYLASMA.
///
/// Kullanici: *"hem normalde hem mesajlarda konum paylasma yok"*.
///
/// ═══════════ NEDEN "OLU OZELLIK" IDI ═══════════
///
/// `location` mesaj tipi DB CHECK'inde (015) ve sunucu beyaz listesinde (turu
/// 59) **ZATEN KABUL EDILIYORDU**; sohbet listesi onizlemesi bile o tip icin
/// "Konum" + harita ikonu ciziyordu. Ama konum ALAN hicbir paket, GONDEREN
/// hicbir yol ve BALONU CIZEN hicbir dal yoktu — bu, projenin SEKIZINCI "sutun
/// var, kullanan yol yok" ornegiydi.
///
/// ═══════════ ICERIK BICIMI: "enlem,boylam" ═══════════
///
/// ⚠️ JSON DEGIL, DUZ METIN. Gerekce: mesaj balonu / sohbet listesi onizlemesi
///    ve PUSH bildirimi, TANIMADIGI bir tipin `content` alanini **HAM olarak**
///    basar. JSON kullanilsaydi eski bir istemcide ya da bildirimde kullanici
///    `{"lat":41.0,"lon":28.9}` gorurdu. "41.0082,28.9784" ise en kotu
///    ihtimalle KOORDINAT olarak okunur — bozuk degil, sadece sade.
/// ⚠️ YAPMA: bu alani JSON'a cevirme.
class KonumServisi {
  /// TURU 90 - KOORDINATTAN OKUNUR YER ADI (ters geocoding).
  ///
  /// Gonderide gosterilecek metni uretir (or. "Gebze, Kocaeli").
  ///
  /// ⚠️ ISLETIM SISTEMININ geocoder'i kullanilir (Android Geocoder, iOS
  ///    CLGeocoder) — API ANAHTARI GEREKTIRMEZ. Google Geocoding API ayri
  ///    bir uc ve ayri faturalandirma isterdi.
  /// ⚠️ geocoding 5.x API'si SINIF TABANLI: ust duzey
  ///    `placemarkFromCoordinates(...)` fonksiyonu KALDIRILDI (turu 87
  ///    dersi — o surumde `locationFromAddress` de ayni sekilde tasindi).
  /// ⚠️ BASARISIZLIK HATA DEGIL: ag yoksa ya da adres bulunamazsa BOS DIZE
  ///    doner ve cagiran taraf koordinati YINE DE kaydeder — ozellik yarim
  ///    kalmaz.
  static Future<String> yerAdi(double enlem, double boylam) async {
    try {
      final l = await Geocoding()
          .placemarkFromCoordinates(enlem, boylam)
          .timeout(const Duration(seconds: 8));
      if (l.isEmpty) return '';
      final p = l.first;
      // Ilce + il: kullanicinin tanidigi olcek budur.
      final parcalar = <String>[
        if ((p.subAdministrativeArea ?? '').isNotEmpty) p.subAdministrativeArea!,
        if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
      ];
      return parcalar.join(', ');
    } catch (_) {
      return '';
    }
  }

  /// Konumu bir kez okur. Basarisizsa `null` doner ve KULLANICIYA SOYLER
  /// (sessizce basarisiz olmaz — bu projede "gonderdim sandim" defalarca yasandi).
  /// ⚠️⚠️⚠️ TURU 128 — **`sessiz` KIPI** (emulatorde goruldu: menuyu her
  ///	acista "Konum alinamadi — acik alanda tekrar dene" seridi
  ///	ciziliyordu).
  ///
  ///	Kullanicinin ISTEDIGI bir islemde (konum paylas, Yakinimda ekrani)
  ///	uyari DOGRU: kisi bir sonuc bekliyor ve sessiz basarisizlik
  ///	"gonderdim sandim" uretir. Ama menudeki mesafe rozetleri KULLANICI
  ///	ISTEMEDEN, arka planda olculuyor — orada uyari SEBEPSIZ bir
  ///	rahatsizliktir; ozellik zaten mesafeyi CIZMEYEREK kendini kapatiyor.
  ///
  /// ⚠️ Varsayilan `false`: mevcut cagri yerlerinin davranisi DEGISMEZ.
  /// ⚠️ YAPMA: `sessiz`i kullanicinin baslattigi akislarda kullanma.
  /// ⚠️⚠️⚠️ TURU 157 - **KONUM IZNI TEK KAPIDAN, SERI.**
  ///
  ///	Kullanici: *"1 kere ya da uygulamayi kullanirken IZINLERI
  ///	VERDIGIMDE navigasyon sikintisi oluyor"*.
  ///
  /// ⚠️⚠️ **KOK NEDEN: ANDROID AYNI ANDA TEK IZIN DIYALOGU KABUL EDER.**
  ///	Ikinci istek diyalog gostermeden **SENKRON BOS SONUCLA**
  ///	duser ve `isGranted` **false** doner. Kod tabaninda UC ayri
  ///	cagri yeri var (onboarding - `konumAl` - `konumAkisi`) ve
  ///	bunlar yarisabiliyor:
  ///	  · ekran acilisi `_yukle -> konumAl` (izin ister)
  ///	  · kullanici "Basla" -> `konumAkisi` (izin ister)
  ///	Ikincisi dusunce `KonumIzniYok` firlar ve takip daha
  ///	**BASLAMADAN** *"Takip icin konum izni gerekiyor"* deyip
  ///	kendini kapatir - kullanici izni AZ ONCE VERMIS OLSA BILE.
  ///
  /// ⚠️⚠️ Bu, turu 85c'de CallKit bildirim izni ile telefon izni
  ///	arasinda yasanan carpismanin BIREBIR AYNISI. O turda ders
  ///	CLAUDE.md'ye yazilmisti; burada TEKRARLANDI.
  ///
  /// ⚠️ Ucus halindeki istek PAYLASILIR: es zamanli cagiranlar AYNI
  ///    `Future`u bekler, yani ikinci bir diyalog HIC acilmaz.
  /// ⚠️ `finally` ile alan bosaltilir - sonraki (es zamanli OLMAYAN)
  ///    cagri gerekirse yeniden sorabilsin. Zaten bekleyenler degeri alir.
  /// ⚠️⚠️ YAPMA: `Permission.locationWhenInUse.request()`i cagri
  ///	yerlerine geri dagitma.
  static Future<bool>? _izinIsi;

  /// ⚠️⚠️⚠️ TURU 159 - **"BIR KEZ IZIN VER" DIYALOGU TEKRAR TEKRAR
  ///	CIKIYORDU** (kullanici sahada gordu: *"navigasyon tek seferlik
  ///	izin verdigimde, uygulamayi KAPATMADAN yine ekranda izin
  ///	geliyor"*).
  ///
  /// ⚠️⚠️ **KOK NEDEN: DURUM HIC SORULMUYORDU.** Govde her cagrida
  ///	KOSULSUZ `request()` calistiriyordu. iOSta "Bir Kez Izin Ver"
  ///	secildiginde yetki verilir ama GECICIDIR; ardindan gelen HER
  ///	yeni istek diyalogu YENIDEN acar. Kullanici izni AZ ONCE
  ///	vermis olsa bile ikinci, ucuncu kez soruluyordu.
  ///
  /// ⚠️⚠️ **IKINCI KOK NEDEN AYRI DOSYADAYDI**: `onboarding_ekrani.dart`
  ///	bu kapiyi ATLAYIP dogrudan `request()` cagiriyordu — hemen
  ///	ustundeki serh *"YAPMA: `request()`i cagri yerlerine geri
  ///	dagitma"* dediği halde. Senaryo: onboardingde "Bir Kez" ->
  ///	harita acilir -> `_yukle` -> `konumAl` -> IKINCI diyalog.
  ///
  /// ⚠️ Verilmis izinde `request()` CAGRILMAZ: iOSta gereksiz, Androidde
  ///    de zararsiz ama anlamsiz.
  /// ⚠️ KALICI RED (`permanentlyDenied`) ve `restricted` durumunda da
  ///    istenmez: sistem zaten diyalog GOSTERMEZ, cagri sessizce false
  ///    doner ve kullanici sebebini ogrenemezdi. Cagiran taraf ona gore
  ///    "Ayarlardan ac" diyor (bkz. `konumAl`).
  /// ⚠️ `limited` (iOS 14+ kismi yetki) GECERLI sayilir — konum icin
  ///    pratikte `whileInUse` ile ayni.
  /// ⚠️⚠️⚠️ TURU 159c - **BU OTURUMDA ZATEN SORDUK MU** (denetim).
  ///
  ///	iOSta "Bir Kez Izin Ver" yetkisi uygulama ARKA PLANA gidip
  ///	donunce dusуer ve durum yeniden `notDetermined` olur. Yalnizca
  ///	`status` bakmak YETMEZ: o an "sorulmamis" gorunur ve kod
  ///	diyalogu YENIDEN acar. Kullanicinin sikayeti tam budur.
  ///
  /// ⚠️⚠️ **SONUC DEGIL, "SORDUK MU" SAKLANIR.** Sonucu onbelleklemek,
  ///	kullanici Ayarlardan izni SONRADAN verirse yanlis (bayat)
  ///	cevap dondururdu. Bayrak yalnizca *diyalogu bir kez actik*
  ///	bilgisini tutar; GERCEK yetki her cagrida `status` ile
  ///	TAZE okunur.
  /// ⚠️⚠️ **AKIS TEKRAR DONGUSU BU KAPI OLMADAN DIYALOG SPAMI URETIR**:
  ///	turu 159b `_akisiBagla` hata dalini takip kapaliyken de
  ///	yeniden baglanacak sekilde acti; izin dusmusse her 2 saniyede
  ///	bir yeni diyalog acilirdi (denetim bunu SEVK ENGELI olarak
  ///	isaretledi).
  /// ⚠️ `izinSifirla()` yalnizca kullanici ACIKCA yeniden denedigi
  ///    yerlerden cagrilir ("Tekrar dene" dugmesi).
  static bool _sorduk = false;

  /// ⚠️ Kullanici ACIKCA yeniden deneyince bayragi birak.
  static void izinSifirla() => _sorduk = false;

  static Future<bool> konumIzni() =>
      _izinIsi ??= () async {
        try {
          final durum = await Permission.locationWhenInUse.status;
          if (durum.isGranted || durum.isLimited) return true;
          if (durum.isPermanentlyDenied || durum.isRestricted) return false;
          // ⚠️⚠️ Bu oturumda ZATEN sorduysak TEKRAR SORMA.
          if (_sorduk) return false;
          _sorduk = true;
          return (await Permission.locationWhenInUse.request()).isGranted;
        } finally {
          _izinIsi = null;
        }
      }();

  /// ⚠️⚠️ TURU 158b - **SEBEP DISARI ACILDI** (yayin oncesi denetim).
  ///
  ///	Turu 158 `_yukle`yi `sessiz: true` yapti (mukerrer SnackBar
  ///	rota ekraninin USTUNDE cikiyordu). Ama panel seridi UC AYRI
  ///	sebebin UCUNU DE *"konum izni gerekiyor"* diye yaziyordu:
  ///	izin VERMIS ama cihazin konum servisi KAPALI olan kullanici
  ///	uygulama ayarlarina gidip iznin ZATEN acik oldugunu goruyor,
  ///	gercek sebebe goturen HICBIR ipucu bulamiyordu ("Tekrar dene"
  ///	de ayni sessiz yolu tekrarladigi icin ekran KALICI olarak
  ///	yanlis sebebi gosteriyordu).
  ///	Ayrica turu 157de gosterilen EYLEME DONUK ipucu ("acik alanda
  ///	tekrar dene") turu 158de KAYBOLMUSTU.
  /// ⚠️ `konumAl` DEGISMEDI: bu, sebebi de isteyen cagri yerleri icin.
  static Future<({({double enlem, double boylam})? konum, String hata})>
      konumAlAyrintili({bool sessiz = false}) async {
    final k = await konumAl(sessiz: sessiz, sebep: _sebep);
    return (konum: k, hata: k == null ? (_sebep.value) : '');
  }

  /// ⚠️ `konumAlAyrintili`nin sebebi topladigi kutu (tek cagri boyunca).
  static final _sebep = ValueNotifier<String>('');

  static Future<({double enlem, double boylam})?> konumAl({
    bool sessiz = false,
    ValueNotifier<String>? sebep,
  }) async {
    sebep?.value = '';
    // ⚠️ IZIN `permission_handler` ile isteniyor (geolocator'in kendi API'si
    //    DEGIL): kod tabaninin geri kalani o paketi kullaniyor ve iki izin
    //    katmani tutmak kacinilmaz olarak DRIFT ederdi.
    // ⚠️ TURU 157 - TEK KAPI (bkz. `konumIzni` serhi).
    if (!await konumIzni()) {
      final m = await Permission.locationWhenInUse.isPermanentlyDenied
          ? 'Konum izni kapalı. Ayarlardan açabilirsin.'
          : 'Konum paylaşmak için konum izni gerekli';
      sebep?.value = m;
      if (!sessiz) _uyar(m);
      return null;
    }

    // ⚠️ SERVIS ACIK MI: izin verilmis olsa bile cihazin konum servisi
    //    kapaliysa `getCurrentPosition` ZAMAN ASIMINA UGRAR ve kullanici
    //    donmus bir ekran gorur. Once soruyoruz.
    if (!await Geolocator.isLocationServiceEnabled()) {
      const m = 'Cihazın konum servisi kapalı. Ayarlardan aç.';
      sebep?.value = m;
      if (!sessiz) _uyar(m);
      return null;
    }

    // ⚠️⚠️⚠️ TURU 158 - **FIX ISTEGI DE TEKILLESTIRILIR.**
    //
    //	Kullanici: *"surekli alttan hata aliyorum, yeniden dene
    //	yeniden dene gibi"*.
    //
    // ⚠️⚠️ **KOK NEDEN: ACILISTA IKI ES ZAMANLI `getCurrentPosition`.**
    //	`initState` hem `_yukle()` hem (menuden Durak ile
    //	gelindiginde) `_durakAc()` cagiriyor; ikisi de 12 saniyelik
    //	birer fix istegi aciyor. iOS tarafinda geolocator TEK SLOTLU
    //	bir sonuc isleyicisi tutuyor: ikinci istek birincinin
    //	blogunu EZIYOR, birincinin future'i HIC tamamlanmiyor ve
    //	12 sn sonra **"Konum alınamadı — açık alanda tekrar dene"**
    //	ekranin ALTINDA cikiyor.
    // ⚠️⚠️ `konumIzni` ZATEN bu deseni kullaniyordu (`_izinIsi`);
    //	fix istegi kullanmiyordu - **asimetrinin kendisi hataydi.**
    //
    // ⚠️⚠️ **`sessiz` PAYLASILAN GOVDEYE GIRMEZ**: govde HIC `_uyar`
    //	cagirmaz, yalnizca SEBEBI dondurur; uyariyi CAGRI YERI kendi
    //	bayragina gore gosterir. Aksi halde ilk cagiran `sessiz: true`
    //	ise gurultulu cagiran HICBIR SEY gormezdi.
    // ⚠️ Izin ve servis kapilari paylasimin DISINDA kalir (ucuz ve
    //    cagri yerine ozel).
    final sonuc = await fix();
    if (sonuc.konum == null) {
      sebep?.value = sonuc.hata;
      if (!sessiz) _uyar(sonuc.hata);
    }
    return sonuc.konum;
  }

  /// ⚠️⚠️⚠️ TURU 158b - **TEK-UCUS KAPISI: PROJEDEKI TEK GIRIS.**
  ///
  ///	Yayin oncesi denetim: turu 158in tek-ucus korumasi YALNIZ
  ///	`konumAl` icindeydi; `isletme_listesi` (IKI yerde) ve
  ///	`konum_secici` `Geolocator.getCurrentPosition`i DOGRUDAN
  ///	cagiriyordu. Yakinimda ekranina giris o kategori ekranindan
  ///	yapiliyor: kullanici acilistaki 8 saniyelik olcum surerken
  ///	haritaya dokununca IKINCI bir 12 saniyelik istek aciliyor ve
  ///	iOSun TEK SLOTLU isleyicisi yuzunden **sikayet #1 AYNEN
  ///	TEKRARLANIYORDU** — yani duzeltme sahada kapanmamisti.
  /// ⚠️⚠️ YAPMA: `Geolocator.getCurrentPosition`i baska yerden
  ///	cagirma. Yeni bir cagri yeri gerekirse BU kapidan gec.
  /// ⚠️ Ucustaki istek PAYLASILIR: farkli zaman asimlariyla
  ///    gelen cagrilar birinciyi bekler (iOSta zaten tek slot var).
  static Future<({({double enlem, double boylam})? konum, String hata})>
      fix() {
    final istek = _fixIsi ??= () async {
      try {
        // ⚠️ `medium` dogruluk YETERLI ve HIZLI; `best` GPS kilidi
        //    bekler ve kapali alanda 10+ saniye surebilir.
        // ⚠️ ZAMAN ASIMI ZORUNLU: kilit alinamazsa istek SONSUZA
        //    KADAR asili kalir.
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 12),
          ),
        );
        return (
          konum: (enlem: p.latitude, boylam: p.longitude),
          hata: '',
        );
      } on TimeoutException {
        return (
          konum: null,
          hata: 'Konum alınamadı — açık alanda tekrar dene',
        );
      } catch (_) {
        return (konum: null, hata: 'Konum alınamadı');
      } finally {
        _fixIsi = null;
      }
    }();
    return istek;
  }

  /// Ucusta olan TEK fix istegi (bkz. `konumAl` serhi).
  static Future<
      ({({double enlem, double boylam})? konum, String hata})>? _fixIsi;

  /// ⚠️⚠️⚠️ TURU 151 — **SUREKLI KONUM AKISI** (rota takibi icin).
  ///
  /// Kullanici sorusu: *"telefonla yurudugumde ARKAMDAN SHAPE GIDECEK MI?"*
  /// Cevap evet; kaynak bu akis.
  ///
  /// ⚠️⚠️ **`foregroundNotificationConfig` VERILMIYOR — BILINCLI.**
  ///	Android 14+ o yapilandirmayla bir ONDEPLAN SERVISI baslatir ve
  ///	manifest'te **`FOREGROUND_SERVICE_LOCATION` izni YOK** (kontrol
  ///	edildi: yalnizca MICROPHONE / CAMERA / PHONE_CALL var). Izinsiz
  ///	baslatmak `SecurityException` ile UYGULAMAYI COKERTIR.
  ///	**DURUST SINIR:** takip bu yuzden UYGULAMA ACIKKEN calisir;
  ///	telefon cebe girip ekran kapaninca Android akisi kisar.
  ///	Arka plan takibi ayri bir izin + servis turu ister.
  ///	⚠️ YAPMA: izni eklemeden `foregroundNotificationConfig` verme.
  ///
  /// ⚠️ `distanceFilter: 5` — yaya hizinda (~1,3 m/sn) ~4 saniyede bir olay.
  ///    Daha kucuk deger GPS gurultusunu olaya cevirir ve pili yer;
  ///    daha buyugu cizginin ilerlemesini goze carpacak kadar geciktirir.
  /// ⚠️ `accuracy: high` — `best` GPS kilidi icin bekler ve sehir icinde
  ///    ilk olayi 10+ saniye geciktirebilir.
  /// ⚠️⚠️⚠️ **IZIN BURADA ISTENIR** (turu 153 duzeltmesi).
  ///	iOS tarafinda AKIS YOLUNDA HICBIR IZIN KAPISI YOK
  ///	(`PositionStreamHandler.m` `onListenWithArguments` icinde
  ///	kontrol yok; `hasPermission` kapilari yalnizca
  ///	`getCurrentPosition` gibi metot cagrilari icin).
  ///	Izinsiz `startUpdatingLocation` cagrilinca iOS
  ///	`kCLErrorDenied` doner, eklenti bunu
  ///	`PositionUpdateException`a cevirir ve kullanici
  ///	**"Konum akışı kesildi"** gorur (sahada yasandi).
  /// ⚠️ Cagiranin izni almis OLDUGUNU VARSAYMA — bu projenin klasik
  ///    "serhin anlattigi kontrol govdede yok" sinifi.
  ///
  /// ⚠️ **PLATFORMA OZEL AYAR ZORUNLU**: duz `LocationSettings` yalnizca
  ///    `accuracy` + `distanceFilter` gonderir; digerleri platform
  ///    varsayilanina duser ve iOS'ta davranis belirsizlesir.
  /// ⚠️⚠️ TURU 155 — akis artik **DOGRULUK** ve **GPS GIDIS YONU** de
  ///	tasiyor (kullanici: konum isaretinin *"cevresinde hafif beyaz
  ///	daire"* ve *"yon oku"*).
  ///
  /// ⚠️⚠️ `yon` **PUSULA DEGIL**: `Position.heading` GPS'in GIDIS
  ///	yonudur (course over ground) ve cihaz DURUYORKEN GECERSIZDIR
  ///	(Android 0.0, iOS negatif). Bu yuzden burada **`null` olarak**
  ///	dondurulur ve asil kaynak `PusulaServisi`dir; bu yalnizca
  ///	pusula yoksa devreye giren YEDEKTIR.
  /// ⚠️ `heading` icin gecerlilik olcutu: negatif ya da tam 0.0 ise
  ///    GUVENILMEZ sayilir. 0.0 gercekten kuzey olabilir ama Android
  ///    `hasBearing()` false iken de 0.0 dondurdugu icin ikisi AYIRT
  ///    EDILEMEZ — yanlis yon gostermektense hic gostermemek dogrudur.
  static Stream<
      ({
        double enlem,
        double boylam,
        double dogrulukM,
        double? yon,
      })> konumAkisi() async* {
    // ⚠️⚠️ TURU 157 - TEK KAPI. Onceden burasi DOGRUDAN
    //	`request()` cagiriyordu ve ekran acilisindaki `konumAl`
    //	ile yarisip **false** aliyordu; takip daha baslamadan
    //	"izin gerekiyor" deyip kapaniyordu (bkz. `konumIzni`).
    if (!await konumIzni()) {
      throw const KonumIzniYok();
    }
    yield* Geolocator.getPositionStream(locationSettings: _akisAyari())
        .map((p) => (
              enlem: p.latitude,
              boylam: p.longitude,
              dogrulukM: p.accuracy,
              yon: (p.heading > 0 && p.heading <= 360) ? p.heading : null,
            ));
  }

  static LocationSettings _akisAyari() {
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        activityType: ActivityType.fitness,
        // ⚠️ `true` olsaydi iOS akisi kendiliginden DURDURUR ve
        //    kullanici "cizgi ilerlemiyor" derdi.
        pauseLocationUpdatesAutomatically: false,
        // ⚠️⚠️ **`false` KALMALI**: `UIBackgroundModes` icinde
        //    `location` YOK; `true` verilirse iOS istisna atar.
        allowBackgroundLocationUpdates: false,
      );
    }
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
      intervalDuration: const Duration(seconds: 2),
      // ⚠️⚠️ `foregroundNotificationConfig` VERILMEZ — manifest'te
      //    `FOREGROUND_SERVICE_LOCATION` YOK ve Android 14+ cokerdi.
    );
  }

  /// "41.0082,28.9784" -> (41.0082, 28.9784). Bozuksa `null`.
  static ({double enlem, double boylam})? ayrist(String icerik) {
    final p = icerik.trim().split(',');
    if (p.length != 2) return null;
    final a = double.tryParse(p[0].trim());
    final b = double.tryParse(p[1].trim());
    if (a == null || b == null) return null;
    // ⚠️ SINIR KONTROLU: bozuk/kotu niyetli bir icerik harita uygulamasina
    //    anlamsiz koordinat gondermesin.
    if (a < -90 || a > 90 || b < -180 || b > 180) return null;
    return (enlem: a, boylam: b);
  }

  /// Cihazin KENDI harita uygulamasinda acar.
  ///
  /// ⚠️ TURU 85b — SERH GUNCELLENDI: `google_maps_flutter` ARTIK KURULU
  ///    ("Yakınımda" ekrani kullaniyor). Buradaki yol yine de DOGRU:
  ///    YOL TARIFI icin cihazin KENDI harita uygulamasi acilir — gomulu
  ///    haritada navigasyon yoktur ve kullanici zaten alisik oldugu
  ///    uygulamada rota almak ister.
  /// ⚠️ CLAUDE.md `cloudMapId` yasagi DURUYOR (ucretli).
  /// ⚠️ `geo:` semasi Android'de dogru calisir; iOS onu TANIMAZ, bu yuzden
  ///    once evrensel `https://maps.google.com/?q=` denenir — o da iOS'ta
  ///    Apple Haritalar/Google Haritalar secimini sisteme birakir.
  static Future<void> haritadaAc(double enlem, double boylam) async {
    final u = Uri.parse('https://maps.google.com/?q=$enlem,$boylam');
    try {
      final acildi = await launchUrl(u, mode: LaunchMode.externalApplication);
      if (!acildi) _uyar('Harita uygulaması açılamadı');
    } catch (_) {
      _uyar('Harita uygulaması açılamadı');
    }
  }

  /// ⚠️ `rootMessengerKey`: bu servis Navigator agacinin DISINDAN da
  ///    cagrilabilir (turu 74 dersi).
  static void _uyar(String m) {
    rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(m)));
  }
}
