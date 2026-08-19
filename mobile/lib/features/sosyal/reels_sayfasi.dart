import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chats/moderasyon_sheet.dart';
import '../home/home_screen.dart' show myProfileProvider;
import '../medya/medya_gorsel.dart';
import '../medya/medya_kapisi.dart';
import 'gonderi_karti.dart' show sayiBicimle;
import 'gonderi_olustur.dart';
import 'medya_video.dart';
import 'profil_sayfasi.dart';
import 'sosyal_servisi.dart';
import 'yorumlar_sayfasi.dart';

/// ⚠️⚠️ TURU 75 — REELS (dikey kaydirmali kisa video akisi).
///
/// ⚠️⚠️ TEK OYNATICI KURALI: `PageView` varsayilan olarak KOMSU sayfalari da
///    kurar. Her sayfada bir `MedyaVideo` olsaydi ayni anda 2-3 AVPlayer/ExoPlayer
///    ayakta olurdu — iOS'ta bu, paylasilan ses oturumu icin gercek bir risk
///    (bu projede process-global ses oturumu turu 64/65/73'te defalarca yakti)
///    ve Android'de gereksiz kod cozucu + veri harcamasi.
///    COZUM: `MedyaVideo` YALNIZ aktif sayfada olusturulur; komsularda KAPAK
///    gorseli cizilir. Kaydirma bitince (`onPageChanged`) oynatici tasinir.
/// ⚠️ YAPMA: her sayfaya kosulsuz `MedyaVideo` koyma.
///
/// ⚠️ SES: reels SESLI acilir (urun karari) AMA `MedyaVideo` icindeki kapi
///    arama/oda/yayin canliyken sesi ZORLA kapatir.
class ReelsSayfasi extends ConsumerStatefulWidget {
  const ReelsSayfasi({super.key});

  @override
  ConsumerState<ReelsSayfasi> createState() => _ReelsSayfasiState();
}

class _ReelsSayfasiState extends ConsumerState<ReelsSayfasi> {
  final _sayfa = PageController();
  final List<Gonderi> _liste = [];
  int _aktif = 0;
  bool _yukleniyor = true;
  bool _dahaVar = true;
  bool _sonrakiGeliyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _sayfa.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final l = await ref.read(sosyalServisiProvider).reels();
      if (!mounted) return;
      setState(() {
        _liste
          ..clear()
          ..addAll(l);
        _dahaVar = l.isNotEmpty;
        _yukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = 'Reels yüklenemedi';
      });
    }
  }

  Future<void> _dahaGetir() async {
    if (_sonrakiGeliyor || !_dahaVar || _liste.isEmpty) return;
    _sonrakiGeliyor = true;
    try {
      final l = await ref
          .read(sosyalServisiProvider)
          .reels(before: _liste.last.createdAt);
      if (!mounted) return;
      // ⚠️ TEKRAR SUZGECI (akis ekraniyla ayni sebep): imlec sinirinda ayni
      //    saniyeye dusen kayitlar iki sayfada da gelebilir.
      final mevcut = _liste.map((g) => g.id).toSet();
      setState(() {
        _liste.addAll(l.where((g) => !mevcut.contains(g.id)));
        _dahaVar = l.isNotEmpty;
      });
    } catch (_) {
      // Sessiz: kullanici kaydirmaya devam edebilir, sonraki denemede gelir.
    } finally {
      _sonrakiGeliyor = false;
    }
  }

  Future<void> _begeniCevir(Gonderi g) async {
    final eskiDurum = g.begendim;
    final eskiSayi = g.begeniSayisi;
    setState(() {
      g.begendim = !eskiDurum;
      g.begeniSayisi = (eskiSayi + (g.begendim ? 1 : -1)).clamp(0, 1 << 30);
    });
    unawaited(HapticFeedback.lightImpact());
    try {
      final s = ref.read(sosyalServisiProvider);
      g.begendim ? await s.begen(g.id) : await s.begeniGeriAl(g.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        g.begendim = eskiDurum;
        g.begeniSayisi = eskiSayi;
      });
    }
  }

  Future<void> _olustur() async {
    if (!MedyaKapisi.izinVer(ref)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            MedyaKapisi.engelSebebi(ref) ?? 'Şu anda video seçilemez',
          ),
        ),
      );
      return;
    }
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const GonderiOlustur(reels: true)),
    );
    if (id != null && mounted) unawaited(_yukle());
  }

  @override
  Widget build(BuildContext context) {
    final benimId = (ref.watch(myProfileProvider).valueOrNull?['id'] ?? '')
        .toString();
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Reels'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'Reels paylaş',
            onPressed: _olustur,
          ),
        ],
      ),
      body: _govde(benimId),
    );
  }

  Widget _govde(String benimId) {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hata != null && _liste.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_hata!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _yukle, child: const Text('Tekrar dene')),
          ],
        ),
      );
    }
    if (_liste.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.clapperboard,
                size: 54,
                color: Colors.white54,
              ),
              const SizedBox(height: 14),
              const Text(
                'Henüz reels yok.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _olustur,
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('İlk reels\'i sen paylaş'),
              ),
            ],
          ),
        ),
      );
    }

    return PageView.builder(
      controller: _sayfa,
      scrollDirection: Axis.vertical,
      itemCount: _liste.length,
      onPageChanged: (i) {
        setState(() => _aktif = i);
        // Son 3 sayfaya girince sonrakini getir.
        if (i >= _liste.length - 3) unawaited(_dahaGetir());
      },
      itemBuilder: (_, i) => _sayfaGovde(_liste[i], i == _aktif, benimId),
    );
  }

  Widget _sayfaGovde(Gonderi g, bool aktif, String benimId) {
    final medya = g.mediaIds.isEmpty ? null : g.mediaIds.first;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (medya == null)
          const ColoredBox(color: Colors.black)
        else if (aktif)
          // ⚠️ YALNIZ aktif sayfada gercek oynatici (tek oynatici kurali).
          MedyaVideo(
            key: ValueKey('reel-${g.id}'),
            mediaId: medya,
            otoOynat: true,
            dongu: true,
            sesli: true,
            dolgu: BoxFit.cover,
            kontrolGoster: false,
          )
        else
          MedyaGorsel(mediaId: medya, kucuk: true, fit: BoxFit.cover),

        // Cift dokunusla begen (video kontrolu kapali oldugu icin cakisma yok).
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap: () {
              if (!g.begendim) _begeniCevir(g);
            },
          ),
        ),

        // Alt bilgi + sag kolon
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xCC000000), Color(0x00000000)],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 40, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _yazarBloku(g)),
                    _sagKolon(g, benimId),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _yazarBloku(Gonderi g) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: g.yazarId)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(
              ad: g.yazarAd,
              mediaId: g.yazarAvatarMediaId,
              avatarUrl: g.yazarAvatar,
              cap: 34,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                g.yazarUsername.isEmpty ? g.yazarAd : '@${g.yazarUsername}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      if (g.metin.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          g.metin,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    ],
  );

  Widget _sagKolon(Gonderi g, String benimId) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _eylem(
        ikon: LucideIcons.heart,
        renk: g.begendim ? const Color(0xFFFF3B5C) : Colors.white,
        etiket: sayiBicimle(g.begeniSayisi),
        onTap: () => _begeniCevir(g),
      ),
      _eylem(
        ikon: LucideIcons.messageCircle,
        renk: Colors.white,
        etiket: sayiBicimle(g.yorumSayisi),
        onTap: g.yorumKapali
            ? null
            : () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        YorumlarSayfasi(gonderi: g, benimId: benimId),
                  ),
                );
                // ⚠️ TURU 75b: sayac PAYLASILAN model uzerinden guncellenir
                //    (bkz. yorumlar_sayfasi serhi) — deger DONMEZ.
                if (mounted) setState(() {});
              },
      ),
      if (g.goruntulenme > 0)
        _eylem(
          ikon: LucideIcons.eye,
          renk: Colors.white,
          etiket: sayiBicimle(g.goruntulenme),
          onTap: null,
        ),
      _eylem(
        ikon: LucideIcons.link,
        renk: Colors.white,
        etiket: '',
        onTap: () async {
          await Clipboard.setData(
            ClipboardData(text: 'https://gebzem.app/p/${g.id}'),
          );
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Bağlantı kopyalandı')));
        },
      ),
      if (g.yazarId != benimId)
        _eylem(
          ikon: LucideIcons.flag,
          renk: Colors.white,
          etiket: '',
          onTap: () =>
              sikayetSheetAc(context, ref, hedefTur: 'reels', hedefId: g.id),
        ),
    ],
  );

  Widget _eylem({
    required IconData ikon,
    required Color renk,
    required String etiket,
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
    child: GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, color: onTap == null ? Colors.white38 : renk, size: 28),
          if (etiket.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                etiket,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
        ],
      ),
    ),
  );
}
