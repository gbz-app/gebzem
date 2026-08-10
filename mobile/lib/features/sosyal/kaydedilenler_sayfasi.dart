import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import "../../core/yenile.dart";

import '../home/home_screen.dart' show myProfileProvider;
import 'gonderi_karti.dart';
import 'profil_sayfasi.dart';
import 'sosyal_servisi.dart';

/// ⚠️⚠️ TURU 75b — KAYDEDILENLER.
///
/// ⚠️ NEDEN EKLENDI: kaydetme bir "KARA DELIK"ti — yer imi dugmesi calisiyor,
///    `post_saves` satiri yaziliyor, ama kaydedileni GOSTEREN ne uc ne ekran
///    vardi. Kullanici bir gonderiyi kaydediyor ve bir daha BULAMIYORDU.
///    Bu projede ayni sinif iki kez yasandi (`deleted_for_all`, `blocks`:
///    veri yaziliyor, okuyan yok).
/// ⚠️ YAPMA: kaydetme dugmesini listeleme yolu olmadan birakma.
///
/// ⚠️ Sunucu erisimi YENIDEN degerlendirir: kaydettikten sonra yazar gizli
///    hesaba gecmis ya da seni engellemis olabilir — o gonderiler listede
///    GORUNMEZ. Yani listenin sayisi kaydettiginden AZ olabilir; bu DOGRU
///    davranistir, hata degil.
class KaydedilenlerSayfasi extends ConsumerStatefulWidget {
  const KaydedilenlerSayfasi({super.key});

  @override
  ConsumerState<KaydedilenlerSayfasi> createState() =>
      _KaydedilenlerSayfasiState();
}

class _KaydedilenlerSayfasiState extends ConsumerState<KaydedilenlerSayfasi> {
  final List<Gonderi> _liste = [];
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final l = await ref.read(sosyalServisiProvider).kaydedilenler();
      if (!mounted) return;
      setState(() {
        _liste
          ..clear()
          ..addAll(l);
        _yukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = 'Kaydedilenler yüklenemedi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final benimId = (ref.watch(myProfileProvider).valueOrNull?['id'] ?? '')
        .toString();
    return Scaffold(
      appBar: AppBar(title: const Text('Kaydedilenler')),
      body: YenileSarmali(
        onRefresh: _yukle,
        // TURU 82b - spinner YALNIZ VERI YOKKEN. Ciplak `_yukleniyor` her
        //    YENILEMEDE govdeyi spinner ile degistiriyordu: icerik yanip
        //    sonuyor, kaydirma konumu sifirlaniyor ve acik temada BEYAZ bir
        //    kare gorunuyordu (profil sayfasindaki "ekran beyaz patliyor"
        //    hatasinin daha hafif hali - ayni sinif, dort ekranda birden).
        // YAPMA: kosulu tekrar ciplak `_yukleniyor`a dondurme.
        child: _yukleniyor && _liste.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _hata != null
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(_hata!)),
                  const SizedBox(height: 10),
                  Center(
                    child: OutlinedButton(
                      onPressed: _yukle,
                      child: const Text('Tekrar dene'),
                    ),
                  ),
                ],
              )
            : _liste.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 140),
                  Icon(LucideIcons.bookmark, size: 46, color: Colors.grey),
                  SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Henüz kaydettiğin gönderi yok.\n'
                      'Beğendiğin gönderilerdeki yer imi simgesine dokun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                itemCount: _liste.length,
                itemBuilder: (_, i) {
                  final g = _liste[i];
                  return GonderiKarti(
                    key: ValueKey(g.id),
                    gonderi: g,
                    benimId: benimId,
                    profileGit: (uid) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfilSayfasi(userId: uid),
                      ),
                    ),
                    onSilindi: () =>
                        setState(() => _liste.removeWhere((x) => x.id == g.id)),
                  );
                },
              ),
      ),
    );
  }
}
