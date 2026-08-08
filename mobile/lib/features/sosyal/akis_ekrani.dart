import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../home/home_screen.dart' show myProfileProvider;
import 'bildirimler_sayfasi.dart';
import 'gonderi_karti.dart';
import 'gonderi_olustur.dart';
import 'profil_sayfasi.dart';
import 'reels_sayfasi.dart';
import 'sosyal_servisi.dart';

/// ⚠️⚠️ TURU 75 — ANA SAYFA AKISI (Instagram/Facebook duzeni).
///
/// ⚠️ SAYFALAMA IMLECLI (cursor): son gonderinin `created_at`i `before` olarak
///    gonderilir. `offset` KULLANILMAZ — yeni gonderi gelince satirlar kayar ve
///    ayni gonderi iki kez gorunur.
///
/// ⚠️ SOGUK BASLANGIC: kimseyi takip etmeyen kullaniciya BOS EKRAN gosterilmez;
///    sunucu "kesfet" (herkese acik yeni gonderiler) doner ve ustte serit cikar.
///    Bos akis yeni kullanicinin urunu terk etme sebebidir.
class AkisEkrani extends ConsumerStatefulWidget {
  const AkisEkrani({super.key});

  @override
  ConsumerState<AkisEkrani> createState() => _AkisEkraniState();
}

class _AkisEkraniState extends ConsumerState<AkisEkrani>
    with AutomaticKeepAliveClientMixin {
  final _kaydirma = ScrollController();
  final List<Gonderi> _liste = [];
  bool _ilkYukleme = true;
  bool _dahaVar = true;
  bool _yukleniyor = false;
  bool _kesfet = false;
  String? _hata;

  /// ⚠️ IndexedStack icinde oldugumuz icin sekme degisince state KORUNUR; ama
  ///    `AutomaticKeepAlive` olmadan ListView kaydirma konumu kaybolabiliyor.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _kaydirma.addListener(_kaydirmaDinle);
    _yenile();
  }

  @override
  void dispose() {
    _kaydirma.dispose();
    super.dispose();
  }

  void _kaydirmaDinle() {
    if (!_kaydirma.hasClients) return;
    final kalan = _kaydirma.position.maxScrollExtent - _kaydirma.position.pixels;
    // 800px kala sonrakini getir — kullanici "yukleniyor" gormeden akmali.
    if (kalan < 800) _dahaGetir();
  }

  Future<void> _yenile() async {
    if (_yukleniyor) return;
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final s = await ref.read(sosyalServisiProvider).akis();
      if (!mounted) return;
      setState(() {
        _liste
          ..clear()
          ..addAll(s.gonderiler);
        _kesfet = s.kesfet;
        _dahaVar = s.gonderiler.isNotEmpty;
        _ilkYukleme = false;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ilkYukleme = false;
        _yukleniyor = false;
        _hata = 'Akış yüklenemedi';
      });
    }
  }

  Future<void> _dahaGetir() async {
    if (_yukleniyor || !_dahaVar || _liste.isEmpty) return;
    setState(() => _yukleniyor = true);
    try {
      final s = await ref
          .read(sosyalServisiProvider)
          .akis(before: _liste.last.createdAt);
      if (!mounted) return;
      setState(() {
        // ⚠️ TEKRAR SUZGECI: imlec sinirinda ayni saniyede olusmus gonderiler
        //    hem onceki hem yeni sayfada gelebilir. Id'ye gore eliyoruz —
        //    yoksa listede CIFT KART cizilir (ve `Key` cakismasi patlatir).
        final mevcut = _liste.map((g) => g.id).toSet();
        final yeni = s.gonderiler.where((g) => !mevcut.contains(g.id)).toList();
        _liste.addAll(yeni);
        _dahaVar = s.gonderiler.isNotEmpty;
        _yukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
    }
  }

  void _profileGit(String userId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProfilSayfasi(userId: userId),
    ));
  }

  Future<void> _olustur({bool reels = false}) async {
    final id = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => GonderiOlustur(reels: reels),
    ));
    // Paylasildiysa akisi bastan getir — kendi gonderini EN USTTE gormelisin.
    if (id != null && mounted) {
      unawaited(_yenile());
      // Profil sayaci (`gonderi_sayisi`) degisti.
      ref.invalidate(myProfileProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final benimId =
        (ref.watch(myProfileProvider).valueOrNull?['id'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gebzem'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.clapperboard),
            tooltip: 'Reels',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ReelsSayfasi(),
            )),
          ),
          IconButton(
            icon: const Icon(LucideIcons.bell),
            tooltip: 'Bildirimler',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const BildirimlerSayfasi(),
            )),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _olustur,
        child: const Icon(LucideIcons.plus),
      ),
      body: RefreshIndicator(
        onRefresh: _yenile,
        child: _govde(benimId),
      ),
    );
  }

  Widget _govde(String benimId) {
    if (_ilkYukleme) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hata != null && _liste.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(_hata!)),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
                onPressed: _yenile, child: const Text('Tekrar dene')),
          ),
        ],
      );
    }
    if (_liste.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Icon(LucideIcons.images, size: 54, color: Colors.grey),
          SizedBox(height: 14),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Henüz gönderi yok.\nİlk paylaşımı sen yap ya da birilerini takip et.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _kaydirma,
      // +1 = alt yukleme gostergesi / +1 = kesfet seridi
      itemCount: _liste.length + (_kesfet ? 1 : 0) + 1,
      itemBuilder: (_, i) {
        var idx = i;
        if (_kesfet) {
          if (i == 0) return _kesfetSeridi();
          idx = i - 1;
        }
        if (idx >= _liste.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: _dahaVar
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Hepsi bu kadar',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          );
        }
        final g = _liste[idx];
        return GonderiKarti(
          // ⚠️ ANAHTAR ZORUNLU: anahtarsiz, liste yenilenince Flutter kart
          //    state'ini (begeni animasyonu, sayfa indeksi) YANLIS karta tasir.
          key: ValueKey(g.id),
          gonderi: g,
          benimId: benimId,
          profileGit: _profileGit,
          onSilindi: () => setState(() => _liste.removeWhere((x) => x.id == g.id)),
        );
      },
    );
  }

  Widget _kesfetSeridi() => Container(
        width: double.infinity,
        color: const Color(0x228B5CF6),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: const Row(
          children: [
            Icon(LucideIcons.compass, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Keşfet — kimseyi takip etmiyorsun. Beğendiğin kişileri takip et, akışın kişiselleşsin.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
}
