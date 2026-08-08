import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

/// ⚠️⚠️⚠️ TURU 74 — SES NOTU YIKIM KAPISI. **BU DOSYAYI OKUMADAN DEĞİŞTİRME.**
///
/// SORUN: ses notu kaydı ve oynatması, aramanın/odanın/yayının ses birimiyle AYNI
/// donanımı kullanır. iOS'ta ses oturumu **PROSES GENELİNDE TEK**; Android'de
/// AudioFocus tek sahiplidir. Kayıt sürerken arama gelirse ARAMA KAZANMALIDIR.
///
/// ⚠️⚠️ **SES NOTU `SesSahipligi` DEFTERİNE YAZILMAZ.** Bu, kolayca yapılacak ama
/// YIKICI olacak bir hatadır. O defter `_odaTemizle` / `room_screen._kapatOda` /
/// `live_*._kapatOda` içinde **`setAudioEnabled(false)` kararını** verir. Ses notu
/// oraya yazılırsa `aramaCanli` **YALAN SÖYLER**: arama biterken ses birimi
/// kapatılmaz, iPhone'da üstteki turuncu mikrofon göstergesi SÖNMEZ ve sonraki
/// aramanın kurulumu bozulur.
/// ⚠️ YAPMA: buradan `SesSahipligi.kaydol(...)` çağırma.
///
/// BUNUN YERİNE: arama/oda/yayın BAŞLARKEN bu kapı çağrılır ve ses notu SUSAR.
/// Kayıt SİLİNMEZ — taslak olarak kalır, kullanıcı görüşme bitince gönderir.
class SesNotuKontrol {
  SesNotuKontrol._();

  /// Şu an kayıt/oynatma yapan bileşenin susturma geri çağrısı + SAHİBİ.
  ///
  /// ⚠️⚠️ TURU 74b (DENETİM BULGUSU) — SAHİPLİK JETONU ZORUNLU.
  ///     İlk sürümde düz atama vardı: ses notu ÇALARKEN kullanıcı mikrofona
  ///     basarsa kayıt, oynatmanın kaydını EZİYORDU. Sonuç: arama geldiğinde
  ///     yalnız kayıt duruyor, **oynatma görüşme boyunca sürüyordu.**
  ///     Simetrik olarak `birak()`/`kapat()` de BAŞKASININ kaydını siliyordu.
  /// ⚠️ YAPMA: sahipsiz `kaydol`/`birak` çağırma.
  static Future<void> Function()? _susturucu;
  static Object? _sahip;

  /// Kayıt/oynatma başlarken kaydol. [sustur] İDEMPOTENT olmalı.
  /// ⚠️ Devralma: önceki sahip varsa ÖNCE o susturulur (iki ses aynı anda çalmasın).
  static void kaydol(Object sahip, Future<void> Function() sustur) {
    final onceki = _susturucu;
    if (onceki != null && _sahip != sahip) {
      unawaited(onceki().timeout(const Duration(milliseconds: 400)).catchError((_) {}));
    }
    _sahip = sahip;
    _susturucu = sustur;
  }

  /// ⚠️ YALNIZ kendi kaydını düşür — başkasınınkini silme.
  static void birak(Object sahip) {
    if (_sahip == sahip) {
      _susturucu = null;
      _sahip = null;
    }
  }

  static bool get aktif => _susturucu != null;

  /// ⚠️⚠️ ARAMA KAZANIR. Arama/oda/yayın kurulmadan ÖNCE çağrılır.
  ///
  /// ⚠️ **400 ms TAVAN ZORUNLU.** Turu 67'de zaman aşımsız `await CallSounds.durdur`
  ///     ekranı asılı bıraktı ve arama son karede donuk kaldı. Ses notunun yıkımı
  ///     HİÇBİR KOŞULDA aramayı bloklamaz: süre aşılırsa devam edilir ve
  ///     **GERÇEK Sentry olayı** yazılır (breadcrumb değil — bu projede breadcrumb
  ///     ancak başka bir olayla yüklendiği için 4 tur boyunca kör kalmıştık).
  /// ⚠️ YAPMA: timeout'u kaldırma; `unawaited` yapma (kayıt sürerken arama
  ///     bağlanırsa mikrofonu iki taraf da ister).
  static Future<void> sustur() async {
    final s = _susturucu;
    if (s == null) return;
    try {
      await s().timeout(const Duration(milliseconds: 400));
    } on TimeoutException {
      unawaited(Sentry.captureMessage(
          'ses notu yikimi 400ms icinde bitmedi — arama devam ediyor'));
    } catch (e) {
      unawaited(Sentry.captureMessage('ses notu yikim hatasi: $e'));
    } finally {
      _susturucu = null;
      _sahip = null;
    }
  }

  /// Senkron acil kapatma (dispose yollarında). ⚠️ YALNIZ kendi kaydını düşürür.
  static void kapat(Object sahip) {
    if (_sahip == sahip) {
      _susturucu = null;
      _sahip = null;
    }
  }
}
