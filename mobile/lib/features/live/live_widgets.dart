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

/// FAZ-5 KONUK SPLIT (kullanici istegi: "grup gorusmesi gibi"): tek video paneli.
/// Renderer IgnorePointer ICINDE (CameraUtils NPE kurali); etiket/ustKatman Stack'te
/// renderer'in USTUNDE, IgnorePointer'in DISINDA (butonlar calisir).
class SplitVideoPaneli extends StatelessWidget {
  const SplitVideoPaneli({
    super.key,
    this.track,
    this.mirrorMode = lk.VideoViewMirrorMode.auto,
    this.etiket = '',
    this.ustKatman,
    this.bosMetin = 'Görüntü bekleniyor...',
  });

  final lk.VideoTrack? track;
  final lk.VideoViewMirrorMode mirrorMode;
  final String etiket;
  final Widget? ustKatman; // Positioned bekler (pill / x butonu)
  final String bosMetin;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(fit: StackFit.expand, children: [
        if (track != null)
          IgnorePointer(
            child: lk.VideoTrackRenderer(track!,
                key: ValueKey('split-${track!.mediaStreamTrack.id}'),
                fit: lk.VideoViewFit.cover,
                mirrorMode: mirrorMode),
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
      ]),
    );
  }
}

/// Dikey split alani: ust + alt iki ESIT panel (TikTok konuk duzeni), 4px bosluk.
Widget yayinSplitAlani({required Widget ust, required Widget alt}) {
  return Column(children: [
    Expanded(child: ust),
    const SizedBox(height: 4),
    Expanded(child: alt),
  ]);
}
