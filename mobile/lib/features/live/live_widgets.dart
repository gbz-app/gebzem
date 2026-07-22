import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

/// SendData sinyalini coz (topic 'meta'; govde JSON {"t": ...}). Bozuksa null.
Map<String, dynamic>? yayinVerisiCoz(List<int> data) {
  try {
    final m = jsonDecode(utf8.decode(data));
    return m is Map<String, dynamic> ? m : null;
  } catch (_) {
    return null;
  }
}

class ChatMesaj {
  ChatMesaj({required this.kimden, required this.metin, this.vurgulu = false});
  final String kimden;
  final String metin;
  final bool vurgulu; // hediye/sistem mesaji (renkli)
}

/// TikTok tarzi yari saydam chat seridi (altta, son ~40 mesaj).
/// [yukseklik]: klavye acikken kucultulur (RenderFlex tasmasi bulgusu).
class ChatSeridi extends StatelessWidget {
  const ChatSeridi({super.key, required this.mesajlar, this.yukseklik = 180});
  final List<ChatMesaj> mesajlar;
  final double yukseklik;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: yukseklik,
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
          stops: [0, .25],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          reverse: true, // en yeni altta, otomatik oraya kayar
          padding: EdgeInsets.zero,
          itemCount: mesajlar.length,
          itemBuilder: (context, i) {
            final m = mesajlar[mesajlar.length - 1 - i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: m.vurgulu ? const Color(0xAA6C2BD9) : Colors.black38,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      children: [
                        TextSpan(
                            text: '${m.kimden}  ',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: m.vurgulu ? Colors.amberAccent : const Color(0xFFB79CFF))),
                        TextSpan(text: m.metin),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Sag alttan yukselen kalp animasyonlari. [patlat] ile n kalp eklenir; her kalp kendi
/// TweenAnimationBuilder'iyla ucar ve bitince listeden duser (ekstra paket yok).
class KalpKatmani extends StatefulWidget {
  const KalpKatmani({super.key});

  @override
  State<KalpKatmani> createState() => KalpKatmaniState();
}

class KalpKatmaniState extends State<KalpKatmani> {
  final _rnd = Random(7);
  final List<int> _kalpler = [];
  int _sayac = 0;

  void patlat(int n) {
    if (!mounted) return;
    setState(() {
      // Ekrani bogmamak icin tek seferde en fazla 12 kalp ciz (300 izleyicili yayinda
      // 5 sn'lik toplu sayi buyuk olabilir)
      for (var i = 0; i < n.clamp(1, 12); i++) {
        _kalpler.add(_sayac++);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(children: [
        for (final id in _kalpler)
          _UcanKalp(
            key: ValueKey(id),
            dx: 20 + _rnd.nextDouble() * 60,
            gecikmeMs: (id % 6) * 120,
            bitti: () => setState(() => _kalpler.remove(id)),
          ),
      ]),
    );
  }
}

class _UcanKalp extends StatelessWidget {
  const _UcanKalp({super.key, required this.dx, required this.gecikmeMs, required this.bitti});
  final double dx;
  final int gecikmeMs;
  final VoidCallback bitti;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 1800 + gecikmeMs),
      onEnd: bitti,
      builder: (context, t, _) {
        final yukseklik = t * 320;
        final salinim = sin(t * pi * 3) * 14;
        return Positioned(
          right: dx + salinim,
          bottom: 96 + yukseklik,
          child: Opacity(
            opacity: (1 - t).clamp(0, 1),
            child: Transform.scale(
              scale: .7 + t * .5,
              child: const Text('💜', style: TextStyle(fontSize: 26)),
            ),
          ),
        );
      },
    );
  }
}

/// Buyuk hediye animasyonu (ekran ortasinda belirip buyuyerek kaybolur)
class HediyePatlamasi extends StatelessWidget {
  const HediyePatlamasi({super.key, required this.emoji, required this.bitti});
  final String emoji;
  final VoidCallback bitti;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1600),
          onEnd: bitti,
          builder: (context, t, _) => Opacity(
            opacity: t < .8 ? 1 : (1 - (t - .8) / .2),
            child: Transform.scale(
              scale: .5 + t * 1.8,
              child: Text(emoji, style: const TextStyle(fontSize: 96)),
            ),
          ),
        ),
      ),
    );
  }
}

/// KONUK/YAYINCI TILE (test turu 11 COKLU-KONUK): tek video VEYA avatar (sesli konuk /
/// kamera kapali). SEAMLESS — beyaz/cerceve border YOK (kullanici istegi). Renderer
/// IgnorePointer ICINDE (CameraUtils NPE kurali); etiket/ustKatman renderer USTUNDE.
class SplitVideoPaneli extends StatelessWidget {
  const SplitVideoPaneli({
    super.key,
    this.track,
    this.mirrorMode = lk.VideoViewMirrorMode.auto,
    this.etiket = '',
    this.ustKatman,
    this.bosMetin = 'Görüntü bekleniyor...',
    this.avatarHarf = '', // dolu ise track yokken avatar goster (sesli konuk)
  });

  final lk.VideoTrack? track;
  final lk.VideoViewMirrorMode mirrorMode;
  final String etiket;
  final Widget? ustKatman; // Positioned bekler (pill / x butonu)
  final String bosMetin;
  final String avatarHarf;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      if (track != null)
        IgnorePointer(
          child: lk.VideoTrackRenderer(track!,
              key: ValueKey('split-${track!.mediaStreamTrack.id}'),
              fit: lk.VideoViewFit.cover,
              mirrorMode: mirrorMode),
        )
      else if (avatarHarf.isNotEmpty)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A0B2E), Color(0xFF16202A)],
            ),
          ),
          alignment: Alignment.center,
          child: CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF6C2BD9),
            child: Text(avatarHarf.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 26)),
          ),
        )
      else
        Container(
          color: const Color(0xFF16202A),
          alignment: Alignment.center,
          child: Text(bosMetin, style: const TextStyle(color: Colors.white54)),
        ),
      if (etiket.isNotEmpty)
        Positioned(
          left: 8,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: Colors.black45, borderRadius: BorderRadius.circular(8)),
            child: Text(etiket,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),
      if (ustKatman != null) ustKatman!,
    ]);
  }
}

/// COKLU-KONUK IZGARA (test turu 11): N tile ekrani DOLDURUR. 2 kisi -> YAN YANA (sol-sag,
/// kullanici istegi "ust alt degil sol sag"); 3-4 -> 2 sutun grid; 5-6 -> son satir tam
/// genislik. Beyaz/cerceve border YOK (seamless). n==1 -> tek tile tam ekran.
Widget yayinIzgara(List<Widget> tiles) {
  final n = tiles.length;
  if (n == 0) return const SizedBox.shrink();
  if (n == 1) return tiles.first;
  final cols = n == 2 ? 2 : (n <= 6 ? 2 : 3);
  final rows = (n + cols - 1) ~/ cols;
  return Column(children: [
    for (var r = 0; r < rows; r++)
      Expanded(
        child: Row(children: [
          // Son satirda daha az tile varsa mevcutlar tam genisligi paylasir (bosluk yok)
          for (var i = r * cols; i < min(r * cols + cols, n); i++)
            Expanded(child: tiles[i]),
        ]),
      ),
  ]);
}
