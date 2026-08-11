/// ⚠️⚠️ TURU 91 — TEKLIF ISTEGI (TALEP) SERVISI.
///
/// Kullanici emri: *"dugun mu yapmak istiyorsun hizmet mi almak istiyorsun,
/// burada STEP STEP... sonra bu bilgiler ornegin kuafore teklif gidecek,
/// digerlerine gidecek, onlar da KARSI TEKLIF verecekler"*.
///
/// ═══════════ YENI SERVIS YAZILMADI ═══════════
///
/// Talep bir `ilanlar` satiridir (`tur='talep'`) ve teklif bir
/// `ilan_basvurular` satiridir. Yani `IlanServisi` ZATEN her seyi yapiyor:
/// `olustur` · `liste` · `detay` · `basvur` (teklif ver) · `basvurular`
/// (gelen teklifler) · `basvuruDurum` (sec/ele) · `basvurularim`
/// (tekliflerim). Bu dosya yalnizca **ADIM ADIM FORM** icin gereken
/// gruplamayi yapar.
///
/// ⚠️ YAPMA: `TalepServisi` diye ikinci bir HTTP katmani yazma — ayni
///    uclarin ikinci kopyasi olur ve KACINILMAZ olarak drift eder.
library;

import '../ilan/ilan_servisi.dart';

/// Bir adimdaki alanlar.
typedef TalepAdimi = ({int no, List<IlanAlani> alanlar});

/// ⚠️⚠️ ADIM GRUPLAMASI **SUNUCUDAN GELEN `adim` ALANINA** gore yapilir.
///
/// Sirayi Dart'a yazmak, turu 77'nin *"Dart'a kategori/tur sabiti yazma"*
/// kuralinin ihlali olurdu: yeni bir alan eklemek yine ISTEMCI GUNCELLEMESI
/// gerektirirdi. Sunucu `Alan.Adim` gonderiyor, istemci yalnizca GRUPLUYOR.
///
/// ⚠️ `adim == 0` olan alanlar (mevcut TUM diger turler) TEK adimda toplanir
///    — yani bu fonksiyon talep DISI turlerde de guvenle kullanilabilir.
List<TalepAdimi> adimlaraBol(List<IlanAlani> alanlar) {
  final harita = <int, List<IlanAlani>>{};
  for (final a in alanlar) {
    harita.putIfAbsent(a.adim, () => []).add(a);
  }
  final anahtarlar = harita.keys.toList()..sort();
  return [
    for (final k in anahtarlar) (no: k, alanlar: harita[k]!),
  ];
}

/// Talep akisinin IKI DALI (kullanici emri: "dugun mu / hizmet mi").
///
/// ⚠️ Dal ayrimi ISTEMCIDE, cunku bu bir SUNUM tercihidir: sunucu tarafinda
///    hepsi ayni `tur='talep'`tir ve kategori listesi sunucudan gelir.
///    Sunucuya "dal" kavrami eklemek, tek bir ekran duzeni icin sema
///    genisletmek olurdu.
/// ⚠️ Bir kategori HICBIR dalda yoksa "Diğer" dalinda gorunur — sessizce
///    kaybolmasindansa yanlis dalda gorunmesi yeglenir (kullanici onu
///    bulabilir).
const dugunKategorileri = <String>{
  'dugun_organizasyon', 'dugun_mekan', 'dugun_fotograf', 'gelinlik',
  'sac_makyaj', 'dugun_muzik', 'dugun_pasta', 'davetiye', 'gelin_arabasi',
};

/// Teklif durumunun kullaniciya gosterilen adi.
///
/// ⚠️ TEK KAYNAK: uc ekran (gelen teklifler · tekliflerim · rozet) ayni
///    metni cizer.
String teklifDurumEtiketi(String durum) => switch (durum) {
  'bekliyor' => 'Bekliyor',
  'goruldu' => 'Görüldü',
  'secildi' => 'Seçildi',
  'elendi' => 'Elendi',
  'geri_cekildi' => 'Geri çekildi',
  _ => durum,
};
