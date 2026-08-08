import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../medya/medya_gorsel.dart';
import 'profil_sayfasi.dart';
import 'sosyal_servisi.dart';

/// ⚠️⚠️ TURU 75 — TAKIPCILER / TAKIP EDILENLER LISTESI.
///
/// ⚠️ SAYFALAMA `offset` ILE (backend boyle): bu listeler kronolojik DEGIL,
///    `follows.created_at DESC` ile sabit siralidir ve akis kadar hizli
///    degismez — offset burada guvenli.
class TakipListesi extends ConsumerStatefulWidget {
  const TakipListesi({
    super.key,
    required this.userId,
    required this.tur, // followers | following
    required this.baslik,
  });

  final String userId;
  final String tur;
  final String baslik;

  @override
  ConsumerState<TakipListesi> createState() => _TakipListesiState();
}

class _TakipListesiState extends ConsumerState<TakipListesi> {
  List<Map<String, dynamic>> _liste = [];
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
      final l = await ref
          .read(sosyalServisiProvider)
          .takipListesi(widget.userId, widget.tur);
      if (!mounted) return;
      setState(() {
        _liste = l;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        // ⚠️ 403 = gizli hesap. Genel "yuklenemedi" demek kullaniciyi yaniltir
        //    (tekrar tekrar dener, hicbir zaman gelmez).
        _hata = e.toString().contains('403')
            ? 'Bu hesap gizli — listeyi göremezsin'
            : 'Liste yüklenemedi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.baslik)),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _hata != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.lock,
                          size: 34, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text(_hata!, textAlign: TextAlign.center),
                    ],
                  ),
                )
              : _liste.isEmpty
                  ? const Center(
                      child: Text('Liste boş',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _liste.length,
                      itemBuilder: (_, i) {
                        final u = _liste[i];
                        final ad = (u['name'] ?? '').toString();
                        final kul = (u['username'] ?? '').toString();
                        return ListTile(
                          leading: Avatar(
                            ad: ad,
                            mediaId: u['avatar_media_id'] as String?,
                            avatarUrl: (u['avatar_url'] ?? '').toString(),
                            cap: 42,
                          ),
                          title: Text(ad),
                          subtitle: kul.isEmpty ? null : Text('@$kul'),
                          onTap: () =>
                              Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                ProfilSayfasi(userId: (u['id'] ?? '').toString()),
                          )),
                        );
                      },
                    ),
    );
  }
}

/// Bekleyen takip istekleri (yalniz GIZLI hesap sahibi gorur).
class TakipIstekleri extends ConsumerStatefulWidget {
  const TakipIstekleri({super.key});

  @override
  ConsumerState<TakipIstekleri> createState() => _TakipIstekleriState();
}

class _TakipIstekleriState extends ConsumerState<TakipIstekleri> {
  List<Map<String, dynamic>> _liste = [];
  bool _yukleniyor = true;

  /// ⚠️ Islenen id'ler: onay/red REST'i ucarken ayni satira tekrar basilmasin.
  final _mesgul = <String>{};

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final l = await ref.read(sosyalServisiProvider).takipIstekleri();
      if (!mounted) return;
      setState(() {
        _liste = l;
        _yukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _karar(String userId, bool onay) async {
    if (!_mesgul.add(userId)) return;
    setState(() {});
    try {
      final s = ref.read(sosyalServisiProvider);
      onay ? await s.istekOnayla(userId) : await s.istekReddet(userId);
      if (!mounted) return;
      setState(() => _liste.removeWhere((u) => (u['id'] ?? '') == userId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('İşlem tamamlanamadı')));
    } finally {
      _mesgul.remove(userId);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Takip istekleri')),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _liste.isEmpty
              ? const Center(
                  child: Text('Bekleyen istek yok',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _liste.length,
                  itemBuilder: (_, i) {
                    final u = _liste[i];
                    final id = (u['id'] ?? '').toString();
                    final calisiyor = _mesgul.contains(id);
                    return ListTile(
                      leading: Avatar(
                        ad: (u['name'] ?? '').toString(),
                        mediaId: u['avatar_media_id'] as String?,
                        avatarUrl: (u['avatar_url'] ?? '').toString(),
                        cap: 42,
                      ),
                      title: Text((u['name'] ?? '').toString()),
                      subtitle: Text('@${u['username'] ?? ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(LucideIcons.check,
                                color: Color(0xFF4CAF50)),
                            onPressed:
                                calisiyor ? null : () => _karar(id, true),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.x, color: Colors.red),
                            onPressed:
                                calisiyor ? null : () => _karar(id, false),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
