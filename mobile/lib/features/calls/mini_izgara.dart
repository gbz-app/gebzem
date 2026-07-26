import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

/// KUCUK PENCERE IZGARASI (test turu 17 — kullanici istegi: "alta indirdigimizde izgara
/// olsun: 2 kisi sol/sag, 3 kisi ustte 2 + altta 1, 4 kisi 4 bolum").
/// Sistem PiP penceresi VE uygulama-ici yuzen pencere bunu kullanir; 1:1 arama, grup
/// aramasi ve canli yayin ORTAK.
///
/// Buyuk izgaradan (yayinIzgara) FARKI: kucuk pencerede bosluk birakmak yerine kutular
/// alani TAMAMEN doldurur (en-boy korunmaz, goruntu `cover` ile kirpilir) — pencere zaten
/// kucuk, ortada bosluk kalmasi kotu duruyordu.
/// En fazla 4 kutu cizilir; kalanlar sag-altta "+N" rozetiyle belirtilir.
Widget miniIzgara(List<Widget> kutular) {
  final hepsi = kutular.length;
  if (hepsi == 0) return const SizedBox.shrink();
  final n = hepsi > 4 ? 4 : hepsi;
  const bosluk = 2.0;

  Widget satir(List<Widget> ogeler) => Row(children: [
        for (var i = 0; i < ogeler.length; i++) ...[
          if (i > 0) const SizedBox(width: bosluk),
          Expanded(child: ogeler[i]),
        ],
      ]);

  Widget icerik;
  if (n == 1) {
    icerik = kutular[0];
  } else if (n == 2) {
    // 2 kisi: UST - ALT (test turu 24 kullanici istegi — kucuk pencere dar oldugu icin
    // yan yana iki dikey goruntu cok kirpiliyordu; ust/alt daha dogru gorunuyor).
    icerik = Column(children: [
      Expanded(child: kutular[0]),
      const SizedBox(height: bosluk),
      Expanded(child: kutular[1]),
    ]);
  } else if (n == 3) {
    // 3 kisi: ustte 2 yan yana, ALTTA 1 TAM GENISLIK
    icerik = Column(children: [
      Expanded(child: satir([kutular[0], kutular[1]])),
      const SizedBox(height: bosluk),
      Expanded(child: kutular[2]),
    ]);
  } else {
    // 4 kisi: 2x2 CEYREK (sol-ust, sag-ust, sol-alt, sag-alt)
    icerik = Column(children: [
      Expanded(child: satir([kutular[0], kutular[1]])),
      const SizedBox(height: bosluk),
      Expanded(child: satir([kutular[2], kutular[3]])),
    ]);
  }
  if (hepsi <= 4) return icerik;
  return Stack(children: [
    Positioned.fill(child: icerik),
    Positioned(
      right: 4,
      bottom: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.black54, borderRadius: BorderRadius.circular(8)),
        child: Text('+${hepsi - 4}',
            style: const TextStyle(color: Colors.white, fontSize: 11)),
      ),
    ),
  ]);
}

/// Kucuk pencere kutusu: video VARSA render, yoksa harf avatari (kamera kapali / sesli).
class MiniKutu extends StatelessWidget {
  const MiniKutu({
    super.key,
    this.track,
    this.harf = '?',
    this.mirror = false,
  });

  final lk.VideoTrack? track;
  final String harf;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final t = track;
    if (t != null) {
      return IgnorePointer(
        child: lk.VideoTrackRenderer(t,
            key: ValueKey('mini-${t.mediaStreamTrack.id}'),
            fit: lk.VideoViewFit.cover,
            mirrorMode: mirror
                ? lk.VideoViewMirrorMode.mirror
                : lk.VideoViewMirrorMode.off),
      );
    }
    return Container(
      color: const Color(0xFF16202A),
      alignment: Alignment.center,
      child: CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFF6C2BD9),
        child: Text(harf.isEmpty ? '?' : harf[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
    );
  }
}
