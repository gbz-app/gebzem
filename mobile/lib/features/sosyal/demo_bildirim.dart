/// ⚠️⚠️⚠️ TURU 115 — BILDIRIM DEMOSU (kullanici emri: *"bir de bildirimler
///	bos, orayi doldur ki gorelim bakalim nasil duruyor"*).
///
/// Bildirimler ekrani gercek veriyle besleniyor ama test veritabaninda hicbir
/// begeni/yorum/takip olmadigi icin **DAIMA BOS** goruluyordu; tasarimi
/// degerlendirmek imkansizdi.
///
/// ═══════════ KURALLAR ═══════════
///
/// ⚠️ Yalnizca `kDemoAkis` acikken uretilir (`demo_veri.dart` TEK BAYRAK).
/// ⚠️ Kimlikler **`demo-` onekli**: `demoKimlik()` kapisi bildirime dokunmayi
///    da eler, yani sahte bir bildirimden gercek bir profile/gonderiye
///    GIDILMEZ ve sunucuya istek ATILMAZ.
/// ⚠️ Alan adlari sunucunun `GET /notifications` yanitiyla **BIREBIR**
///    (`tur`, `aktor_ad`, `aktor_avatar_media_id`, `hedef_tur`, `hedef_id`,
///    `created_at`, `okundu`). Ayri bir model YAZILMADI — ekran ayni
///    `Map<String, dynamic>` govdesini cizer, yani demo ile gercegin
///    gorunumu AYRISAMAZ.
/// ⚠️ Turler ekranin TANIDIGI kumeden secildi (`_metin` switch'i): bilinmeyen
///    bir tur Sentry'ye "bilinmeyen bildirim turu" alarmi dusururdu.
library;

import 'demo_veri.dart' show kDemoAkis;

/// `created_at` sunucu bicimi (ISO-8601). Ekran `gonderiZamani` ile
/// "5 dk" gibi bicimlendiriyor; sabit bir tarih yazmak "3 ay once" gosterirdi.
String _once(Duration d) =>
    DateTime.now().toUtc().subtract(d).toIso8601String();

Map<String, dynamic> _b({
  required String tur,
  required String ad,
  required Duration once,
  String hedefTur = 'gonderi',
  String hedefId = 'demo-foto',
  bool okundu = false,
}) => {
  'id': 'demo-bildirim-$tur-${once.inMinutes}',
  'tur': tur,
  'aktor_id': 'demo-$ad',
  'aktor_ad': ad,
  'aktor_avatar_media_id': null,
  'aktor_avatar': '',
  'hedef_tur': hedefTur,
  'hedef_id': hedefId,
  'created_at': _once(once),
  'okundu': okundu,
};

/// ⚠️ SIRA: sunucu da `created_at DESC` donduruyor; demo listesi de YENIDEN
///    ESKIYE gider. Karisik bir sira "bildirimler sirasiz" izlenimi verirdi.
/// ⚠️ Ilk ucu OKUNMAMIS (vurgulu zemin), kalanlar okunmus — ekranin IKI
///    durumu da tek bakista gorunsun.
List<Map<String, dynamic>> demoBildirimler() {
  if (!kDemoAkis) return const [];
  return [
    _b(tur: 'begeni', ad: 'Mehmet Kaya', once: const Duration(minutes: 4)),
    _b(
      tur: 'yorum',
      ad: 'Sinem Ateş',
      once: const Duration(minutes: 18),
      hedefId: 'demo-konum',
    ),
    _b(tur: 'takip', ad: 'Elif Yılmaz', once: const Duration(hours: 1),
        hedefTur: 'kullanici', hedefId: 'demo-elif'),
    _b(
      tur: 'takip_istegi',
      ad: 'Burak Şahin',
      once: const Duration(hours: 3),
      hedefTur: 'kullanici',
      hedefId: 'demo-burak',
      okundu: true,
    ),
    _b(
      tur: 'begeni',
      ad: 'Ayşe Demir',
      once: const Duration(hours: 6),
      hedefId: 'demo-galeri',
      okundu: true,
    ),
    _b(
      tur: 'yorum',
      ad: 'Ali Yıldız',
      once: const Duration(hours: 9),
      hedefId: 'demo-video',
      okundu: true,
    ),
    _b(
      tur: 'takip_onaylandi',
      ad: 'Zeynep Ak',
      once: const Duration(days: 1),
      hedefTur: 'kullanici',
      hedefId: 'demo-zeynep',
      okundu: true,
    ),
  ];
}
