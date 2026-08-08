import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/home_screen.dart' show myProfileProvider;
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
    if (_g == null) _cek();
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
      appBar: AppBar(title: const Text('Gönderi')),
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
                  profileGit: (uid) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfilSayfasi(userId: uid),
                    ),
                  ),
                  // Silinince bu sayfada kalacak bir sey yok.
                  onSilindi: () => Navigator.of(context).pop(),
                ),
              ],
            ),
    );
  }
}
