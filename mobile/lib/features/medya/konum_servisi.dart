import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' show Geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../router.dart' show rootMessengerKey;

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
  static Future<({double enlem, double boylam})?> konumAl({
    bool sessiz = false,
  }) async {
    // ⚠️ IZIN `permission_handler` ile isteniyor (geolocator'in kendi API'si
    //    DEGIL): kod tabaninin geri kalani o paketi kullaniyor ve iki izin
    //    katmani tutmak kacinilmaz olarak DRIFT ederdi.
    final izin = await Permission.locationWhenInUse.request();
    if (!izin.isGranted) {
      if (!sessiz) _uyar(
        izin.isPermanentlyDenied
            ? 'Konum izni kapalı. Ayarlardan açabilirsin.'
            : 'Konum paylaşmak için konum izni gerekli',
      );
      return null;
    }

    // ⚠️ SERVIS ACIK MI: izin verilmis olsa bile cihazin konum servisi
    //    kapaliysa `getCurrentPosition` ZAMAN ASIMINA UGRAR ve kullanici
    //    donmus bir ekran gorur. Once soruyoruz.
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!sessiz) _uyar('Cihazın konum servisi kapalı');
      return null;
    }

    try {
      // ⚠️ `medium` dogruluk YETERLI ve HIZLI: sohbette konum paylasmak icin
      //    metre hassasiyeti gerekmiyor; `best` GPS kilidi bekler ve kapali
      //    alanda 10+ saniye surebilir.
      // ⚠️ ZAMAN ASIMI ZORUNLU: kilit alinamazsa istek SONSUZA KADAR asili
      //    kalir ve kullanici "gonderilmiyor" der.
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return (enlem: p.latitude, boylam: p.longitude);
    } on TimeoutException {
      if (!sessiz) _uyar('Konum alınamadı — açık alanda tekrar dene');
      return null;
    } catch (e) {
      if (!sessiz) _uyar('Konum alınamadı');
      return null;
    }
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
