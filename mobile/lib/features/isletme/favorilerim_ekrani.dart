/// ⚠️⚠️ TURU 94 — FAVORI ISLETMELER.
///
/// Kullanici kategori ekraninin sag ustune **kalp** istedi. Kalbin gidecegi
/// yer burasi; favorileme ise KARTIN uzerindeki kalpten yapiliyor. Ikisi
/// AYNI TURDA yazildi — biri olmadan oteki "dugme var, hicbir sey yapmiyor"
/// sinifina yeni bir ornek olurdu (bu projede DOKUZ kez sahaya cikti).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/yenile.dart';
import 'isletme_kart.dart';
import 'isletme_servisi.dart';

class FavorilerimEkrani extends ConsumerStatefulWidget {
  const FavorilerimEkrani({super.key});

  @override
  ConsumerState<FavorilerimEkrani> createState() => _FavorilerimState();
}

class _FavorilerimState extends ConsumerState<FavorilerimEkrani> {
  List<IsletmeOzet>? _liste;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final l = await ref.read(isletmeServisiProvider).favorilerim();
      if (!mounted) return;
      setState(() {
        _liste = l;
        _hata = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _hata = 'Favoriler alınamadı');
    }
  }

  /// ⚠️ TURU 178 — **YEMEK EKRANIYLA AYNI HEADER** (kullanici emri:
  //	*"favorilerim sayfasi da yemek header gibi olsun"*).
  //	44 dp yukseklik · ortada baslik · solda `arrowLeft`.
  // ⚠️ `AppBar` KULLANILMIYOR: Material'in kendi `BackButton`u PLATFORMA
  //	gore degisir (Android ok / iOS chevron) ve baslik SOLA yaslidir;
  //	kullanicinin gordugu fark tam buydu.
  Widget _header(BuildContext context) => const SizedBox(
        height: 44,
        child: Stack(
          children: [
            Center(
              child: Text(
                'Favorilerim',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _GeriOku(),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    // ⚠️ TURU 178 — bu ekran YEMEK kategorisinin kalbinden aciliyor; o
    //    ekran siyah oldugu icin burasi da koyu (bkz. `koyuSayfa`).
    return koyuSayfa(Scaffold(
      // ⚠️ `YenileSarmali` + `AlwaysScrollableScrollPhysics`: bos listede de
      //    asagi-cek CALISMALI (turu 83b'de dort kardes ekranda ayni sinif
      //    duzeltilmisti).
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: YenileSarmali(
        onRefresh: _yukle,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_hata != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Text(_hata!, style: const TextStyle(color: Colors.grey)),
                    TextButton(
                        onPressed: _yukle, child: const Text('Tekrar dene')),
                  ],
                ),
              )
            else if (l == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (l.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  children: [
                    Icon(LucideIcons.heart, size: 34, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      'Henüz favorin yok.\n'
                      'Beğendiğin işletmenin kapağındaki kalbe dokun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              // ⚠️ Kart **ORTAK** (`isletme_kart.dart`): kategori ekraniyla
              //    ayni. Kopya cizilseydi puan/teslimat/kampanya bir ekranda
              //    guncellenip otekinde geride kalirdi.
              for (final o in l)
                IsletmeKarti(
                  o: o,
                  // ⚠️ Bu ekranda favoriden cikarilan kart LISTEDEN DUSER:
                  //    "Favorilerim"de favori olmayan bir satir birakmak
                  //    kullaniciyi "kaldirdim mi kalmadi mi" diye birakirdi.
                  favoriDegisti: (favori) {
                    if (!favori) setState(() => l.remove(o));
                  },
                ),
          ],
        ),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

/// ⚠️ Geri oku AYRI bir widget: header `const` olabilsin diye
///    (`Navigator.of` bir `BuildContext` ister, const agacta cagrilamaz).
class _GeriOku extends StatelessWidget {
  const _GeriOku();

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(LucideIcons.arrowLeft, size: 24),
        ),
      );
}
