/// ⚠️⚠️⚠️ TURU 96f — KAYITLI KONUMLAR (kullanici emri: *"geri tusu yerine
/// navigator ikonu koy, saginda Ev yazsin; tikladiginda filtreleme gibi popup
/// ciksin, burada mevcut eklenen konum, yeni konum ekleme gibi seyler
/// olsun"*).
///
/// ⚠️⚠️ **KONUMLAR CIHAZDA TUTULUYOR, SUNUCUDA DEGIL** ve bu bilincli:
///	`users` tablosunda adres diye bir sutun, adres girisi diye bir ekran
///	YOK. Sunucuya yazmak bir migration + uc + yetki kapisi demekti; bu tur
///	SALT ARAYUZ turu (kullanici emri: *"backend vs. ugrasma, arayuzu
///	gormemiz gerekiyor"*).
/// ⚠️ Cihazda tutmanin GERCEK BEDELI var ve durustce yazili: kullanici
///    telefon degistirince ya da uygulamayi silince adresleri KAYBEDER.
///    Backend turunda `user_adresler` tablosuna tasinmali.
///
/// ⚠️⚠️ BU EKRAN **SAHTE VERI URETMEZ**: hicbir hazir adres yazilmadi.
///	Kayit yoksa liste bos gorunur ve tek eylem "Yeni konum ekle"dir.
///	Ornek olsun diye "Ev / İş" satiri cizmek, dokununca hicbir sey
///	yapmayan bir arayuz olurdu (bu projede en pahali hata sinifi).
///
/// ⚠️ Secilen konum KART MESAFESINI besler: `isletme_listesi` once bunu
///    okur, yoksa GPS'e duser. Iki kaynak da ayni alani doldurur.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harita_pin.dart';
import 'isletme_kart.dart' show kYanBosluk, kYaricap, kVurgu, kYuzeyGri;

/// Kayitli bir konum.
class Konum {
  const Konum({required this.ad, required this.enlem, required this.boylam});

  final String ad;
  final double enlem;
  final double boylam;

  Map<String, dynamic> toJson() =>
      {'ad': ad, 'enlem': enlem, 'boylam': boylam};

  static Konum json(Map<String, dynamic> m) => Konum(
        ad: (m['ad'] ?? '').toString(),
        enlem: (m['enlem'] as num?)?.toDouble() ?? 0,
        boylam: (m['boylam'] as num?)?.toDouble() ?? 0,
      );
}

/// Konum deposu — `SharedPreferences`.
///
/// ⚠️ `SharedPreferences` acilamazsa uygulama YINE DE CALISIR: liste bos
///    doner, ekleme sessizce basarisiz olur. Konum bir KOLAYLIK, uygulamanin
///    calismasi ona BAGLI DEGIL.
class KonumDeposu {
  static const _liste = 'konumlar';
  static const _secili = 'konum_secili';

  static Future<List<Konum>> hepsi() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ham = p.getString(_liste);
      if (ham == null || ham.isEmpty) return const [];
      return (jsonDecode(ham) as List)
          .map((e) => Konum.json((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> yaz(List<Konum> l) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_liste, jsonEncode(l.map((e) => e.toJson()).toList()));
    } catch (_) {/* konum bir kolaylik; yazilamazsa uygulama calisir */}
  }

  /// ⚠️ INDEKS degil AD saklanir: liste siralamasi degisince indeks BASKA
  ///    bir konumu gosterirdi.
  static Future<String> seciliAd() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString(_secili) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> seciliYaz(String ad) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_secili, ad);
    } catch (_) {}
  }

  /// Secili konum nesnesi; yoksa `null`.
  static Future<Konum?> secili() async {
    final l = await hepsi();
    if (l.isEmpty) return null;
    final ad = await seciliAd();
    for (final k in l) {
      if (k.ad == ad) return k;
    }
    return l.first;
  }
}

/// Konum secici — alttan panel.
///
/// ⚠️ Filtre paneliyle **AYNI DIL**: %100 genislik, ustte X + ortali baslik,
///    altta tam genislikte birincil dugme. Iki panel farkli gorunseydi
///    kullanici "baska bir uygulama" hissi alirdi.
/// ⚠️ Yukseklik SABIT DEGIL (`shrinkWrap`): kayitli konum sayisi 0 da olabilir
///    8 de. Filtre paneli gibi %95 yapilsaydi tek satirlik listede ekranin
///    tamami BOS gorunurdu.
Future<bool> konumSeciciAc(BuildContext context) async {
  final sonuc = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (c) => const _KonumPaneli(),
  );
  return sonuc == true;
}

class _KonumPaneli extends StatefulWidget {
  const _KonumPaneli();

  @override
  State<_KonumPaneli> createState() => _KonumPaneliState();
}

class _KonumPaneliState extends State<_KonumPaneli> {
  List<Konum> _liste = const [];
  String _secili = '';
  bool _yukleniyor = true;
  bool _ekleniyor = false;

  @override
  void initState() {
    super.initState();
    _oku();
  }

  Future<void> _oku() async {
    final l = await KonumDeposu.hepsi();
    final s = await KonumDeposu.seciliAd();
    if (!mounted) return;
    setState(() {
      _liste = l;
      _secili = s.isEmpty && l.isNotEmpty ? l.first.ad : s;
      _yukleniyor = false;
    });
  }

  /// ⚠️⚠️ YENI KONUM = **CIHAZIN GERCEK KONUMU**. Elle enlem/boylam yazdirmak
  ///	ya da haritadan sectirmek bu turun kapsami disinda; ikisi de ayri bir
  ///	ekran ister. Bugun calisan tek durust yol GPS.
  /// ⚠️ Izin reddedilirse SEBEP soylenir: sessizce hicbir sey olmamasi
  ///    "dugme bozuk" hissi verir.
  /// ⚠️ Ad **ZORUNLU DEGIL**: bos birakilirsa sira numarasi verilir. Zorunlu
  ///    olsaydi konum eklemek iki adima cikardi.
  /// ⚠️⚠️⚠️ TURU 96g — IKI YOL: **GPS** ya da **HARITADAN PIN** (kullanici
  ///	emri: *"konum secte haritadan pin secebilelim, Yemeksepeti gibi"*).
  ///
  /// ⚠️ Harita secenegi YALNIZ harita anahtarli derlemede cizilir
  ///    (`haritadanSecilebilir`): anahtarsiz derlemede `GoogleMap`
  ///    Android'de filigranli gri kutu, iOS'ta BOS ekran olurdu (turu 85).
  ///    Basildiginda bos ekran acan bir dugme "bozuk" gorunur.
  /// ⚠️ Tek secenek varsa SORU SORULMAZ: dogrudan GPS'e gider. Tek maddelik
  ///    bir menu, kullaniciya gereksiz bir dokunus maliyeti demektir.
  Future<void> _yeniKonum() async {
    if (!haritadanSecilebilir) {
      await _ekle();
      return;
    }
    final secim = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.crosshair),
              title: const Text('Bulunduğum konum'),
              subtitle: const Text('GPS ile otomatik bul'),
              onTap: () => Navigator.of(c).pop('gps'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.map),
              title: const Text('Haritadan seç'),
              subtitle: const Text('Pini istediğin yere taşı'),
              onTap: () => Navigator.of(c).pop('harita'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || secim == null) return;
    if (secim == 'gps') {
      await _ekle();
    } else {
      await _haritadan();
    }
  }

  /// Haritadan pin secip kaydeder.
  ///
  /// ⚠️ Baslangic noktasi: **son bilinen konum**, yoksa secili konum, o da
  ///    yoksa Gebze merkezi. Haritayi 0,0'da (Gine Korfezi) acmak kullaniciya
  ///    okyanus gosterirdi.
  Future<void> _haritadan() async {
    var enlem = 40.8028, boylam = 29.4307; // Gebze merkez
    try {
      final son = await Geolocator.getLastKnownPosition();
      if (son != null) {
        enlem = son.latitude;
        boylam = son.longitude;
      } else if (_liste.isNotEmpty) {
        enlem = _liste.first.enlem;
        boylam = _liste.first.boylam;
      }
    } catch (_) {/* baslangic noktasi bir KOLAYLIK; hata onemli degil */}
    if (!mounted) return;
    final nokta = await haritadanPinSec(context,
        baslangicEnlem: enlem, baslangicBoylam: boylam);
    if (nokta == null || !mounted) return;
    final ad = await _adSor();
    if (ad == null || !mounted) return;
    final yeni = [
      ..._liste,
      Konum(ad: ad, enlem: nokta.$1, boylam: nokta.$2),
    ];
    await KonumDeposu.yaz(yeni);
    await KonumDeposu.seciliYaz(ad);
    if (!mounted) return;
    setState(() {
      _liste = yeni;
      _secili = ad;
    });
  }

  Future<void> _ekle() async {
    if (_ekleniyor) return;
    setState(() => _ekleniyor = true);
    final mesajci = ScaffoldMessenger.of(context);
    try {
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      if (izin != LocationPermission.always &&
          izin != LocationPermission.whileInUse) {
        mesajci.showSnackBar(const SnackBar(
          content: Text('Konum izni verilmedi.'),
        ));
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      final ad = await _adSor();
      if (ad == null || !mounted) return;
      final yeni = [
        ..._liste,
        Konum(ad: ad, enlem: p.latitude, boylam: p.longitude),
      ];
      await KonumDeposu.yaz(yeni);
      await KonumDeposu.seciliYaz(ad);
      if (!mounted) return;
      setState(() {
        _liste = yeni;
        _secili = ad;
      });
    } catch (_) {
      mesajci.showSnackBar(const SnackBar(
        content: Text('Konum alınamadı. GPS açık mı?'),
      ));
    } finally {
      if (mounted) setState(() => _ekleniyor = false);
    }
  }

  /// Ad sorar. `null` = vazgecildi.
  ///
  /// ⚠️ Hazir secenekler (Ev · İş · Diğer) SADECE KISAYOL: kullanici serbest
  ///    metin de yazabilir. Yalniz uc secenek sunmak "baska adres ekleyemem"
  ///    demek olurdu.
  Future<String?> _adSor() async {
    final kutu = TextEditingController(
      text: _liste.any((k) => k.ad == 'Ev') ? '' : 'Ev',
    );
    final sonuc = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Konuma ad ver'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final h in const ['Ev', 'İş', 'Diğer'])
                  ActionChip(
                    label: Text(h),
                    onPressed: () => kutu.text = h,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kutu,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Örn. Ev'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () {
              final t = kutu.text.trim();
              Navigator.of(c).pop(t.isEmpty ? 'Konum ${_liste.length + 1}' : t);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    kutu.dispose();
    return sonuc;
  }

  Future<void> _sil(Konum k) async {
    final yeni = _liste.where((e) => e.ad != k.ad).toList();
    await KonumDeposu.yaz(yeni);
    if (k.ad == _secili) {
      await KonumDeposu.seciliYaz(yeni.isEmpty ? '' : yeni.first.ad);
    }
    if (!mounted) return;
    setState(() {
      _liste = yeni;
      if (k.ad == _secili) _secili = yeni.isEmpty ? '' : yeni.first.ad;
    });
  }

  @override
  Widget build(BuildContext context) {
    final koyu = Theme.of(context).brightness == Brightness.dark;
    final yazi = koyu ? Colors.white : const Color(0xFF1A1A1A);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: Stack(
            children: [
              // ⚠️ Baslik **GERCEK MERKEZDE**: `Expanded` ile ortalansaydi
              //    soldaki X kadar saga kayardi (filtre panelinde tam bu
              //    hata vardi ve kullanici fark etti).
              Center(
                child: Text('Konumun',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: yazi)),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(LucideIcons.x, size: 22, color: yazi),
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: kYuzeyGri(context)),
        if (_yukleniyor)
          const Padding(
            padding: EdgeInsets.all(28),
            child: CircularProgressIndicator(),
          )
        else ...[
          if (_liste.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(kYanBosluk, 24, kYanBosluk, 8),
              child: Text(
                'Kayıtlı konumun yok.\nEklersen kartlarda uzaklık gösterilir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: yazi.withValues(alpha: 0.6)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _liste.length,
              itemBuilder: (_, i) {
                final k = _liste[i];
                final secili = k.ad == _secili;
                return ListTile(
                  leading: Icon(
                    secili ? LucideIcons.navigation : LucideIcons.mapPin,
                    color: secili ? kVurgu(context) : yazi,
                  ),
                  title: Text(k.ad,
                      style: TextStyle(
                          fontWeight:
                              secili ? FontWeight.w700 : FontWeight.w500)),
                  subtitle: Text(
                    '${k.enlem.toStringAsFixed(4)}, '
                    '${k.boylam.toStringAsFixed(4)}',
                    style: TextStyle(
                        fontSize: 12, color: yazi.withValues(alpha: 0.5)),
                  ),
                  trailing: IconButton(
                    icon: Icon(LucideIcons.trash2,
                        size: 18, color: yazi.withValues(alpha: 0.6)),
                    tooltip: 'Sil',
                    onPressed: () => _sil(k),
                  ),
                  onTap: () async {
                    await KonumDeposu.seciliYaz(k.ad);
                    if (context.mounted) Navigator.of(context).pop(true);
                  },
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kYanBosluk, 8, kYanBosluk, 8),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  // ⚠️ Renk TEMADAN ALINMAZ: varsayilan `primary` YESIL ve
                  //    kullanici bu ekranlarda yesili reddetti (bkz. `kVurgu`).
                  backgroundColor: kVurgu(context),
                  foregroundColor: koyu ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kYaricap(52)),
                  ),
                ),
                onPressed: _ekleniyor ? null : _yeniKonum,
                icon: _ekleniyor
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.plus, size: 18),
                label: Text(_ekleniyor ? 'Konum alınıyor…' : 'Yeni konum ekle'),
              ),
            ),
          ),
        ],
        // ⚠️ Jest cubugu olan telefonlarda dugme cubugun ALTINDA kalmasin.
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 4),
      ],
    );
  }
}
