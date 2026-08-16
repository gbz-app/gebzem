import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/home_screen.dart' show myProfileProvider;
import 'demo_veri.dart' show kDemoAkis;
import 'demo_yorum.dart';
import 'gonderi_karti.dart';
import 'profil_sayfasi.dart';
import 'sosyal_servisi.dart';

/// ⚠️⚠️ TURU 75 — TEK GONDERI SAYFASI.
///
/// IKI GIRIS YOLU:
///   · `gonderi` HAZIR verilir (profil izgarasindan gelinir) — ANINDA cizilir.
///   · `gonderiId` verilir (bildirimden/derin baglantidan gelinir) — sunucudan cekilir.
///
/// ⚠️ IKISINDEN BIRI ZORUNLU; assert ile derleme zamanina yakin yakalanir.
///    Aksi halde bos ekran acilir ve sebebi belli olmaz.
class GonderiDetay extends ConsumerStatefulWidget {
  const GonderiDetay({super.key, this.gonderi, this.gonderiId})
    : assert(
        gonderi != null || gonderiId != null,
        'gonderi ya da gonderiId verilmeli',
      );

  final Gonderi? gonderi;
  final String? gonderiId;

  @override
  ConsumerState<GonderiDetay> createState() => _GonderiDetayState();
}

class _GonderiDetayState extends ConsumerState<GonderiDetay> {
  Gonderi? _g;
  bool _yukleniyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _g = widget.gonderi;
    if (_g == null) {
      _cek();
    } else {
      // ⚠️⚠️ TURU 76 (DENETIM BULGUSU) — GORUNTULENME HIC ARTMIYORDU.
      //    Sunucu sayaci YALNIZ `GET /posts/{id}` icinde artiriyor. Bu ekran
      //    hazir bir `Gonderi` NESNESIYLE acildiginda (profil izgarasi, kesfet
      //    izgarasi, kaydedilenler — yani GERCEK giris yollarinin COGU) o istek
      //    HIC ATILMIYORDU. Sonuc: kullanicinin ozellikle istedigi
      //    "goruntulenme sayisi" istatistigi pratikte HEP 0 kalirdi.
      // ⚠️ SESSIZ tazeleme: spinner YOK, hata ekrani YOK — elimizde zaten
      //    cizilecek gonderi var; ag hatasi kullaniciya BOS EKRAN gostermemeli.
      unawaited(_sessizTazele());
    }
  }

  /// Sunucudan taze sayilari alir (ve GORUNTULENMEYI artirir).
  ///
  /// ⚠️ `_g` NESNESI DEGISTIRILMEZ, ALANLARI GUNCELLENIR: model akis/izgara ile
  ///    PAYLASILIYOR (bu dosyanin ve kartin dayandigi desen). Yeni nesne
  ///    atasaydik detayda yapilan begeni, geri donuldugunde izgarada gorunmezdi.
  Future<void> _sessizTazele() async {
    try {
      final taze = await ref
          .read(sosyalServisiProvider)
          .gonderiGetir(widget.gonderi!.id);
      if (!mounted) return;
      final g = _g;
      if (g == null) return;
      setState(() {
        g.begeniSayisi = taze.begeniSayisi;
        g.yorumSayisi = taze.yorumSayisi;
        g.begendim = taze.begendim;
        g.kaydettim = taze.kaydettim;
        g.metin = taze.metin;
        g.yorumKapali = taze.yorumKapali;
        g.duzenlendi = taze.duzenlendi;
      });
    } catch (_) {
      // sessiz — ekranda zaten gecerli bir gonderi var
    }
  }

  Future<void> _cek() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final g = await ref
          .read(sosyalServisiProvider)
          .gonderiGetir(widget.gonderiId!);
      if (!mounted) return;
      setState(() {
        _g = g;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      setState(() {
        _yukleniyor = false;
        _hata = s.contains('403')
            ? 'Bu hesap gizli'
            : s.contains('404')
            ? 'Gönderi bulunamadı ya da kaldırıldı'
            : 'Gönderi açılamadı';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final benimId = (ref.watch(myProfileProvider).valueOrNull?['id'] ?? '')
        .toString();
    final g = _g;
    return Scaffold(
      // ⚠️⚠️⚠️ TURU 98i — THREADS DUZENI (kullanici ekran goruntusu):
      //	baslik **Yazışma**, altinda goruntulenme sayisi; sagda bildirim
      //	ve ••• dugmeleri.
      // ⚠️ Goruntulenme YALNIZ demoda yazilir; gercek gonderide sunucudan
      //    gelen goruntulenme alani kullanilir ve 0 ise HIC yazilmaz
      //    (uydurma sayi YOK).
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Yazışma', style: TextStyle(fontSize: 17)),
            if ((g?.goruntulenme ?? 0) > 0)
              Text(
                '${sayiBicimle(g!.goruntulenme)} görüntüleme',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
          ],
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : g == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_hata ?? 'Gönderi açılamadı'),
                  if (widget.gonderiId != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _cek,
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ],
              ),
            )
          : ListView(
              children: [
                GonderiKarti(
                  key: ValueKey(g.id),
                  gonderi: g,
                  benimId: benimId,
                  detayda: true,
                  profileGit: (uid) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfilSayfasi(userId: uid),
                    ),
                  ),
                  // Silinince bu sayfada kalacak bir sey yok.
                  onSilindi: () => Navigator.of(context).pop(),
                ),
                // ⚠️⚠️ TURU 98i — YORUM BOLUMU (Threads duzeni, kullanici
                //	ekran goruntusu): ayrac satiri + threadli yorumlar.
                // ⚠️ YALNIZ DEMODA: gercek yorum hatti YorumlarSayfasinda
                //    duruyor ve DEGISMEDI.
                if (kDemoAkis) ...[
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Row(
                      children: [
                        const Text(
                          'Başlıca',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Icon(LucideIcons.chevronDown, size: 16),
                        const Spacer(),
                        Text(
                          'Hareketi gör',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ],
                    ),
                  ),
                  for (final y in demoYorumlar(g.id)) ...[
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.06),
                    ),
                    DemoYorumSatiri(y: y, cizgi: y.yanitlar.isNotEmpty),
                    for (final alt in y.yanitlar)
                      DemoYorumSatiri(y: alt, girinti: 30),
                  ],
                  const SizedBox(height: 24),
                ],
              ],
            ),
    );
  }
}
