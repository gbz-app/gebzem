import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'active_call_controller.dart';

/// AKTIF ARAMA — minimize edilmis aramada TUM sayfalarin ustunde gorunur.
/// TEST TURU 10: SESLI aramada eski yesil bant; GORUNTULU aramada SURUKLENEBILIR YUZEN
/// VIDEO penceresi (WhatsApp mini oynatici): karsi tarafin videosu + dokun-don + mic/kapat
/// butonlari. Uygulama-ici gezinmede karsi taraf gorunur, cökme yok (uzak track guard'li;
/// arama bitince arama==null -> render durur). Sistem PiP'e (iOS Dusuk Guc Modu/ayar) BAGIMLI
/// DEGIL — %100 Flutter kontrolunde.
/// MaterialApp.builder icinde yasar => Navigator DISINDA: Navigator.of(context) YASAK
/// (restore/leave controller ustunden; rootNavigatorKey).
class AktifAramaBanner extends ConsumerStatefulWidget {
  const AktifAramaBanner({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AktifAramaBanner> createState() => _AktifAramaBannerState();
}

class _AktifAramaBannerState extends ConsumerState<AktifAramaBanner> {
  // Yuzen pencere konumu (null = ilk cizimde sag-uste yerlesir). Surukleyince guncellenir.
  Offset? _pos;
  static const double _w = 116;
  static const double _h = 168;

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(activeCallProvider);
    final b = c.arama;
    if (b == null || !c.minimized) return widget.child;

    final ad = c.isGroup
        ? (b.chatTitle.isEmpty ? 'Grup araması' : b.chatTitle)
        : b.peerName;

    // SESLI arama -> eski yesil bant (video yok). GORUNTULU -> yuzen video penceresi.
    if (!b.video) {
      return Stack(children: [widget.child, _sesliBant(c, ad)]);
    }
    return Stack(children: [widget.child, _yuzenVideo(c, ad)]);
  }

  // ---- SESLI ARAMA: ust yesil bant (eski davranis) ----
  Widget _sesliBant(ActiveCallController c, String ad) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: const Color(0xFF25D366),
        child: SafeArea(
          bottom: false,
          child: InkWell(
            onTap: c.restore,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                const Icon(LucideIcons.phone, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 13,
                  backgroundColor: Colors.white24,
                  child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ad,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      const Text('Aramaya dönmek için dokun',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                Text(c.durumMetni,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ---- GORUNTULU ARAMA: suruklenebilir yuzen video penceresi ----
  Widget _yuzenVideo(ActiveCallController c, String ad) {
    final ekran = MediaQuery.of(context).size;
    final guvenli = MediaQuery.of(context).padding;
    // Ilk konum: sag-ust (durum cubugu + bir miktar bosluk altinda)
    final pos = _pos ??
        Offset(ekran.width - _w - 12, guvenli.top + 12);
    final video = c.bantVideo; // uzak video (grup: aktif konusan); yoksa avatar

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        // Surukle: pencereyi tasi (ekran icinde tut)
        onPanUpdate: (d) {
          final ny = (pos.dy + d.delta.dy)
              .clamp(guvenli.top + 4, ekran.height - _h - guvenli.bottom - 4);
          final nx = (pos.dx + d.delta.dx).clamp(4.0, ekran.width - _w - 4);
          setState(() => _pos = Offset(nx.toDouble(), ny.toDouble()));
        },
        // Videoya dokun -> aramaya don
        onTap: c.restore,
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF0B141A),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: _w,
              height: _h,
              child: Stack(fit: StackFit.expand, children: [
                // Video VEYA avatar (karsi kamera kapali/ses akisi)
                if (video != null)
                  lk.VideoTrackRenderer(video,
                      key: ValueKey('bant-${video.mediaStreamTrack.id}'),
                      fit: lk.VideoViewFit.cover)
                else
                  _bantAvatar(ad),
                // Ust: isim + CANLI sure (okunur olsun diye koyu serit)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Row(children: [
                      Expanded(
                        child: Text(ad,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                      Text(c.durumMetni,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                    ]),
                  ),
                ),
                // Alt: kontrol butonlari (mic / kapat) — WhatsApp mini kontrol
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      _miniBtn(
                        c.micOn ? LucideIcons.mic : LucideIcons.micOff,
                        c.micOn ? Colors.white : Colors.redAccent,
                        c.toggleMic,
                      ),
                      _miniBtn(LucideIcons.phoneOff, Colors.white,
                          () => c.leave(notifyServer: true),
                          arka: Colors.redAccent),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, Color renk, VoidCallback onTap, {Color? arka}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: arka ?? Colors.white24),
        child: Icon(icon, color: renk, size: 16),
      ),
    );
  }

  Widget _bantAvatar(String ad) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0B2E), Color(0xFF0B141A)],
        ),
      ),
      alignment: Alignment.center,
      child: CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFF6C2BD9),
        child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontSize: 22)),
      ),
    );
  }
}
