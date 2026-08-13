/// ⚠️⚠️⚠️ TURU 96f — KAYITLI KONUMLAR (kullanici emri: *"geri tusu yerine
/// navigator ikonu koy, saginda Ev yazsin; tikladiginda filtreleme gibi popup
/// ciksin, burada mevcut eklenen konum, yeni konum ekleme gibi seyler
/// olsun"*) + turu 96g: *"konum secte haritadan pin secebilelim"*.
///
/// ⚠️⚠️⚠️ TURU 96h — **KONUMLAR ARTIK SUNUCUDA** (`user_adresler`,
///	migration 048). Turu 96f'de cihazda (`SharedPreferences`) tutuluyordu
///	ve sinir durustce yaziliydi: *"telefon degisince ya da uygulama
///	silinince adresler KAYBOLUR"*. O borc bu turda kapatildi.
/// ⚠️ Cihaz onbellegi BIRAKILMADI: iki kaynak kacinilmaz olarak drift eder
///    (bu projede "ayni kuralin iki kopyasi" sinifi ALTI kez sahaya cikti).
///    Ag yoksa liste bos doner ve panel "kayitli konumun yok" der — YANLIS
///    bir adres gostermekten iyidir.
///
/// ⚠️⚠️ BU EKRAN **SAHTE VERI URETMEZ**: hicbir hazir adres yazilmadi.
///	Kayit yoksa liste bos gorunur ve tek eylem "Yeni konum ekle"dir.
///	Ornek olsun diye "Ev / İş" satiri cizmek, dokununca hicbir sey
///	yapmayan bir arayuz olurdu (bu projede en pahali hata sinifi).
///
/// ⚠️ Secilen konum KART MESAFESINI besler: `isletme_listesi` once bunu
///    okur, yoksa GPS'e duser.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../core/api.dart';
import '../../core/denetleyici_sahibi.dart';
import 'harita_pin.dart';
import 'isletme_kart.dart' show kYanBosluk, kYaricap, kVurgu, kYuzeyGri;

/// Kayitli bir konum.
class Konum {
  const Konum({
    required this.id,
    required this.ad,
    required this.enlem,
    required this.boylam,
    required this.secili,
  });

  /// ⚠️ Sunucu id'si: secme/silme bunu kullanir. Turu 96f'de konumlar
  ///    cihazdaydi ve ADLA adresleniyordu; sunucuda ad tekil olsa da id daha
  ///    guvenli (ad degisse bile satir ayni kalir).
  final String id;
  final String ad;
  final double enlem;
  final double boylam;
  final bool secili;

  static Konum json(Map<String, dynamic> m) => Konum(
        id: (m['id'] ?? '').toString(),
        ad: (m['ad'] ?? '').toString(),
        enlem: (m['enlem'] as num?)?.toDouble() ?? 0,
        boylam: (m['boylam'] as num?)?.toDouble() ?? 0,
        secili: m['secili'] == true,
      );
}

/// Konum deposu — sunucu (`/users/me/adresler`).
///
/// ⚠️ Hatalar YUTULUR ve BOS liste doner: konum bir KOLAYLIK, uygulamanin
///    calismasi ona BAGLI DEGIL. Ag hatasinda ekran acilmaya devam eder.
class KonumDeposu {
  /// ⚠️ `Ref` ve `WidgetRef` ORTAK BIR ARAYUZ PAYLASMAZ; ikisini de kabul
  ///    eden bir imza yazilamaz. Cozum: cagiran taraf `Dio`yu VERIR — depo
  ///    Riverpod'a hic bagli degil ve test edilebilir kalir.
  static Future<List<Konum>> hepsi(Dio api) async {
    try {
      final r = await api.get('/users/me/adresler');
      final l = (r.data['adresler'] as List?) ?? [];
      return l
          .map((e) => Konum.json((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      // ⚠️⚠️ TURU 96i — SESSIZ YUTMA YASAK. Hata yine YUTULUYOR (konum bir
      //	KOLAYLIK, ekran acilmaya devam etmeli) ama ARTIK GORUNUR: aksi
      //	halde "sunucuda adres VAR, panel BOS diyor" durumu hicbir yerde
      //	iz birakmiyordu ve teshis EMULATORDE ELLE arandi.
      //	(CLAUDE.md tekrarlayan ders: *"bu patlarsa TELEMETRIDE gorur
      //	muyum?" — cevap hayirsa once olcumu koy.*)
      debugPrint('KONUM: adresler okunamadi -> $e');
      unawaited(Sentry.captureMessage('adresler okunamadi: $e'));
      return const [];
    }
  }

  /// Secili konum; yoksa `null`.
  ///
  /// ⚠️ Sunucu "tek secili" kuralini KISIMLI TEKIL INDEKSLE garanti ediyor;
  ///    istemci "hangisi secili" hesabi YAPMAZ. Hicbiri isaretli degilse
  ///    ilki kullanilir.
  static Future<Konum?> secili(Dio api) async {
    final l = await hepsi(api);
    for (final k in l) {
      if (k.secili) return k;
    }
    return l.isEmpty ? null : l.first;
  }

  static Future<void> ekle(Dio api, String ad, double enlem, double boylam) =>
      api.post('/users/me/adresler',
          data: {'ad': ad, 'enlem': enlem, 'boylam': boylam});

  static Future<void> sec(Dio api, String id) =>
      api.post('/users/me/adresler/$id/sec');

  static Future<void> sil(Dio api, String id) =>
      api.delete('/users/me/adresler/$id');
}

/// Konum secici — alttan panel.
///
/// ⚠️ Filtre paneliyle **AYNI DIL**: %100 genislik, ustte X + ORTALI baslik,
///    altta tam genislikte birincil dugme.
/// ⚠️ Yukseklik SABIT DEGIL (`shrinkWrap`): kayitli konum 0 da olabilir 20 de.
///    Filtre paneli gibi %95 yapilsaydi tek satirlik listede ekranin tamami
///    BOS gorunurdu.
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

class _KonumPaneli extends ConsumerStatefulWidget {
  const _KonumPaneli();

  @override
  ConsumerState<_KonumPaneli> createState() => _KonumPaneliState();
}

class _KonumPaneliState extends ConsumerState<_KonumPaneli> {
  List<Konum> _liste = const [];
  bool _yukleniyor = true;
  bool _ekleniyor = false;

  @override
  void initState() {
    super.initState();
    _oku();
  }

  Future<void> _oku() async {
    final l = await KonumDeposu.hepsi(ref.read(apiProvider));
    if (!mounted) return;
    setState(() {
      _liste = l;
      _yukleniyor = false;
    });
  }

  /// ⚠️⚠️⚠️ IKI YOL: **GPS** ya da **HARITADAN PIN** (kullanici emri:
  ///	*"konum secte haritadan pin secebilelim, Yemeksepeti gibi"*).
  ///
  /// ⚠️ Harita secenegi YALNIZ harita anahtarli derlemede cizilir
  ///    (`haritadanSecilebilir`): anahtarsiz derlemede `GoogleMap`
  ///    Android'de filigranli gri kutu, iOS'ta BOS ekran olurdu (turu 85).
  ///    Basildiginda bos ekran acan bir dugme "bozuk" gorunur.
  /// ⚠️ Tek secenek varsa SORU SORULMAZ: dogrudan GPS'e gider. Tek maddelik
  ///    bir menu, kullaniciya gereksiz bir dokunus maliyeti demektir.
  Future<void> _yeniKonum() async {
    if (!haritadanSecilebilir) {
      await _gpsIle();
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
      await _gpsIle();
    } else {
      await _haritadan();
    }
  }

  /// ⚠️ Izin reddedilirse SEBEP soylenir: sessizce hicbir sey olmamasi
  ///    "dugme bozuk" hissi verir.
  Future<void> _gpsIle() async {
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
        mesajci.showSnackBar(
            const SnackBar(content: Text('Konum izni verilmedi.')));
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      await _kaydet(p.latitude, p.longitude);
    } catch (_) {
      mesajci.showSnackBar(
          const SnackBar(content: Text('Konum alınamadı. GPS açık mı?')));
    } finally {
      if (mounted) setState(() => _ekleniyor = false);
    }
  }

  /// Haritadan pin secip kaydeder.
  ///
  /// ⚠️ Baslangic noktasi: **son bilinen konum**, yoksa kayitli ilk konum, o
  ///    da yoksa Gebze merkezi. Haritayi 0,0'da (Gine Korfezi) acmak
  ///    kullaniciya okyanus gosterirdi.
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
    await _kaydet(nokta.$1, nokta.$2);
  }

  /// Ad sorup sunucuya yazar.
  ///
  /// ⚠️ Yeni adres sunucuda DAIMA SECILI olur (bkz. `adres.go`): kullanici
  ///    bir adres ekliyorsa amaci onu kullanmaktir.
  Future<void> _kaydet(double enlem, double boylam) async {
    final ad = await _adSor();
    if (ad == null || !mounted) return;
    final mesajci = ScaffoldMessenger.of(context);
    try {
      await KonumDeposu.ekle(ref.read(apiProvider), ad, enlem, boylam);
    } catch (_) {
      mesajci.showSnackBar(
          const SnackBar(content: Text('Konum kaydedilemedi.')));
      return;
    }
    await _oku();
  }

  /// Ad sorar. `null` = vazgecildi.
  ///
  /// ⚠️ Hazir secenekler (Ev · İş · Diğer) SADECE KISAYOL: kullanici serbest
  ///    metin de yazabilir. Yalniz uc secenek sunmak "baska adres ekleyemem"
  ///    demek olurdu.
  /// ⚠️ Ad ZORUNLU DEGIL: bos birakilirsa sira numarasi verilir.
  Future<String?> _adSor() async {
    final kutu = TextEditingController(
      text: _liste.any((k) => k.ad == 'Ev') ? '' : 'Ev',
    );
    final sonuc = await showDialog<String>(
      context: context,
      builder: (c) => DenetleyiciSahibi(
        denetleyiciler: [kutu],
        child: AlertDialog(
        title: const Text('Konuma ad ver'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final h in const ['Ev', 'İş', 'Diğer'])
                  ActionChip(label: Text(h), onPressed: () => kutu.text = h),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kutu,
              autofocus: true,
              // ⚠️ Sunucu 40 karakter tavani uyguluyor; istemci de AYNI tavani
              //    koyar ki kullanici yazarken ogrensin (400 yiyip sonradan
              //    ogrenmesin).
              maxLength: 40,
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
      ),
    );
    return sonuc;
  }

  Future<void> _sil(Konum k) async {
    try {
      await KonumDeposu.sil(ref.read(apiProvider), k.id);
    } catch (_) {/* silinemezse liste ayni kalir; yeniden denenebilir */}
    await _oku();
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
              //    soldaki X kadar saga kayardi (filtre panelinde tam bu hata
              //    vardi ve kullanici fark etti).
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
                return ListTile(
                  leading: Icon(
                    k.secili ? LucideIcons.navigation : LucideIcons.mapPin,
                    color: k.secili ? kVurgu(context) : yazi,
                  ),
                  title: Text(k.ad,
                      style: TextStyle(
                          fontWeight:
                              k.secili ? FontWeight.w700 : FontWeight.w500)),
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
                    try {
                      await KonumDeposu.sec(ref.read(apiProvider), k.id);
                    } catch (_) {/* secilemezse panel acik kalir */}
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
