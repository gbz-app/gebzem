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

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return Scaffold(
      appBar: AppBar(title: const Text('Favorilerim')),
      // ⚠️ `YenileSarmali` + `AlwaysScrollableScrollPhysics`: bos listede de
      //    asagi-cek CALISMALI (turu 83b'de dort kardes ekranda ayni sinif
      //    duzeltilmisti).
      body: YenileSarmali(
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
    );
  }
}
