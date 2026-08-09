import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ⚠️⚠️ TURU 80 — REZERVASYON (restoran) + RANDEVU (doktor vb.).
///
/// Kullanici emri: *"restoran/yemek firmalarindan rezervasyon, doktor vs.den
/// randevu alinabilmeli"*.
///
/// ⚠️ IKISI TEK YAPIDIR — sunucuda da tek tablo. Fark yalnizca ETIKET (`tur`)
///    ve iki alan (`kisiSayisi` vs `hizmet`). Ayri model yazmak "ayni kuralin
///    iki kopyasi" demekti.
/// ⚠️ `tur` SUNUCUDAN gelir, istemci GONDERMEZ (isletme kategorisinden
///    turetilip olusturma aninda DONDURULUR).

/// Bir zaman dilimi.
class Slot {
  const Slot({required this.saat, required this.zaman, required this.musait});

  /// "14:30" — kullaniciya gosterilen YEREL saat (sunucu bicimliyor).
  final String saat;

  /// RFC3339 (UTC) — olusturma isteginde AYNEN geri gonderilir.
  /// ⚠️ Istemci kendi saat hesabini YAPMAZ; sunucunun verdigi degeri tasir.
  final String zaman;
  final bool musait;

  static Slot json(Map<String, dynamic> m) => Slot(
    saat: (m['saat'] ?? '').toString(),
    zaman: (m['zaman'] ?? '').toString(),
    musait: m['musait'] == true,
  );
}

/// Bir gunun slot listesi + isletmenin randevu ayarlari.
class UygunGun {
  const UygunGun({
    required this.acik,
    required this.tur,
    required this.slotlar,
    this.ileriGun = 14,
    this.mesaj = '',
  });

  final bool acik;

  /// 'rezervasyon' | 'randevu' — ARAYUZ METINLERI buna gore degisir.
  final String tur;
  final List<Slot> slotlar;

  /// ⚠️⚠️ TURU 80b — ISLETMENIN "kac gun ileriye" AYARI (denetim bulgusu).
  ///    Sunucu bu alani BASINDAN BERI donduruyordu ama model OKUMUYORDU ve
  ///    gun seridi 14'e SABITTI: 30 gun secen isletmenin ayari FIILEN
  ///    calismiyor, 3 gun secenin musterisi ise gormedigi bir duvara
  ///    carpiyordu ("Bu tarih için randevu açık değil").
  ///    Bu, projede ALTI kez tekrarlayan "sunucu donduruyor, istemci okumuyor"
  ///    sinifinin yenisiydi.
  final int ileriGun;
  final String mesaj;

  bool get rezervasyonMu => tur == 'rezervasyon';

  static UygunGun json(Map<String, dynamic> m) => UygunGun(
    acik: m['acik'] == true,
    tur: (m['tur'] ?? 'randevu').toString(),
    slotlar: ((m['slotlar'] as List?) ?? [])
        .map((e) => Slot.json((e as Map).cast<String, dynamic>()))
        .toList(),
    ileriGun: (m['ileri_gun'] as num?)?.toInt() ?? 14,
    mesaj: (m['mesaj'] ?? '').toString(),
  );
}

class Randevu {
  Randevu({
    required this.id,
    required this.isletmeId,
    required this.musteriId,
    required this.tur,
    required this.baslangic,
    required this.sureDakika,
    required this.kisiSayisi,
    required this.hizmet,
    required this.notMusteri,
    required this.notIsletme,
    required this.durum,
    required this.karsiAd,
    required this.karsiKullaniciAdi,
    required this.karsiAvatarMediaId,
  });

  final String id;
  final String isletmeId;
  final String musteriId;
  final String tur;
  final DateTime baslangic;
  final int sureDakika;
  final int kisiSayisi;
  final String hizmet;
  final String notMusteri;
  final String notIsletme;

  /// ⚠️ Alan DEGISEBILIR (durum gecisi) — bu yuzden `final` DEGIL.
  String durum;

  /// Karsi taraf (musteri listesinde ISLETME, gelen kutusunda MUSTERI).
  final String karsiAd;
  final String karsiKullaniciAdi;
  final String? karsiAvatarMediaId;

  bool get rezervasyonMu => tur == 'rezervasyon';

  /// ⚠️ Durum etiketleri TEK YERDE — ekranlar kendi metnini uydurmasin.
  String get durumMetni => switch (durum) {
    'bekliyor' => 'Onay bekliyor',
    'onaylandi' => 'Onaylandı',
    'reddedildi' => 'Reddedildi',
    'iptal' => 'İptal edildi',
    'iptal_isletme' => 'İşletme iptal etti',
    'geldi' => 'Gerçekleşti',
    'gelmedi' => 'Gelinmedi',
    _ => durum,
  };

  /// Hala degistirilebilir mi (iptal edilebilir mi).
  bool get aktif => durum == 'bekliyor' || durum == 'onaylandi';

  static Randevu json(Map<String, dynamic> m) => Randevu(
    id: (m['id'] ?? '').toString(),
    isletmeId: (m['isletme_id'] ?? '').toString(),
    musteriId: (m['musteri_id'] ?? '').toString(),
    tur: (m['tur'] ?? 'randevu').toString(),
    baslangic:
        DateTime.tryParse((m['baslangic'] ?? '').toString())?.toLocal() ??
        DateTime.now(),
    sureDakika: (m['sure_dakika'] as num?)?.toInt() ?? 30,
    kisiSayisi: (m['kisi_sayisi'] as num?)?.toInt() ?? 1,
    hizmet: (m['hizmet'] ?? '').toString(),
    notMusteri: (m['not_musteri'] ?? '').toString(),
    notIsletme: (m['not_isletme'] ?? '').toString(),
    durum: (m['durum'] ?? 'bekliyor').toString(),
    karsiAd: (m['karsi_ad'] ?? '').toString(),
    karsiKullaniciAdi: (m['karsi_kullanici_adi'] ?? '').toString(),
    karsiAvatarMediaId: m['karsi_avatar_media_id'] as String?,
  );
}

/// Isletmenin randevu ayarlari.
class RandevuAyar {
  const RandevuAyar({
    required this.acik,
    required this.tur,
    required this.slotDakika,
    required this.slotKapasite,
    required this.ileriGun,
    required this.otomatikOnay,
  });

  final bool acik;
  final String tur;
  final int slotDakika;

  /// ⚠️ KAPASITE = AYNI ANDA KAC RANDEVU (masa sayisi), KISI SAYISI DEGIL.
  final int slotKapasite;
  final int ileriGun;
  final bool otomatikOnay;

  bool get rezervasyonMu => tur == 'rezervasyon';

  static RandevuAyar json(Map<String, dynamic> m) => RandevuAyar(
    acik: m['acik'] == true,
    tur: (m['tur'] ?? 'randevu').toString(),
    slotDakika: (m['slot_dakika'] as num?)?.toInt() ?? 30,
    slotKapasite: (m['slot_kapasite'] as num?)?.toInt() ?? 1,
    ileriGun: (m['ileri_gun'] as num?)?.toInt() ?? 14,
    otomatikOnay: m['otomatik_onay'] == true,
  );
}

class RandevuServisi {
  RandevuServisi(this._ref);
  final Ref _ref;
  Dio get _api => _ref.read(apiProvider);

  /// ⚠️ TARIH `YYYY-MM-DD` — sunucu bunu Turkiye saatiyle yorumlar.
  Future<UygunGun> uygunSaatler(String isletmeId, DateTime gun) async {
    final t =
        '${gun.year.toString().padLeft(4, '0')}-'
        '${gun.month.toString().padLeft(2, '0')}-'
        '${gun.day.toString().padLeft(2, '0')}';
    final r = await _api.get(
      '/isletmeler/$isletmeId/uygun-saatler',
      queryParameters: {'tarih': t},
    );
    return UygunGun.json((r.data as Map).cast<String, dynamic>());
  }

  /// ⚠️ `zaman` sunucunun verdigi RFC3339 degeri — istemci KENDI hesaplamaz.
  Future<String> olustur({
    required String isletmeId,
    required String zaman,
    int kisiSayisi = 1,
    String hizmet = '',
    String not = '',
  }) async {
    final r = await _api.post(
      '/isletmeler/$isletmeId/randevu',
      data: {
        'baslangic': zaman,
        'kisi_sayisi': kisiSayisi,
        'hizmet': hizmet,
        'not_musteri': not,
      },
    );
    return (r.data['id'] ?? '').toString();
  }

  Future<void> durum(String id, String yeni, {String notIsletme = ''}) async {
    await _api.post(
      '/randevular/$id/durum',
      data: {'durum': yeni, if (notIsletme.isNotEmpty) 'not_isletme': notIsletme},
    );
  }

  Future<List<Randevu>> randevularim({bool gecmis = false}) =>
      _liste('/randevularim', gecmis: gecmis);

  Future<List<Randevu>> isletmeRandevulari({
    bool gecmis = false,
    String durum = '',
  }) => _liste('/isletme/randevular', gecmis: gecmis, durum: durum);

  Future<List<Randevu>> _liste(
    String yol, {
    bool gecmis = false,
    String durum = '',
  }) async {
    final r = await _api.get(
      yol,
      queryParameters: {
        if (gecmis) 'gecmis': '1',
        if (durum.isNotEmpty) 'durum': durum,
      },
    );
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['randevular'] as List?) ?? [])
        .map((e) => Randevu.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<RandevuAyar> ayar() async {
    final r = await _api.get('/isletme/randevu-ayar');
    return RandevuAyar.json((r.data as Map).cast<String, dynamic>());
  }

  /// ⚠️ TUM ALANLAR OPSIYONEL — gonderilmeyen alan sunucuda MEVCUDU KORUR
  ///    (`COALESCE`). Duz deger gonderseydik kullanicinin dokunmadigi ayar
  ///    sifirlanirdi (turu 78'in koordinat ezme hatasinin ayni sinifi).
  Future<RandevuAyar> ayarKaydet({
    bool? acik,
    int? slotDakika,
    int? slotKapasite,
    int? ileriGun,
    bool? otomatikOnay,
  }) async {
    final r = await _api.put(
      '/isletme/randevu-ayar',
      data: {
        if (acik != null) 'acik': acik,
        if (slotDakika != null) 'slot_dakika': slotDakika,
        if (slotKapasite != null) 'slot_kapasite': slotKapasite,
        if (ileriGun != null) 'ileri_gun': ileriGun,
        if (otomatikOnay != null) 'otomatik_onay': otomatikOnay,
      },
    );
    return RandevuAyar.json((r.data as Map).cast<String, dynamic>());
  }

  Future<List<String>> kapaliGunler() async {
    final r = await _api.get('/isletme/randevu-kapali');
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['gunler'] as List?) ?? []).map((e) => e.toString()).toList();
  }

  Future<void> kapaliGunAyarla(String tarih, bool kapali) async {
    await _api.post(
      '/isletme/randevu-kapali',
      data: {'tarih': tarih, 'kapali': kapali},
    );
  }
}

final randevuServisiProvider = Provider<RandevuServisi>(RandevuServisi.new);

/// ⚠️ GUN ADLARI — TEK KAYNAK. `intl` paketi var ama `DateFormat` yerellestirme
///    verisi gerektiriyor ve uygulamada `flutter_localizations` YOK; sabit
///    Turkce liste hem daha ucuz hem KESIN.
const List<String> kGunKisa = [
  'Pzt',
  'Sal',
  'Çar',
  'Per',
  'Cum',
  'Cmt',
  'Paz',
];

const List<String> kAyAdlari = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

/// "12 Ağustos 14:30" — randevu satirlarinda TEK bicimlendirici.
String randevuZamani(DateTime d) =>
    '${d.day} ${kAyAdlari[d.month - 1]} '
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';
