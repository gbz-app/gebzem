import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

/// "BEKLEMEDE" KATMANI (test turu 21 — WhatsApp deneyimi).
///
/// Karsi taraf uygulamayi arka plana alir / kapatir / aramayi beklemeye alirsa video track'i
/// MUTE olur ama SON KARE renderer'da kalir. WhatsApp bu kareyi BULANIKLASTIRIP uzerine
/// "Beklemede" yazar — siyah ekran ya da avatar yerine "donmus ama bilincli" bir gorunum.
/// Biz de aynisini yapiyoruz: video + BackdropFilter(blur) + etiket.
///
/// [track] null ise (hic video yok / abonelik yok) avatar yedegi cizilir.
class BeklemedeKatmani extends StatelessWidget {
  const BeklemedeKatmani({
    super.key,
    required this.track,
    this.harf = '?',
    this.etiket = 'Beklemede',
    this.bulaniklik = 12,
  });

  final lk.VideoTrack? track;
  final String harf;
  final String etiket;
  final double bulaniklik;

  @override
  Widget build(BuildContext context) {
    final t = track;
    return Stack(fit: StackFit.expand, children: [
      if (t != null)
        IgnorePointer(
          // Son kare burada kalir (mute'ta yeni kare gelmez) -> blur ile yumusatilir
          child: lk.VideoTrackRenderer(t,
              key: ValueKey('beklet-${t.mediaStreamTrack.id}'),
              fit: lk.VideoViewFit.cover),
        )
      else
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A0B2E), Color(0xFF0B141A)],
            ),
          ),
          alignment: Alignment.center,
          child: CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF6C2BD9),
            child: Text(harf.isEmpty ? '?' : harf[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 26)),
          ),
        ),
      // BULANIKLIK + hafif karartma (WhatsApp gorunumu)
      Positioned.fill(
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: bulaniklik, sigmaY: bulaniklik),
            child: Container(color: Colors.black.withValues(alpha: 0.25)),
          ),
        ),
      ),
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14)),
          child: Text(etiket,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }
}
