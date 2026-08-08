import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calls/call_provider.dart';
import '../calls/medya_beklet.dart' show SesSahipligi;
import '../calls/pip_service.dart';
import '../../router.dart' show rootMessengerKey;

/// ⚠️⚠️⚠️ TURU 74 — MEDYA ÇAKIŞMA KAPISI. **BU DOSYAYI OKUMADAN MEDYA KODU YAZMA.**
///
/// Bu uygulamada aynı anda 1:1 arama, sesli oda ya da canlı yayın olabilir. iOS'ta:
///   · Ses birimi `RTCAudioSession.isAudioEnabled` **PROSES GENELİNDE TEK** bayraktır,
///   · flutter_webrtc **TEK PAYLAŞILAN `videoCapturer`** tutar.
/// Bu yüzden sohbette kamera açmak ya da ses kaydetmek, SÜREN bir aramayı/yayını
/// öldürebilir. Proje bunu 70+ turda defalarca yaşadı:
///   · turu 50 — iki capture oturumu birbirini öldürdü, aramaların **%14'ünde**
///     tek taraflı video (9/9 iOS).
///   · turu 64/65 — ses oturumunu geri alma denemesi `!pri`
///     (`AVAudioSessionErrorCodeInsufficientPriority`) ile REDDEDİLDİ.
///   · turu 62-C — Android'de ses rotası bozulup hoparlöre atladı.
///
/// KARAR TABLOSU (araştırma + denetim sonucu):
/// | İşlem                     | Arama/oda/yayın sürerken |
/// |---------------------------|--------------------------|
/// | Galeriden seçme           | SERBEST (kamera/mikrofona dokunmaz) |
/// | **Kamerayla çekim**       | **ENGELLİ** |
/// | **Ses notu kaydı**        | **ENGELLİ** |
/// | **Ses notu oynatma**      | **ENGELLİ** |
/// | Fotoğraf görüntüleme      | SERBEST |
/// | Sıkıştırma / yükleme      | SERBEST (saf CPU / ağ) |
///
/// ⚠️ İKİ KAYNAK BİRDEN SORULUR, biri yetmez:
///   · `SesSahipligi` — gerçekten bağlı bir arama/oda/yayın var mı (turu 73 defteri).
///     ⚠️ Tek başına ÇALMA fazını kaçırır (arama henüz bağlanmadı ama zil çalıyor).
///   · `mesgulMu` — ekranda bir arama/oda/yayın muhafızı var mı (çalma fazı dahil).
///     ⚠️ Tek başına bayat muhafız yüzünden yanlış pozitif verebilir.
///   · `PipService.gsmAramada` — hücresel görüşme sürüyor mu.
/// ⚠️ YAPMA: bu üçünden birini çıkarma.
/// ⚠️ YAPMA: bu mantığı çağıran yerlere kopyalama — TEK KAYNAK burasıdır.
class MedyaKapisi {
  MedyaKapisi._();

  /// ⚠️⚠️ TURU 74b (DENETİM BULGUSU) — SİSTEM PICKER'I AÇIK MI?
  ///
  /// Galeri/kamera picker'ı AYRI SÜREÇTE çalışır ve donanımı bizden ÇALMAZ —
  /// ama **uygulamayı arka plana atar** ve BİZİM kendi yaşam döngüsü kodumuz
  /// bunu "kullanıcı uygulamadan çıktı" sanıp:
  ///   · `active_call_controller` görüntülü aramanın KAMERASINI KAPATIR
  ///     (PiP kuruluysa 900 ms sonra, değilse ANINDA),
  ///   · dönüşte `_kesintidenTopla` → `_sesiAc(true)` ile ses birimini
  ///     ZORLA TOGGLE eder (~50-150 ms sağırlık),
  ///   · oda/yayın ekranları da `resumed` dalında `_sesiAc(true)` çağırır.
  /// Sonuç: görüntülü arama sürerken galeriden fotoğraf seçen kullanıcının
  /// karşı tarafı **donmuş/kapalı kamera** görürdü.
  ///
  /// Bu bayrak "arka plana geçiş GERÇEK Mİ" ayrımını sağlar; picker yüzünden
  /// olan geçişlerde kamera/ses yıkımı ATLANIR.
  /// ⚠️ `try/finally` ile SET/RESET edilmeli — picker iptal edilse bile bayrak
  ///     asılı kalmamalı (asılı kalırsa gerçek arka plan geçişinde kamera
  ///     kapanmaz ve iOS kesintisi yaşanır).
  static bool pickerAcik = false;

  /// ⚠️⚠️ İKİ AYRI METOT VAR — KARIŞTIRMA:
  ///
  ///   · [donanimSerbest] — **YAN ETKİSİZ**. `build()` içinden, her karede
  ///     çağrılabilir (kamera satırını gizlemek için).
  ///   · [izinVer] — **YAN ETKİLİ**. Yalnızca kullanıcı DOKUNDUĞUNDA çağrılır.
  ///
  /// Neden ayrı: `mesgulMu` bayat muhafızları TEMİZLER ve Sentry'e ölçüm yazar
  /// (turu 56 self-heal). `build()` içinden çağrılırsa her karede çalışır ve
  /// Sentry'i doldurur. Bu yüzden yan etkili kontrol yalnızca aksiyon yolundadır.
  /// ⚠️ YAPMA: `izinVer`i `build()` içinde çağırma.
  /// ⚠️ YAPMA: `donanimSerbest`e `mesgulMu` ekleme.
  static bool donanimSerbest(WidgetRef ref) {
    if (PipService.gsmAramada.value) return false;
    if (SesSahipligi.aramaCanli) return false;
    // Oda/yayın da donanımı tutar (SesSahipligi'nde `oda_`/`yayin_` önekiyle kayıtlı).
    if (SesSahipligi.odaVeyaYayinCanli) return false;
    // ⚠️ Çalma fazı: arama henüz bağlanmadı (SesSahipligi'ne girmedi) ama zil çalıyor.
    //    Ham `aramadaMi` yan etkisizdir — self-heal YAPMAZ.
    if (ref.read(callServiceProvider.notifier).aramadaMi) return false;
    return true;
  }

  /// Neden engelli olduğunu kullanıcıya anlatan metin (null = engel yok).
  static String? engelSebebi(WidgetRef ref) {
    if (donanimSerbest(ref)) return null;
    if (PipService.gsmAramada.value) {
      return 'Telefon görüşmeniz sürerken kullanılamaz.';
    }
    if (SesSahipligi.odaVeyaYayinCanli) {
      return 'Sohbet odası veya canlı yayın sürerken kullanılamaz.';
    }
    return 'Görüşme sürerken kullanılamaz.';
  }

  /// Engelliyse kullanıcıya söyler ve `false` döner. **YAN ETKİLİ** — yalnızca
  /// kullanıcı dokunduğunda çağrılır (bkz. [donanimSerbest] şerhi).
  /// ⚠️ `rootMessengerKey`: bu çağrı bir bottom sheet içinden gelebilir ve
  ///     `ScaffoldMessenger.of(context)` sheet kapanınca ölü bağlamda kalır.
  static bool izinVer(WidgetRef ref) {
    // ⚠️ Aksiyon yolunda `mesgulMu` DA sorulur: bayat muhafızları temizler
    //     (turu 56 self-heal) ve gerçek durumu söyler. Yan etkisi burada KABUL
    //     EDİLEBİLİR çünkü kare başına değil, dokunuş başına çalışır.
    if (ref.read(callServiceProvider.notifier).mesgulMu(etiket: 'medya')) {
      rootMessengerKey.currentState?.showSnackBar(const SnackBar(
        content: Text('Görüşme sürerken kullanılamaz.'),
        duration: Duration(seconds: 3),
      ));
      return false;
    }
    final sebep = engelSebebi(ref);
    if (sebep == null) return true;
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(sebep), duration: const Duration(seconds: 3)),
    );
    return false;
  }
}
