import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../etkinlik/etkinlik_ekranlari.dart';
import '../etkinlik/etkinlik_servisi.dart';
import '../medya/medya_gorsel.dart';
import '../sosyal/profil_sayfasi.dart';

/// ⚠️⚠️ TURU 78 — KATEGORI INIS SAYFASININ UST SLIDER'I.
///
/// Kullanici emri: "kategori sayfasinin ustunde slider reklam alani olacak".
///
/// ⚠️ ICERIK **ORGANIK**: dogrulanmis isletmeler + yaklasan etkinlikler.
///    `reklamlar` tablosu ACILMADI cunku bugun icerigini girecek YOL YOK
///    (odeme yok, admin panelinden gorsel YUKLENEMEZ — ayrintili gerekce
///    `backend/internal/vitrin/handler.go` serhinde).
///
/// ⚠️ YENI PAKET EKLENMEDI: `PageView` + `Timer`. Bu projede her yeni Flutter
///    paketi iOS/Android derleme riski (sentry 8.x, eski firebase, pbxproj/BOM).
class VitrinSlider extends ConsumerStatefulWidget {
  const VitrinSlider({super.key, required this.dikey});

  /// yemek | kafe | market | isletme | ilan | hizmet | etkinlik
  final String dikey;

  @override
  ConsumerState<VitrinSlider> createState() => _VitrinSliderState();
}

class _VitrinSliderState extends ConsumerState<VitrinSlider> {
  final _sayfa = PageController();
  Timer? _oto;
  List<_Slayt>? _slaytlar;
  int _aktif = 0;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  /// ⚠️⚠️ TURU 78b — KATEGORI DEGISINCE **YENIDEN YUKLENIR** (denetim bulgusu).
  ///
  ///	`_yukle()` YALNIZCA `initState`te cagriliyordu. Ama iki ana ekran
  ///	`dikey`i CALISMA ANINDA degistiriyor: isletme rehberinde kategori cipine
  ///	("Yemek", "Kafe"), ilan listesinde tur cipine ("Emlak", "Vasıta")
  ///	basildiginda widget'in tipi ve agactaki yeri AYNI kaldigi icin Flutter
  ///	State'i KORUR ve slider **ESKI kategorinin slaytlarini** gostermeye devam
  ///	ederdi. Kullanici "Emlak"a basip vitrinde ARABA gorurdu; slayta
  ///	dokundugunda da yanlis kayda giderdi.
  /// ⚠️ Liste SIFIRLANIR (`null`): eski slaytlar yenisi gelene kadar EKRANDA
  ///	KALMAMALI, yoksa kisa bir sure yanlis kategori gosterilir.
  /// ⚠️ Otomatik gecis timer'i da durdurulur; yeni liste gelince `_yukle`
  ///	gerekiyorsa yeniden baslatir.
  @override
  void didUpdateWidget(covariant VitrinSlider eski) {
    super.didUpdateWidget(eski);
    if (eski.dikey != widget.dikey) {
      _oto?.cancel();
      _aktif = 0;
      setState(() => _slaytlar = null);
      _yukle();
    }
  }

  @override
  void dispose() {
    // ⚠️⚠️ TIMER **MUTLAKA** IPTAL EDILIR. Bu projede `IndexedStack` tum
    //    cocuklari CANLI tutuyor; iptal edilmeyen bir timer sekme
    //    degistirildikten sonra da calisir, pil yakar ve `_sayfa`
    //    (dispose edilmis controller) uzerinde animasyon deneyip PATLAR.
    _oto?.cancel();
    _sayfa.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final r = await ref
          .read(apiProvider)
          .get('/vitrin', queryParameters: {'dikey': widget.dikey});
      final m = (r.data as Map).cast<String, dynamic>();
      final l = ((m['slaytlar'] as List?) ?? [])
          .map((e) => _Slayt.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      if (!mounted) return;
      setState(() => _slaytlar = l);
      if (l.length > 1) _otoBaslat();
    } on DioException {
      // ⚠️ SESSIZ: vitrin SUS ESYASIDIR, sayfanin asil isini (liste) bloklamaz.
      //    Hata durumunda slider HIC CIZILMEZ — kirik bir kutu gostermekten iyi.
      if (mounted) setState(() => _slaytlar = const []);
    }
  }

  void _otoBaslat() {
    _oto?.cancel();
    _oto = Timer.periodic(const Duration(seconds: 5), (_) {
      final l = _slaytlar;
      if (!mounted || l == null || l.length < 2) return;
      // ⚠️ `hasClients` KAPISI ZORUNLU: sayfa henuz agaca baglanmadiysa ya da
      //    kullanici baska sekmedeyse `animateToPage` PATLAR.
      if (!_sayfa.hasClients) return;
      final sonraki = (_aktif + 1) % l.length;
      _sayfa.animateToPage(
        sonraki,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _ac(_Slayt s) {
    if (s.hedefTur == 'isletme') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: s.hedefId)),
      );
      return;
    }
    // ⚠️ Etkinlik detayi bir `Etkinlik` NESNESI istiyor; elimizde yalniz id
    //    var. Once SUNUCUDAN cekiyoruz — yarim bir nesne uydurmak, detay
    //    ekraninda bos alanlar ve yanlis "kontenjan doldu" hesabi demekti.
    unawaited(_etkinligeGit(s.hedefId));
  }

  Future<void> _etkinligeGit(String id) async {
    try {
      final e = await ref.read(etkinlikServisiProvider).detay(id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EtkinlikDetayEkrani(etkinlik: e)),
      );
    } catch (_) {
      // sessiz — vitrin sus esyasi
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _slaytlar;
    // ⚠️⚠️ BOS/YUKLENIYOR durumunda HIC CIZILMEZ (yer tutucu bile yok).
    //    Bos gri bir kutu "burada bir sey olmali ama yok" hissi verir; ustelik
    //    yeni kurulumda vitrin HER ZAMAN bos olacagi icin kalici bir leke olurdu.
    if (l == null || l.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _sayfa,
            itemCount: l.length,
            onPageChanged: (i) => setState(() => _aktif = i),
            itemBuilder: (_, i) => _kart(l[i]),
          ),
        ),
        if (l.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < l.length; i++)
                  Container(
                    width: _aktif == i ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _aktif == i
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _kart(_Slayt s) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: GestureDetector(
      onTap: () => _ac(s),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (s.mediaId != null && s.mediaId!.isNotEmpty)
              MedyaGorsel(mediaId: s.mediaId!, fit: BoxFit.cover)
            else
              const ColoredBox(color: Color(0xFF2A2140)),
            // ⚠️ Alt karartma: baslik acik renkli gorselde de OKUNUR olmali.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.baslik,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (s.altBaslik.isNotEmpty)
                    Text(
                      s.altBaslik,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Slayt {
  _Slayt({
    required this.baslik,
    required this.altBaslik,
    required this.mediaId,
    required this.hedefTur,
    required this.hedefId,
  });

  final String baslik;
  final String altBaslik;
  final String? mediaId;
  final String hedefTur;
  final String hedefId;

  static _Slayt fromJson(Map<String, dynamic> m) => _Slayt(
    baslik: (m['baslik'] ?? '').toString(),
    altBaslik: (m['alt_baslik'] ?? '').toString(),
    mediaId: m['media_id'] as String?,
    hedefTur: (m['hedef_tur'] ?? '').toString(),
    hedefId: (m['hedef_id'] ?? '').toString(),
  );
}
